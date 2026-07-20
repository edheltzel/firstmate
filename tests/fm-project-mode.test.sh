#!/usr/bin/env bash
# tests/fm-project-mode.test.sh - unit coverage for bin/fm-project-mode.sh, the
# single parser of the data/projects.md registry line. Covers the delivery
# mode/yolo output (unchanged, backward-compatible) AND the --fleet Fleet
# display-name resolution the herdr backend derives "<Display>-Fleet" worker
# workspace labels from (docs/herdr-backend.md "Fleet workspaces"). The herdr
# resolver has only INDIRECT coverage of this awk, so these tests pin the
# registry-line contract directly.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCRATCH=$(fm_test_tmproot fm-project-mode)
mkdir -p "$SCRATCH/data"
cat > "$SCRATCH/data/projects.md" <<'EOF'
- Echo [no-mistakes] - voice daemon (added 2026-07-17)
- atlas-config [direct-PR fleet=Atlas] - config (added 2026-07-17)
- MyChron [local-only +yolo fleet=MyChron] - emr (added 2026-07-19)
- Ali [no-mistakes +yolo] - health (added 2026-07-19)
- Legacy - no bracket at all (added 2026-07-01)
- FleetOnly [fleet=Custom] - only a fleet token, no mode (added 2026-07-20)
- Agent-Themis [local-only] - registry key differs from its clone-dir basename (added 2026-07-20)
- Aliased-Key [direct-PR fleet=Shown] - key differs from basename AND carries a fleet alias (added 2026-07-20)
EOF

run() { FM_HOME="$SCRATCH" FM_DATA_OVERRIDE="$SCRATCH/data" "$ROOT/bin/fm-project-mode.sh" "$@" 2>/dev/null; }

# --- --fleet: default = repository name --------------------------------------
[ "$(run --fleet Echo)" = "Echo" ] || fail "--fleet Echo should default to the repo name 'Echo'"
pass "fm-project-mode --fleet: a project with no fleet= alias defaults to its repository name"

# --- --fleet: explicit alias overrides the default ---------------------------
[ "$(run --fleet atlas-config)" = "Atlas" ] || fail "--fleet atlas-config should resolve the fleet=Atlas alias, got '$(run --fleet atlas-config)'"
pass "fm-project-mode --fleet: an explicit fleet= alias overrides the repository-name default"

# --- --fleet: alias coexists with mode + +yolo, order-independent ------------
[ "$(run --fleet MyChron)" = "MyChron" ] || fail "--fleet MyChron should resolve fleet=MyChron alongside local-only +yolo"
[ "$(run --fleet Ali)" = "Ali" ] || fail "--fleet Ali (mode + +yolo, no alias) should default to 'Ali'"
[ "$(run --fleet FleetOnly)" = "Custom" ] || fail "a bracket with only fleet= (no mode) should still resolve the alias, got '$(run --fleet FleetOnly)'"
pass "fm-project-mode --fleet: fleet= coexists with mode and +yolo tokens, and works without a mode token"

# --- --fleet: no bracket, unregistered, and no registry all default to name --
[ "$(run --fleet Legacy)" = "Legacy" ] || fail "--fleet on a legacy (no-bracket) line should default to the name"
[ "$(run --fleet Unregistered)" = "Unregistered" ] || fail "--fleet on an unregistered project should default deterministically to the given name"
NOREG=$(fm_test_tmproot fm-project-mode-noreg)
[ "$(FM_HOME="$NOREG" FM_DATA_OVERRIDE="$NOREG/data" "$ROOT/bin/fm-project-mode.sh" --fleet Whatever 2>/dev/null)" = "Whatever" ] \
  || fail "--fleet with no registry file at all should default to the given name"
pass "fm-project-mode --fleet: no bracket, unregistered project, and missing registry all default deterministically to the name"

# --- --fleet <key> <default>: key differs from the repository basename ---------
# The herdr backend passes the canonical registry key AND the repository basename
# default so a key-mismatched project resolves its mode/Fleet without renaming the
# workspace (bin/fm-project-mode.sh header; the Agent-Themis/Firstmate case).
[ "$(run --fleet Agent-Themis Firstmate)" = "Firstmate" ] \
  || fail "--fleet <key> <default>: a registered key with no fleet= alias must return the basename DEFAULT, not the key, got '$(run --fleet Agent-Themis Firstmate)'"
[ "$(run --fleet Aliased-Key Firstmate)" = "Shown" ] \
  || fail "--fleet <key> <default>: an explicit fleet= alias must win over the basename default, got '$(run --fleet Aliased-Key Firstmate)'"
[ "$(run --fleet Unregistered some-clone)" = "some-clone" ] \
  || fail "--fleet <key> <default>: an unknown key must fall back to the basename DEFAULT, got '$(run --fleet Unregistered some-clone)'"
[ "$(FM_HOME="$NOREG" FM_DATA_OVERRIDE="$NOREG/data" "$ROOT/bin/fm-project-mode.sh" --fleet AnyKey clone-dir 2>/dev/null)" = "clone-dir" ] \
  || fail "--fleet <key> <default>: with no registry file, the basename DEFAULT is used"
# Unknown key is still visibly diagnosed on stderr (the safest-fallback contract).
WARN=$(FM_HOME="$SCRATCH" FM_DATA_OVERRIDE="$SCRATCH/data" "$ROOT/bin/fm-project-mode.sh" --fleet Unregistered some-clone 2>&1 >/dev/null)
case "$WARN" in *"not in registry"*) : ;; *) fail "--fleet <key> <default>: an unknown key must still warn to stderr, got '$WARN'" ;; esac
pass "fm-project-mode --fleet <key> <default>: key-vs-basename resolution (default wins over key, alias wins over default, unknown still warns)"

# --- mode lookup keys on the registry KEY, not the clone basename -------------
[ "$(run Agent-Themis)" = "local-only off" ] || fail "mode lookup by registry key Agent-Themis should be 'local-only off', got '$(run Agent-Themis)'"
[ "$(run Firstmate)" = "no-mistakes off" ] || fail "the clone basename 'Firstmate' is NOT a registry key here, so it must fall back to 'no-mistakes off', got '$(run Firstmate)'"
pass "fm-project-mode: the mode lookup keys on the registry key; a bare clone basename that is not a key falls back to the safe default"

# --- mode/yolo output is byte-identical for existing callers (backward-compat) -
[ "$(run Echo)" = "no-mistakes off" ] || fail "mode/yolo output changed for Echo: got '$(run Echo)'"
[ "$(run atlas-config)" = "direct-PR off" ] || fail "the fleet= token must not disturb mode/yolo: got '$(run atlas-config)'"
[ "$(run MyChron)" = "local-only on" ] || fail "fleet= + +yolo must both parse: got '$(run MyChron)'"
[ "$(run Ali)" = "no-mistakes on" ] || fail "mode/yolo output changed for Ali: got '$(run Ali)'"
[ "$(run FleetOnly)" = "no-mistakes off" ] || fail "a fleet-only bracket must not be read as a mode: got '$(run FleetOnly)'"
[ "$(run Unregistered)" = "no-mistakes off" ] || fail "an unregistered project must still default to 'no-mistakes off'"
pass "fm-project-mode: the default '<mode> <yolo>' output stays byte-identical for existing callers, unaffected by fleet="
