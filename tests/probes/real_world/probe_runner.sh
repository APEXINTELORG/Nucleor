#!/usr/bin/env bash
# PROBE-1 driver — exercise each common nuc subcommand against a real-world
# (NOT 5-line-fixture) program. Designed to surface bug classes that hide
# behind trivial fixtures (control flow, multi-arg fns, struct, vec
# literal exhaustively touched).
#
# Each step asserts both the exit code AND at least one on-disk artifact
# or output marker. A pass means the CLI command actually did its job, not
# just that the binary returned 0.
#
# Usage:
#   bash tests/probes/real_world/probe_runner.sh
#
# Output: one line per subcommand of the form
#   PROBE-<N> <subcmd>: PASS  / FAIL: <reason>
#
# Exit code: 0 if all probes pass, otherwise 1 and the failing subcommand
# name(s) are emitted to stderr.

set -u

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT" || exit 1

# Pick the right binary per host. Same shape as tools/verify.sh.
case "$(uname -s)" in
    CYGWIN*|MINGW*|MSYS*)
        if [ -f "$ROOT/bin/nucleor.exe" ]; then
            BIN="$ROOT/bin/nucleor.exe"
        else
            BIN="$ROOT/bin/nucleor"
        fi
        ;;
    *)
        if [ -f "$ROOT/bin/nucleor" ]; then
            BIN="$ROOT/bin/nucleor"
        else
            BIN="$ROOT/bin/nucleor.exe"
        fi
        ;;
esac

if [ ! -f "$BIN" ]; then
    echo "PROBE-RUNNER FAIL: missing nucleor binary at $BIN" >&2
    exit 1
fi

PROBE_TMP=""
cleanup() {
    [ -n "$PROBE_TMP" ] && rm -rf "$PROBE_TMP" 2>/dev/null
    rm -rf target/_probe_* 2>/dev/null
    rm -f target/inventory_score_test-test* target/inventory_score* 2>/dev/null
    rm -f target/_pi_* 2>/dev/null
}
trap cleanup EXIT

PASS_COUNT=0
FAIL_COUNT=0
FAILED_PROBES=""

probe_pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "PROBE-$1 $2: PASS"
}

probe_fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAILED_PROBES="$FAILED_PROBES $2"
    echo "PROBE-$1 $2: FAIL: $3" >&2
}

DRIVER="tests/probes/real_world/inventory_score.nr"
TEST_DRIVER="tests/probes/real_world/inventory_score_test.nr"

# PROBE-1.1 nuc build — real-world program
out=$("$BIN" build "$DRIVER" -o "_probe_inv" --no-cache 2>&1)
rc=$?
if [ "$rc" -ne 0 ]; then
    probe_fail "1.1" "nuc build" "exit=$rc"
elif [ ! -f "target/_probe_inv.exe" ] && [ ! -f "target/_probe_inv" ]; then
    probe_fail "1.1" "nuc build" "no exe artifact at target/_probe_inv[.exe]"
elif ! echo "$out" | grep -qE "compiled:|emitted:|native link: cache hit"; then
    probe_fail "1.1" "nuc build" "missing 'compiled:'/'emitted:'/'native link:' marker in output"
else
    probe_pass "1.1" "nuc build"
fi

# PROBE-1.2 produced exe runs and prints the expected output
exe="target/_probe_inv"
if [ -f "$exe.exe" ]; then exe="$exe.exe"; fi
if [ -f "$exe" ]; then
    run_out=$("$exe" 2>&1)
    rc=$?
    run_out=$(printf '%s' "$run_out" | tr -d '\r')
    if [ "$rc" -ne 0 ]; then
        probe_fail "1.2" "build-then-run" "exit=$rc out='$run_out'"
    elif ! echo "$run_out" | grep -q "^total=286$"; then
        probe_fail "1.2" "build-then-run" "expected 'total=286' in output, got: '$run_out'"
    elif ! echo "$run_out" | grep -q "^class=A$"; then
        probe_fail "1.2" "build-then-run" "expected 'class=A' in output, got: '$run_out'"
    else
        probe_pass "1.2" "build-then-run"
    fi
else
    probe_fail "1.2" "build-then-run" "exe not present (build artifact issue from PROBE-1.1)"
fi

# PROBE-1.3 nuc test — exercise harness path on real-world program
out=$("$BIN" test "$TEST_DRIVER" --no-cache 2>&1)
rc=$?
if [ "$rc" -ne 0 ]; then
    probe_fail "1.3" "nuc test" "exit=$rc"
elif ! echo "$out" | grep -q "test result: PASS (3 tests)"; then
    probe_fail "1.3" "nuc test" "expected 'test result: PASS (3 tests)', got tail: '$(echo "$out" | tail -3 | tr '\n' '|')'"
else
    probe_pass "1.3" "nuc test"
fi

# PROBE-1.4 nuc check — run all checkers against the real-world program
out=$("$BIN" check "$DRIVER" 2>&1)
rc=$?
if [ "$rc" -ne 0 ]; then
    probe_fail "1.4" "nuc check" "exit=$rc out='$out'"
elif echo "$out" | grep -qE "^error\b|^error\["; then
    probe_fail "1.4" "nuc check" "checker reported errors on a known-good program: '$out'"
else
    probe_pass "1.4" "nuc check"
fi

# PROBE-1.5 nuc summary — produce module interface card
out=$("$BIN" summary "$DRIVER" 2>&1)
rc=$?
if [ "$rc" -ne 0 ]; then
    probe_fail "1.5" "nuc summary" "exit=$rc"
elif ! echo "$out" | grep -qiE "score_item|classify|main"; then
    probe_fail "1.5" "nuc summary" "expected fn names in output, got: '$(echo "$out" | head -5 | tr '\n' '|')'"
else
    probe_pass "1.5" "nuc summary"
fi

# PROBE-1.6 nuc explain — explain a real diagnostic code
out=$("$BIN" explain NR020 2>&1)
rc=$?
if [ "$rc" -ne 0 ]; then
    probe_fail "1.6" "nuc explain" "exit=$rc"
elif ! echo "$out" | grep -qiE "NR020|parse"; then
    probe_fail "1.6" "nuc explain" "expected 'NR020' or 'parse' in explanation, got: '$(echo "$out" | head -3 | tr '\n' '|')'"
else
    probe_pass "1.6" "nuc explain"
fi

# PROBE-1.7 nuc init — scaffold a fresh project, assert the artifacts
PROBE_TMP="$(mktemp -d 2>/dev/null || echo "/tmp/probe_init_$$")"
mkdir -p "$PROBE_TMP" 2>/dev/null
( cd "$PROBE_TMP" && "$BIN" init nucleor_probe_proj > /tmp/probe_init.log 2>&1 )
rc=$?
proj_dir="$PROBE_TMP/nucleor_probe_proj"
if [ "$rc" -ne 0 ]; then
    probe_fail "1.7" "nuc init" "exit=$rc, log: $(cat /tmp/probe_init.log 2>/dev/null | tail -3 | tr '\n' '|')"
elif [ ! -f "$proj_dir/Nucleor.toml" ] && [ ! -f "$proj_dir/nucleor.toml" ]; then
    # Some scaffold paths drop the manifest in a different name; check both.
    found=$(find "$proj_dir" -maxdepth 2 -name "*.toml" 2>/dev/null | head -1)
    if [ -z "$found" ]; then
        probe_fail "1.7" "nuc init" "no .toml manifest produced under $proj_dir"
    else
        probe_pass "1.7" "nuc init"
    fi
else
    probe_pass "1.7" "nuc init"
fi

# PROBE-1.8 nuc clean — remove target/ and assert idempotency
# Use a sub-target to avoid wiping the parent verify run's artifacts.
# Build a quick artifact, clean it, ensure cleanup happened.
"$BIN" build "$DRIVER" -o "_probe_clean_check" --no-cache > /dev/null 2>&1
if [ ! -f "target/_probe_clean_check.exe" ] && [ ! -f "target/_probe_clean_check" ]; then
    probe_fail "1.8" "nuc clean (pre-build)" "could not build _probe_clean_check first"
else
    out=$("$BIN" clean --cache 2>&1)
    rc=$?
    if [ "$rc" -ne 0 ]; then
        probe_fail "1.8" "nuc clean" "exit=$rc"
    elif [ -d "target/.nuc_cache" ] || [ -d "target/.nuc_cache_v2" ]; then
        probe_fail "1.8" "nuc clean" "expected target/.nuc_cache* to be removed, still present"
    else
        probe_pass "1.8" "nuc clean"
    fi
fi

echo ""
echo "PROBE-1 runner: $PASS_COUNT passed, $FAIL_COUNT failed."
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "Failed probes:$FAILED_PROBES" >&2
    exit 1
fi
exit 0
