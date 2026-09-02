#!/usr/bin/env bash
# Self-update a running Themis firstmate from Kun, then its secondmates.
#
# Mechanical half of the /updatefirstmate skill. From a clean Themis checkout:
#   1. Fetch the upstream remote (kunchenguid/firstmate). If it is missing, skip
#      and report; never invent a remote.
#   2. Fast-forward local master to upstream/main without checking master out.
#      Never force, stash, or merge-commit onto master. Dirty or diverged master
#      is skipped and reported.
#   3. Push master to origin/master only when that is a clean fast-forward of the
#      GitHub default mirror. An unsafe push is skipped and reported and does not
#      block the Themis merge.
#   4. Merge master into the current Themis checkout so unique Themis commits
#      remain. Fast-forward Themis only when it is already an ancestor of master.
#   5. On merge conflict, print the conflicted paths and leave the merge in
#      progress for resolution. Never force.
# If HEAD is not Themis, skip that merge and report "on <branch>, expected Themis".
# Never check out master as HEAD of the running home.
# Never force, never stash, never discard unlanded work.
#
# Secondmate homes stay on the existing origin fast-forward path owned by
# bin/fm-ff-lib.sh. A tracked-files fast-forward never touches the gitignored
# operational dirs (data/, state/, config/, projects/, .no-mistakes/).
#
# The script does not re-read AGENTS.md or nudge secondmates itself. Those are
# LLM / tmux actions the skill performs. Caller summary:
#   - one status line per target (updated/already current/skipped)
#   - reread-firstmate: yes|no
#   - nudge-secondmates: fm-<id>...|none
#
# Usage: fm-update.sh [--remote-code-root|--help]
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
SECONDMATES_MD="$FM_HOME/data/secondmates.md"
THEMIS_BRANCH="Themis"
MIRROR_BRANCH="master"
UPSTREAM_REMOTE="upstream"
UPSTREAM_REF="upstream/main"
UPDATE_MODE="themis"
# shellcheck source=bin/fm-ff-lib.sh
. "$SCRIPT_DIR/fm-ff-lib.sh"

"$SCRIPT_DIR/fm-guard.sh" || true

usage() { echo "usage: fm-update.sh [--remote-code-root|--help]" >&2; }

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi
if [ "${1:-}" = "--remote-code-root" ]; then
  UPDATE_MODE="remote-code-root"
  shift
fi
[ $# -eq 0 ] || { usage; exit 1; }

# Path of the worktree that has <branch> checked out, if any.
branch_worktree() {
  local dir=$1 branch=$2 path="" line
  while IFS= read -r line; do
    case "$line" in
      worktree\ *) path=${line#worktree } ;;
      branch\ refs/heads/"$branch")
        printf '%s\n' "$path"
        return 0
        ;;
    esac
  done < <(git -C "$dir" worktree list --porcelain 2>/dev/null)
  return 1
}

ff_checked_out_ref() (
  local wt=$1 label=$2 dest=$3 src_rev=$4 src_label=$5 expected_rev=$6
  local head_path="" head_lock="" lock_token="" head_ref current_rev before after after_rev out
  local git_dir="" common_dir="" index_path="" txn_git_dir=""

  head_path=$(git -C "$wt" rev-parse --path-format=absolute --git-path HEAD 2>/dev/null || true)
  [ -n "$head_path" ] || {
    echo "$label: skipped: cannot lock checked-out $dest"
    return 1
  }
  head_lock="${head_path}.lock"
  lock_token="$$:$RANDOM:$RANDOM"
  if ! ( set -C; printf '%s\n' "$lock_token" > "$head_lock" ) 2>/dev/null; then
    echo "$label: skipped: checked-out $dest is busy"
    return 1
  fi
  release_ff_locks() {
    case "$txn_git_dir" in
      "$git_dir"/fm-update-git.*) rm -rf -- "$txn_git_dir" ;;
    esac
    if [ -f "$head_lock" ] && [ "$(cat "$head_lock" 2>/dev/null || true)" = "$lock_token" ]; then
      rm -f -- "$head_lock"
    fi
  }
  trap release_ff_locks EXIT
  trap 'exit 1' HUP INT TERM

  head_ref=$(git -C "$wt" symbolic-ref --quiet HEAD 2>/dev/null || true)
  if [ "$head_ref" != "refs/heads/$dest" ]; then
    echo "$label: skipped: checked-out worktree left $dest"
    return 1
  fi
  if git_operation_in_progress "$wt"; then
    echo "$label: skipped: git operation in progress"
    return 1
  fi
  if [ -n "$(dirty_status "$wt" no)" ]; then
    echo "$label: skipped: dirty working tree"
    return 1
  fi
  current_rev=$(git -C "$wt" rev-parse HEAD 2>/dev/null || true)
  if [ "$current_rev" != "$expected_rev" ]; then
    echo "$label: skipped: $dest changed during update"
    return 1
  fi
  if [ "$current_rev" = "$src_rev" ]; then
    echo "$label: already current"
    return 0
  fi
  if ! git -C "$wt" merge-base --is-ancestor "$current_rev" "$src_rev" 2>/dev/null; then
    echo "$label: skipped: diverged from $src_label"
    return 1
  fi

  git_dir=$(git -C "$wt" rev-parse --path-format=absolute --git-dir 2>/dev/null || true)
  common_dir=$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
  index_path=$(git -C "$wt" rev-parse --path-format=absolute --git-path index 2>/dev/null || true)
  if [ -z "$git_dir" ] || [ -z "$common_dir" ] || [ -z "$index_path" ]; then
    echo "$label: skipped: cannot prepare checked-out $dest"
    return 1
  fi
  txn_git_dir=$(mktemp -d "$git_dir/fm-update-git.XXXXXX" 2>/dev/null || true)
  if [ -z "$txn_git_dir" ]; then
    echo "$label: skipped: cannot prepare checked-out $dest"
    return 1
  fi
  printf 'ref: refs/heads/%s\n' "$dest" > "$txn_git_dir/HEAD"
  printf '%s\n' "$common_dir" > "$txn_git_dir/commondir"
  if [ -f "$git_dir/config.worktree" ]; then
    ln -s "$git_dir/config.worktree" "$txn_git_dir/config.worktree"
  fi
  if [ -d "$git_dir/info" ]; then
    ln -s "$git_dir/info" "$txn_git_dir/info"
  fi

  before=$(git -C "$wt" rev-parse --short "$current_rev")
  if ! out=$(GIT_DIR="$txn_git_dir" GIT_WORK_TREE="$wt" GIT_INDEX_FILE="$index_path" \
    git -C "$wt" -c "branch.$dest.mergeOptions=" -c merge.autoStash=false \
      merge --ff-only --commit --no-squash --no-edit "$src_rev" 2>&1); then
    echo "$label: skipped: fast-forward failed: $(first_line "$out")"
    return 1
  fi
  after_rev=$(git -C "$wt" rev-parse HEAD 2>/dev/null || true)
  if [ "$after_rev" != "$src_rev" ] || git_operation_in_progress "$wt" \
    || [ -n "$(dirty_status "$wt" no)" ]; then
    echo "$label: skipped: fast-forward did not complete"
    return 1
  fi
  after=$(git -C "$wt" rev-parse --short "$after_rev")
  echo "$label: updated $before..$after"
  trap - EXIT
  release_ff_locks
)

# Fast-forward local <dest> to <src> without checking it out.
ff_update_ref() {
  local dir=$1 label=$2 dest=$3 src=$4 src_label=${5:-$4}
  local src_rev dest_rev cur wt before after

  if ! src_rev=$(git -C "$dir" rev-parse --verify --quiet "${src}^{commit}" 2>/dev/null); then
    echo "$label: skipped: $src_label does not exist"
    return 1
  fi
  if ! dest_rev=$(git -C "$dir" rev-parse --verify --quiet "refs/heads/${dest}^{commit}" 2>/dev/null); then
    echo "$label: skipped: no local $dest branch"
    return 1
  fi

  cur=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || echo "")
  if [ "$cur" = "$dest" ]; then
    echo "$label: skipped: currently checked out"
    return 1
  fi

  wt=$(branch_worktree "$dir" "$dest" || true)
  if [ -n "$wt" ]; then
    ff_checked_out_ref "$wt" "$label" "$dest" "$src_rev" "$src_label" "$dest_rev"
    return $?
  fi

  if [ "$dest_rev" = "$src_rev" ]; then
    echo "$label: already current"
    return 0
  fi
  if ! git -C "$dir" merge-base --is-ancestor "$dest_rev" "$src_rev" 2>/dev/null; then
    echo "$label: skipped: diverged from $src_label"
    return 1
  fi

  before=$(git -C "$dir" rev-parse --short "$dest_rev")
  if ! git -C "$dir" update-ref "refs/heads/$dest" "$src_rev" "$dest_rev"; then
    echo "$label: skipped: fast-forward failed"
    return 1
  fi
  after=$(git -C "$dir" rev-parse --short "refs/heads/$dest")
  echo "$label: updated $before..$after"
}

push_mirror_if_safe() {
  local dir=$1 verified_rev=$2 remote_rev before after out

  if ! git -C "$dir" remote get-url origin >/dev/null 2>&1; then
    echo "origin/$MIRROR_BRANCH: skipped: no origin remote"
    return 0
  fi
  if ! git -C "$dir" cat-file -e "${verified_rev}^{commit}" 2>/dev/null; then
    echo "origin/$MIRROR_BRANCH: skipped: verified $UPSTREAM_REF commit is unavailable"
    return 0
  fi
  if ! fetch_once "$dir" origin; then
    echo "origin/$MIRROR_BRANCH: skipped: fetch failed"
    return 0
  fi
  if ! remote_rev=$(git -C "$dir" rev-parse --verify --quiet "refs/remotes/origin/${MIRROR_BRANCH}^{commit}" 2>/dev/null); then
    echo "origin/$MIRROR_BRANCH: skipped: origin/$MIRROR_BRANCH does not exist"
    return 0
  fi
  if [ "$verified_rev" = "$remote_rev" ]; then
    echo "origin/$MIRROR_BRANCH: already current"
    return 0
  fi
  if ! git -C "$dir" merge-base --is-ancestor "$remote_rev" "$verified_rev" 2>/dev/null; then
    echo "origin/$MIRROR_BRANCH: skipped: not a fast-forward"
    return 0
  fi
  before=$(git -C "$dir" rev-parse --short "$remote_rev")
  after=$(git -C "$dir" rev-parse --short "$verified_rev")
  if ! out=$(git -C "$dir" push origin "$verified_rev:refs/heads/$MIRROR_BRANCH" 2>&1); then
    echo "origin/$MIRROR_BRANCH: skipped: push failed: $(first_line "$out")"
    return 0
  fi
  echo "origin/$MIRROR_BRANCH: pushed $before..$after"
}

git_operation_in_progress() {
  local dir=$1 name path
  for name in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD REBASE_HEAD BISECT_LOG rebase-merge rebase-apply sequencer; do
    path=$(git -C "$dir" rev-parse --path-format=absolute --git-path "$name" 2>/dev/null || true)
    if [ -n "$path" ] && [ -e "$path" ]; then
      return 0
    fi
  done
  return 1
}

# Merge local master into Themis. Never switches HEAD to master.
merge_themis() {
  local dir=$1 source_rev=${2:-} source_error=${3:-"local $MIRROR_BRANCH is not at $UPSTREAM_REF"}
  local cur local_rev merged_rev instr before after out files f
  FF_STATUS="skipped"
  FF_INSTR=""

  if [ ! -d "$dir" ]; then
    echo "firstmate: skipped: not a directory"
    return 0
  fi
  if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "firstmate: skipped: not a git repo"
    return 0
  fi

  cur=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || echo "")
  if [ -z "$cur" ]; then
    echo "firstmate: skipped: detached HEAD, expected $THEMIS_BRANCH"
    return 0
  fi
  if [ "$cur" != "$THEMIS_BRANCH" ]; then
    echo "firstmate: skipped: on $cur, expected $THEMIS_BRANCH"
    return 0
  fi
  if git_operation_in_progress "$dir"; then
    echo "firstmate: skipped: git operation in progress"
    return 0
  fi
  if [ -n "$(dirty_status "$dir" no)" ]; then
    echo "firstmate: skipped: dirty working tree"
    return 0
  fi
  if [ -z "$source_rev" ]; then
    echo "firstmate: skipped: $source_error"
    return 0
  fi
  if ! git -C "$dir" cat-file -e "${source_rev}^{commit}" 2>/dev/null; then
    echo "firstmate: skipped: verified $UPSTREAM_REF commit is unavailable"
    return 0
  fi

  local_rev=$(git -C "$dir" rev-parse HEAD 2>/dev/null) || {
    echo "firstmate: skipped: cannot read HEAD"
    return 0
  }
  if [ "$local_rev" = "$source_rev" ] || git -C "$dir" merge-base --is-ancestor "$source_rev" HEAD 2>/dev/null; then
    FF_STATUS="current"
    echo "firstmate: already current"
    return 0
  fi

  before=$(git -C "$dir" rev-parse --short "$local_rev")
  if out=$(git -C "$dir" -c "branch.$THEMIS_BRANCH.mergeOptions=" -c merge.autoStash=false \
    merge --ff --commit --no-squash --no-edit "$source_rev" 2>&1); then
    merged_rev=$(git -C "$dir" rev-parse HEAD 2>/dev/null || true)
    if [ -z "$merged_rev" ] \
      || ! git -C "$dir" merge-base --is-ancestor "$local_rev" "$merged_rev" 2>/dev/null \
      || ! git -C "$dir" merge-base --is-ancestor "$source_rev" "$merged_rev" 2>/dev/null \
      || git_operation_in_progress "$dir" \
      || [ -n "$(dirty_status "$dir" no)" ]; then
      echo "firstmate: skipped: merge did not complete"
      return 0
    fi
    after=$(git -C "$dir" rev-parse --short "$merged_rev")
    instr=$(changed_instr "$dir" "$local_rev")
    FF_STATUS="updated"
    FF_INSTR="$instr"
    if [ -n "$instr" ]; then
      echo "firstmate: updated $before..$after (instructions changed: $instr)"
    else
      echo "firstmate: updated $before..$after"
    fi
    return 0
  fi

  files=$(git -C "$dir" diff --name-only --diff-filter=U 2>/dev/null || true)
  if git -C "$dir" rev-parse --verify --quiet MERGE_HEAD >/dev/null 2>&1; then
    echo "firstmate: skipped: merge conflict"
    while IFS= read -r f; do
      [ -n "$f" ] && echo "conflict: $f"
    done <<< "$files"
    return 0
  fi
  echo "firstmate: skipped: merge failed: $(first_line "$out")"
}

# --- main firstmate repo ---------------------------------------------------

reread_firstmate="no"

if [ "$UPDATE_MODE" = "remote-code-root" ]; then
  ff_target "$FM_ROOT" "firstmate" origin no no
else
  verified_mirror_rev=""
  mirror_error="upstream was not refreshed"
  if ! git -C "$FM_ROOT" remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
    echo "upstream: skipped: no $UPSTREAM_REMOTE remote"
    echo "$MIRROR_BRANCH: skipped: $mirror_error"
  elif ! fetch_once "$FM_ROOT" "$UPSTREAM_REMOTE" \
    "refs/heads/main:refs/remotes/$UPSTREAM_REMOTE/main"; then
    echo "upstream: skipped: fetch failed"
    echo "$MIRROR_BRANCH: skipped: $mirror_error"
  else
    mirror_error="local $MIRROR_BRANCH is not at $UPSTREAM_REF"
    upstream_rev=$(git -C "$FM_ROOT" rev-parse --verify --quiet "${UPSTREAM_REF}^{commit}" 2>/dev/null || true)
    if [ -z "$upstream_rev" ]; then
      echo "$MIRROR_BRANCH: skipped: $UPSTREAM_REF does not exist"
    elif ff_update_ref "$FM_ROOT" "$MIRROR_BRANCH" "$MIRROR_BRANCH" "$upstream_rev" "$UPSTREAM_REF" \
      && [ "$(git -C "$FM_ROOT" rev-parse "refs/heads/$MIRROR_BRANCH")" = "$upstream_rev" ]; then
      verified_mirror_rev=$upstream_rev
    fi
  fi

  if [ -n "$verified_mirror_rev" ]; then
    push_mirror_if_safe "$FM_ROOT" "$verified_mirror_rev"
  else
    echo "origin/$MIRROR_BRANCH: skipped: $mirror_error"
  fi
  merge_themis "$FM_ROOT" "$verified_mirror_rev" "$mirror_error"
fi
if [ "$FF_STATUS" = "updated" ] && [ -n "$FF_INSTR" ]; then
  reread_firstmate="yes"
fi

# --- secondmates -----------------------------------------------------------
# An updated live secondmate is nudged whenever it advanced (nudge_requires_instr
# is "no" here): /updatefirstmate's nudge is a gentle re-read steer, kept on the
# same condition it has always used.

FF_NUDGE_WINDOWS=""
FF_SEEN_HOMES=""

# Live direct reports first: state/<id>.meta with kind=secondmate carries the
# authoritative home= path.
sweep_live_secondmate_metas "$STATE" origin no

# Registry backstop: a secondmate registered in data/secondmates.md but without
# a live meta (e.g. between restarts) is still its persistent on-disk home.
if [ -f "$SECONDMATES_MD" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "- "*) ;;
      *) continue ;;
    esac
    if ! secondmate_registry_parse_line "$line"; then
      echo "secondmate registry: skipped malformed entry: $line" >&2
      continue
    fi
    id=$SECONDMATE_REGISTRY_ID
    home=$SECONDMATE_REGISTRY_HOME
    if [ "$SECONDMATE_REGISTRY_REMOTE" -eq 1 ]; then
      if remote_out=$("$SCRIPT_DIR/fm-on.sh" "$id" fm-remote-secondmate-control.sh update "$id" < /dev/null 2>&1); then
        remote_result=$(printf '%s\n' "$remote_out" | tail -1)
        case "$remote_result" in
          synced:*)
            echo "remote secondmate $id: updated on $SECONDMATE_REGISTRY_HOST (${remote_result#synced: })"
            if [ -f "$STATE/$id.meta" ] && grep -qx 'kind=secondmate' "$STATE/$id.meta"; then
              FF_NUDGE_WINDOWS="$FF_NUDGE_WINDOWS fm-$id"
            fi
            ;;
          current:*) echo "remote secondmate $id: already current on $SECONDMATE_REGISTRY_HOST (${remote_result#current: })" ;;
          *) echo "remote secondmate $id: skipped on $SECONDMATE_REGISTRY_HOST: malformed update result" >&2 ;;
        esac
      else
        echo "remote secondmate $id: skipped on $SECONDMATE_REGISTRY_HOST: ${remote_out%%$'\n'*}" >&2
      fi
    else
      process_secondmate "$id" "$home" "" origin no
    fi
  done < "$SECONDMATES_MD"
fi

# --- caller action summary -------------------------------------------------

echo "reread-firstmate: $reread_firstmate"
echo "nudge-secondmates:${FF_NUDGE_WINDOWS:- none}"
