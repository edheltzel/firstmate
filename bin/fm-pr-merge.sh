#!/usr/bin/env bash
# Merge a task's PR after recording pr= and any available pr_head= through
# bin/fm-pr-check.sh, so teardown can verify landed work after squash merges.
# The full canonical GitHub PR URL is parsed by bin/fm-pr-lib.sh and the derived
# owner/repository and PR number are passed to gh-axi as separate arguments.
#
# Merge method defaults to --squash when the caller passes none of --squash,
# --merge, --rebase, or --method after the optional -- separator. Extra args
# must not include --repo or -R because the repository comes only from the URL.
# Usage: fm-pr-merge.sh <task-id> <pr-url> [-- <extra gh-axi pr merge args>]
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"

# shellcheck source=bin/fm-pr-lib.sh
. "$SCRIPT_DIR/fm-pr-lib.sh"

if [ "$#" -lt 2 ]; then
  echo "error: invalid PR merge request" >&2
  exit 2
fi
ID=$1
RAW_URL=$2
# bin/fm-pr-lib.sh parses GitLab merge request URLs so the watcher can follow
# them, but this path still addresses only GitHub by owner/repository. The
# provider check holds that refusal exactly as it was until merge parity lands.
if ! fm_pr_task_id_valid "$ID" || ! fm_pr_url_parse "$RAW_URL" \
  || [ "$FM_PR_PROVIDER" != github ]; then
  echo "error: invalid PR merge request" >&2
  exit 2
fi
URL=$FM_PR_URL
PR_OWNER=$FM_PR_OWNER
PR_REPO=$FM_PR_REPO
PR_NUMBER=$FM_PR_NUMBER
shift 2
[ "${1:-}" = "--" ] && shift

caller_has_merge_method() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --squash|--merge|--rebase|--method|--method=*) return 0 ;;
    esac
  done
  return 1
}

atlas_rest_merge() {
  local verified_head=$1 method=squash method_seen=0 body='' body_set=0 subject='' subject_set=0 delete_branch=0 arg value
  shift
  while [ "$#" -gt 0 ]; do
    arg=$1
    case "$arg" in
      --merge|--squash|--rebase)
        value=${arg#--}
        if [ "$method_seen" -eq 1 ] && [ "$method" != "$value" ]; then
          echo "error: choose only one Atlas REST merge method" >&2
          return 1
        fi
        method=$value
        method_seen=1
        ;;
      --method)
        [ "$#" -ge 2 ] || { echo "error: --method requires a value" >&2; return 1; }
        value=$2
        shift
        case "$value" in merge|squash|rebase) ;; *) echo "error: unsupported Atlas REST merge method" >&2; return 1 ;; esac
        if [ "$method_seen" -eq 1 ] && [ "$method" != "$value" ]; then
          echo "error: choose only one Atlas REST merge method" >&2
          return 1
        fi
        method=$value
        method_seen=1
        ;;
      --method=*)
        value=${arg#--method=}
        case "$value" in merge|squash|rebase) ;; *) echo "error: unsupported Atlas REST merge method" >&2; return 1 ;; esac
        if [ "$method_seen" -eq 1 ] && [ "$method" != "$value" ]; then
          echo "error: choose only one Atlas REST merge method" >&2
          return 1
        fi
        method=$value
        method_seen=1
        ;;
      --body)
        [ "$#" -ge 2 ] || { echo "error: --body requires a value" >&2; return 1; }
        body=$2
        body_set=1
        shift
        ;;
      --body=*)
        body=${arg#--body=}
        body_set=1
        ;;
      --body-file)
        [ "$#" -ge 2 ] || { echo "error: --body-file requires a path" >&2; return 1; }
        [ -f "$2" ] && [ ! -L "$2" ] || { echo "error: Atlas merge body file is unavailable" >&2; return 1; }
        body=$(cat "$2") || return 1
        body_set=1
        shift
        ;;
      --body-file=*)
        value=${arg#--body-file=}
        [ -f "$value" ] && [ ! -L "$value" ] || { echo "error: Atlas merge body file is unavailable" >&2; return 1; }
        body=$(cat "$value") || return 1
        body_set=1
        ;;
      --subject)
        [ "$#" -ge 2 ] || { echo "error: --subject requires a value" >&2; return 1; }
        subject=$2
        subject_set=1
        shift
        ;;
      --subject=*)
        subject=${arg#--subject=}
        subject_set=1
        ;;
      --delete-branch)
        delete_branch=1
        ;;
      --auto)
        echo "error: Atlas REST merge does not support --auto; use an explicit merge method" >&2
        return 1
        ;;
      *)
        echo "error: unsupported Atlas REST merge argument: $arg" >&2
        return 1
        ;;
    esac
    shift
  done

  rest_args=(PUT "/repos/$PR_OWNER/$PR_REPO/pulls/$PR_NUMBER/merge" --field "sha=$verified_head" --field "merge_method=$method")
  [ "$body_set" -eq 0 ] || rest_args+=(--field "commit_message=$body")
  [ "$subject_set" -eq 0 ] || rest_args+=(--field "commit_title=$subject")
  env -u GH_TOKEN -u GITHUB_TOKEN -u GH_ENTERPRISE_TOKEN -u GH_HOST \
    gh-axi api "${rest_args[@]}" >/dev/null 2>/dev/null || return 1
  if [ "$delete_branch" -eq 1 ]; then
    env -u GH_TOKEN -u GITHUB_TOKEN -u GH_ENTERPRISE_TOKEN -u GH_HOST \
      gh-axi api DELETE "/repos/$PR_OWNER/$PR_REPO/git/refs/heads/$META_BRANCH" >/dev/null 2>/dev/null || return 1
  fi
}

reject_repo_overrides() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --repo|--repo=*|-R|-R?*)
        echo "error: extra merge arguments must not override the repository" >&2
        return 1
        ;;
    esac
  done
}

reject_repo_overrides "$@" || exit 1

# Task-derived paths are constructed only after the canonical ID validation.
META="$STATE/$ID.meta"
if [ ! -f "$META" ] || [ -L "$META" ]; then
  echo "error: task metadata is unavailable" >&2
  exit 1
fi

"$SCRIPT_DIR/fm-pr-check.sh" "$ID" "$URL"
grep -qxF "pr=$URL" "$META" || {
  echo "error: PR metadata recording failed" >&2
  exit 1
}

merge_args=()
if ! caller_has_merge_method "$@"; then
  merge_args=(--squash)
fi

PR_IDENTITY=$(grep '^pr_identity=' "$META" | tail -1 | cut -d= -f2- || true)
BINDING="$STATE/$ID.pr-binding"
META_BRANCH=$(grep '^pr_branch=' "$META" | tail -1 | cut -d= -f2- || true)
if [ -e "$BINDING" ] || [ -L "$BINDING" ]; then
  PR_IDENTITY=$(fm_pr_binding_profile "$BINDING") || { echo "error: invalid host identity binding" >&2; exit 1; }
  [ "$PR_IDENTITY" = atlas-pat ] || { echo "error: unsupported host identity binding" >&2; exit 1; }
elif [ -n "$PR_IDENTITY" ]; then
  echo "error: opted-in task has no host identity binding" >&2
  exit 1
fi
if [ "$PR_IDENTITY" = atlas-pat ]; then
  MERGE_ASSERT_OUTPUT=
  if [ "${FM_PR_IDENTITY_TEST_MODE:-0}" = 1 ]; then
    MERGE_ASSERT_OUTPUT=$(FM_ROOT_OVERRIDE="$FM_ROOT" FM_HOME="$FM_HOME" FM_STATE_OVERRIDE="$STATE" \
      "$FM_ROOT/bin/fm-pr-identity.sh" merge-assert "$ID" "$URL") || exit 1
  else
    MERGE_ASSERT_OUTPUT=$(env -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE FM_HOME="$FM_HOME" \
      "$FM_ROOT/bin/fm-pr-identity.sh" merge-assert "$ID" "$URL") || exit 1
  fi
  VERIFIED_HEAD=$(printf '%s\n' "$MERGE_ASSERT_OUTPUT" | sed -n 's/^verified_head=//p' | head -1)
  fm_pr_head_valid "$VERIFIED_HEAD" || { echo "error: merge assertion returned no verified head" >&2; exit 1; }
  atlas_rest_merge "$VERIFIED_HEAD" "$@"
elif [ -n "$PR_IDENTITY" ]; then
  echo "error: unknown task PR identity profile" >&2
  exit 1
else
  gh-axi pr merge "$PR_NUMBER" --repo "$PR_OWNER/$PR_REPO" "${merge_args[@]+"${merge_args[@]}"}" "$@"
fi
