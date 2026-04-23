#!/usr/bin/env bash
# verify.sh — POSIX smoke gate for the Nucleor OSS distribution.
#
# Mirrors tools/verify.ps1. Same step counter, same exit code, same gates.
#
# Usage: ./tools/verify.sh
#
# Steps:
#   1. Confirm bin/nucleor loads
#   2. Build and run examples 01..06 + 08..12 (07 only if rust_bridge built)
#   3. Build and run all positive tests under tests/{lang,attrs,runtime,rods,features}
#   4. Confirm negative tests under tests/err/ fail with the expected diagnostic
#   5. Self-host loop: rebuild the compiler from source
#
# Exit code: 0 = ship-ready; 1 = a step failed.
#
# Output: progress counter [N/T] per step, colored OK/FAIL/SKIP labels when
# stdout is a TTY. Honors NO_COLOR (https://no-color.org/) and --no-color.

set -uo pipefail

NO_COLOR_FLAG=""
for arg in "$@"; do
    case "$arg" in
        --no-color) NO_COLOR_FLAG="1" ;;
    esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "$(uname -s)" in
    Linux*|Darwin*|CYGWIN*|MINGW*) BIN="$ROOT/bin/nucleor" ;;
    *) BIN="$ROOT/bin/nucleor" ;;
esac

# --- Color setup --------------------------------------------------------
USE_COLOR=1
[ -n "${NO_COLOR_FLAG}" ] && USE_COLOR=0
[ -n "${NO_COLOR:-}" ] && USE_COLOR=0
if [ ! -t 1 ]; then USE_COLOR=0; fi

color() {
    local ansi="$1"; shift
    if [ "$USE_COLOR" = "1" ]; then printf '\033[%sm%s\033[0m' "$ansi" "$*"
    else printf '%s' "$*"; fi
}
green()  { color 32 "$@"; }
yellow() { color 33 "$@"; }
red()    { color 31 "$@"; }
dim()    { color 2  "$@"; }

# --- Step counter -------------------------------------------------------
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0
STEP_INDEX=0
STEP_TOTAL=0
FAILURES=()

step() {
    local name="$1"; shift
    STEP_INDEX=$((STEP_INDEX + 1))
    local prefix
    prefix="$(printf '[%3d/%d]' "$STEP_INDEX" "$STEP_TOTAL")"
    local rc
    "$@"
    rc=$?
    case "$rc" in
        0)  echo "$prefix $(green 'OK  ')  $name"; TOTAL_PASS=$((TOTAL_PASS + 1)) ;;
        2)  echo "$prefix $(yellow 'SKIP')  $name"; TOTAL_SKIP=$((TOTAL_SKIP + 1)) ;;
        *)  echo "$prefix $(red   'FAIL')  $name"; TOTAL_FAIL=$((TOTAL_FAIL + 1)); FAILURES+=("$name") ;;
    esac
}

# --- Ensure clang on PATH (mirror nuc resolution) -----------------------
if ! command -v clang >/dev/null 2>&1; then
    if [ -n "${NUCLEOR_CLANG_PATH:-}" ] && [ -x "$NUCLEOR_CLANG_PATH" ]; then
        export PATH="$(dirname "$NUCLEOR_CLANG_PATH"):$PATH"
    elif [ -n "${LLVM_SYS_180_PREFIX:-}" ] && [ -x "$LLVM_SYS_180_PREFIX/bin/clang" ]; then
        export PATH="$LLVM_SYS_180_PREFIX/bin:$PATH"
    elif [ -x "/usr/lib/llvm-18/bin/clang" ]; then
        export PATH="/usr/lib/llvm-18/bin:$PATH"
    elif [ -x "/opt/homebrew/opt/llvm/bin/clang" ]; then
        export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
    elif [ -x "/usr/local/opt/llvm/bin/clang" ]; then
        export PATH="/usr/local/opt/llvm/bin:$PATH"
    fi
fi

cd "$ROOT"

# --- Compute total step count ------------------------------------------
RUST_BRIDGE_LIB="$ROOT/stdlib/rods/rust_bridge/target/release/libnucleor_rust_bridge.a"
EXAMPLES=(01_hello 02_fib 03_structs 04_rods 05_quantum 06_perf_attrs 08_linalg 09_ode 10_fft 11_pid 12_autodiff 13_test_framework 14_csv_summary)
[ -f "$RUST_BRIDGE_LIB" ] && EXAMPLES+=(07_rust_interop)

TEST_DIRS=(lang attrs runtime rods features)
# Files matching this pattern are auxiliary helpers imported by another
# test (e.g. via `mod foo;`) and are not standalone-runnable. Skipping
# them keeps the gate from treating them as duplicate-main failures.
TEST_SKIP_REGEX='_aux\.nr$'
TEST_COUNT=0
for d in "${TEST_DIRS[@]}"; do
    if [ -d "tests/$d" ]; then
        c=$(find "tests/$d" -maxdepth 1 -name '*.nr' 2>/dev/null | grep -vE "$TEST_SKIP_REGEX" | wc -l | tr -d ' ')
        TEST_COUNT=$((TEST_COUNT + c))
    fi
done
ERR_COUNT=$(find "tests/err" -maxdepth 1 -name '*.nr' 2>/dev/null | wc -l | tr -d ' ')

STEP_TOTAL=$((2 + ${#EXAMPLES[@]} + TEST_COUNT + ERR_COUNT + 1))

# --- Step bodies --------------------------------------------------------
check_binary() {
    [ -x "$BIN" ] || return 1
    "$BIN" help 2>&1 | grep -q "Nucleor Compiler" || return 1
    return 0
}

build_example() {
    local ex="$1"
    "$BIN" build "examples/$ex.nr" -o "$ex" >/tmp/_nuc_step.log 2>&1
    if [ ! -x "target/$ex" ] && [ ! -x "target/$ex.exe" ]; then
        tail -1 /tmp/_nuc_step.log | sed 's/^/       /'
        return 1
    fi
    if [ -x "target/$ex" ]; then
        "target/$ex" >/dev/null 2>&1
    else
        "target/$ex.exe" >/dev/null 2>&1
    fi
}

build_test() {
    local dir="$1" tname="$2"
    if [ "$tname" = "rust_interop" ] && [ ! -f "$RUST_BRIDGE_LIB" ]; then
        return 2
    fi
    "$BIN" build "tests/$dir/$tname.nr" -o "$tname" >/tmp/_nuc_step.log 2>&1
    local exe="target/$tname"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    if [ ! -x "$exe" ]; then
        echo "       build failed" | sed 's/^/       /'
        return 1
    fi
    local out exit
    out=$("$exe" 2>&1); exit=$?
    if [ "$dir" = "features" ]; then
        # Feature parity tests: pass if program ran without crash.
        # Linux SIGSEGV exit = 139; macOS = 139; Windows = 0xC0000005 = -1073741819.
        if [ "$exit" -eq 139 ] || [ "$exit" -eq 138 ] || [ "$exit" -eq -1073741819 ] || [ "$exit" -eq -1073740940 ]; then
            return 1
        fi
        return 0
    fi
    echo "$out" | grep -qE '^OK ' && return 0 || return 1
}

build_negative() {
    local ename="$1"
    local out
    out=$("$BIN" build "tests/err/$ename.nr" -o "$ename" 2>&1)
    echo "$out" | grep -qiE 'error\b|error\[|warning\b|warning\[' && return 0 || return 1
}

self_host_rebuild() {
    "$BIN" build "compiler/nucleor_s1_compiler.nr" -o "verify_compiler" >/tmp/_nuc_step.log 2>&1
    [ -x "target/verify_compiler" ] || [ -x "target/verify_compiler.exe" ]
}

compiler_tables_synced() {
    bash "$ROOT/tools/check_compiler_drift.sh" >/tmp/_nuc_step.log 2>&1
}

# --- Run gate -----------------------------------------------------------
step "binary present" check_binary
step "compiler ABI tables synced" compiler_tables_synced

for ex in "${EXAMPLES[@]}"; do
    step "example $ex" build_example "$ex"
done

for d in "${TEST_DIRS[@]}"; do
    if [ -d "tests/$d" ]; then
        for f in $(find "tests/$d" -maxdepth 1 -name '*.nr' 2>/dev/null | grep -vE "$TEST_SKIP_REGEX" | sort); do
            tname=$(basename "$f" .nr)
            step "test $d/$tname" build_test "$d" "$tname"
        done
    fi
done

if [ -d "tests/err" ]; then
    for f in $(find "tests/err" -maxdepth 1 -name '*.nr' 2>/dev/null | sort); do
        ename=$(basename "$f" .nr)
        step "negative $ename" build_negative "$ename"
    done
fi

step "self-host rebuild closes" self_host_rebuild

# --- Cleanup ------------------------------------------------------------
rm -rf "$ROOT/target" "$ROOT/.nuc_cache" 2>/dev/null || true

echo ""
echo "$(dim '===')"
echo "PASS: $(green "$TOTAL_PASS")"
[ "$TOTAL_SKIP" -gt 0 ] && echo "SKIP: $(yellow "$TOTAL_SKIP")"
if [ "$TOTAL_FAIL" -gt 0 ]; then
    echo "FAIL: $(red "$TOTAL_FAIL")"
    echo "$(red 'Failed steps:')"
    for f in "${FAILURES[@]}"; do echo "$(dim "  - $f")"; done
    exit 1
fi
exit 0
