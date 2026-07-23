#!/usr/bin/env bash
# Resolve a project's delivery mode, yolo flag, and Fleet display name from the
# data/projects.md registry. This is the single authoritative parser of the
# registry line format; other scripts call it rather than re-parsing the line.
#
#   fm-project-mode.sh <project-key>                     -> "<mode> <yolo>"
#   fm-project-mode.sh --fleet <project-key> [<default>] -> "<fleet-display-name>"
#   fm-project-mode.sh --pr-identity <project-key>       -> profile or "none"
#
# <project-key> is the registry KEY (the first field of a registry line), which
# is the single canonical project identity. It is NOT necessarily the repository
# directory basename: a project can be registered under a key that differs from
# its clone directory name (e.g. the firstmate repo itself registered as
# "Agent-Themis" while its checkout basename is "Firstmate"). Callers pass the
# key, not a guessed-from-path name, so mode and Fleet resolution agree.
#
# Registry line format (data/projects.md):
#   - <name> - <desc> (added <date>)                          -> no-mistakes off, fleet=<name>
#   - <name> [<mode>] - <desc> (added <date>)                  -> <mode> off, fleet=<name>
#   - <name> [<mode> +yolo] - <desc> (added <date>)            -> <mode> on, fleet=<name>
#   - <name> [<mode> fleet=<Display>] - <desc> (added <date>)  -> <mode> off, fleet=<Display>
#   - <name> [<mode> fleet=<Display> pr-identity=atlas-pat] - <desc> -> broker profile
#
# The bracket holds optional space-separated tokens. mode is ALWAYS the first
# bracket token (or absent); +yolo and fleet=<Display> are optional and
# order-independent but must come AFTER the mode token - fleet= in position 1
# is defensively NOT read as the mode, but keep it after mode for clarity.
# <Display> is a single whitespace-free token because the bracket is space-split
# and the herdr backend uses it verbatim as the "<Display>-Fleet" workspace label
# (docs/herdr-backend.md "Fleet workspaces").
#
# Fleet display name = the configured fleet=<Display> alias on the key's entry if
# present, else the caller-supplied <default> (the repository basename), else the
# key itself when no <default> is given. Keeping the display DEFAULT separate from
# the lookup KEY is what lets a key that differs from the repository basename
# resolve its mode correctly WITHOUT renaming the workspace: a delivery-identity
# key such as "Agent-Themis" must not turn a "Firstmate-Fleet" workspace into
# "Agent-Themis-Fleet". Only an explicit fleet=<Display> alias renames it. This is
# the single authoritative source of the Fleet display name; the herdr backend
# derives the ordinary-worker workspace label "<fleet-display-name>-Fleet" from it
# (bin/backends/herdr.sh), passing the canonical key and the basename default.
# A single-argument "--fleet <name>" call is still valid and unchanged: with no
# <default>, the name serves as both key and display default (the case where the
# registry key and the repository basename are the same).
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
elif [ "${1:-}" = "--pr-identity" ]; then
  WANT=pr_identity
  shift
fi
NAME=${1:?usage: fm-project-mode.sh [--fleet|--pr-identity] <project-key> [<default-display>]}
# The Fleet display DEFAULT (used only when the key's entry carries no fleet=
# alias). Defaults to the key itself so a single-argument --fleet call keeps its
# prior behavior. Unused in mode mode.
FLEET_DEFAULT=${2:-$NAME}

if [ ! -f "$REG" ]; then
  if [ "$WANT" = fleet ]; then
    printf '%s\n' "$FLEET_DEFAULT"
  elif [ "$WANT" = pr_identity ]; then
    printf '%s\n' none
  else
    echo "warn: no registry at $REG; defaulting $NAME to no-mistakes off" >&2
    echo "no-mistakes off"
  fi
  exit 0
fi

# Single bracket parser: emits mode, yolo, fleet, profile, and a strict-query
# error marker, while preserving the old fields for existing callers.
parsed=$(awk -v n="$NAME" '
  $1=="-" && $2==n {
    mode="no-mistakes"; yolo="off"; fleet=""; profile="none"; profile_error="";
    if ($3 ~ /^\[/) {
      s="";
      for (i=3; i<=NF; i++) { s = s (s==""?"":" ") $i; if ($i ~ /\]$/) break }
      gsub(/^\[|\]$/, "", s);           # strip the surrounding brackets
      k = split(s, a, " ");
      if (a[1] != "" && a[1] != "+yolo" && a[1] !~ /^fleet=/) mode = a[1];
      for (j=1; j<=k; j++) {
        if (a[j]=="+yolo") yolo="on";
        else if (a[j] ~ /^fleet=/) fleet=substr(a[j], 7);
        else if (a[j] ~ /^pr-identity=/) {
          if (profile != "none") profile_error="duplicate-pr-identity";
          profile=substr(a[j], 13);
          if (profile == "") profile_error="empty-pr-identity";
          if (j == 1 || a[1] !~ /^(no-mistakes|direct-PR|local-only)$/) profile_error="reordered-pr-identity";
        }
      }
      if (profile != "none" && mode == "local-only") profile_error="local-only-pr-identity";
      if (profile != "none" && profile != "atlas-pat") profile_error="unknown-pr-identity";
    }
    printf "%s\t%s\t%s\t%s\t%s\n", mode, yolo, fleet, profile, profile_error; exit
  }
' "$REG")

if [ -z "$parsed" ]; then
  if [ "$WANT" = fleet ]; then
    echo "warn: project \"$NAME\" not in registry; Fleet name defaults to \"$FLEET_DEFAULT\"" >&2
    printf '%s\n' "$FLEET_DEFAULT"
  elif [ "$WANT" = pr_identity ]; then
    printf '%s\n' none
  else
    echo "warn: project \"$NAME\" not in registry; defaulting to no-mistakes off" >&2
    echo "no-mistakes off"
  fi
  exit 0
fi

mode=${parsed%%$'\t'*}
rest=${parsed#*$'\t'}
yolo=${rest%%$'\t'*}
rest=${rest#*$'\t'}
fleet=${rest%%$'\t'*}

if [ "$WANT" = pr_identity ]; then
  rest=${rest#*$'\t'}
  profile=${rest%%$'\t'*}
  profile_error=${rest#*$'\t'}
  if [ -n "$profile_error" ]; then
    echo "error: invalid pr-identity for $NAME ($profile_error)" >&2
    exit 2
  fi
  printf '%s\n' "$profile"
  exit 0
fi

if [ "$WANT" = fleet ]; then
  if [ -n "$fleet" ]; then
    printf '%s\n' "$fleet"
  else
    printf '%s\n' "$FLEET_DEFAULT"
  fi
  exit 0
fi

case "$mode" in
  no-mistakes|direct-PR|local-only) ;;
  *) echo "warn: unknown mode \"$mode\" for $NAME; defaulting to no-mistakes off" >&2; mode=no-mistakes; yolo=off ;;
esac
case "$yolo" in on|off) ;; *) yolo=off ;; esac
echo "$mode $yolo"
