#!/usr/bin/env bash
# verify.sh — POSIX smoke gate for the Nucleor OSS distribution.
#
# Mirrors tools/verify.ps1. Same step counter, same exit code, same gates.
#
# Usage: ./tools/verify.sh
#
# Steps:
#   1. Confirm bin/nucleor loads
#   2. Build and run examples 01..06 + 08..18 (07 only if rust_bridge built)
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
# Probe for clang on Windows accepts either `clang` or `clang.exe`, since
# MSVC LLVM packages ship only the .exe. Path-not-found env vars (e.g.
# stale LLVM_SYS_180_PREFIX) silently fall through.
if ! command -v clang >/dev/null 2>&1; then
    if [ -n "${NUCLEOR_CLANG_PATH:-}" ] && { [ -x "$NUCLEOR_CLANG_PATH" ] || [ -x "${NUCLEOR_CLANG_PATH}.exe" ]; }; then
        export PATH="$(dirname "$NUCLEOR_CLANG_PATH"):$PATH"
    elif [ -n "${LLVM_SYS_180_PREFIX:-}" ] && { [ -x "$LLVM_SYS_180_PREFIX/bin/clang" ] || [ -x "$LLVM_SYS_180_PREFIX/bin/clang.exe" ]; }; then
        export PATH="$LLVM_SYS_180_PREFIX/bin:$PATH"
    elif [ -x "/c/Program Files/LLVM/bin/clang.exe" ]; then
        export PATH="/c/Program Files/LLVM/bin:$PATH"
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
# rust_bridge artifact name varies by toolchain:
#   POSIX (gcc/clang): libnucleor_rust_bridge.a
#   Windows (MSVC):    nucleor_rust_bridge.lib
# Detect either; downstream test gate uses the same heuristic.
RUST_BRIDGE_DIR="$ROOT/stdlib/rods/rust_bridge/target/release"
RUST_BRIDGE_LIB=""
if [ -f "$RUST_BRIDGE_DIR/libnucleor_rust_bridge.a" ]; then
    RUST_BRIDGE_LIB="$RUST_BRIDGE_DIR/libnucleor_rust_bridge.a"
elif [ -f "$RUST_BRIDGE_DIR/nucleor_rust_bridge.lib" ]; then
    RUST_BRIDGE_LIB="$RUST_BRIDGE_DIR/nucleor_rust_bridge.lib"
fi
# Read example list from the single source of truth (shared with
# verify.ps1). v0.2.60 — eliminates the drift class that bit
# v0.2.59.
EXAMPLES_FILE="$ROOT/tools/examples.list"
EXAMPLES=()
if [ -f "$EXAMPLES_FILE" ]; then
    while IFS= read -r line; do
        # Skip blank lines and comments
        case "$line" in
            ""|"#"*) continue ;;
        esac
        EXAMPLES+=("$line")
    done < "$EXAMPLES_FILE"
fi
[ -n "$RUST_BRIDGE_LIB" ] && EXAMPLES+=(07_rust_interop)

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

# Step count: 1 binary present + 1 ABI parity + 1 CLI explain
# + 1 bootstrap + 1 check+abi + 1 inspectors + 1 diagnostics
# + 1 init + 1 doc + 1 lock + 1 test
# + N examples + N tests + N negative + 1 self-host
STEP_TOTAL=$((11 + ${#EXAMPLES[@]} + TEST_COUNT + ERR_COUNT + 1))

# --- Step bodies --------------------------------------------------------
check_binary() {
    [ -x "$BIN" ] || return 1
    "$BIN" help 2>&1 | grep -q "Nucleor Compiler" || return 1
    return 0
}

# CLI smoke check (added v0.2.64) — exercises `nuc explain` so the
# explain registry in nucleor_tools_suite.nr stays wired to the
# error codes spec. Without this, codes can be added to
# docs/spec/Nucleor_Error_Codes.md but never registered.
cli_explain_smoke() {
    local out
    out=$("$BIN" explain NUM-001 2>&1)
    [ -n "$out" ] || return 1
    echo "$out" | grep -q "NUM-001" || return 1
    # Title line should mention "Mixed-width" (per Error_Codes.md row)
    echo "$out" | grep -q "Mixed-width" || return 1
    # Reference line should point at the spec doc
    echo "$out" | grep -q "Nucleor_Error_Codes" || return 1
    return 0
}

# nuc bootstrap status smoke (added v0.2.70). Verifies the bootstrap
# status command (NUCLEOR_BOOTSTRAP_CONTRACT.md indicator) reports
# the expected stage + self-hosted status.
cli_bootstrap_smoke() {
    local out
    out=$("$BIN" bootstrap 2>&1)
    [ -n "$out" ] || return 1
    echo "$out" | grep -q "Nucleor Bootstrap Status" || return 1
    echo "$out" | grep -q "Stage: 1 (self-hosted)" || return 1
    echo "$out" | grep -q "Self-hosted: yes" || return 1
    return 0
}

# nuc check + abi smoke (added v0.2.70). Verifies the no-codegen
# check command and the ABI import inspector both produce structured
# output on a known-good source file. Catches regressions in the
# diagnostic emission pipeline that don't surface through build/test.
cli_check_abi_smoke() {
    local out
    # `nuc check` should report no diagnostics on examples/01_hello.nr
    out=$("$BIN" check examples/01_hello.nr 2>&1)
    [ -n "$out" ] || return 1
    echo "$out" | grep -q "OK — no diagnostics\|OK -- no diagnostics" || return 1
    # `nuc abi` should print the ABI version + extern imports section
    out=$("$BIN" abi examples/01_hello.nr 2>&1)
    [ -n "$out" ] || return 1
    echo "$out" | grep -q "ABI version:" || return 1
    echo "$out" | grep -q "extern imports:" || return 1
    return 0
}

# nuc summary + audit + query + impact smoke (added v0.2.71).
# Inspector commands that produce structured output (summary text or
# JSON) for tooling integration. Bundled into one step to keep
# pre-iteration overhead small.
cli_inspector_smoke() {
    local out
    # nuc summary — module/effect summary text
    out=$("$BIN" summary examples/01_hello.nr 2>&1)
    echo "$out" | grep -q "// Module: examples/01_hello.nr" || return 1
    echo "$out" | grep -q "fn main" || return 1
    # nuc audit — JSON audit report
    out=$("$BIN" audit examples/01_hello.nr 2>&1)
    echo "$out" | grep -q '"type": "audit_report"' || return 1
    echo "$out" | grep -q '"functions": 1' || return 1
    # nuc query — JSON function inventory
    out=$("$BIN" query examples/01_hello.nr 2>&1)
    echo "$out" | grep -q '"functions":\[' || return 1
    echo "$out" | grep -q '"name":"main"' || return 1
    # nuc impact — JSON callee/caller graph for one fn
    out=$("$BIN" impact examples/01_hello.nr main 2>&1)
    echo "$out" | grep -q '"target":"main"' || return 1
    echo "$out" | grep -q '"found":true' || return 1
    return 0
}

# nuc policy/certify/translate/evidence/graph/perf/bench smoke
# (added v0.2.72). Bundles seven advanced/diagnostic commands into
# one gate step. Each gets minimal output validation; the goal is
# "this command path produces structured output without crashing"
# rather than full semantic verification.
cli_diagnostic_smoke() {
    local out
    # nuc policy — policy compliance check (PASS on default)
    out=$("$BIN" policy examples/01_hello.nr 2>&1)
    echo "$out" | grep -q "Policy:" || return 1
    echo "$out" | grep -q "Result:" || return 1
    # nuc certify — strict-mode verification pass
    out=$("$BIN" certify examples/01_hello.nr 2>&1)
    echo "$out" | grep -q "source:" || return 1
    # nuc translate — Sage translation pass
    out=$("$BIN" translate examples/01_hello.nr 2>&1)
    echo "$out" | grep -q "translated:" || return 1
    # nuc evidence — SPDX + provenance JSON (SLSA v1)
    out=$("$BIN" evidence examples/01_hello.nr 2>&1)
    echo "$out" | grep -q '"spdx":' || return 1
    echo "$out" | grep -q '"provenance":' || return 1
    # nuc graph — call-graph node/edge counts
    out=$("$BIN" graph examples/01_hello.nr 2>&1)
    echo "$out" | grep -q "functions:" || return 1
    echo "$out" | grep -q "edges:" || return 1
    # nuc perf — performance analysis report header
    out=$("$BIN" perf examples/01_hello.nr 2>&1)
    echo "$out" | grep -q "Nucleor Performance Analysis" || return 1
    # nuc bench — benchmark harness against the source
    out=$("$BIN" bench examples/01_hello.nr 2>&1)
    echo "$out" | grep -q "source:" || return 1
    return 0
}

# nuc init scaffolding smoke (added v0.2.66) — verifies the
# new-user-first-command produces a working project. Catches
# regressions in the init template (Nucleor.toml fields,
# src/main.nr scaffold) that the example/test gate misses.
cli_init_smoke() {
    local sandbox="/tmp/_nuc_init_smoke_$$"
    rm -rf "$sandbox"
    mkdir -p "$sandbox" || return 1
    (
        cd "$sandbox" || exit 1
        "$BIN" init smokeproj >/dev/null 2>&1 || exit 1
        [ -f smokeproj/Nucleor.toml ] || exit 1
        [ -f smokeproj/src/main.nr ]   || exit 1
        # Manifest must declare package name + entry
        grep -q 'name = "smokeproj"' smokeproj/Nucleor.toml || exit 1
        grep -q 'entry = "src/main.nr"' smokeproj/Nucleor.toml || exit 1
        # Scaffold must compile + run
        cd smokeproj || exit 1
        "$BIN" build src/main.nr -o smokeproj >/dev/null 2>&1 || exit 1
        local exe="target/smokeproj"
        [ -x "$exe.exe" ] && exe="$exe.exe"
        [ -x "$exe" ] || exit 1
        local out
        out=$("$exe" 2>&1)
        [ -n "$out" ] || exit 1
    )
    local rc=$?
    rm -rf "$sandbox"
    return $rc
}

# nuc test single-file smoke (added v0.2.69) — RFC-0021 phase 1
# test framework. Verifies discovery + harness file write + child
# build + child run for a #[test]-annotated function. The bug
# v0.2.69 fixed (target/ not created before harness write) is
# directly catchable by this step.
cli_test_smoke() {
    local sandbox="/tmp/_nuc_test_smoke_$$"
    rm -rf "$sandbox"
    mkdir -p "$sandbox" || return 1
    (
        cd "$sandbox" || exit 1
        cat > t.nr <<'NREOF'
#[test]
fn test_addition() {
    let x: i64 = 2 + 2;
    if x != 4 { print("FAIL"); return; };
    print("PASS test_addition");
}
fn main() -> i64 { return 0; }
NREOF
        local out
        out=$("$BIN" test t.nr 2>&1)
        echo "$out" | grep -q "discovered tests: 1" || exit 1
        echo "$out" | grep -q "test_addition"      || exit 1
        echo "$out" | grep -q "PASS test_addition" || exit 1
        echo "$out" | grep -q "test result: PASS"  || exit 1
    )
    local rc=$?
    rm -rf "$sandbox"
    return $rc
}

# nuc lock smoke (added v0.2.68) — RFC-0019 package manager phase 1
# is a v0.2 deliverable. Verifies the lockfile generator reads
# Nucleor.toml, walks the (trivial in this case) dependency graph,
# and writes Nucleor.lock with the expected fields.
cli_lock_smoke() {
    local sandbox="/tmp/_nuc_lock_smoke_$$"
    rm -rf "$sandbox"
    mkdir -p "$sandbox" || return 1
    (
        cd "$sandbox" || exit 1
        "$BIN" init lockproj >/dev/null 2>&1 || exit 1
        cd lockproj || exit 1
        "$BIN" lock >/dev/null 2>&1 || exit 1
        [ -f Nucleor.lock ] || exit 1
        # Schema: must have the four canonical fields (version, root,
        # root_package, [[package]] table for the project itself)
        grep -q '^version = ' Nucleor.lock || exit 1
        grep -q '^root = "Nucleor.toml"' Nucleor.lock || exit 1
        grep -q '^root_package = "lockproj"' Nucleor.lock || exit 1
        grep -q '^\[\[package\]\]' Nucleor.lock || exit 1
        grep -q '^name = "lockproj"' Nucleor.lock || exit 1
    )
    local rc=$?
    rm -rf "$sandbox"
    return $rc
}

# nuc doc skeleton smoke (added v0.2.67) — RFC-0029 phase 1 doc
# generator is a v0.2 deliverable. Verifies the generator reads
# /// doc comments, emits a Markdown doc with function index + per-fn
# signature blocks, and the --out flag writes to file.
cli_doc_smoke() {
    local sandbox="/tmp/_nuc_doc_smoke_$$"
    rm -rf "$sandbox"
    mkdir -p "$sandbox" || return 1
    (
        cd "$sandbox" || exit 1
        cat > smoke.nr <<'NREOF'
/// Adds two integers.
fn smoke_add(a: i64, b: i64) -> i64 { return a + b; }
NREOF
        local stdout_out
        stdout_out=$("$BIN" doc smoke.nr 2>&1)
        # Stdout mode: must produce a Markdown doc that mentions the fn
        echo "$stdout_out" | grep -q "smoke_add" || exit 1
        echo "$stdout_out" | grep -q "## Function index" || exit 1
        echo "$stdout_out" | grep -q "Adds two integers" || exit 1
        echo "$stdout_out" | grep -q "Signature" || exit 1
        # --out mode: must write the file
        "$BIN" doc smoke.nr --out smoke.md >/dev/null 2>&1 || exit 1
        [ -f smoke.md ] || exit 1
        grep -q "smoke_add" smoke.md || exit 1
    )
    local rc=$?
    rm -rf "$sandbox"
    return $rc
}

build_example() {
    local ex="$1"
    "$BIN" build "examples/$ex.nr" -o "$ex" >/tmp/_nuc_step.log 2>&1
    if [ ! -x "target/$ex" ] && [ ! -x "target/$ex.exe" ]; then
        tail -1 /tmp/_nuc_step.log | sed 's/^/       /'
        return 1
    fi
    # Capture stdout to /tmp/_nuc_ex_out.log so we can shape-check it.
    # Catches the silent-regression case where an example builds + exits
    # 0 but produces wrong/no output (added v0.2.61).
    if [ -x "target/$ex" ]; then
        "target/$ex" >/tmp/_nuc_ex_out.log 2>&1
    else
        "target/$ex.exe" >/tmp/_nuc_ex_out.log 2>&1
    fi
    local rc=$?
    if [ "$rc" -ne 0 ]; then
        tail -1 /tmp/_nuc_ex_out.log | sed 's/^/       /'
        return 1
    fi
    # Non-empty stdout shape check (added v0.2.61) — catches silent
    # regressions where the binary builds + exits 0 but prints nothing.
    if [ ! -s /tmp/_nuc_ex_out.log ]; then
        echo "       example produced empty output" | sed 's/^/       /'
        return 1
    fi
    return 0
}

build_test() {
    local dir="$1" tname="$2"
    if [ "$tname" = "rust_interop" ] && [ -z "$RUST_BRIDGE_LIB" ]; then
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
step "CLI: nuc explain NUM-001 wired" cli_explain_smoke
step "CLI: nuc bootstrap status reports correctly" cli_bootstrap_smoke
step "CLI: nuc check + abi inspect" cli_check_abi_smoke
step "CLI: nuc summary/audit/query/impact (inspectors)" cli_inspector_smoke
step "CLI: nuc policy/certify/translate/evidence/graph/perf/bench (diagnostics)" cli_diagnostic_smoke
step "CLI: nuc init scaffolding works" cli_init_smoke
step "CLI: nuc doc generator works" cli_doc_smoke
step "CLI: nuc lock writes Nucleor.lock" cli_lock_smoke
step "CLI: nuc test runs #[test] functions" cli_test_smoke

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
