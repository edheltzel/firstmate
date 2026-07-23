#!/usr/bin/env bash
# Static watcher program for a validated PR/MR poll sidecar.
# It emits exactly one merged line for a merged PR or MR and stays silent on
# non-opted-in errors, so a failed lookup can never be read as a merge. An
# opted-in identity check delegates to the host broker and emits a safe
# read-error line so auth failure is visible.
# The provider-tagged identity is data in the sidecar and is never interpolated
# into this source, so these bytes are identical for every task.
# Non-opted providers are read through their own standard CLI, gh for GitHub and
# glab for GitLab, so an upstream checkout needs no extra tooling to follow either.
set -u
LC_ALL=C
export LC_ALL
data=
POLL_ROOT=${FM_PR_POLL_ROOT:-${FM_ROOT_OVERRIDE:-}}
POLL_HOME=${FM_PR_POLL_HOME:-${FM_HOME:-}}
POLL_STATE=${FM_PR_POLL_STATE:-${FM_STATE_OVERRIDE:-${POLL_HOME:+$POLL_HOME/state}}}
POLL_TASK_ID=${FM_PR_POLL_TASK_ID:-}

if [ "$#" -eq 6 ] && [ "$1" = --validated ]; then
  provider=$2
  url=$3
  host=$4
  path=$5
  number=$6
elif [ "$#" -eq 0 ]; then
  case "$0" in
    *.check.sh) data=${0%.check.sh}.pr-poll ;;
    *) exit 0 ;;
  esac

  [ -f "$data" ] && [ ! -L "$data" ] || exit 0
  { exec 3< "$data"; } 2>/dev/null || exit 0
  IFS= read -r provider <&3 || exit 0
  IFS= read -r url <&3 || exit 0
  IFS= read -r host <&3 || exit 0
  IFS= read -r path <&3 || exit 0
  IFS= read -r number <&3 || exit 0
  if IFS= read -r _extra <&3; then
    exit 0
  fi
  exec 3<&-
else
  exit 0
fi

if [ -n "$POLL_TASK_ID" ] && [ -n "$POLL_STATE" ]; then
  data="$POLL_STATE/$POLL_TASK_ID.pr-poll"
fi
if [ -z "$POLL_TASK_ID" ] && [ -n "$data" ]; then
  POLL_TASK_ID=${data##*/}
  POLL_TASK_ID=${POLL_TASK_ID%.pr-poll}
fi

case "$number" in
  [1-9]*) ;;
  *) exit 0 ;;
esac
case "$number" in
  *[!0-9]*) exit 0 ;;
esac

atlas_opted_in=0
atlas_binding_state=absent
atlas_meta_identity=none
if [ -n "$POLL_TASK_ID" ] && [ -n "$POLL_STATE" ]; then
  poll_meta="$POLL_STATE/$POLL_TASK_ID.meta"
  if [ -f "$poll_meta" ] && [ ! -L "$poll_meta" ]; then
    atlas_meta_identity=$(sed -n 's/^pr_identity=//p' "$poll_meta" | tail -1)
  fi
  poll_binding="$POLL_STATE/$POLL_TASK_ID.pr-binding"
  if [ -e "$poll_binding" ] || [ -L "$poll_binding" ]; then
    atlas_opted_in=1
    if [ -f "$poll_binding" ] && [ ! -L "$poll_binding" ] \
      && [ "$(stat -f %l "$poll_binding" 2>/dev/null || stat -c %h "$poll_binding" 2>/dev/null)" = 1 ]; then
      atlas_binding_profile=$(awk -F= '$1 == "profile" { count++; value=$2 } END { if (count == 1 && value != "") print value; else exit 1 }' "$poll_binding" 2>/dev/null || true)
      if [ "$atlas_binding_profile" = atlas-pat ]; then
        atlas_binding_state=valid
      else
        atlas_binding_state=invalid
      fi
    else
      atlas_binding_state=invalid
    fi
  elif [ "$atlas_meta_identity" = atlas-pat ]; then
    atlas_opted_in=1
    atlas_binding_state=missing
  fi
  if [ "$atlas_meta_identity" = atlas-pat ]; then
    atlas_opted_in=1
  elif [ "$atlas_binding_state" = valid ]; then
    atlas_binding_state=invalid
  fi
fi

# Every component is revalidated here rather than trusted from the sidecar, and
# the stored URL must then be exactly reconstructible from those components, so
# a doctored sidecar cannot redirect this poll at another host or project.
case "$provider" in
  github)
    [ "$host" = github.com ] || exit 0
    owner=${path%%/*}
    repo=${path#*/}
    [ "${#owner}" -ge 1 ] && [ "${#owner}" -le 39 ] || exit 0
    case "$owner" in
      *[!A-Za-z0-9-]*|-*|*-|*--*) exit 0 ;;
    esac
    [ "${#repo}" -ge 1 ] && [ "${#repo}" -le 100 ] || exit 0
    case "$repo" in
      .|..|*[!A-Za-z0-9._-]*) exit 0 ;;
    esac
    [ "$url" = "https://github.com/$owner/$repo/pull/$number" ] || exit 0
    if [ "$atlas_opted_in" = 1 ] && [ "$atlas_binding_state" != valid ]; then
      if [ "$atlas_binding_state" = missing ] || [ -z "$POLL_TASK_ID" ] || [ -z "$POLL_ROOT" ] \
        || [ -z "$POLL_HOME" ] || [ -z "$POLL_STATE" ]; then
        printf '%s\n' 'read-error: Atlas PR binding is unavailable'
      else
        printf '%s\n' 'read-error: Atlas PR binding is invalid or downgraded'
      fi
      exit 0
    fi
    if [ -n "$POLL_TASK_ID" ] && [ -n "$POLL_ROOT" ] && [ -n "$POLL_HOME" ] \
      && [ -f "$POLL_STATE/$POLL_TASK_ID.pr-binding" ] \
      && [ ! -L "$POLL_STATE/$POLL_TASK_ID.pr-binding" ]; then
      if [ "${FM_PR_IDENTITY_TEST_MODE:-0}" = 1 ]; then
        verify_output=$(FM_ROOT_OVERRIDE="$POLL_ROOT" FM_HOME="$POLL_HOME" \
          FM_STATE_OVERRIDE="$POLL_STATE" "$POLL_ROOT/bin/fm-pr-identity.sh" \
          verify "$POLL_TASK_ID" "$url" 2>/dev/null) || {
          printf '%s\n' 'read-error: Atlas PR verification failed'
          exit 0
        }
      else
        verify_output=$(env -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE \
          FM_HOME="$POLL_HOME" "$POLL_ROOT/bin/fm-pr-identity.sh" \
          verify "$POLL_TASK_ID" "$url" 2>/dev/null) || {
          printf '%s\n' 'read-error: Atlas PR verification failed'
          exit 0
        }
      fi
      merged=$(printf '%s\n' "$verify_output" | sed -n 's/^merged=//p' | head -1)
      [ "$merged" = 1 ] && printf '%s\n' merged
      exit 0
    fi
    [ "$atlas_opted_in" = 0 ] || { printf '%s\n' 'read-error: Atlas PR binding could not be evaluated'; exit 0; }
    state=$(gh pr view "$url" --json state -q .state 2>/dev/null) || exit 0
    [ "$state" = MERGED ] && printf '%s\n' merged
    ;;
  gitlab)
    [ "${#host}" -ge 1 ] && [ "${#host}" -le 253 ] || exit 0
    [ "$host" != github.com ] || exit 0
    case "$host" in
      .*|*.|*..*|*[!a-z0-9.-]*) exit 0 ;;
    esac
    [ "${#path}" -ge 3 ] && [ "${#path}" -le 1024 ] || exit 0
    case "$path" in
      /*|*/|*//*) exit 0 ;;
    esac
    # A GitLab project sits under at least one group at no fixed depth, and
    # GitLab reserves the "-" segment as its route separator.
    rest=$path
    segments=0
    while [ -n "$rest" ]; do
      case "$rest" in
        */*) segment=${rest%%/*}; rest=${rest#*/} ;;
        *) segment=$rest; rest= ;;
      esac
      segments=$((segments + 1))
      [ "$segments" -le 20 ] || exit 0
      [ "${#segment}" -ge 1 ] && [ "${#segment}" -le 255 ] || exit 0
      case "$segment" in
        .|..|-*|*.git|*.atom|*[!A-Za-z0-9._-]*) exit 0 ;;
      esac
    done
    [ "$segments" -ge 2 ] || exit 0
    [ "$url" = "https://$host/$path/-/merge_requests/$number" ] || exit 0
    # glab resolves the instance from the project URL passed to -R, so the host
    # comes from the validated record rather than glab's configured default.
    # It cannot take a merge request URL the way gh does: that form shells out
    # to git for the current repository, and the watcher runs in no repository.
    # The state is read from glab's own field output rather than its JSON,
    # because plain glab has no field selector and firstmate does not require a
    # JSON processor; only an exact "merged" wakes, so a changed format or an
    # unreadable merge request stays silent instead of reporting a merge.
    raw=$(glab mr view "$number" -R "https://$host/$path" 2>/dev/null) || exit 0
    state=$(printf '%s\n' "$raw" | sed -n 's/^state:[[:space:]]*//p' | head -1) || exit 0
    [ "$state" = merged ] && printf '%s\n' merged
    ;;
  *) exit 0 ;;
esac
exit 0
