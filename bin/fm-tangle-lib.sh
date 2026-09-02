# shellcheck shell=bash
# Shared worktree-tangle guard for the firstmate-on-itself case.
# Usage: . bin/fm-tangle-lib.sh
#
# Firstmate can manage linked git worktrees of itself: disposable crewmate
# worktrees use the selected provider, and Treehouse-leased secondmate homes are
# linked worktrees of the same repo, while the PRIMARY checkout (the repo root
# firstmate operates from) is a normal checkout
# on a real branch - normally the default branch, main. The "worktree tangle"
# failure mode is a crewmate spawned to work on firstmate ITSELF branching and
# committing in the primary checkout instead of its own disposable worktree,
# stranding the primary on a feature branch (e.g. fm/readme-restructure-d3).
#
# fm_primary_tangle_branch detects exactly that and nothing else: a NAMED branch
# checked out in the given root that differs from the caller's expected branch.
# The expected branch defaults to the repository default. A caller with a
# deliberate long-running branch, such as the Themis self-updater, may name it.
# The classifier is deliberately silent for detached HEAD, which is how every
# linked worktree and secondmate home legitimately sits on the default branch.

# Resolve the default branch name of the git repo at <dir>: prefer origin/HEAD,
# then fall back to a local main/master. Echoes the name, or returns 1.
fm_default_branch() {
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

# If the git checkout at <root> is tangled - on a NAMED branch that is not the
# optional <expected-branch>, or the repository default when it is omitted - echo
# the offending branch name and return 0. For every healthy state (not a git work
# tree, detached HEAD, or already on the expected branch) echo nothing and return
# 1. Detached HEAD is how linked worktrees and secondmate homes legitimately sit,
# so they never trip this.
fm_primary_tangle_branch() {
  local root=$1 expected=${2:-} cur
  git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  cur=$(git -C "$root" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
  [ -n "$cur" ] || return 1
  if [ -z "$expected" ]; then
    expected=$(fm_default_branch "$root") || return 1
  fi
  [ "$cur" = "$expected" ] && return 1
  printf '%s\n' "$cur"
  return 0
}
