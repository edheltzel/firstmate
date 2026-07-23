#!/usr/bin/env bash
# Host-owned broker for an opted-in GitHub PR identity.
#
# The worker sees only this command and non-secret task metadata. The broker
# resolves one credential definition, authenticates the expected GitHub login,
# binds operations to the recorded repository and task branch, and exposes only
# preflight, push, create, verify, read, and merge-assert operations.
#
# A same-user worker can still inspect the host environment, so this is an
# operational guardrail against accidental identity drift and wrong-repository
# publication, not OS-level credential isolation. The token is never placed in
# argv, task metadata, worker environment, status, logs, or a generated file.
#
# Usage:
#   fm-pr-identity.sh preflight <task-id> <project-key> <project-dir>
#   fm-pr-identity.sh push <task-id>
#   fm-pr-identity.sh create <task-id> <title-file> <body-file>
#   fm-pr-identity.sh verify <task-id> <pr-url>
#   fm-pr-identity.sh read <task-id> <pr-url>
#   fm-pr-identity.sh merge-assert <task-id> <pr-url>
#   fm-pr-identity.sh reconcile <task-id> <pr-url>
#   fm-pr-identity.sh reset <task-id> --confirm-no-pr
#
# Failure categories are stable prefixes for automation: credential-*,
# signing-policy, commits, commit-attribution, repository, branch, pr-mismatch,
# read-auth, verify, publication-state, retry-unsafe, concurrent, and state-write.
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
TEST_MODE=${FM_PR_IDENTITY_TEST_MODE:-0}
if [ "$TEST_MODE" = 1 ]; then
  GH_AXI="${FM_PR_IDENTITY_GH_AXI:-gh-axi}"
  ATLAS_ENV_FILE="${FM_ATLAS_ENV_FILE:-${HOME:-}/.env}"
else
  GH_AXI=gh-axi
  ATLAS_ENV_FILE="${HOME:-}/.env"
fi
EXPECTED_LOGIN=Atlas-Key
EXPECTED_AUTHOR_NAME=Atlas
EXPECTED_AUTHOR_EMAIL=atlas@rainyday.media
PROFILE=atlas-pat
GH_AXI_SUPPORTED_VERSION=0.1.27
PAT=
ATLAS_API_STATUS=unknown
HOST_COMMIT_ERROR=unknown
LOCK_DIR=
LOCK_PROCESS=
TMP_FILE=
META=
META_PROFILE=
META_PROJECT_KEY=
META_REPO=
META_BRANCH=
META_BASE=
META_WORKTREE=
META_HEAD=
META_BINDING=
META_BINDING_PROFILE=
META_BINDING_PROJECT_KEY=
META_BINDING_REPO=
META_BINDING_BRANCH=
META_BINDING_BASE=
META_BINDING_PROJECT=

# shellcheck source=bin/fm-pr-lib.sh disable=SC1091
. "$SCRIPT_DIR/fm-pr-lib.sh"

usage() {
  sed -n 's/^# \{0,1\}//p' "$0" | sed -n '/^Host-owned broker for/,$p' | head -25
}

fail() {
  printf 'error[%s]: %s; remote=%s; retry=%s\n' "$1" "$4" "$2" "$3" >&2
  exit 1
}

reject_runtime_overrides() {
  [ "$TEST_MODE" = 1 ] && return 0
  [ -z "${FM_ROOT_OVERRIDE:-}" ] || fail metadata unknown no "production broker rejects FM_ROOT_OVERRIDE"
  [ -z "${FM_STATE_OVERRIDE:-}" ] || fail metadata unknown no "production broker rejects FM_STATE_OVERRIDE"
  [ -z "${FM_DATA_OVERRIDE:-}" ] || fail metadata unknown no "production broker rejects FM_DATA_OVERRIDE"
}

reject_runtime_overrides

cleanup() {
  [ -z "$TMP_FILE" ] || rm -f -- "$TMP_FILE"
  [ -z "$LOCK_DIR" ] || [ "$LOCK_PROCESS" != "${BASHPID:-$$}" ] \
    || rmdir "$LOCK_DIR" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

task_valid() {
  local id=${1-}
  fm_pr_task_id_valid "$id" && [ "${#id}" -le 64 ]
}

safe_branch() {
  case "${1-}" in
    ''|/*|*..*|*@*|*[!A-Za-z0-9._/-]*) return 1 ;;
  esac
}

safe_project_key() {
  case "${1-}" in ''|*[!A-Za-z0-9._-]*) return 1 ;; esac
}

repo_valid() {
  local repo=${1-} owner name
  owner=${repo%%/*}
  name=${repo#*/}
  [ "$owner" != "$repo" ] || return 1
  case "$owner" in ''|*[!A-Za-z0-9-]*|-*|*-|*--*) return 1 ;; esac
  case "$name" in ''|.|..|*[!A-Za-z0-9._-]*) return 1 ;; esac
  [ "${#owner}" -le 39 ] && [ "${#name}" -le 100 ]
}

metadata_value() {
  local file=$1 key=$2
  awk -F= -v wanted="$key" '$1 == wanted { value=$0; sub(/^[^=]*=/, "", value); print value; exit }' "$file"
}

metadata_count() {
  local file=$1 key=$2
  awk -F= -v wanted="$key" '$1 == wanted { count++ } END { print count + 0 }' "$file"
}

repo_from_remote() {
  local dir=$1 raw repo
  raw=$(git -C "$dir" remote get-url origin 2>/dev/null) || return 1
  case "$raw" in
    git@github.com:*.git) repo=${raw#git@github.com:}; repo=${repo%.git} ;;
    git@github.com:*) repo=${raw#git@github.com:} ;;
    https://github.com/*.git) repo=${raw#https://github.com/}; repo=${repo%.git} ;;
    https://github.com/*) repo=${raw#https://github.com/} ;;
    *) return 1 ;;
  esac
  repo_valid "$repo" || return 1
  printf '%s\n' "$repo"
}

default_branch() {
  local dir=$1 ref branch
  ref=$(git -C "$dir" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
  if [ -n "$ref" ]; then
    printf '%s\n' "${ref#origin/}"
    return 0
  fi
  for branch in main master; do
    if git -C "$dir" show-ref --verify --quiet "refs/heads/$branch"; then
      printf '%s\n' "$branch"
      return 0
    fi
  done
  return 1
}

load_pat() {
  local env_file="$ATLAS_ENV_FILE" line candidate value count=0
  PAT=
  [ -f "$env_file" ] && [ ! -L "$env_file" ] || fail credential-missing none no "Atlas credential file is unavailable"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|\#*) continue ;;
      'export '*) candidate=${line#export } ;;
      *) candidate=$line ;;
    esac
    case "$candidate" in
      ATLAS_KEY_PAT=*)
        count=$((count + 1))
        value=${candidate#ATLAS_KEY_PAT=}
        case "$value" in ''|*[!A-Za-z0-9._:/+%-]*) fail credential-malformed none no "Atlas credential assignment is malformed" ;; esac
        PAT=$value
        ;;
      *ATLAS_KEY_PAT=*) fail credential-malformed none no "Atlas credential assignment is malformed" ;;
    esac
  done < "$env_file"
  [ "$count" -eq 1 ] || {
    [ "$count" -eq 0 ] && fail credential-missing none no "exactly one Atlas credential assignment is required"
    fail credential-duplicate none no "exactly one Atlas credential assignment is required"
  }
}

atlas_api() {
  local endpoint=$1 output_file=${2:-} output status
  ATLAS_API_STATUS=transport
  if output=$(env -u GH_TOKEN -u GITHUB_TOKEN -u GH_ENTERPRISE_TOKEN -u GH_HOST \
    GH_TOKEN="$PAT" "$GH_AXI" api "$endpoint" 2>&1); then
    ATLAS_API_STATUS=200
    if [ -n "$output_file" ]; then
      printf '%s\n' "$output" > "$output_file"
    else
      printf '%s\n' "$output"
    fi
    return 0
  fi
  status=$(printf '%s\n' "$output" | sed -n 's/.*HTTP \([0-9][0-9][0-9]\).*/\1/p' | tail -1 || true)
  [ -n "$status" ] && ATLAS_API_STATUS=$status
  return 1
}

host_api() {
  env -u GH_TOKEN -u GITHUB_TOKEN -u GH_ENTERPRISE_TOKEN -u GH_HOST \
    "$GH_AXI" api "$1" 2>/dev/null
}

host_api_request() {
  env -u GH_TOKEN -u GITHUB_TOKEN -u GH_ENTERPRISE_TOKEN -u GH_HOST \
    "$GH_AXI" api "$@" 2>/dev/null
}

require_gh_axi_contract() {
  local version
  version=$("$GH_AXI" --version 2>/dev/null) \
    || fail dependency unknown no "supported gh-axi version could not be verified"
  [ "$version" = "$GH_AXI_SUPPORTED_VERSION" ] \
    || fail dependency unknown no "unsupported gh-axi version; expected $GH_AXI_SUPPORTED_VERSION"
}

verify_atlas_access() {
  local repo=$1 response login permission
  response=$(atlas_api /user) || fail credential-auth none no "Atlas credential authentication failed"
  login=$(fm_pr_toon_scalar "$response" login)
  [ "$login" = "$EXPECTED_LOGIN" ] || fail credential-identity none no "Atlas credential did not authenticate as the expected login"
  response=$(atlas_api "/repos/$repo/collaborators/$EXPECTED_LOGIN/permission") \
    || fail credential-capability none no "Atlas credential capability could not be verified"
  permission=$(fm_pr_toon_scalar "$response" permission)
  case "$permission" in admin|maintain|write) ;; *) fail credential-capability none no "Atlas credential lacks repository write capability" ;; esac
}

verify_unsigned_policy() {
  local repo=$1 base=$2 response enabled response_file
  response_file=$(mktemp "$STATE/.fm-atlas-policy.XXXXXX") \
    || fail state-write unknown no "repository signing policy response is unavailable"
  if ! atlas_api "/repos/$repo/branches/$base/protection/required_signatures" "$response_file"; then
    rm -f -- "$response_file"
    # GitHub documents 404 from this optional sub-resource as no required
    # signature policy for the branch. Forbidden, authentication, malformed,
    # and server failures remain unknown and therefore refuse publication.
    [ "$ATLAS_API_STATUS" = 404 ] \
      || fail signing-policy unknown no "repository unsigned-signing policy could not be verified"
    return 0
  fi
  response=$(cat "$response_file") || {
    rm -f -- "$response_file"
    fail signing-policy unknown no "repository signing policy response could not be read"
  }
  rm -f -- "$response_file"
  enabled=$(fm_pr_toon_scalar "$response" enabled)
  case "$enabled" in
    false|False|0) ;;
    true|True|1) fail signing-policy none no "repository requires signed commits but this profile is unsigned" ;;
    *) fail signing-policy unknown no "repository signing policy response was not explicit" ;;
  esac
}

preflight() {
  local id=$1 project_key=$2 project_dir=$3 profile repo base project_real
  require_gh_axi_contract
  task_valid "$id" || fail metadata none no "invalid task identity"
  safe_project_key "$project_key" || fail metadata none no "invalid canonical project key"
  [ -d "$project_dir" ] && [ ! -L "$project_dir" ] || fail metadata none no "project checkout is unavailable"
  profile=$(env FM_HOME="$FM_HOME" FM_DATA_OVERRIDE="${FM_DATA_OVERRIDE:-$FM_HOME/data}" \
    "$FM_ROOT/bin/fm-project-mode.sh" --pr-identity "$project_key" 2>/dev/null) \
    || fail profile none no "project identity profile is invalid or local-only"
  [ "$profile" = "$PROFILE" ] || {
    [ "$profile" = none ] && fail profile none no "project has no Atlas identity opt-in"
    fail profile none no "project identity profile is unsupported"
  }
  repo=$(repo_from_remote "$project_dir") || fail repository none no "project origin is not an exact GitHub repository"
  base=$(default_branch "$project_dir") || fail repository none no "project default branch is unavailable"
  safe_branch "$base" || fail repository none no "project default branch is invalid"
  load_pat
  verify_atlas_access "$repo"
  verify_unsigned_policy "$repo" "$base"
  project_real=$(cd "$project_dir" 2>/dev/null && pwd -P) \
    || fail repository none no "project checkout path could not be canonicalized"
  write_binding "$id" "$project_key" "$repo" "fm/$id" "$base" "$project_real"
  printf 'profile=%s\nrepo=%s\nbranch=fm/%s\nbase=%s\n' "$PROFILE" "$repo" "$id" "$base"
}

write_binding() {
  local id=$1 project_key=$2 repo=$3 branch=$4 base=$5 worktree=$6 tmp
  mkdir -p "$STATE" || fail state-write unknown no "task state is unavailable"
  tmp=$(mktemp "$STATE/.fm-pr-binding.$id.XXXXXX") \
    || fail state-write unknown no "identity binding is unavailable"
  TMP_FILE=$tmp
  umask 077
  {
    printf 'version=1\n'
    printf 'task=%s\nprofile=%s\nproject_key=%s\nrepo=%s\nbranch=%s\nbase=%s\nproject=%s\n' \
      "$id" "$PROFILE" "$project_key" "$repo" "$branch" "$base" "$worktree"
  } > "$tmp" || fail state-write unknown no "identity binding could not be written"
  chmod 0600 "$tmp" || fail state-write unknown no "identity binding could not be protected"
  mv -f -- "$tmp" "$STATE/$id.pr-binding" \
    || fail state-write unknown no "identity binding could not be committed"
  TMP_FILE=
}

load_binding() {
  local id=$1 value
  META_BINDING="$STATE/$id.pr-binding"
  [ -f "$META_BINDING" ] && [ ! -L "$META_BINDING" ] \
    || fail metadata unknown no "host identity binding is unavailable"
  value=$(stat -f %l "$META_BINDING" 2>/dev/null || stat -c %h "$META_BINDING" 2>/dev/null)
  [ "$value" = 1 ] || fail metadata unknown no "host identity binding is unsafe"
  for value in version task profile project_key repo branch base project; do
    [ "$(metadata_count "$META_BINDING" "$value")" -eq 1 ] \
      || fail metadata unknown no "host identity binding has duplicate or missing fields"
  done
  [ "$(metadata_value "$META_BINDING" version)" = 1 ] \
    || fail metadata unknown no "host identity binding version is unsupported"
  [ "$(metadata_value "$META_BINDING" task)" = "$id" ] \
    || fail metadata unknown no "host identity binding task is inconsistent"
  META_BINDING_PROFILE=$(metadata_value "$META_BINDING" profile)
  META_BINDING_PROJECT_KEY=$(metadata_value "$META_BINDING" project_key)
  META_BINDING_REPO=$(metadata_value "$META_BINDING" repo)
  META_BINDING_BRANCH=$(metadata_value "$META_BINDING" branch)
  META_BINDING_BASE=$(metadata_value "$META_BINDING" base)
  META_BINDING_PROJECT=$(metadata_value "$META_BINDING" project)
  [ "$META_BINDING_PROFILE" = "$PROFILE" ] \
    || fail profile unknown no "host identity binding is not the Atlas broker profile"
  safe_project_key "$META_BINDING_PROJECT_KEY" \
    || fail metadata unknown no "host identity binding project identity is invalid"
  repo_valid "$META_BINDING_REPO" \
    || fail metadata unknown no "host identity binding repository is invalid"
  [ "$META_BINDING_BRANCH" = "fm/$id" ] \
    || fail branch none no "host identity binding branch does not match the task identity"
  safe_branch "$META_BINDING_BASE" \
    || fail metadata unknown no "host identity binding base branch is invalid"
  [ -d "$META_BINDING_PROJECT" ] && [ ! -L "$META_BINDING_PROJECT" ] \
    || fail metadata unknown no "host identity binding project is unavailable"
}

load_metadata() {
  local id=$1 value current_profile
  task_valid "$id" || fail metadata unknown no "invalid task identity"
  load_binding "$id"
  META="$STATE/$id.meta"
  [ -f "$META" ] && [ ! -L "$META" ] || fail metadata unknown no "task metadata is unavailable"
  value=$(stat -f %l "$META" 2>/dev/null || stat -c %h "$META" 2>/dev/null)
  [ "$value" = 1 ] || fail metadata unknown no "task metadata is unsafe"
  for value in pr_identity pr_project_key pr_repo pr_branch pr_base project worktree; do
    [ "$(metadata_count "$META" "$value")" -eq 1 ] || fail metadata unknown no "task metadata has duplicate or missing identity fields"
  done
  META_PROFILE=$(metadata_value "$META" pr_identity)
  META_PROJECT_KEY=$(metadata_value "$META" pr_project_key)
  META_REPO=$(metadata_value "$META" pr_repo)
  META_BRANCH=$(metadata_value "$META" pr_branch)
  META_BASE=$(metadata_value "$META" pr_base)
  META_WORKTREE=$(metadata_value "$META" worktree)
  [ "$META_PROFILE" = "$META_BINDING_PROFILE" ] \
    || fail profile unknown no "task metadata disagrees with the host identity binding"
  [ "$META_PROJECT_KEY" = "$META_BINDING_PROJECT_KEY" ] \
    || fail metadata unknown no "task metadata disagrees with the host project binding"
  [ "$META_REPO" = "$META_BINDING_REPO" ] \
    || fail repository unknown no "task metadata disagrees with the host repository binding"
  [ "$META_BRANCH" = "$META_BINDING_BRANCH" ] \
    || fail branch none no "task metadata disagrees with the host branch binding"
  [ "$META_BASE" = "$META_BINDING_BASE" ] \
    || fail metadata unknown no "task metadata disagrees with the host base binding"
  META_PROJECT=$(metadata_value "$META" project)
  value=$(cd "$META_PROJECT" 2>/dev/null && pwd -P) \
    || fail metadata unknown no "task metadata project path is unavailable"
  [ "$value" = "$META_BINDING_PROJECT" ] \
    || fail metadata unknown no "task metadata disagrees with the host project binding"
  profile_data_override=${FM_DATA_OVERRIDE:-$FM_HOME/data}
  current_profile=$(env FM_HOME="$FM_HOME" FM_DATA_OVERRIDE="$profile_data_override" \
    "$FM_ROOT/bin/fm-project-mode.sh" --pr-identity "$META_PROJECT_KEY" 2>/dev/null) \
    || fail profile unknown no "current project identity policy could not be verified"
  [ "$current_profile" = "$PROFILE" ] \
    || fail profile unknown no "current project identity policy no longer authorizes the Atlas broker"
  [ "$META_PROFILE" = "$PROFILE" ] || fail profile unknown no "task is not bound to the Atlas broker profile"
  safe_project_key "$META_PROJECT_KEY" || fail metadata unknown no "task project identity is invalid"
  repo_valid "$META_REPO" || fail metadata unknown no "task repository binding is invalid"
  [ "$META_BRANCH" = "fm/$id" ] || fail branch none no "task branch binding does not match the task identity"
  safe_branch "$META_BASE" || fail metadata unknown no "task base branch binding is invalid"
  [ -d "$META_WORKTREE" ] && [ ! -L "$META_WORKTREE" ] || fail metadata unknown no "task worktree is unavailable"
  value=$(cd "$META_WORKTREE" 2>/dev/null && pwd -P) || fail metadata unknown no "task worktree is not a Git checkout"
  [ "$value" = "$(git -C "$META_WORKTREE" rev-parse --show-toplevel 2>/dev/null)" ] || fail metadata unknown no "task worktree path is not canonical"
  value=$(repo_from_remote "$META_WORKTREE") || fail repository unknown no "task origin is not an exact GitHub repository"
  [ "$value" = "$META_REPO" ] || fail repository unknown no "task origin differs from its recorded repository"
}

acquire_lock() {
  local id=$1
  mkdir -p "$STATE" || fail state-write unknown no "task state is unavailable"
  LOCK_DIR="$STATE/.fm-pr-identity-$id.lock"
  mkdir "$LOCK_DIR" 2>/dev/null || fail concurrent unknown no "another broker operation owns this task"
  chmod 0700 "$LOCK_DIR" || fail concurrent unknown no "task broker lock is unsafe"
  LOCK_PROCESS=${BASHPID:-$$}
}

write_record() {
  local id=$1 remote=$2 pr_state=$3 head=$4 url=$5 category=$6 retry=$7 tmp
  mkdir -p "$STATE" || fail state-write "$remote" no "task state is unavailable"
  tmp=$(mktemp "$STATE/.fm-pr-publication.$id.XXXXXX") || fail state-write "$remote" no "publication record is unavailable"
  TMP_FILE=$tmp
  umask 077
  {
    printf 'version=1\n'
    printf 'task=%s\nprofile=%s\nproject_key=%s\nrepo=%s\nbranch=%s\nbase=%s\n' \
      "$id" "$META_PROFILE" "$META_PROJECT_KEY" "$META_REPO" "$META_BRANCH" "$META_BASE"
    printf 'head=%s\nremote_state=%s\npr_state=%s\npr_url=%s\nerror_category=%s\nretry_safe=%s\n' \
      "$head" "$remote" "$pr_state" "$url" "$category" "$retry"
  } > "$tmp" || fail state-write "$remote" no "publication record could not be written"
  chmod 0600 "$tmp" || fail state-write "$remote" no "publication record could not be protected"
  mv -f -- "$tmp" "$STATE/$id.pr-publication" || fail state-write "$remote" no "publication record could not be committed"
  TMP_FILE=
}

load_commit_binding() {
  local base_ref commit author_name author_email committer_name committer_email signed
  base_ref=$(git -C "$META_WORKTREE" rev-parse --verify "refs/remotes/origin/$META_BASE" 2>/dev/null || \
    git -C "$META_WORKTREE" rev-parse --verify "refs/heads/$META_BASE" 2>/dev/null) \
    || fail commits unknown no "task base branch cannot be resolved locally"
  META_HEAD=$(git -C "$META_WORKTREE" rev-parse --verify HEAD 2>/dev/null) || fail commits unknown no "task head cannot be resolved"
  [ -z "$(git -C "$META_WORKTREE" status --porcelain 2>/dev/null)" ] || fail commits none no "task worktree has uncommitted changes"
  git -C "$META_WORKTREE" rev-list "$base_ref..HEAD" 2>/dev/null | grep -q . \
    || fail commits none no "task branch has no commits beyond its base"
  while IFS=$(printf '\t') read -r commit author_name author_email committer_name committer_email; do
    [ -n "$commit" ] || continue
    [ "$author_name" = "$EXPECTED_AUTHOR_NAME" ] && [ "$author_email" = "$EXPECTED_AUTHOR_EMAIL" ] \
      || fail commit-attribution none no "a task commit is not attributed to Atlas"
    [ "$committer_name" = "$EXPECTED_AUTHOR_NAME" ] && [ "$committer_email" = "$EXPECTED_AUTHOR_EMAIL" ] \
      || fail commit-attribution none no "a task committer is not attributed to Atlas"
    signed=$(git -C "$META_WORKTREE" cat-file commit "$commit" 2>/dev/null | grep -c '^gpgsig ' || true)
    [ "$signed" -eq 0 ] || fail signing-policy none no "a task commit contains a signature under the unsigned policy"
  done <<EOF
$(git -C "$META_WORKTREE" log --format='%H%x09%an%x09%ae%x09%cn%x09%ce' "$base_ref..HEAD" 2>/dev/null)
EOF
  printf '%s\n' "$base_ref"
}

git_auth_command() {
  local remote=$1
  shift
  # The empty helper value clears inherited helpers before this inline helper.
  # shellcheck disable=SC2016
  GIT_TERMINAL_PROMPT=0 GIT_ASKPASS='' \
    FM_PR_IDENTITY_PUSH_TOKEN="$PAT" FM_PR_IDENTITY_PUSH_REPO="$META_REPO" git -C "$META_WORKTREE" \
    -c credential.helper= \
    -c 'credential.helper=!f() { protocol=; host=; path=; while IFS= read -r line || [ -n "$line" ]; do case "$line" in protocol=*) protocol=${line#protocol=} ;; host=*) host=${line#host=} ;; path=*) path=${line#path=} ;; esac; done; path=${path%.git}; [ "$protocol" = https ] && [ "$host" = github.com ] && [ "$path" = "$FM_PR_IDENTITY_PUSH_REPO" ] && [ -n "$FM_PR_IDENTITY_PUSH_TOKEN" ] || exit 1; printf "username=x-access-token\\npassword=%s\\n\\n" "$FM_PR_IDENTITY_PUSH_TOKEN"; }; f' \
    -c credential.useHttpPath=true -c "remote.origin.pushurl=$remote" "$@"
}

push_task() {
  local id=$1 base_ref remote remote_head
  require_gh_axi_contract
  load_metadata "$id"
  acquire_lock "$id"
  publication_retry_gate "$id"
  load_pat
  verify_atlas_access "$META_REPO"
  verify_unsigned_policy "$META_REPO" "$META_BASE"
  base_ref=$(load_commit_binding)
  META_HEAD=$(git -C "$META_WORKTREE" rev-parse --verify HEAD 2>/dev/null) || fail commits unknown no "task head cannot be resolved"
  [ "$(git -C "$META_WORKTREE" branch --show-current 2>/dev/null)" = "$META_BRANCH" ] \
    || fail branch none no "task checkout is not on its recorded branch"
  [ "$META_BRANCH" != "$META_BASE" ] || fail branch none no "default-branch publication is forbidden"
  remote="https://github.com/$META_REPO.git"
  if ! git_auth_command "$remote" push origin "$META_BRANCH:$META_BRANCH" >/dev/null 2>/dev/null; then
    write_record "$id" unknown unknown "$META_HEAD" "" transport no
    fail transport unknown no "host-controlled HTTPS push failed"
  fi
  remote_head=$(git_auth_command "$remote" ls-remote "$remote" "refs/heads/$META_BRANCH" 2>/dev/null | awk 'NR == 1 { print $1; exit }') || {
    write_record "$id" unknown unknown "$META_HEAD" "" remote-verify no
    fail remote-verify unknown no "pushed branch could not be read back"
  }
  fm_pr_head_valid "$remote_head" || {
    write_record "$id" unknown unknown "$META_HEAD" "" remote-verify no
    fail remote-verify unknown no "remote branch returned an invalid head"
  }
  [ "$remote_head" = "$META_HEAD" ] || {
    write_record "$id" conflict unknown "$META_HEAD" "" remote-verify no
    fail remote-verify conflict no "remote branch head differs from the verified local head"
  }
  write_record "$id" pushed pushed "$META_HEAD" "" none yes
  printf 'pushed: repo=%s branch=%s head=%s\n' "$META_REPO" "$META_BRANCH" "$META_HEAD"
}

pr_number_from_url() {
  local url=$1
  fm_pr_url_parse "$url" && [ "$FM_PR_PROVIDER" = github ] && [ "$FM_PR_PATH" = "$META_REPO" ] || return 1
  printf '%s\n' "$FM_PR_NUMBER"
}

read_pr() {
  local id=$1 url=$2 number raw login head_ref head_sha base_ref state merged merged_at expected_head head_line base_line
  require_gh_axi_contract
  load_metadata "$id"
  number=$(pr_number_from_url "$url") || fail pr-mismatch unknown no "PR URL is not the recorded repository"
  raw=$(host_api "/repos/$META_REPO/pulls/$number") || fail read-auth unknown no "host PR read authentication failed"
  login=$(fm_pr_toon_section_scalar "$raw" user login); [ -n "$login" ] || login=$(fm_pr_toon_scalar "$raw" login)
  [ -n "$login" ] || login=$(fm_pr_toon_scalar "$raw" user)
  head_ref=$(fm_pr_toon_section_scalar "$raw" head ref)
  head_sha=$(fm_pr_toon_section_scalar "$raw" head sha)
  base_ref=$(fm_pr_toon_section_scalar "$raw" base ref)
  if [ -z "$head_ref" ] || [ -z "$head_sha" ]; then
    head_line=$(fm_pr_toon_scalar "$raw" head)
    head_ref=${head_line#ref }
    head_ref=${head_ref%%,*}
    head_sha=${head_line#*sha }
  fi
  if [ -z "$base_ref" ]; then
    base_line=$(fm_pr_toon_scalar "$raw" base)
    base_ref=${base_line#ref }
    base_ref=${base_ref%%,*}
  fi
  state=$(fm_pr_toon_scalar "$raw" state)
  merged=$(fm_pr_toon_scalar "$raw" merged)
  merged_at=$(fm_pr_toon_scalar "$raw" merged_at)
  case "$merged" in true|True|1) merged=1 ;; *) merged=0 ;; esac
  case "$merged_at" in null|Null|'<nil>'|'') merged_at= ;; esac
  [ "$merged" = 1 ] || [ -n "$merged_at" ] && merged=1
  [ "$login" = "$EXPECTED_LOGIN" ] || fail pr-mismatch none no "PR author is not Atlas-Key"
  [ "$head_ref" = "$META_BRANCH" ] || fail pr-mismatch none no "PR head branch is not the task branch"
  fm_pr_head_valid "$head_sha" || fail pr-mismatch none no "PR head is invalid"
  [ "$base_ref" = "$META_BASE" ] || fail pr-mismatch none no "PR base branch is not the recorded base"
  expected_head=$(metadata_value "$META" pr_head)
  [ -z "$expected_head" ] || [ "$expected_head" = "$head_sha" ] || fail pr-mismatch none no "PR head changed after identity verification"
  printf 'state=%s\nmerged=%s\nrepo=%s\nbranch=%s\nbase=%s\nhead_sha=%s\nauthor=%s\nurl=https://github.com/%s/pull/%s\n' \
    "$state" "$merged" "$META_REPO" "$head_ref" "$base_ref" "$head_sha" "$login" "$META_REPO" "$number"
}

host_commit_rows() {
  local endpoint=$1 page raw rows count
  HOST_COMMIT_ERROR=unknown
  page=1
  while [ "$page" -le 100 ]; do
    raw=$(host_api "$endpoint?per_page=100&page=$page") || {
      HOST_COMMIT_ERROR=read-auth
      return 1
    }
    count=$(fm_pr_toon_array_count "$raw") || {
      HOST_COMMIT_ERROR=malformed
      return 1
    }
    rows=$(fm_pr_toon_commit_rows <<EOF
$raw
EOF
) || {
      HOST_COMMIT_ERROR=malformed
      return 1
    }
    [ -n "$rows" ] && printf '%s\n' "$rows"
    [ "$count" -eq 0 ] && return 0
    [ "$count" -lt 100 ] && return 0
    [ "$page" -lt 100 ] || {
      HOST_COMMIT_ERROR=pagination
      return 1
    }
    page=$((page + 1))
  done
  HOST_COMMIT_ERROR=pagination
  return 1
}

verification_error() {
  printf 'error[%s]: %s; remote=%s; retry=%s\n' "$1" "$4" "$2" "$3" >&2
  return 1
}

verify_task_commits() {
  local id=$1 number=$2 base_ref local_file remote_file rows_file sha author committer
  if ! base_ref=$(load_commit_binding); then
    verification_error commits unknown no "task commit binding could not be loaded"
    return 1
  fi
  local_file=$(mktemp "$STATE/.fm-atlas-local-commits.XXXXXX") \
    || { verification_error commits unknown no "commit comparison is unavailable"; return 1; }
  remote_file=$(mktemp "$STATE/.fm-atlas-remote-commits.XXXXXX") \
    || { rm -f -- "$local_file"; verification_error commits unknown no "commit comparison is unavailable"; return 1; }
  rows_file=$(mktemp "$STATE/.fm-atlas-remote-rows.XXXXXX") \
    || { rm -f -- "$local_file" "$remote_file"; verification_error commits unknown no "commit comparison is unavailable"; return 1; }
  TMP_FILE=$rows_file
  if ! git -C "$META_WORKTREE" log --format='%H' "$base_ref..HEAD" | sort -u > "$local_file"; then
    rm -f -- "$local_file" "$remote_file" "$rows_file"; TMP_FILE=
    verification_error commits unknown no "local commit set could not be read"
    return 1
  fi
  if ! host_commit_rows "/repos/$META_REPO/pulls/$number/commits" > "$rows_file"; then
    rm -f -- "$local_file" "$remote_file" "$rows_file"; TMP_FILE=
    case "$HOST_COMMIT_ERROR" in
      malformed) verification_error verify-malformed unknown no "PR commit-list response was malformed" ;;
      pagination) verification_error verify-pagination unknown no "PR commit-list pagination could not be completed" ;;
      *) verification_error read-auth unknown no "PR commit-list read authentication failed" ;;
    esac
    return 1
  fi
  cut -f1 "$rows_file" | sed '/^$/d' > "$remote_file"
  if [ ! -s "$remote_file" ]; then
    rm -f -- "$local_file" "$remote_file" "$rows_file"; TMP_FILE=
    verification_error pr-mismatch none no "PR commit list is empty"
    return 1
  fi
  commit_error=
  while IFS=$(printf '\t') read -r sha author committer; do
    if ! fm_pr_head_valid "$sha"; then
      commit_error=invalid-sha
      break
    fi
    if [ "$author" != "$EXPECTED_LOGIN" ] || [ "$committer" != "$EXPECTED_LOGIN" ]; then
      commit_error=attribution
      break
    fi
  done < "$rows_file"
  if [ "$commit_error" = invalid-sha ]; then
    rm -f -- "$local_file" "$remote_file" "$rows_file"; TMP_FILE=
    verification_error pr-mismatch none no "PR commit list contains an invalid SHA"
    return 1
  fi
  if [ "$commit_error" = attribution ]; then
    rm -f -- "$local_file" "$remote_file" "$rows_file"; TMP_FILE=
    verification_error commit-attribution none no "a remote PR commit is not associated with Atlas-Key"
    return 1
  fi
  sort -u -o "$remote_file" "$remote_file"
  if ! cmp -s "$local_file" "$remote_file"; then
    rm -f -- "$local_file" "$remote_file" "$rows_file"; TMP_FILE=
    verification_error pr-mismatch none no "PR commit set differs from the verified task commit set"
    return 1
  fi
  rm -f -- "$local_file" "$remote_file" "$rows_file"
  TMP_FILE=
}

verify_task() {
  local id=$1 url=$2 read_output number head remote_state
  load_metadata "$id"
  acquire_lock "$id"
  read_output=$(read_pr "$id" "$url") || {
    remote_state=$(publication_field "$id" remote_state unknown)
    write_record "$id" "$remote_state" verification-failed "$(publication_field "$id" head unknown)" "$url" read-auth no
    fail read-auth "$remote_state" no "PR identity verification failed; remote state is preserved"
  }
  number=$(pr_number_from_url "$url") || fail pr-mismatch unknown no "PR URL is not the recorded repository"
  if ! verify_task_commits "$id" "$number"; then
    remote_state=$(publication_field "$id" remote_state unknown)
    write_record "$id" "$remote_state" verification-failed "$(publication_field "$id" head unknown)" "$url" verify no
    fail verify "$remote_state" no "PR commit attribution could not be verified; remote state is preserved"
  fi
  head=$(printf '%s\n' "$read_output" | sed -n 's/^head_sha=//p' | head -1)
  write_record "$id" published verified "$head" "$url" none yes
  printf '%s\nverified=1\n' "$read_output"
}

publication_field() {
  local id=$1 key=$2 fallback=$3 file="$STATE/$1.pr-publication" value
  if [ -f "$file" ] && [ ! -L "$file" ]; then
    value=$(metadata_value "$file" "$key")
    [ -n "$value" ] && { printf '%s\n' "$value"; return 0; }
  fi
  printf '%s\n' "$fallback"
}

publication_retry_gate() {
  local id=$1 retry_state remote_state
  retry_state=$(publication_field "$id" retry_safe yes)
  remote_state=$(publication_field "$id" remote_state unknown)
  case "$retry_state" in
    yes) ;;
    no) fail retry-unsafe "$remote_state" no "publication state is retry-unsafe; reconcile or explicitly reset it" ;;
    *) fail publication-state "$remote_state" no "publication record has an invalid retry state" ;;
  esac
}

publication_duplicate_gate() {
  local id=$1 existing_url
  existing_url=$(publication_field "$id" pr_url '')
  [ -z "$existing_url" ] \
    || fail publication-duplicate pushed no "a PR already exists for this task; reconcile it before any create retry"
}

create_task() {
  local id=$1 title_file=$2 body_file=$3 title raw url read_output
  load_metadata "$id"
  acquire_lock "$id"
  publication_retry_gate "$id"
  publication_duplicate_gate "$id"
  [ -f "$title_file" ] && [ ! -L "$title_file" ] || fail input pushed no "PR title file is unavailable"
  [ -f "$body_file" ] && [ ! -L "$body_file" ] || fail input pushed no "PR body file is unavailable"
  title=$(cat "$title_file") || fail input pushed no "PR title could not be read"
  [ -n "$title" ] || fail input pushed no "PR title is empty"
  load_pat
  verify_atlas_access "$META_REPO"
  verify_unsigned_policy "$META_REPO" "$META_BASE"
  load_commit_binding >/dev/null
  grep -qxF 'remote_state=pushed' "$STATE/$id.pr-publication" 2>/dev/null \
    || fail publication-state none no "push must succeed before PR creation"
  raw=$(env -u GH_TOKEN -u GITHUB_TOKEN -u GH_ENTERPRISE_TOKEN -u GH_HOST GH_TOKEN="$PAT" \
    "$GH_AXI" pr create --repo "$META_REPO" --head "$META_BRANCH" --base "$META_BASE" \
    --title "$title" --body-file "$body_file" 2>/dev/null) || {
      write_record "$id" pushed create-failed "$META_HEAD" "" create no
      fail create pushed no "Atlas PR creation failed; the remote branch is preserved"
    }
  url=$(printf '%s\n' "$raw" | grep -Eo 'https://github\.com/[A-Za-z0-9-]+/[A-Za-z0-9._-]+/pull/[1-9][0-9]*' | tail -1 || true)
  fm_pr_url_parse "$url" && [ "$FM_PR_PATH" = "$META_REPO" ] || {
    write_record "$id" pushed create-unattributed "$META_HEAD" "" create no
    fail create pushed no "PR creation returned no attributable repository URL"
  }
  write_record "$id" pushed created "$META_HEAD" "$url" unverified no
  read_output=$(read_pr "$id" "$url") || {
    write_record "$id" pushed verification-failed "$META_HEAD" "$url" verify no
    fail verify pushed no "created PR could not be attributed safely; the remote branch is preserved"
  }
  verify_task_commits "$id" "$FM_PR_NUMBER" || {
    write_record "$id" pushed verification-failed "$META_HEAD" "$url" verify no
    fail verify pushed no "created PR commit set could not be verified; the remote branch is preserved"
  }
  write_record "$id" published verified "$META_HEAD" "$url" none yes
  printf 'created: url=%s\n' "$url"
}

reset_task() {
  local id=$1 confirmation=$2 existing_url
  load_metadata "$id"
  [ "$confirmation" = --confirm-no-pr ] \
    || fail publication-state unknown no "reset requires --confirm-no-pr"
  acquire_lock "$id"
  existing_url=$(publication_field "$id" pr_url '')
  [ -z "$existing_url" ] \
    || fail retry-unsafe pushed no "a PR URL is recorded; reconcile it instead of resetting"
  write_record "$id" unknown reset unknown '' none yes
  printf 'reset: task=%s retry_safe=yes\n' "$id"
}

merge_assert() {
  local id=$1 url=$2 response user_response login state verified_head
  response=$(read_pr "$id" "$url") || exit 1
  user_response=$(host_api /user) \
    || fail merge-auth unknown no "captain merge authentication failed"
  login=$(fm_pr_toon_scalar "$user_response" login)
  [ "$login" = "edheltzel" ] || fail merge-auth none no "merge authority is not Ed"
  state=$(printf '%s\n' "$response" | sed -n 's/^state=//p' | head -1)
  case "$state" in OPEN|open) ;; *) fail merge-auth none no "PR is not open for an Ed-authorized merge" ;; esac
  verified_head=$(printf '%s\n' "$response" | sed -n 's/^head_sha=//p' | head -1)
  fm_pr_head_valid "$verified_head" || fail merge-auth none no "PR did not return a valid merge head"
  printf 'merge-authority=edheltzel\nverified_head=%s\n' "$verified_head"
}

case "${1:-}" in
  preflight)
    [ "$#" -eq 4 ] || { usage >&2; exit 2; }
    preflight "$2" "$3" "$4"
    ;;
  push)
    [ "$#" -eq 2 ] || { usage >&2; exit 2; }
    push_task "$2"
    ;;
  create)
    [ "$#" -eq 4 ] || { usage >&2; exit 2; }
    create_task "$2" "$3" "$4"
    ;;
  verify|read|merge-assert)
    [ "$#" -eq 3 ] || { usage >&2; exit 2; }
    case "$1" in
      verify) verify_task "$2" "$3" ;;
      read) read_pr "$2" "$3" ;;
      merge-assert) merge_assert "$2" "$3" ;;
    esac
    ;;
  reconcile)
    [ "$#" -eq 3 ] || { usage >&2; exit 2; }
    verify_task "$2" "$3"
    ;;
  reset)
    [ "$#" -eq 3 ] || { usage >&2; exit 2; }
    reset_task "$2" "$3"
    ;;
  --help|-h)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
