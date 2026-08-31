#!/usr/bin/env bash
set -uo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
LAUNCHER="$ROOT/bin/omarchy-coffer"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

passed=0
failed=0

ok() { printf 'ok   %s\n' "$1"; passed=$((passed + 1)); }
no() { printf 'FAIL %s\n  %s\n' "$1" "${2:-}"; failed=$((failed + 1)); }

fake_coffer() {
  cat > "$TMP/coffer" <<SH
#!/usr/bin/env bash
printf '%s\n' "\$@" >> "$TMP/argv"
$1
SH
  chmod +x "$TMP/coffer"
  : > "$TMP/argv"
}

run() { COFFER_BIN="$TMP/coffer" "$LAUNCHER" "$@"; }

fake_coffer 'exit 0'

out=$(run which)
[[ "$out" == "$TMP/coffer" ]] && ok "which reports the resolved executable" \
  || no "which reports the resolved executable" "got: $out"

out=$(HOME=/nonexistent PATH=/usr/bin XDG_DATA_HOME=/nonexistent XDG_DATA_DIRS=/nonexistent "$LAUNCHER" stash 2>&1)
[[ $? -ne 0 ]] || true
HOME=/nonexistent PATH=/usr/bin XDG_DATA_HOME=/nonexistent XDG_DATA_DIRS=/nonexistent "$LAUNCHER" stash >/dev/null 2>&1
[[ $? -eq 3 ]] && ok "a missing Coffer exits 3" || no "a missing Coffer exits 3" "got exit $?"
[[ "$out" == *"not found"* ]] && ok "a missing Coffer says so on stderr" \
  || no "a missing Coffer says so on stderr" "got: $out"

run bogus >/dev/null 2>&1
[[ $? -eq 2 ]] && ok "an unknown action exits 2" || no "an unknown action exits 2"

run done >/dev/null 2>&1
[[ $? -eq 2 ]] && ok "done without an id exits 2" || no "done without an id exits 2"

run done abc123
sleep 0.3
grep -qx -- "--done=abc123" "$TMP/argv" && ok "done forwards the inlined id" \
  || no "done forwards the inlined id" "argv: $(cat "$TMP/argv")"

run stash
sleep 0.3
grep -qx -- "--stash" "$TMP/argv" && ok "stash forwards --stash" \
  || no "stash forwards --stash" "argv: $(cat "$TMP/argv")"

fake_coffer 'sleep 30'
start=$(date +%s%N)
run clip
elapsed=$(( ($(date +%s%N) - start) / 1000000 ))
if [[ $elapsed -lt 2000 ]]; then
  ok "a long-lived Coffer does not hold the launcher open (${elapsed}ms)"
else
  no "a long-lived Coffer does not hold the launcher open" "took ${elapsed}ms"
fi
pkill -f "$TMP/coffer" 2>/dev/null

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[[ $failed -eq 0 ]]
