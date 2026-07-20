#!/usr/bin/env bash
# Resolve a project's delivery mode, yolo flag, and Fleet display name from the
# data/projects.md registry. This is the single authoritative parser of the
# registry line format; other scripts call it rather than re-parsing the line.
#
#   fm-project-mode.sh <project-name>            -> "<mode> <yolo>"
#   fm-project-mode.sh --fleet <project-name>    -> "<fleet-display-name>"
#
# Registry line format (data/projects.md):
#   - <name> - <desc> (added <date>)                          -> no-mistakes off, fleet=<name>
#   - <name> [<mode>] - <desc> (added <date>)                  -> <mode> off, fleet=<name>
#   - <name> [<mode> +yolo] - <desc> (added <date>)            -> <mode> on, fleet=<name>
#   - <name> [<mode> fleet=<Display>] - <desc> (added <date>)  -> <mode> off, fleet=<Display>
#
# The bracket holds optional space-separated tokens. mode is ALWAYS the first
# bracket token (or absent); +yolo and fleet=<Display> are optional and
# order-independent but must come AFTER the mode token - fleet= in position 1
# is defensively NOT read as the mode, but keep it after mode for clarity.
# <Display> is a single whitespace-free token because the bracket is space-split
# and the herdr backend uses it verbatim as the "<Display>-Fleet" workspace label
# (docs/herdr-backend.md "Fleet workspaces").
#
# Fleet display name = the configured fleet=<Display> alias if present, else the
# project name itself (the repository name). This is the single authoritative
# source of the Fleet display name; the herdr backend derives the ordinary-worker
# workspace label "<fleet-display-name>-Fleet" from it (bin/backends/herdr.sh).
#
# mode = how a finished change reaches main:
#   no-mistakes  full pipeline -> PR -> captain merge (default)
#   direct-PR    push + PR via gh-axi, no pipeline -> captain merge
#   local-only   local branch, no remote/PR -> captain approve -> guarded local merge
# yolo (orthogonal) = when on, firstmate makes approval decisions itself (PR merges,
#   ask-user findings, local-only merge approval) without checking the captain - except
#   anything destructive/irreversible/security-sensitive, which still escalates.
#
# An unknown/missing project or unknown mode falls back to "no-mistakes off" and warns
# to stderr, so a typo never silently drops the gate. An unknown/missing project's Fleet
# name defaults deterministically to the given name, so an unregistered project still
# gets a stable "<name>-Fleet" worker workspace.
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
DATA="${FM_DATA_OVERRIDE:-$FM_HOME/data}"
REG="$DATA/projects.md"

WANT=mode
if [ "${1:-}" = "--fleet" ]; then
  WANT=fleet
  shift
fi
NAME=${1:?usage: fm-project-mode.sh [--fleet] <project-name>}

if [ ! -f "$REG" ]; then
  if [ "$WANT" = fleet ]; then
    printf '%s\n' "$NAME"
  else
    echo "warn: no registry at $REG; defaulting $NAME to no-mistakes off" >&2
    echo "no-mistakes off"
  fi
  exit 0
fi

# Single bracket parser: emits "<mode>\t<yolo>\t<fleet>" (fleet empty when the
# line carries no fleet= alias), or nothing if the project is absent.
parsed=$(awk -v n="$NAME" '
  $1=="-" && $2==n {
    mode="no-mistakes"; yolo="off"; fleet="";
    if ($3 ~ /^\[/) {
      s="";
      for (i=3; i<=NF; i++) { s = s (s==""?"":" ") $i; if ($i ~ /\]$/) break }
      gsub(/^\[|\]$/, "", s);           # strip the surrounding brackets
      k = split(s, a, " ");
      if (a[1] != "" && a[1] != "+yolo" && a[1] !~ /^fleet=/) mode = a[1];
      for (j=1; j<=k; j++) {
        if (a[j]=="+yolo") yolo="on";
        else if (a[j] ~ /^fleet=/) fleet=substr(a[j], 7);
      }
    }
    printf "%s\t%s\t%s\n", mode, yolo, fleet; exit
  }
' "$REG")

if [ -z "$parsed" ]; then
  if [ "$WANT" = fleet ]; then
    echo "warn: project \"$NAME\" not in registry; Fleet name defaults to \"$NAME\"" >&2
    printf '%s\n' "$NAME"
  else
    echo "warn: project \"$NAME\" not in registry; defaulting to no-mistakes off" >&2
    echo "no-mistakes off"
  fi
  exit 0
fi

mode=${parsed%%$'\t'*}
rest=${parsed#*$'\t'}
yolo=${rest%%$'\t'*}
fleet=${rest#*$'\t'}

if [ "$WANT" = fleet ]; then
  if [ -n "$fleet" ]; then
    printf '%s\n' "$fleet"
  else
    printf '%s\n' "$NAME"
  fi
  exit 0
fi

case "$mode" in
  no-mistakes|direct-PR|local-only) ;;
  *) echo "warn: unknown mode \"$mode\" for $NAME; defaulting to no-mistakes off" >&2; mode=no-mistakes; yolo=off ;;
esac
case "$yolo" in on|off) ;; *) yolo=off ;; esac
echo "$mode $yolo"
