#!/usr/bin/env bash
# Behavior tests for OMP harness detection, lock identity, and composer shapes.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP_ROOT=$(fm_test_tmproot fm-omp-harness)
BASE_PATH=${FM_TEST_BASE_PATH:-/usr/bin:/bin:/usr/sbin:/sbin}

make_ps() {  # <dir> <args>
  local dir=$1 args=$2 fakebin
  fakebin=$(fm_fakebin "$dir")
  cat > "$fakebin/ps" <<SH
#!/usr/bin/env bash
case "\$*" in
  *'comm='*) printf '%s\n' bun ;;
  *'args='*) printf '%s\n' '$args' ;;
  *'ppid='*) printf '%s\n' 1 ;;
esac
SH
  chmod +x "$fakebin/ps"
  printf '%s\n' "$fakebin"
}

test_omp_detection_marker_and_bun_ancestry() {
  local fb out
  out=$(env -u CLAUDECODE -u PI_CODING_AGENT -u GROK_AGENT OMP_AGENT=1 \
    "$ROOT/bin/fm-harness.sh")
  [ "$out" = omp ] || fail "OMP_AGENT=1 should detect omp, got '$out'"

  fb=$(make_ps "$TMP_ROOT/ancestry" 'bun bun /Users/test/.bun/bin/omp --auto-approve')
  out=$(env -u CLAUDECODE -u PI_CODING_AGENT -u GROK_AGENT -u OMP_AGENT \
    PATH="$fb:$BASE_PATH" "$ROOT/bin/fm-harness.sh")
  [ "$out" = omp ] || fail "the verified Bun executable ancestry should detect omp, got '$out'"

  fb=$(make_ps "$TMP_ROOT/unrelated" 'bun /tmp/build.ts prompt mentions omp')
  out=$(env -u CLAUDECODE -u PI_CODING_AGENT -u GROK_AGENT -u OMP_AGENT \
    PATH="$fb:$BASE_PATH" "$ROOT/bin/fm-harness.sh")
  [ "$out" = unknown ] || fail "an unrelated Bun process should stay unknown, got '$out'"
  pass "OMP detection uses the launch marker or exact Bun ancestry"
}

test_omp_bun_process_can_hold_session_lock() {
  local home fb out
  home="$TMP_ROOT/lock-home"
  mkdir -p "$home/state"
  printf '%s\n' "$$" > "$home/state/.lock"
  fb=$(make_ps "$TMP_ROOT/lock" 'bun bun /Users/test/.bun/bin/omp --auto-approve')
  out=$(FM_HOME="$home" PATH="$fb:$BASE_PATH" "$ROOT/bin/fm-lock.sh" status)
  assert_contains "$out" "lock: held by live harness pid" \
    "session lock did not recognize OMP's Bun process"
  pass "OMP's exact Bun process is a verified session-lock holder"
}

make_composer_tmux() {  # <dir>
  local dir=$1 fakebin
  fakebin=$(fm_fakebin "$dir")
  cat > "$fakebin/tmux" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in
  display-message) printf '%s\n' 0 ;;
  capture-pane) cat "${FM_OMP_COMPOSER_CAPTURE:?}" ;;
esac
SH
  chmod +x "$fakebin/tmux"
  printf '%s\n' "$fakebin"
}

test_omp_rounded_composer_classifies_empty_and_pending() {
  local dir fb capture out
  dir="$TMP_ROOT/composer"
  fb=$(make_composer_tmux "$dir")
  capture="$dir/capture"

  printf '%s\n' '╰─                                                                            ─╯' > "$capture"
  out=$(PATH="$fb:$BASE_PATH" FM_OMP_COMPOSER_CAPTURE="$capture" \
    bash -c '. "$0/bin/fm-tmux-lib.sh"; fm_tmux_composer_state pane' "$ROOT")
  [ "$out" = empty ] || fail "OMP's glyphless rounded idle composer should be empty, got '$out'"

  printf '%s\n' '╰─ pending instructions                                                       ─╯' > "$capture"
  out=$(PATH="$fb:$BASE_PATH" FM_OMP_COMPOSER_CAPTURE="$capture" \
    bash -c '. "$0/bin/fm-tmux-lib.sh"; fm_tmux_composer_state pane' "$ROOT")
  [ "$out" = pending ] || fail "OMP's rounded composer with real text should be pending, got '$out'"
  pass "OMP's rounded composer preserves empty-versus-pending safety"
}

test_omp_busy_signature_is_registered() {
  bash -c '. "$0/bin/fm-tmux-lib.sh"; printf "%s" "$FM_TMUX_BUSY_REGEX_DEFAULT"' "$ROOT" \
    | grep -F '⟨esc⟩' >/dev/null \
    || fail "tmux busy signature does not include OMP's cancel hint"
  grep -F '⟨esc⟩' "$ROOT/bin/fm-watch.sh" >/dev/null \
    || fail "watcher busy signature does not include OMP's cancel hint"
  pass "OMP busy signature is shared by watcher and tmux submit logic"
}

test_omp_detection_marker_and_bun_ancestry
test_omp_bun_process_can_hold_session_lock
test_omp_rounded_composer_classifies_empty_and_pending
test_omp_busy_signature_is_registered

echo "# all fm-omp-harness tests passed"
