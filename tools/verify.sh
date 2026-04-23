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

# Step count: 1 binary present + 1 ABI parity + 1 tools-rebuild
# + 1 help coverage + 1 utility smoke + 1 json smoke + 1 version
# + 1 showcase build + 1 CLI explain + 1 explain-full + 1 bootstrap
# + 1 check+abi + 1 inspectors + 1 diagnostics + 1 init + 1 doc
# + 1 lock + 1 test
# + N examples + N tests + N negative + 1 self-host
STEP_TOTAL=$((18 + ${#EXAMPLES[@]} + TEST_COUNT + ERR_COUNT + 1))

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
    # v0.2.82 — the Contract: line names a doc file. Verify it
    # exists at the repo root so `nuc bootstrap` doesn't dangle.
    # Catches the drift class that bit NUCLEOR_BOOTSTRAP_CONTRACT.md
    # being referenced from v0.2.70 onward without ever being
    # committed.
    local contract_path
    contract_path=$(echo "$out" | sed -n 's/^[[:space:]]*Contract:[[:space:]]*//p')
    [ -n "$contract_path" ] || return 1
    [ -f "$ROOT/$contract_path" ] || return 1
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
showcase_build_smoke() {
    # v0.2.90 — verify the four `examples/showcase/*.nr` programs
    # build cleanly. They're not run-tested because they produce
    # streaming ANSI dashboards that don't terminate on their own.
    # Build-only catches regressions where a stdlib change breaks
    # the showcase compile path even though the standard examples
    # still compile.
    local prog
    for prog in lorenz vqe_h2 market_maker wing_simulator; do
        local out
        out=$("$BIN" build "examples/showcase/$prog.nr" -o "showcase_$prog" 2>&1)
        if [ ! -x "target/showcase_$prog" ] && [ ! -x "target/showcase_$prog.exe" ]; then
            echo "       showcase build failed for $prog"
            echo "$out" | tail -2
            return 1
        fi
    done
    return 0
}

cli_version_smoke() {
    # v0.2.87 — every spelling of "give me the version" must work:
    # --version (canonical), -v (short), -V (rustc/gcc convention),
    # version (no-dash subcommand). Gates against regression on any
    # of the four aliases, all of which existed by v0.2.87.
    local out
    for variant in --version -v -V version; do
        out=$("$BIN" "$variant" 2>&1 | head -1)
        case "$out" in
            "nucleor "*) ;;
            *) echo "       $variant: unexpected output: $out"; return 1 ;;
        esac
    done
    return 0
}

cli_json_smoke() {
    # v0.2.86 — exercise the --json variants on every CLI command
    # that documents one. Output must start with `{` (or `[` for
    # array-shaped responses) so the gate catches regressions
    # where --json silently falls back to the text path.
    #
    # Note: --json must come AFTER the source positional for the
    # file-taking commands; see CHANGELOG v0.2.86 for the parser
    # quirk discussion.
    local out
    # commands taking [file] [--json]
    for cmd in audit summary query abi evidence graph perf check; do
        out=$("$BIN" "$cmd" examples/01_hello.nr --json 2>&1 | head -1)
        case "$out" in
            \{*|\[*) ;;  # JSON
            *) echo "       $cmd --json: not JSON: $out"; return 1 ;;
        esac
    done
    # explain CODE --json (CODE is positional, not file)
    out=$("$BIN" explain NUM-001 --json 2>&1 | head -1)
    case "$out" in
        \{*) ;;
        *) echo "       explain --json: not JSON: $out"; return 1 ;;
    esac
    # bootstrap --json (no positional)
    out=$("$BIN" bootstrap --json 2>&1 | head -1)
    case "$out" in
        \{*) ;;
        *) echo "       bootstrap --json: not JSON: $out"; return 1 ;;
    esac
    # lock --json (no positional, returns error JSON outside a project)
    out=$("$BIN" lock --json 2>&1 | head -1)
    case "$out" in
        \{*) ;;
        *) echo "       lock --json: not JSON: $out"; return 1 ;;
    esac
    return 0
}

cli_utility_smoke() {
    # v0.2.85 — smoke the zero-side-effect utility commands that
    # weren't yet under gate coverage: zen, mco, registry list,
    # stage-dump tokens, fix --imports.
    # `clean` / `scram` are NOT smoked because they delete target/
    # mid-gate. Each command must produce non-empty output and
    # NOT leak the "The system cannot find the file specified."
    # cmd-shell stderr message that v0.2.85 fixed for registry list.
    local out
    out=$("$BIN" zen 2>&1)
    [ -n "$out" ] || return 1
    echo "$out" | grep -q "The Zen of Nucleor" || return 1
    out=$("$BIN" mco 2>&1)
    [ -n "$out" ] || return 1
    echo "$out" | grep -q "Mars Climate Orbiter" || return 1
    out=$("$BIN" registry list 2>&1)
    [ -n "$out" ] || return 1
    echo "$out" | grep -q "registry: " || return 1
    echo "$out" | grep -q "packages: " || return 1
    # Catch the v0.2.85 stderr leak by name — if it ever returns,
    # this fires.
    echo "$out" | grep -q "system cannot find" && return 1
    out=$("$BIN" stage-dump tokens examples/01_hello.nr 2>&1)
    [ -n "$out" ] || return 1
    echo "$out" | grep -q "TOKENS" || return 1
    out=$("$BIN" fix --imports examples/01_hello.nr 2>&1)
    [ -n "$out" ] || return 1
    return 0
}

cli_help_coverage_smoke() {
    # v0.2.84 — every dispatched CLI subcommand must appear in the
    # `nuc help` output. Catches the drift class that bit `doc` and
    # `fix` (both shipped + smoke-tested but absent from help).
    local out
    out=$("$BIN" help 2>&1) || return 1
    local cmds=(
        "build" "build-fast" "build-strict" "build-shared" "build-wasm" "build-ptx"
        "run" "emit" "test" "bench" "perf" "bootstrap" "stage-dump"
        "summary" "query" "abi" "evidence" "impact" "graph" "doc" "profile"
        "lock" "install" "add" "publish" "registry" "sage"
        "check" "explain"
        "audit" "policy" "certify" "translate"
        "init" "clean" "scram" "fix" "zen" "mco"
    )
    local cmd
    for cmd in "${cmds[@]}"; do
        # Match the command at the start of an indented help line so
        # we don't get false positives from prose ("the build step").
        echo "$out" | grep -qE "^  $cmd\b" || return 1
    done
    return 0
}

cli_explain_full_smoke() {
    # v0.2.79 — audits the v0.2 error-code set against the explain
    # registry. v0.2.80 — extended to the full forward-looking
    # spec catalog (RFC-0001..0014, 0015..0022, 0031, 0032). Catches
    # the drift class that bit NUM-004 / TST-001/002/003 in v0.2.79
    # (4 codes spec'd but missing from registry) and again in
    # v0.2.80 (44 more). When adding a new code, list it here AND
    # in the spec doc AND in the explain registry — this step is
    # the cross-link.
    local codes=(
        # NR — compiler pipeline (RFC-0020 baseline)
        "NR001" "NR005" "NR010" "NR020" "NR030" "NR031" "NR032" "NR033"
        "NR034" "NR040" "NR050" "NR051" "NR070" "NR090"
        # RFC-0001 RT
        "RT-001" "RT-002" "RT-003" "RT-004" "RT-005" "RT-006" "RT-007" "RT-008"
        # RFC-0002 allocators
        "ALLOC-001" "ALLOC-002" "ALLOC-003"
        # RFC-0003 typed frames
        "FRAME-001" "FRAME-002" "FRAME-003"
        # RFC-0004 assume!
        "ASSUME-001" "ASSUME-002" "ASSUME-003" "ASSUME-004" "ASSUME-005"
        # RFC-0005 units
        "UNIT-001" "UNIT-002" "UNIT-003" "UNIT-004" "UNIT-005"
        # RFC-0006 contracts
        "CONTRACT-001" "CONTRACT-002" "CONTRACT-003" "CONTRACT-004"
        "CONTRACT-005" "CONTRACT-006" "CONTRACT-007"
        # RFC-0007 atomic
        "ATOMIC-001" "ATOMIC-002" "ATOMIC-003" "ATOMIC-004"
        # RFC-0008 ISR
        "ISR-001" "ISR-002" "ISR-003" "ISR-004" "ISR-005" "ISR-006"
        # RFC-0009 WCET
        "WCET-001" "WCET-002" "WCET-003" "WCET-004" "WCET-005" "WCET-006"
        # RFC-0010 DLPack
        "DLPACK-001" "DLPACK-002" "DLPACK-003" "DLPACK-004" "DLPACK-005"
        # RFC-0011 nuc-cxx
        "CXX-001" "CXX-002" "CXX-003" "CXX-004" "CXX-005"
        # RFC-0012 nuc-bindgen
        "BINDGEN-001" "BINDGEN-002" "BINDGEN-003" "BINDGEN-004" "BINDGEN-005"
        # RFC-0013 URDF
        "URDF-001" "URDF-002" "URDF-003" "URDF-004" "URDF-005" "URDF-006"
        # RFC-0014 max_depth
        "DEPTH-001" "DEPTH-002" "DEPTH-003" "DEPTH-004" "DEPTH-005"
        # RFC-0015 numeric types (v0.2)
        "NUM-001" "NUM-002" "NUM-003" "NUM-004" "NUM-005"
        # RFC-0016 Result/Option/match (v0.2; 007..010 for v0.4 RFC-0023)
        "MATCH-001" "MATCH-002" "MATCH-003" "MATCH-004" "MATCH-005" "MATCH-006"
        "MATCH-007" "MATCH-008" "MATCH-009" "MATCH-010"
        # RFC-0017 collections (v0.2)
        "COLL-001" "COLL-002" "COLL-003" "COLL-004" "COLL-005"
        # RFC-0018 modules (v0.2)
        "MOD-001" "MOD-002" "MOD-003" "MOD-004" "MOD-005" "MOD-006"
        # RFC-0019 packages (v0.2)
        "PKG-001" "PKG-002" "PKG-003" "PKG-004" "PKG-005" "PKG-006"
        # RFC-0021 test framework (v0.2)
        "TST-001" "TST-002" "TST-003"
        # RFC-0022 cross-platform (v0.2)
        "TGT-001" "TGT-002" "TGT-003" "TGT-004"
        # RFC-0031 algebraic laws
        "LAW-001" "LAW-002" "LAW-003" "LAW-004"
        # RFC-0032 effects
        "EFF-001" "EFF-002" "EFF-003" "EFF-004" "EFF-005"
    )
    local code
    for code in "${codes[@]}"; do
        local out
        out=$("$BIN" explain "$code" 2>&1)
        if echo "$out" | grep -q "unknown error code"; then
            return 1
        fi
        if ! echo "$out" | grep -q "$code"; then
            return 1
        fi
    done
    return 0
}

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

tools_rebuild() {
    # v0.2.79 — rebuild the tools binary so the explain registry,
    # `nuc test` harness writer, and other tools-suite logic are
    # tested against the current source. Without this, a pull that
    # updates compiler/nucleor_tools_suite.nr would leave the
    # user's stale bin/nucleor_tools.exe in place and the
    # cli_explain_full_smoke step would fail spuriously (or, worse,
    # pass against the stale binary while the new code was broken).
    "$BIN" build "compiler/nucleor_tools_suite.nr" -o "nucleor_tools" >/tmp/_nuc_step.log 2>&1
    if [ -x "target/nucleor_tools" ]; then
        cp "target/nucleor_tools" "$ROOT/bin/nucleor_tools" 2>/dev/null
        return 0
    fi
    if [ -x "target/nucleor_tools.exe" ]; then
        cp "target/nucleor_tools.exe" "$ROOT/bin/nucleor_tools.exe" 2>/dev/null
        return 0
    fi
    return 1
}

compiler_tables_synced() {
    bash "$ROOT/tools/check_compiler_drift.sh" >/tmp/_nuc_step.log 2>&1
}

# --- Run gate -----------------------------------------------------------
step "binary present" check_binary
step "compiler ABI tables synced" compiler_tables_synced
step "tools-suite rebuild" tools_rebuild
step "CLI: nuc help advertises every dispatched command" cli_help_coverage_smoke
step "CLI: nuc zen/mco/registry/stage-dump/fix (utilities)" cli_utility_smoke
step "CLI: --json variants emit machine-readable JSON" cli_json_smoke
step "CLI: --version / -v / -V / version aliases" cli_version_smoke
step "examples/showcase: lorenz/vqe_h2/market_maker/wing_simulator build" showcase_build_smoke
step "CLI: nuc explain NUM-001 wired" cli_explain_smoke
step "CLI: nuc explain — full spec code set wired" cli_explain_full_smoke
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
