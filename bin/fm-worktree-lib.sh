# shellcheck shell=bash
# Ship/scout worktree provider for session-provider-only backends.
# Usage: . bin/fm-worktree-lib.sh
#
# Firstmate prefers GitButler-linked git worktrees when `but` is present and
# git worktrees work. GitButler 0.22 has no worktree-create CLI, so the
# but path creates and removes those worktrees with `git worktree add/remove`.
# Treehouse remains the fallback when `but` is missing or git worktrees cannot
# be created, and it still owns durable secondmate home leases.
# FM_WORKTREE_PROVIDER=but|treehouse pins the choice (tests); unset is auto.
# FM_BUT_WORKTREE_ROOT overrides the but-path pool (tests).
# This file is the single owner of provider selection, but-path add/remove,
# and the session-backend treehouse dependency delta.
# shellcheck source=bin/fm-tangle-lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fm-tangle-lib.sh"

fm_but_worktrees_capable() {
  local cmd
  command -v but >/dev/null 2>&1 || return 1
  while IFS= read -r cmd; do
    [ "$cmd" = worktree ] && return 0
  done <<EOF
$(git --list-cmds=main 2>/dev/null)
EOF
  return 1
}

fm_worktree_provider() {
  case "${FM_WORKTREE_PROVIDER:-}" in
    but|treehouse)
      printf '%s\n' "$FM_WORKTREE_PROVIDER"
      return 0
      ;;
    '')
      ;;
    *)
      echo "error: unknown FM_WORKTREE_PROVIDER '${FM_WORKTREE_PROVIDER}' (want but or treehouse)" >&2
      return 1
      ;;
  esac
  if fm_but_worktrees_capable; then
    printf '%s\n' but
    return 0
  fi
  if command -v treehouse >/dev/null 2>&1; then
    printf '%s\n' treehouse
    return 0
  fi
  echo "error: no worktree provider (need but or treehouse)" >&2
  return 1
}

# Empty when session-provider backends do not need treehouse; otherwise
# prints `treehouse` for fm_backend_required_tools to append.
fm_worktree_session_tool() {
  case "$(fm_worktree_provider 2>/dev/null || echo treehouse)" in
    but) ;;
    *) printf '%s' treehouse ;;
  esac
}

fm_worktree_but_root() {
  if [ -n "${FM_BUT_WORKTREE_ROOT:-}" ]; then
    printf '%s\n' "$FM_BUT_WORKTREE_ROOT"
    return 0
  fi
  printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/firstmate/worktrees"
}

fm_worktree_but_path() {  # <project> <id>
  local project=$1 id=$2 root proj_real digest
  root=$(fm_worktree_but_root)
  if [ -n "${FM_BUT_WORKTREE_ROOT:-}" ]; then
    printf '%s/%s\n' "$root" "$id"
    return 0
  fi
  proj_real=$(cd "$project" && pwd -P) || return 1
  digest=$(printf '%s' "$proj_real" | git hash-object --stdin) || return 1
  printf '%s/%s/%s\n' "$root" "${digest%"${digest#????????????}"}" "$id"
}

fm_worktree_but_add() {  # <project> <id>
  local project=$1 id=$2 dest base parent
  dest=$(fm_worktree_but_path "$project" "$id") || return 1
  if [ -e "$dest" ]; then
    echo "error: GitButler worktree path already exists: $dest" >&2
    return 1
  fi
  parent=$(dirname "$dest")
  mkdir -p "$parent" || return 1
  base=$(fm_default_branch "$project" 2>/dev/null || true)
  if [ -n "$base" ]; then
    git -C "$project" worktree add --detach "$dest" "$base" >&2 || return 1
  else
    git -C "$project" worktree add --detach "$dest" >&2 || return 1
  fi
  printf '%s\n' "$dest"
}

fm_worktree_but_remove() {  # <project> <worktree>
  local project=$1 worktree=$2
  git -C "$project" worktree remove --force "$worktree"
}
