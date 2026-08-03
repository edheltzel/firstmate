#!/usr/bin/env bash
# Resolve a project's REGISTERED delivery posture and identity annotations from
# data/projects.md. This is the single authoritative parser of the registry line.
#
#   fm-project-mode.sh [--raw] <project-key>              -> "<mode> <yolo>"
#   fm-project-mode.sh --fleet <project-key> [<default>]  -> Fleet display name
#   fm-project-mode.sh --pr-identity <project-key>        -> profile or "none"
#   fm-project-mode.sh --known <project-key>              -> "yes" or "no"
#
# MECHANICAL CONSUMERS ONLY. The mode query answers what posture the captain
# registered for the project, never how a task ships. Firstmate resolves each
# task's mode and yolo at intake and passes them explicitly to fm-brief/fm-spawn.
# The project key still owns Fleet/Archon grouping, PR publication identity, and
# the spawn-time advisory comparison with the registered standing posture.
#
# Registry bracket tokens are space-separated. The first token is the registered
# mode; later tokens may include +yolo, fleet=<Display>, and
# pr-identity=atlas-pat. no-mistakes-prod-only is a conditional registry policy,
# not a task mode: normal mode queries map it to no-mistakes for mechanical
# consumers, while --raw preserves the annotation for intake/advisory callers.
# Unknown or invalid mode queries default safely to "no-mistakes off".
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
DATA="${FM_DATA_OVERRIDE:-$FM_HOME/data}"
REG="$DATA/projects.md"

WANT=mode
RAW=0
case "${1:-}" in
  --raw) RAW=1; shift ;;
  --fleet) WANT=fleet; shift ;;
  --pr-identity) WANT=pr_identity; shift ;;
  --known) WANT=known; shift ;;
esac
NAME=${1:?usage: fm-project-mode.sh [--raw|--fleet|--pr-identity|--known] <project-key> [<default-display>]}
FLEET_DEFAULT=${2:-$NAME}

missing_project() {
  case "$WANT" in
    fleet) printf '%s\n' "$FLEET_DEFAULT" ;;
    pr_identity) printf '%s\n' none ;;
    known) printf '%s\n' no ;;
    *)
      echo "warn: project \"$NAME\" not in registry; defaulting to no-mistakes off" >&2
      printf '%s\n' 'no-mistakes off'
      ;;
  esac
}

if [ ! -f "$REG" ]; then
  [ "$WANT" != mode ] || echo "warn: no registry at $REG; defaulting $NAME to no-mistakes off" >&2
  case "$WANT" in
    fleet) printf '%s\n' "$FLEET_DEFAULT" ;;
    pr_identity) printf '%s\n' none ;;
    known) printf '%s\n' no ;;
    *) printf '%s\n' 'no-mistakes off' ;;
  esac
  exit 0
fi

parsed=$(awk -v n="$NAME" '
  $1=="-" && $2==n {
    mode="no-mistakes"; yolo="off"; fleet=""; profile="none";
    profile_seen=0; profile_error="";
    if ($3 ~ /^\[/) {
      s="";
      for (i=3; i<=NF; i++) { s = s (s==""?"":" ") $i; if ($i ~ /\]$/) break }
      gsub(/^\[|\]$/, "", s);
      k=split(s, a, " ");
      if (a[1] != "" && a[1] != "+yolo" && a[1] !~ /^(fleet=|pr-identity=)/) mode=a[1];
      for (j=1; j<=k; j++) {
        if (a[j] == "+yolo") yolo="on";
        else if (a[j] ~ /^fleet=/) fleet=substr(a[j], 7);
        else if (a[j] ~ /^pr-identity=/) {
          if (profile_seen == 1) profile_error="duplicate-pr-identity";
          profile_seen=1;
          profile=substr(a[j], 13);
          if (profile == "") profile_error="empty-pr-identity";
          if (j == 1 || a[1] !~ /^(no-mistakes|direct-PR|local-only|no-mistakes-prod-only)$/) profile_error="reordered-pr-identity";
        }
      }
      if (profile_seen == 1 && mode == "local-only") profile_error="local-only-pr-identity";
      if (profile_seen == 1 && mode == "no-mistakes") profile_error="no-mistakes-pr-identity";
      if (profile_seen == 1 && mode == "no-mistakes-prod-only") profile_error="conditional-pr-identity";
      if (profile_seen == 1 && profile != "atlas-pat") profile_error="unknown-pr-identity";
    }
    printf "%s\t%s\t%s\t%s\t%s\n", mode, yolo, fleet, profile, profile_error;
    exit
  }
' "$REG")

if [ -z "$parsed" ]; then
  missing_project
  exit 0
fi

mode=${parsed%%$'\t'*}
rest=${parsed#*$'\t'}
yolo=${rest%%$'\t'*}
rest=${rest#*$'\t'}
fleet=${rest%%$'\t'*}
rest=${rest#*$'\t'}
profile=${rest%%$'\t'*}
profile_error=${rest#*$'\t'}

case "$WANT" in
  known) printf '%s\n' yes; exit 0 ;;
  fleet)
    if [ -n "$fleet" ]; then printf '%s\n' "$fleet"; else printf '%s\n' "$FLEET_DEFAULT"; fi
    exit 0
    ;;
  pr_identity)
    if [ -n "$profile_error" ]; then
      echo "error: invalid pr-identity for $NAME ($profile_error)" >&2
      exit 2
    fi
    printf '%s\n' "$profile"
    exit 0
    ;;
esac

case "$mode" in
  no-mistakes|direct-PR|local-only|no-mistakes-prod-only) ;;
  *) echo "warn: unknown mode \"$mode\" for $NAME; defaulting to no-mistakes off" >&2; mode=no-mistakes; yolo=off ;;
esac
case "$yolo" in on|off) ;; *) yolo=off ;; esac
if [ "$RAW" -eq 0 ] && [ "$mode" = no-mistakes-prod-only ]; then
  mode=no-mistakes
fi
printf '%s %s\n' "$mode" "$yolo"
