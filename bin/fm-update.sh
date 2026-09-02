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
#   5. On merge conflict, abort, print the conflicted paths, and leave Themis
#      untouched. Never force.
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
# Usage: fm-update.sh [--help]
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
# shellcheck source=bin/fm-ff-lib.sh
. "$SCRIPT_DIR/fm-ff-lib.sh"

"$SCRIPT_DIR/fm-guard.sh" || true

usage() { echo "usage: fm-update.sh [--help]" >&2; }

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
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

# Fast-forward local <dest> to <src> without checking it out.
ff_update_ref() {
  local dir=$1 label=$2 dest=$3 src=$4
  local src_rev dest_rev cur wt before after

  if ! src_rev=$(git -C "$dir" rev-parse --verify --quiet "${src}^{commit}" 2>/dev/null); then
    echo "$label: skipped: $src does not exist"
    return 0
  fi
  if ! dest_rev=$(git -C "$dir" rev-parse --verify --quiet "refs/heads/${dest}^{commit}" 2>/dev/null); then
    echo "$label: skipped: no local $dest branch"
    return 0
  fi

  cur=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || echo "")
  if [ "$cur" = "$dest" ]; then
    echo "$label: skipped: currently checked out"
    return 0
  fi

  wt=$(branch_worktree "$dir" "$dest" || true)
  if [ -n "$wt" ]; then
    if [ -n "$(dirty_status "$wt" no)" ]; then
      echo "$label: skipped: dirty working tree"
      return 0
    fi
    echo "$label: skipped: checked out in another worktree"
    return 0
  fi

  if [ "$dest_rev" = "$src_rev" ]; then
    echo "$label: already current"
    return 0
  fi
  if ! git -C "$dir" merge-base --is-ancestor "$dest_rev" "$src_rev" 2>/dev/null; then
    echo "$label: skipped: diverged from $src"
    return 0
  fi

  before=$(git -C "$dir" rev-parse --short "$dest_rev")
  if ! git -C "$dir" update-ref "refs/heads/$dest" "$src_rev" "$dest_rev"; then
    echo "$label: skipped: fast-forward failed"
    return 0
  fi
  after=$(git -C "$dir" rev-parse --short "refs/heads/$dest")
  echo "$label: updated $before..$after"
}

push_mirror_if_safe() {
  local dir=$1 local_rev remote_rev kun_rev before after out

  if ! git -C "$dir" remote get-url origin >/dev/null 2>&1; then
    echo "origin/$MIRROR_BRANCH: skipped: no origin remote"
    return 0
  fi
  if ! local_rev=$(git -C "$dir" rev-parse --verify --quiet "refs/heads/${MIRROR_BRANCH}^{commit}" 2>/dev/null); then
    echo "origin/$MIRROR_BRANCH: skipped: no local $MIRROR_BRANCH branch"
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
  if ! kun_rev=$(git -C "$dir" rev-parse --verify --quiet "${UPSTREAM_REF}^{commit}" 2>/dev/null); then
    echo "origin/$MIRROR_BRANCH: skipped: $UPSTREAM_REF does not exist"
    return 0
  fi
  if [ "$local_rev" != "$kun_rev" ]; then
    echo "origin/$MIRROR_BRANCH: skipped: local $MIRROR_BRANCH is not at $UPSTREAM_REF"
    return 0
  fi
  if [ "$local_rev" = "$remote_rev" ]; then
    echo "origin/$MIRROR_BRANCH: already current"
    return 0
  fi
  if ! git -C "$dir" merge-base --is-ancestor "$remote_rev" "$local_rev" 2>/dev/null; then
    echo "origin/$MIRROR_BRANCH: skipped: not a fast-forward"
    return 0
  fi
  before=$(git -C "$dir" rev-parse --short "$remote_rev")
  after=$(git -C "$dir" rev-parse --short "$local_rev")
  if ! out=$(git -C "$dir" push origin "$MIRROR_BRANCH" 2>&1); then
    echo "origin/$MIRROR_BRANCH: skipped: push failed: $(first_line "$out")"
    return 0
  fi
  echo "origin/$MIRROR_BRANCH: pushed $before..$after"
}

abort_merge_if_needed() {
  local dir=$1
  if git -C "$dir" rev-parse --verify --quiet MERGE_HEAD >/dev/null 2>&1; then
    git -C "$dir" merge --abort >/dev/null 2>&1 || true
  fi
}

# Merge local master into Themis. Never switches HEAD to master.
merge_themis() {
  local dir=$1
  local cur local_rev master_rev instr before after out files f
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
  if [ -n "$(dirty_status "$dir" no)" ]; then
    echo "firstmate: skipped: dirty working tree"
    return 0
  fi
  if ! master_rev=$(git -C "$dir" rev-parse --verify --quiet "refs/heads/${MIRROR_BRANCH}^{commit}" 2>/dev/null); then
    echo "firstmate: skipped: no local $MIRROR_BRANCH branch"
    return 0
  fi

  local_rev=$(git -C "$dir" rev-parse HEAD 2>/dev/null) || {
    echo "firstmate: skipped: cannot read HEAD"
    return 0
  }
  if [ "$local_rev" = "$master_rev" ] || git -C "$dir" merge-base --is-ancestor "$master_rev" HEAD 2>/dev/null; then
    FF_STATUS="current"
    echo "firstmate: already current"
    return 0
  fi

  instr=$(changed_instr "$dir" "$MIRROR_BRANCH")
  before=$(git -C "$dir" rev-parse --short HEAD)
  if out=$(git -C "$dir" -c merge.ff=true merge --no-edit "$MIRROR_BRANCH" 2>&1); then
    after=$(git -C "$dir" rev-parse --short HEAD)
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
    abort_merge_if_needed "$dir"
    return 0
  fi
  echo "firstmate: skipped: merge failed: $(first_line "$out")"
  abort_merge_if_needed "$dir"
}

# --- main firstmate repo ---------------------------------------------------

reread_firstmate="no"

if ! git -C "$FM_ROOT" remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
  echo "upstream: skipped: no $UPSTREAM_REMOTE remote"
elif ! fetch_once "$FM_ROOT" "$UPSTREAM_REMOTE"; then
  echo "upstream: skipped: fetch failed"
fi

ff_update_ref "$FM_ROOT" "$MIRROR_BRANCH" "$MIRROR_BRANCH" "$UPSTREAM_REF"
push_mirror_if_safe "$FM_ROOT"
merge_themis "$FM_ROOT"
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
