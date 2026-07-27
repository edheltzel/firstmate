#!/usr/bin/env bash
# Behavior tests for session-lock harness identity and serialized claims.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

LOCK="$ROOT/bin/fm-lock.sh"
TMP_ROOT=$(fm_test_tmproot fm-session-lock)

make_fake_ps() {
  local fakebin=$1
  mkdir -p "$fakebin"
  cat > "$fakebin/ps" <<'SH'
#!/usr/bin/env bash
set -u
pid=
prev=
for arg in "$@"; do
  if [ "$prev" = -p ]; then
    pid=$arg
    break
  fi
  prev=$arg
done
case "$*" in
  *"comm="*)
    if [ "$pid" = "${FM_FAKE_OLD_PID:-}" ]; then
      printf '%s\n' "${FM_FAKE_OLD_COMM:-/bin/sleep}"
    elif [ "$pid" = "${FM_FAKE_HARNESS_PID:-}" ]; then
      printf '%s\n' "${FM_FAKE_HARNESS_COMM:-/usr/local/bin/codex}"
    elif [ -n "${FM_FAKE_HARNESS_PIDS_FILE:-}" ] && grep -Fx "$pid" "$FM_FAKE_HARNESS_PIDS_FILE" >/dev/null 2>&1; then
      printf '%s\n' '/usr/local/bin/codex'
    elif [ -n "${FM_FAKE_COMM:-}" ]; then
      printf '%s\n' "$FM_FAKE_COMM"
    else
      printf '%s\n' '/bin/bash'
    fi
    ;;
  *"args="*)
    printf '%s\n' "${FM_FAKE_ARGS:-${FM_FAKE_HARNESS_ARGS:-bash}}"
    ;;
  *"ppid="*)
    printf '%s\n' "${FM_FAKE_HARNESS_PID:-1}"
    ;;
  *) exit 1 ;;
esac
SH
  chmod +x "$fakebin/ps"
}

dead_pid() {
  local pid=999999
  while kill -0 "$pid" 2>/dev/null; do
    pid=$((pid + 1))
  done
  printf '%s\n' "$pid"
}

run_status_case() {
  local home=$1 fakebin=$2 comm=$3 args=$4
  mkdir -p "$home/state"
  printf '%s\n' "$$" > "$home/state/.lock"
  FM_HOME="$home" FM_FAKE_COMM="$comm" FM_FAKE_ARGS="$args" \
    PATH="$fakebin:$PATH" "$LOCK" status
}

test_live_supported_executable_names() {
  local fakebin="$TMP_ROOT/live-names/fakebin" home="$TMP_ROOT/live-names/home" spec comm args out
  make_fake_ps "$fakebin"
  mkdir -p "$home/state"
  for spec in \
    "codex|/usr/local/bin/codex|codex --session" \
    "claude|/usr/local/bin/claude|claude --resume" \
    "pi|/tmp/pi|/tmp/pi 30" \
    "pi-signed|/tmp/pi-signed|pi-signed --session"; do
    IFS='|' read -r _ comm args <<EOF
$spec
EOF
    out=$(run_status_case "$home" "$fakebin" "$comm" "$args")
    assert_contains "$out" 'lock: held by live harness pid' \
      "live supported executable $comm was classified as stale"
  done
  pass "session-lock: codex, claude, bare pi, and pi-signed executable names stay live"
}

test_arguments_do_not_authenticate_retitled_executable() {
  local fakebin="$TMP_ROOT/retitled/fakebin" home="$TMP_ROOT/retitled/home" out
  make_fake_ps "$fakebin"
  out=$(run_status_case "$home" "$fakebin" /usr/bin/sleep '/usr/bin/sleep codex --session')
  assert_contains "$out" 'lock: stale (pid' \
    "a non-harness executable with codex only in its arguments was treated as live"
  pass "session-lock: command arguments cannot retitle an unrelated executable"
}

test_interpreter_script_arguments_remain_supported() {
  local fakebin="$TMP_ROOT/interpreter/fakebin" home="$TMP_ROOT/interpreter/home" out
  make_fake_ps "$fakebin"
  out=$(run_status_case "$home" "$fakebin" /usr/local/bin/node '/opt/bin/codex --resume')
  assert_contains "$out" 'lock: held by live harness pid' \
    "node-launched codex was classified as stale"
  out=$(run_status_case "$home" "$fakebin" /usr/local/bin/python3 '/opt/bin/claude --resume')
  assert_contains "$out" 'lock: held by live harness pid' \
    "python-launched claude was classified as stale"
  pass "session-lock: supported interpreter-launched harnesses remain live"
}

test_dead_owner_is_reclaimed() {
  local fakebin="$TMP_ROOT/dead/fakebin" home="$TMP_ROOT/dead/home" dead holder out status lock_pid
  make_fake_ps "$fakebin"
  mkdir -p "$home/state"
  dead=$(dead_pid)
  printf '%s\n' "$dead" > "$home/state/.lock"
  sleep 3 &
  holder=$!
  status=0
  out=$(FM_HOME="$home" FM_FAKE_HARNESS_PID="$holder" PATH="$fakebin:$PATH" "$LOCK" 2>&1) || status=$?
  kill "$holder" 2>/dev/null || true
  wait "$holder" 2>/dev/null || true
  expect_code 0 "$status" "dead session-lock owner should be reclaimed"
  assert_contains "$out" "lock acquired: harness pid $holder" \
    "reclaimed lock did not publish the verified harness owner"
  lock_pid=$(cat "$home/state/.lock")
  [ "$lock_pid" = "$holder" ] || fail "reclaimed lock claim was not verified in place"
  pass "session-lock: dead owner reclamation remains available"
}

test_live_pi_owner_is_not_stolen() {
  local fakebin="$TMP_ROOT/live-pi/fakebin" home="$TMP_ROOT/live-pi/home" old holder out status lock_pid
  make_fake_ps "$fakebin"
  mkdir -p "$home/state"
  sleep 3 &
  old=$!
  printf '%s\n' "$old" > "$home/state/.lock"
  sleep 3 &
  holder=$!
  status=0
  out=$(FM_HOME="$home" FM_FAKE_HARNESS_PID="$holder" FM_FAKE_OLD_PID="$old" \
    FM_FAKE_OLD_COMM=/tmp/pi PATH="$fakebin:$PATH" "$LOCK" 2>&1) || status=$?
  kill "$old" "$holder" 2>/dev/null || true
  wait "$old" "$holder" 2>/dev/null || true
  expect_code 1 "$status" "live bare-pi owner must block a competing acquisition"
  assert_contains "$out" 'another live firstmate session holds the lock' \
    "live bare-pi owner refusal was not reported"
  lock_pid=$(cat "$home/state/.lock")
  [ "$lock_pid" = "$old" ] || fail "live bare-pi owner was overwritten"
  pass "session-lock: a live bare-pi owner is not falsely treated as stale"
}

test_concurrent_claims_have_one_verified_winner() {
  local case_dir="$TMP_ROOT/concurrent" fakebin="$TMP_ROOT/concurrent/fakebin" home="$TMP_ROOT/concurrent/home"
  local pids=() i winner_count winner_pid lock_pid holders_file
  make_fake_ps "$fakebin"
  mkdir -p "$home/state" "$case_dir/out"
  holders_file="$case_dir/holders"
  : > "$holders_file"
  i=1
  while [ "$i" -le 12 ]; do
    (
      sleep 3 &
      local_holder=$!
      printf '%s\n' "$local_holder" >> "$holders_file"
      FM_HOME="$home" FM_FAKE_HARNESS_PID="$local_holder" FM_FAKE_HARNESS_PIDS_FILE="$holders_file" PATH="$fakebin:$PATH" \
        "$LOCK" > "$case_dir/out/$i" 2>&1
      rc=$?
      printf 'rc=%s holder=%s\n' "$rc" "$local_holder" >> "$case_dir/out/$i"
      wait "$local_holder" 2>/dev/null || true
    ) &
    pids+=("$!")
    i=$((i + 1))
  done
  for pid in "${pids[@]}"; do
    wait "$pid" || true
  done
  winner_count=$(grep -l '^lock acquired: harness pid ' "$case_dir"/out/* | wc -l | tr -d ' ')
  [ "$winner_count" -eq 1 ] || fail "concurrent session-lock claims had $winner_count winners"
  winner_pid=$(sed -n 's/^lock acquired: harness pid //p' "$case_dir"/out/*)
  lock_pid=$(cat "$home/state/.lock")
  [ "$lock_pid" = "$winner_pid" ] || fail "concurrent claim overwrote the verified winner"
  pass "session-lock: concurrent contenders leave one verified owner without overwrite"
}

test_live_supported_executable_names
test_arguments_do_not_authenticate_retitled_executable
test_interpreter_script_arguments_remain_supported
test_dead_owner_is_reclaimed
test_live_pi_owner_is_not_stolen
test_concurrent_claims_have_one_verified_winner

echo "# all fm-session-lock tests passed"
