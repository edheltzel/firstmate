#!/usr/bin/env bash
# Shared session-lock harness identity.
#
# ONE owner of the decision about which verified harness process holds a home
# session lock and whether a current process descends from that harness.
# bin/fm-lock.sh uses it to acquire and inspect state/.lock.
# This file is sourced by scripts and has no side effects on source.

# Known harness command names; extend when a new adapter is verified.
FM_HARNESS_RE='claude|codex|opencode|grok|^pi$|^pi-signed$'

# Match only the executable name, never the command arguments.
fm_harness_comm_matches() {
  local comm=$1 name
  name=$(basename "$comm")
  case "$name" in
    *claude*|*codex*|*opencode*|*grok*|pi|pi-signed) return 0 ;;
    *) return 1 ;;
  esac
}

# Walk the current process ancestry and print the first verified harness pid.
# The harness pid lives as long as the session, unlike a transient tool shell.
fm_harness_ancestry_pid() {
  local pid=$$ comm args
  for _ in 1 2 3 4 5 6 7 8; do
    comm=$(ps -o comm= -p "$pid" 2>/dev/null) || return 1
    args=$(ps -o args= -p "$pid" 2>/dev/null)
    if fm_harness_comm_matches "$comm"; then
      echo "$pid"
      return 0
    fi
    # Bare interpreters can carry the harness name in their script path.
    case "$comm" in
      *node*|*python*)
        printf '%s' "$args" | grep -qE "$FM_HARNESS_RE" && {
          echo "$pid"
          return 0
        }
        ;;
    esac
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    [ -n "$pid" ] && [ "$pid" -gt 1 ] || return 1
  done
  return 1
}

# Return success only for a live process with a verified executable identity.
fm_harness_pid_alive() {
  local pid=$1 comm args
  kill -0 "$pid" 2>/dev/null || return 1
  comm=$(ps -o comm= -p "$pid" 2>/dev/null) || return 1
  if fm_harness_comm_matches "$comm"; then
    return 0
  fi
  case "$comm" in
    *node*|*python*)
      args=$(ps -o args= -p "$pid" 2>/dev/null)
      printf '%s' "$args" | grep -qE "$FM_HARNESS_RE"
      ;;
    *) return 1 ;;
  esac
}
