#!/usr/bin/env bash
# verify.sh — POSIX smoke gate for the Nucleor OSS distribution.
#
# Mirrors tools/verify.ps1. Same step counter, same exit code, same gates.
#
# Usage: ./tools/verify.sh
#
# Step shape (203 steps total as of v0.2.111):
#   1.  Binary present + loads
#   2.  ABI parity (s1 ↔ tools-suite)
#   3.  Tools-suite rebuild (since v0.2.79)
#   4.  Mojibake clean (since v0.2.91)
#   5.  Help-coverage (since v0.2.84) — every dispatched cmd in `nuc help`
#   6.  Utility smoke (zen / mco / registry / stage-dump / fix; v0.2.85)
#   7.  JSON-flag smoke (11 commands; v0.2.86)
#   8.  Version aliases (--version / -v / -V / version; v0.2.87)
#   9.  Showcase build (lorenz / vqe_h2 / market_maker / wing_simulator; v0.2.90)
#   10. CLI: explain NUM-001 (single quick-fail canary; v0.2.64)
#   11. CLI: explain — full 130-code spec catalog (v0.2.79+v0.2.80)
#   12. CLI: bootstrap status + Contract: file resolves (v0.2.70+v0.2.82)
#   13. CLI: check + abi inspect (v0.2.70)
#   14. CLI: summary/audit/query/impact (inspectors; v0.2.71)
#   15. CLI: policy/certify/translate/evidence/graph/perf/bench (diagnostics; v0.2.72)
#   16. CLI: init scaffolding (v0.2.66)
#   17. CLI: doc generator (v0.2.67)
#   18. CLI: lock writes Nucleor.lock (v0.2.68)
#   19. CLI: test runs #[test] functions (v0.2.69)
#   20..N. Build + run every example under examples/
#   N+1.. Build + run every positive test under tests/{lang,attrs,runtime,rods,features}
#   ...   Confirm every tests/err/*.nr fails with at least a diagnostic line
#   final Self-host rebuild closes (compile s1 source via current binary)
#
# Exit code: 0 = ship-ready; 1 = a step failed.
#
# Output: progress counter [N/T] per step, colored OK/FAIL/SKIP labels when
# stdout is a TTY. Honors NO_COLOR (https://no-color.org/) and --no-color.

set -uo pipefail

# T1.1 safety: cap virtual memory at 2 GB so a runaway compile or
# test fails fast. Healthy compiles are sub-1 GB; the prior blowups
# we hunted hit ~20 GB, so 2 GB is the right "alarm" threshold.
# Override via NUCLEOR_MEM_CAP_KB env var (units: KB; "0" = no cap).
: "${NUCLEOR_MEM_CAP_KB:=2097152}"
if [ "${NUCLEOR_MEM_CAP_KB}" != "0" ]; then
    ulimit -v "${NUCLEOR_MEM_CAP_KB}" 2>/dev/null || true
fi

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
# + 1 mojibake check + 1 err-EXPECT-headers + 1 help coverage
# + 1 utility smoke + 1 json + 1 version + 1 showcase build
# + 1 CLI explain + 1 explain-full + 1 bootstrap + 1 check+abi
# + 1 inspectors + 1 diagnostics + 1 init + 1 doc + 1 lock + 1 test
# + N examples + N tests + N negative + 1 self-host + 2 budgets
# + 1 T1.7 bootstrap-seed (v0.2.339)
STEP_TOTAL=$((20 + ${#EXAMPLES[@]} + TEST_COUNT + ERR_COUNT + 47))

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
    # v0.2.90 — verify the `examples/showcase/*.nr` programs build
    # cleanly. The animated dashboards (lorenz / vqe_h2 / market_maker
    # / wing_simulator) are build-only because they produce streaming
    # ANSI output that doesn't terminate on its own. The robotics
    # showcase (added v0.2.206) DOES terminate on its own and is
    # additionally run-tested below to gate the IK / TOPP / collision
    # / BVH integration path against regression.
    local prog
    for prog in lorenz vqe_h2 market_maker wing_simulator robotic_arm; do
        local out
        out=$("$BIN" build "examples/showcase/$prog.nr" -o "showcase_$prog" 2>&1)
        if [ ! -x "target/showcase_$prog" ] && [ ! -x "target/showcase_$prog.exe" ]; then
            echo "       showcase build failed for $prog"
            echo "$out" | tail -2
            return 1
        fi
    done
    # Run the robotics showcase end-to-end and require all 8 stages
    # complete with the final marker line. Catches regressions in any
    # of the v0.2.174-205 robotics rods composed by the showcase.
    local rrun
    rrun=$("./target/showcase_robotic_arm" 2>&1 || true)
    if ! printf '%s\n' "$rrun" | grep -q "Showcase complete: 10 stages"; then
        echo "       robotic_arm showcase did not complete 10 stages"
        printf '%s\n' "$rrun" | tail -10
        return 1
    fi
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

err_tests_have_expect_smoke() {
    # v0.2.118 — every tests/err/*.nr file must carry an
    # `// EXPECT: <code> <text>` header on its first comment line.
    # Locks down the v0.2.117 bulk-add (33/33 tests headerized).
    # Going forward, contributors adding a new negative test must
    # also document what diagnostic it fires.
    local missing=()
    for f in "$ROOT"/tests/err/*.nr; do
        if ! head -3 "$f" | grep -q "^// EXPECT:"; then
            missing+=("$(basename "$f")")
        fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo "       err tests missing EXPECT header:"
        for m in "${missing[@]}"; do
            echo "         - $m"
        done
        return 1
    fi
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
        # OWN series — borrow checker (expansion of NR031, since v0.2.119;
        # OWN-013 added v0.2.131 — spawn-capture for non-Send DeviceBuffer)
        "OWN-001" "OWN-002" "OWN-003" "OWN-004" "OWN-005" "OWN-006"
        "OWN-007" "OWN-008" "OWN-009" "OWN-010" "OWN-011" "OWN-012"
        "OWN-013"
        # GOV series — governance policies (since v0.2.131)
        "GOV-001" "GOV-002"
        # TNT series — taint analysis (expansion of NR033, since v0.2.120)
        "TNT-001"
        # TYP series — type checker (expansion of NR030, since v0.2.119)
        "TYP-001" "TYP-002" "TYP-003" "TYP-004" "TYP-005"
        "TYP-006" "TYP-007" "TYP-008" "TYP-009" "TYP-010"
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
        # T1.1 Phase 10 (v0.2.319): expanded NUM namespace.
        "NUM-006" "NUM-007" "NUM-008" "NUM-009" "NUM-010"
        "NUM-011" "NUM-012" "NUM-013" "NUM-014" "NUM-015"
        "NUM-016" "NUM-017" "NUM-018" "NUM-019" "NUM-020"
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
        # RFC-0020 DIAG (minted v0.3.36 — first DIAG-NNN code)
        "DIAG-001"
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
        # v0.3.41: tightened from synopsis-only to full-entry
        # check. explain_error_known() only checks title; a code
        # with title but missing summary or explanation passed
        # silently. Now also assert the cause line (2) and hint
        # line (3) are non-empty -- catches drift where a
        # contributor adds a code to the title registry but
        # forgets the matching summary or explanation entry.
        local line2 line3
        line2=$(echo "$out" | sed -n '2p')
        line3=$(echo "$out" | sed -n '3p')
        if [ -z "$line2" ]; then
            echo "       $code: missing cause/summary line in explain output" | sed 's/^/       /'
            return 1
        fi
        if [ -z "$line3" ]; then
            echo "       $code: missing hint/explanation line in explain output" | sed 's/^/       /'
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
    # --no-cache: see v0.3.26 — diagnostic-dependent tests must skip
    # the source cache, or a stale .nuc_cache silently swallows the
    # error/warning the assertion grep is looking for.
    out=$("$BIN" build "tests/err/$ename.nr" -o "$ename" --no-cache 2>&1)
    echo "$out" | grep -qiE 'error\b|error\[|warning\b|warning\[' && return 0 || return 1
}

self_host_rebuild() {
    "$BIN" build "compiler/nucleor_s1_compiler.nr" -o "verify_compiler" >/tmp/_nuc_step.log 2>&1
    [ -x "target/verify_compiler" ] || [ -x "target/verify_compiler.exe" ]
}

# v0.2.161 — guard against memory regressions in the self-host compile.
# Runs the s1 self-host with NUC_TRACE_ALLOC=1 and asserts the total
# tracked allocation stays under the budget. Without this gate, any
# future change that re-introduces an allocate-then-discard pattern in
# the type checker (the class of bug that caused the v0.2.158 9.7 GB
# leak) could ship silently.
#
# Budget: 400 MB total tracked. v0.2.160 baseline is ~185 MB; the
# headroom (2.2x) absorbs minor growth as the s1 source itself grows
# without flagging legitimate scaling. Tighten if necessary as the
# architectural Ship 3 (TypeId interner) lands.
self_host_memory_budget() {
    # v0.2.167 — tightened from 250 MB to 100 MB after the Vec
    # initial-capacity fix dropped baseline from 137 MB to 67 MB.
    # 50% headroom over the 67 MB baseline. Production-scale source
    # files (1-2 MB) will need this lifted; the s1 self-host (485 KB)
    # is the canonical regression target.
    _memory_budget_for "compiler/nucleor_s1_compiler.nr" 100 "self-host" "verify_budget"
}

tools_suite_memory_budget() {
    # v0.2.171 — tools_suite is 1.7× the size of the s1 (822 KB vs
    # 485 KB) and roughly proportionally heavier on type-check
    # work, so the budget is set proportionally: 100 MB × 1.7 + a
    # bit of margin = 200 MB. Same regression-protection rationale.
    _memory_budget_for "compiler/nucleor_tools_suite.nr" 200 "tools-suite" "verify_tools_budget"
}

t33_wcet_estimator() {
    "$BIN" build "tests/fixtures/t33_wcet_overrun.nr" -o "_t33_wcet_check" --no-cache >/tmp/_nuc_step.log 2>&1
    grep -qE 'warning\[RT-004\]: static WCET estimate [0-9]+ us' /tmp/_nuc_step.log || return 1
    grep -q 'exceeds #\[deadline = 1 us\]' /tmp/_nuc_step.log || return 1
    grep -q 'v1 estimator' /tmp/_nuc_step.log || return 1
}

t35_rt007_unguarded_deadline() {
    # T3.5 (v0.3.3): warn when #[deadline] has neither #[no_alloc]
    # nor #[no_panic] — alloc/panic break WCET determinism.
    "$BIN" build "tests/fixtures/t35_rt007.nr" -o "_t35_rt007_check" --no-cache >/tmp/_nuc_step.log 2>&1
    grep -qE 'warning\[RT-007\]:' /tmp/_nuc_step.log || return 1
    grep -q 'has #\[deadline\] but neither #\[no_alloc\] nor #\[no_panic\]' /tmp/_nuc_step.log || return 1
}

t34_export_decls() {
    # T3.4 (v0.3.4): #[export] attribute → C forward declaration
    # in `nuc gen-headers` output. Lets external C code call into
    # Nucleor-compiled fns through the unmangled LLVM symbol.
    local hdr="/tmp/_t34_export.h"
    "$BIN" gen-headers "tests/fixtures/t34_export.nr" -o "$hdr" >/tmp/_nuc_step.log 2>&1
    [ -f "$hdr" ] || return 1
    grep -q 'int64_t nuc_add(int64_t a, int64_t b);' "$hdr" || return 1
    grep -q 'double nuc_dot(Vec3 a, Vec3 b);' "$hdr" || return 1
    grep -q 'void nuc_noop(void);' "$hdr" || return 1
    # private_helper has no #[export] — must NOT appear.
    if grep -q 'private_helper' "$hdr"; then return 1; fi
    # Existing extern fn import path still works.
    grep -q 'void host_logger(int64_t msg_ptr, int64_t msg_len);' "$hdr" || return 1
}

t36_no_dyn_clean() {
    # T3.6 (v0.3.5): #[no_dyn] (RT-003) — same shape as T3.2.
    # Two #[no_dyn] fns with static-dispatch arithmetic + 2 #[test]
    # cases that PASS verify the marker mechanism works without
    # false-positive on the attribute literal itself.
    "$BIN" test "tests/smoke/t36_no_dyn_clean.nr" >/tmp/_nuc_step.log 2>&1
    grep -q "PASS: test_no_dyn_pid_static_dispatch" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_no_dyn_fk_static_dispatch" /tmp/_nuc_step.log || return 1
    grep -q "test result: PASS (2 tests)" /tmp/_nuc_step.log || return 1
}

t311_arena_builtin_smoke() {
    # T3.11 (v0.3.11): #[test]-framework coverage for the bare
    # arena_new / arena_alloc / arena_reset / arena_destroy
    # builtin path. The runtime fix shipped in v0.2.154 but
    # never received #[test] coverage (the existing
    # tests/lang/arena_builtin.nr is a main-fn shape).
    "$BIN" test "tests/smoke/t311_arena_builtin.nr" >/tmp/_nuc_step.log 2>&1
    grep -q "PASS: test_arena_round_trip" /tmp/_nuc_step.log || return 1
    grep -q "test result: PASS (1 test)" /tmp/_nuc_step.log || return 1
}

t310_rt008_recursion() {
    # T3.10 (v0.3.9): RT-008 — direct self-recursion in a
    # #[deadline] fn warns. Bounded recursion opts out via
    # #[max_depth = N]. Two paired fixtures: unbounded fires
    # RT-008, bounded stays clean.
    "$BIN" build "tests/fixtures/t310_rt008_recursion.nr" -o "_t310_rt008_check" --no-cache >/tmp/_nuc_step.log 2>&1
    grep -qE "warning\[RT-008\]: 'fib_unbounded' has #\[deadline\] and recursively calls itself" /tmp/_nuc_step.log || return 1
    grep -q "add #\[max_depth" /tmp/_nuc_step.log || return 1
    "$BIN" build "tests/fixtures/t310_rt008_bounded.nr" -o "_t310_bounded_check" --no-cache >/tmp/_nuc_step.log 2>&1
    if grep -q "RT-008" /tmp/_nuc_step.log; then return 1; fi
    return 0
}

t324_ffi_no_alloc_marker() {
    # T3.15 (v0.3.24): #[ffi_no_alloc] / #[ffi_no_panic]
    # markers on extern declarations narrow the RT-005 scope.
    # Annotated extern is not flagged when called from a
    # matching RT body; un-annotated still fires.
    # --no-cache: see T3.16 comment — diagnostic-dependent
    # tests must skip the source cache or they silently pass
    # on stale cache entries.
    "$BIN" build "tests/fixtures/t324_ffi_no_alloc.nr" -o "_t324_check" --no-cache >/tmp/_nuc_step.log 2>&1
    grep -qE "warning\[RT-005\]: FFI call 'host_unsafe'" /tmp/_nuc_step.log || return 1
    if grep -qE "warning\[RT-005\]: FFI call 'host_safe'" /tmp/_nuc_step.log; then return 1; fi
}

t326_ffi_intersection() {
    # T3.16 (v0.3.26): #[deadline] intersection rule for the
    # v0.3.24 #[ffi_no_*] markers. A #[deadline] caller treats
    # an extern as RT-safe iff it carries BOTH markers
    # (deadline determinism subsumes the no-alloc + no-panic
    # contracts). Three externs: alloc-only, panic-only, both.
    # RT-005 should mention the two single-marker externs but
    # NOT the both-marker one.
    #
    # --no-cache because the source cache hit short-circuits the
    # parse/typecheck/emit pipeline that produces RT-005, so a
    # stale .nuc_cache from prior interactive debugging would
    # silently swallow the diagnostic. CI starts cold and would
    # pass without --no-cache; --no-cache is for local rerun
    # robustness.
    "$BIN" build "tests/fixtures/t326_ffi_intersection.nr" -o "_t326_check" --no-cache >/tmp/_nuc_step.log 2>&1
    grep -qE "warning\[RT-005\]: FFI call 'h_alloc_only'" /tmp/_nuc_step.log || return 1
    grep -qE "warning\[RT-005\]: FFI call 'h_panic_only'" /tmp/_nuc_step.log || return 1
    if grep -qE "warning\[RT-005\]: FFI call 'h_both'" /tmp/_nuc_step.log; then return 1; fi
}

t39_rt005_ffi_call() {
    # T3.9 (v0.3.8): RT-005 — extern fn call from inside an
    # RT-marked fn body warns. v1 is text-scan: every literal
    # `<extern_name>(` substring in the stripped body fires.
    # Until #[ffi_no_*] annotations land, every FFI call is
    # treated as RT-unsafe.
    "$BIN" build "tests/fixtures/t39_rt005_ffi.nr" -o "_t39_rt005_check" --no-cache >/tmp/_nuc_step.log 2>&1
    grep -qE "warning\[RT-005\]: FFI call 'host_telemetry'" /tmp/_nuc_step.log || return 1
    grep -q "from #\[no_alloc\] fn 'rt_path'" /tmp/_nuc_step.log || return 1
    return 0
}

t326_cli_help_cmds_drift() {
    # T3.26 (v0.3.44): drift gate for the cli_help_coverage_smoke
    # cmds list. Both verify.sh and verify.ps1 hardcode the same
    # ~39-entry CLI command set; a new command added to one but
    # forgotten in the other would leave the smoke check half-
    # blind on the corresponding OS. Pure regex scan of both
    # cmds-array bodies; asserts the sets match exactly.
    local sh_cmds ps_cmds
    sh_cmds=$(awk '/local cmds=\(/,/^    \)/' "$ROOT/tools/verify.sh" \
              | grep -oE '"[a-z][a-z0-9-]*"' | tr -d '"' | sort -u)
    ps_cmds=$(awk '/\$cmds = @\(/,/^    \)/' "$ROOT/tools/verify.ps1" \
              | grep -oE '"[a-z][a-z0-9-]*"' | tr -d '"' | sort -u)
    local missing_a missing_b
    missing_a=$(comm -23 <(echo "$sh_cmds") <(echo "$ps_cmds"))
    missing_b=$(comm -13 <(echo "$sh_cmds") <(echo "$ps_cmds"))
    if [ -n "$missing_a" ]; then
        echo "       drift: cli help cmds in verify.sh but missing from verify.ps1:" | sed 's/^/       /'
        echo "$missing_a" | sed 's/^/         - /'
        return 1
    fi
    if [ -n "$missing_b" ]; then
        echo "       drift: cli help cmds in verify.ps1 but missing from verify.sh:" | sed 's/^/       /'
        echo "$missing_b" | sed 's/^/         - /'
        return 1
    fi
    return 0
}

t325_examples_list_drift() {
    # T3.25 (v0.3.43): drift gate for tools/examples.list
    # against the actual examples/ directory. Every .nr file
    # in examples/ must appear in examples.list, OR be in the
    # explicit conditional allowlist (07_rust_interop, which
    # is added by both verify scripts only when RUST_BRIDGE_LIB
    # is set). Catches the class where a contributor adds a new
    # example file but forgets to enumerate it in examples.list,
    # so the verify gate silently skips it.
    local dir_set list_set extras allowed
    dir_set=$(ls "$ROOT"/examples/*.nr 2>/dev/null | xargs -n1 basename | sed 's/\.nr$//' | sort -u)
    list_set=$(grep -v '^#' "$ROOT/tools/examples.list" | grep -v '^$' | sort -u)
    # Conditional allowlist — examples that verify scripts add only
    # under specific env conditions and are intentionally not in
    # examples.list. Mirror in verify.ps1's T3.25 implementation.
    allowed=$(echo "$list_set"; echo "07_rust_interop")
    allowed=$(echo "$allowed" | sort -u)
    extras=$(comm -23 <(echo "$dir_set") <(echo "$allowed"))
    if [ -n "$extras" ]; then
        echo "       drift: examples/*.nr not in examples.list (or conditional allowlist):" | sed 's/^/       /'
        echo "$extras" | sed 's/^/         - /'
        return 1
    fi
    # Reverse: every name in examples.list must correspond to an
    # actual file. Catches stale entries.
    local missing
    missing=$(comm -23 <(echo "$list_set") <(echo "$dir_set"))
    if [ -n "$missing" ]; then
        echo "       drift: examples.list entries with no matching examples/*.nr file:" | sed 's/^/       /'
        echo "$missing" | sed 's/^/         - /'
        return 1
    fi
    return 0
}

t324_spec_doc_drift() {
    # T3.24 (v0.3.42): drift gate against the docs/spec/
    # Nucleor_Error_Codes.md Markdown table. Every code in the
    # canonical set (verify.sh codes array) must appear as a
    # row in the spec doc; every code in the spec doc must
    # be in the canonical set. Catches the drift class that
    # left NUM-006..020 missing from the spec for ~80 ships
    # after their v0.2.319 introduction.
    local canon spec
    canon=$(awk '/local codes=\(/,/^    \)/' "$ROOT/tools/verify.sh" \
            | grep -oE '"[A-Z]+-?[0-9]+"' | tr -d '"' | sort -u)
    spec=$(grep -oE '\| (NR[0-9]+|[A-Z]+-[0-9]+) \|' "$ROOT/docs/spec/Nucleor_Error_Codes.md" \
           | grep -oE '(NR[0-9]+|[A-Z]+-[0-9]+)' | sort -u)
    local missing_a missing_b
    missing_a=$(comm -23 <(echo "$canon") <(echo "$spec"))
    missing_b=$(comm -13 <(echo "$canon") <(echo "$spec"))
    if [ -n "$missing_a" ]; then
        echo "       drift: codes in canonical set but missing from spec doc:" | sed 's/^/       /'
        echo "$missing_a" | sed 's/^/         - /'
        return 1
    fi
    if [ -n "$missing_b" ]; then
        echo "       drift: codes in spec doc but missing from canonical set:" | sed 's/^/       /'
        echo "$missing_b" | sed 's/^/         - /'
        return 1
    fi
    return 0
}

t323_diag_code_drift() {
    # T3.23 (v0.3.39, extended v0.3.40): three-way drift gate
    # for the parallel canonical diagnostic code lists. The
    # set lives in THREE places:
    #   * `is_known_diag_code` in compiler/nucleor_s1_compiler.nr
    #   * `local codes=(...)` in tools/verify.sh
    #   * `$codes = @(...)` in tools/verify.ps1
    # v0.3.39 caught s1 vs same-script drift; v0.3.40 closes
    # the cross-script gap (the original NUM-006..020 gap was
    # sh-vs-ps1 drift, which a same-script check can't see).
    # Asserts all three sets are pairwise equal.
    local s1_set sh_set ps1_set
    s1_set=$(grep -oE 'str_eq\(code, "[A-Z]+-?[0-9]+"\)' "$ROOT/compiler/nucleor_s1_compiler.nr" \
             | grep -oE '"[A-Z]+-?[0-9]+"' | tr -d '"' | sort -u)
    sh_set=$(awk '/local codes=\(/,/^    \)/' "$ROOT/tools/verify.sh" \
             | grep -oE '"[A-Z]+-?[0-9]+"' | tr -d '"' | sort -u)
    ps1_set=$(awk '/\$codes = @\(/,/^    \)/' "$ROOT/tools/verify.ps1" \
              | grep -oE '"[A-Z]+-?[0-9]+"' | tr -d '"' | sort -u)
    _drift_diff() {
        local label_a="$1" label_b="$2" set_a="$3" set_b="$4"
        local missing_b
        missing_b=$(comm -23 <(echo "$set_a") <(echo "$set_b"))
        if [ -n "$missing_b" ]; then
            echo "       drift: codes in $label_a but missing from $label_b:" | sed 's/^/       /'
            echo "$missing_b" | sed 's/^/         - /'
            return 1
        fi
        return 0
    }
    _drift_diff "verify.sh"  "is_known_diag_code" "$sh_set"  "$s1_set"  || return 1
    _drift_diff "is_known_diag_code" "verify.sh"  "$s1_set"  "$sh_set"  || return 1
    _drift_diff "verify.ps1" "is_known_diag_code" "$ps1_set" "$s1_set"  || return 1
    _drift_diff "is_known_diag_code" "verify.ps1" "$s1_set"  "$ps1_set" || return 1
    _drift_diff "verify.sh"  "verify.ps1"         "$sh_set"  "$ps1_set" || return 1
    _drift_diff "verify.ps1" "verify.sh"          "$ps1_set" "$sh_set"  || return 1
    return 0
}

t321_diag001_self_suppress() {
    # T3.21 (v0.3.37, tightened v0.3.47): #[allow(DIAG-001)]
    # suppresses DIAG-001 itself. Fixture has #[allow(WAT-001)]
    # (would fire DIAG-001 for the WAT- unknown prefix) plus a
    # file-wide #[allow(DIAG-001)]. The suppression pass runs
    # AFTER the emit pass, so the DIAG-001 warning gets dropped
    # before reaching the user.
    #
    # v0.3.47: tightened from "no DIAG-001 fires" to a real
    # three-way assertion -- (1) build exits 0 (compilation
    # actually succeeded; v0.3.37's check would pass even on a
    # compile error since no DIAG-001 emits from a non-compiled
    # file), (2) no DIAG-001 warning surfaces (the suppression
    # worked), (3) no error fires either (catches a regression
    # that promotes DIAG-001 to error tier and bypasses the
    # warning suppressor).
    "$BIN" build "tests/fixtures/t321_diag001_self_suppress.nr" -o "_t321_diag001_self_check" --no-cache >/tmp/_nuc_step.log 2>&1
    local rc=$?
    [ "$rc" = "0" ] || return 1
    if grep -qE 'warning\[DIAG-001\]' /tmp/_nuc_step.log; then return 1; fi
    if grep -qE 'error\[DIAG-001\]' /tmp/_nuc_step.log; then return 1; fi
    return 0
}

t331_mixed_fp_ops() {
    # T3.31 (v0.3.56): production-coverage lock for f64 inline
    # binops with MIXED operand kinds. Asserts five cross-kind
    # ops compute correctly post v0.3.53/54/55:
    #   field × fn-call → 3    (cast) × field  → 21
    #   field × vec[i]  → 6    (cast) × vec[i] → 20
    #   fn-call × vec[i] → 5
    "$BIN" build "tests/fixtures/t331_mixed_fp_ops.nr" -o "_t331_check" --no-cache >/tmp/_nuc_step.log 2>&1
    [ -x "target/_t331_check" ] || [ -x "target/_t331_check.exe" ] || return 1
    local exe
    if [ -x "target/_t331_check" ]; then exe="target/_t331_check"; else exe="target/_t331_check.exe"; fi
    "$exe" >/tmp/_nuc_step.log 2>&1
    grep -qE '^3\.0+$'   /tmp/_nuc_step.log || return 1
    grep -qE '^6\.0+$'   /tmp/_nuc_step.log || return 1
    grep -qE '^5\.0+$'   /tmp/_nuc_step.log || return 1
    grep -qE '^21\.0+$'  /tmp/_nuc_step.log || return 1
    grep -qE '^20\.0+$'  /tmp/_nuc_step.log || return 1
    return 0
}

t330_vec_index_fp_ops() {
    # T3.30 (v0.3.55): regression test for the f64 inline
    # binop-on-Vec-indexing codegen bug fixed in v0.3.55.
    # Asserts five ops on Vec<f64>[i] produce correct values:
    #   add: 1+4=5    sub: 1-4=-3   mul: 1*4=4   div: 8/4=2
    #   nested: v[0]*v[1] + v[2]*v[5] + v[4]*v[6] = 32
    "$BIN" build "tests/fixtures/t330_vec_index_fp_ops.nr" -o "_t330_check" --no-cache >/tmp/_nuc_step.log 2>&1
    [ -x "target/_t330_check" ] || [ -x "target/_t330_check.exe" ] || return 1
    local exe
    if [ -x "target/_t330_check" ]; then exe="target/_t330_check"; else exe="target/_t330_check.exe"; fi
    "$exe" >/tmp/_nuc_step.log 2>&1
    grep -qE '^5\.0+$'    /tmp/_nuc_step.log || return 1
    grep -qE '^-3\.0+$'   /tmp/_nuc_step.log || return 1
    grep -qE '^4\.0+$'    /tmp/_nuc_step.log || return 1
    grep -qE '^2\.0+$'    /tmp/_nuc_step.log || return 1
    grep -qE '^32\.0+$'   /tmp/_nuc_step.log || return 1
    return 0
}

t329_fn_call_fp_ops() {
    # T3.29 (v0.3.54): regression test for the f64 inline
    # binop-on-fn-call codegen bug fixed in v0.3.54.
    # Asserts five ops on fn-call results compute correctly:
    #   add: 1+4=5    sub: 1-4=-3   mul: 1*4=4   div: 8/4=2
    #   nested: 1*4 + 2*5 + 3*6 = 32
    "$BIN" build "tests/fixtures/t329_fn_call_fp_ops.nr" -o "_t329_check" --no-cache >/tmp/_nuc_step.log 2>&1
    [ -x "target/_t329_check" ] || [ -x "target/_t329_check.exe" ] || return 1
    local exe
    if [ -x "target/_t329_check" ]; then exe="target/_t329_check"; else exe="target/_t329_check.exe"; fi
    "$exe" >/tmp/_nuc_step.log 2>&1
    grep -qE '^5\.0+$'    /tmp/_nuc_step.log || return 1
    grep -qE '^-3\.0+$'   /tmp/_nuc_step.log || return 1
    grep -qE '^4\.0+$'    /tmp/_nuc_step.log || return 1
    grep -qE '^2\.0+$'    /tmp/_nuc_step.log || return 1
    grep -qE '^32\.0+$'   /tmp/_nuc_step.log || return 1
    return 0
}

t328_struct_field_fp_ops() {
    # T3.28 (v0.3.53): regression test for the f64 inline
    # binary-op-on-struct-field codegen bug fixed in v0.3.53.
    # Builds the fixture, runs it, asserts each of the four
    # primary ops + the nested-binop dot product produce the
    # mathematically correct value:
    #   add: 1+4 = 5     mul: 1*4 = 4     dot: 1*4+2*5+3*6 = 32
    #   sub: 1-4 = -3    div: 8/4 = 2
    "$BIN" build "tests/fixtures/t328_struct_field_fp_ops.nr" -o "_t328_check" --no-cache >/tmp/_nuc_step.log 2>&1
    [ -x "target/_t328_check" ] || [ -x "target/_t328_check.exe" ] || return 1
    local exe
    if [ -x "target/_t328_check" ]; then exe="target/_t328_check"; else exe="target/_t328_check.exe"; fi
    "$exe" >/tmp/_nuc_step.log 2>&1
    grep -qE '^5\.0+$'    /tmp/_nuc_step.log || return 1
    grep -qE '^-3\.0+$'   /tmp/_nuc_step.log || return 1
    grep -qE '^4\.0+$'    /tmp/_nuc_step.log || return 1
    grep -qE '^2\.0+$'    /tmp/_nuc_step.log || return 1
    grep -qE '^32\.0+$'   /tmp/_nuc_step.log || return 1
    return 0
}

t327_export_workaround_dot() {
    # T3.27 (v0.3.52): regression test for the v0.3.51 codegen
    # workaround. examples/22_rt_export.nr's nuc_print_dot
    # uses lifted-let bindings to compute (1,2,3)·(4,5,6) = 32.
    # The example sweep already builds + runs ex22 but only
    # checks for non-empty stdout; if the workaround broke,
    # nuc_print_dot would print 0 and the sweep would silently
    # pass. T3.27 strictly asserts the example output contains
    # the literal "32.0" — the dot product the workaround
    # produces. If the underlying inline-multiply codegen bug
    # is later fixed (v0.4 AST codegen), this test still
    # passes because the workaround pattern remains correct.
    "$BIN" build "examples/22_rt_export.nr" -o "_t327_check" --no-cache >/tmp/_nuc_step.log 2>&1
    [ -x "target/_t327_check" ] || [ -x "target/_t327_check.exe" ] || return 1
    local exe
    if [ -x "target/_t327_check" ]; then exe="target/_t327_check"; else exe="target/_t327_check.exe"; fi
    "$exe" >/tmp/_nuc_step.log 2>&1
    grep -qE '32\.0+' /tmp/_nuc_step.log || return 1
    return 0
}

t320_diag001_unknown_code() {
    # T3.20 (v0.3.36, extended v0.3.38, v0.3.46): DIAG-001
    # warning fires for #[allow(_fn)] / #[deny(_fn)] CODE
    # arguments not in the canonical enumerated diagnostic
    # code set. Fixture has five offending attributes:
    #   - 4 unknown-prefix codes (caught since v0.3.36)
    #   - 1 within-series typo (RT-099 — caught since v0.3.38)
    # Plus one control (#[allow_fn(RT-007)]) that must NOT fire.
    #
    # v0.3.46 strict-shape extension: also asserts each of the
    # four attribute-shape prefixes emit correctly. Catches
    # regressions where emit_diag001_unknown_codes swaps
    # shapes (e.g., reports an #[allow] code with the
    # #[allow_fn] message body and vice versa).
    "$BIN" build "tests/fixtures/t320_diag001_unknown_code.nr" -o "_t320_diag001_check" --no-cache >/tmp/_nuc_step.log 2>&1
    local count
    count=$(grep -cE 'warning\[DIAG-001\]' /tmp/_nuc_step.log)
    [ "$count" = "5" ] || return 1
    grep -qE "'WAT-001'"      /tmp/_nuc_step.log || return 1
    grep -qE "'BOGUS-002'"    /tmp/_nuc_step.log || return 1
    grep -qE "'GIBBERISH-003'" /tmp/_nuc_step.log || return 1
    grep -qE "'NONSENSE-004'" /tmp/_nuc_step.log || return 1
    grep -qE "'RT-099'"       /tmp/_nuc_step.log || return 1
    # Control: RT-007 must NOT trigger DIAG-001.
    if grep -qE "'RT-007'" /tmp/_nuc_step.log; then return 1; fi
    # v0.3.46 shape-prefix assertions. Each pairing locks the
    # diag's attribute-shape body text against the offending
    # code, so a future swap (e.g., file-wide emitting per-fn
    # text) is caught.
    grep -qE "'WAT-001' in #\[allow\(\.\.\.\)\]"           /tmp/_nuc_step.log || return 1
    grep -qE "'BOGUS-002' in #\[deny\(\.\.\.\)\]"          /tmp/_nuc_step.log || return 1
    grep -qE "'GIBBERISH-003' in #\[allow_fn\(\.\.\.\)\] on fn 'first_unknown'"     /tmp/_nuc_step.log || return 1
    grep -qE "'NONSENSE-004' in #\[deny_fn\(\.\.\.\)\] on fn 'second_unknown'"      /tmp/_nuc_step.log || return 1
    grep -qE "'RT-099' in #\[allow_fn\(\.\.\.\)\] on fn 'within_series_typo'"       /tmp/_nuc_step.log || return 1
    return 0
}

t323_allow_fn_error_tier_strict() {
    # T3.19 (v0.3.34): companion to T3.18. The err-sweep
    # already builds err_t323_allow_fn_no_error_suppress.nr and
    # asserts SOME diagnostic fires, but build_negative accepts
    # either error or warning -- so a regression where
    # #[allow_fn(RT-001)] started silently demoting errors to
    # warnings (or to nothing) would still pass the sweep.
    # T3.19 strictly asserts:
    #   * error[RT-001] fires (the design intent: errors are
    #     non-suppressible per RFC-0001)
    #   * warning[RT-001] does NOT fire (would indicate the
    #     allow_fn improperly demoted the diag tier instead of
    #     leaving it at error tier untouched)
    "$BIN" build "tests/err/err_t323_allow_fn_no_error_suppress.nr" -o "_t323_strict_check" --no-cache >/tmp/_nuc_step.log 2>&1
    grep -qE 'error\[RT-001\]' /tmp/_nuc_step.log || return 1
    if grep -qE 'warning\[RT-001\]' /tmp/_nuc_step.log; then return 1; fi
    return 0
}

t321_deny_fn_promotes_strict() {
    # T3.18 (v0.3.33): the err-sweep already builds
    # err_t321_deny_fn.nr and asserts SOME diagnostic fires, but
    # `build_negative` accepts either error or warning -- so a
    # regression where #[deny_fn(RT-007)] silently stops
    # promoting (warning stays warning) would still pass the
    # sweep. T3.18 strictly asserts that:
    #   * error[RT-007] fires (the promotion happened), AND
    #   * warning[RT-007] does NOT fire (the original tier was
    #     replaced, not added alongside).
    "$BIN" build "tests/err/err_t321_deny_fn.nr" -o "_t321_strict_check" --no-cache >/tmp/_nuc_step.log 2>&1
    grep -qE 'error\[RT-007\]' /tmp/_nuc_step.log || return 1
    if grep -qE 'warning\[RT-007\]' /tmp/_nuc_step.log; then return 1; fi
    return 0
}

t317_allow_fn_rt004() {
    # T3.17 (v0.3.32): closes the coverage gap left by T3.12
    # (which proved #[allow_fn] works for RT-007 only). Same
    # shape: two #[deadline = 1] fns whose bodies each blow the
    # v1 WCET estimate; only the second has #[allow_fn(RT-004)],
    # so RT-004 should fire exactly ONCE. Validates the v0.3.31
    # message-text claim that #[allow_fn(RT-004)] is a real
    # opt-out, not vapor advertisement.
    "$BIN" build "tests/fixtures/t317_allow_fn_rt004.nr" -o "_t317_check" --no-cache >/tmp/_nuc_step.log 2>&1
    grep -qE 'warning\[RT-004\]' /tmp/_nuc_step.log || return 1
    local count
    count=$(grep -cE 'warning\[RT-004\]' /tmp/_nuc_step.log)
    [ "$count" = "1" ] || return 1
}

t320_allow_fn_per_fn() {
    # T3.12 (v0.3.20): per-fn #[allow_fn(CODE)] suppresses
    # one diagnostic for the next fn declaration only. The
    # fixture has two #[deadline]-marked fns that would each
    # fire RT-007; only the second has #[allow_fn(RT-007)],
    # so RT-007 should mention unguarded_one but NOT
    # unguarded_two.
    "$BIN" build "tests/fixtures/t320_allow_fn.nr" -o "_t320_check" --no-cache >/tmp/_nuc_step.log 2>&1
    grep -qE 'warning\[RT-007\]' /tmp/_nuc_step.log || return 1
    # Inner-fn name carries a content-hash; we can't grep for
    # the user-facing wrapper directly. Assert exactly ONE
    # RT-007 warning fired (file-wide allow would suppress
    # both; per-fn must suppress only one).
    local count
    count=$(grep -cE 'warning\[RT-007\]' /tmp/_nuc_step.log)
    [ "$count" = "1" ] || return 1
}

t38_rt006_async_attr() {
    # T3.8 (v0.3.7): #[no_alloc] / #[no_panic] / #[no_dyn] /
    # #[deadline] on an `async fn` is rejected with RT-006
    # because async cannot honor any RT contract. Negative
    # fixtures err_rt006_async_no_alloc.nr +
    # err_rt006_async_deadline.nr cover both spellings; this
    # step asserts the no_alloc variant fires the exact text.
    "$BIN" build "tests/err/err_rt006_async_no_alloc.nr" -o "_t38_rt006_check" --no-cache >/tmp/_nuc_step.log 2>&1
    grep -qE 'error\[RT-006\]: RT attribute' /tmp/_nuc_step.log || return 1
    grep -q "on async fn 'poll_loop'" /tmp/_nuc_step.log || return 1
    grep -q "async is non-deterministic" /tmp/_nuc_step.log || return 1
}

t37_rt_string_skip() {
    # T3.7 (v0.3.6): RT-001/002/003 v1 checkers strip `"..."`
    # string literals + `// ...` line comments before scanning,
    # so a forbidden name appearing inside a quoted/commented
    # region no longer false-triggers. Three #[no_alloc/panic/dyn]
    # fns that contain forbidden tokens ONLY in stripped regions
    # + 3 #[test] cases that PASS prove the strip pass works.
    "$BIN" test "tests/smoke/t37_rt_string_skip.nr" >/tmp/_nuc_step.log 2>&1
    grep -q "PASS: test_alloc_name_in_string_compiles" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_panic_name_in_comment_compiles" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_dyn_token_in_string_compiles" /tmp/_nuc_step.log || return 1
    grep -q "test result: PASS (3 tests)" /tmp/_nuc_step.log || return 1
}

t32_no_panic_clean() {
    "$BIN" test "tests/smoke/t32_no_panic_clean.nr" >/tmp/_nuc_step.log 2>&1
    grep -q "PASS: test_no_panic_pure_arithmetic" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_no_panic_loop_with_arithmetic" /tmp/_nuc_step.log || return 1
    grep -q "test result: PASS (2 tests)" /tmp/_nuc_step.log || return 1
}

v030_deadline_pass() {
    "$BIN" test "tests/smoke/v030_deadline_runtime.nr" >/tmp/_nuc_step.log 2>&1
    grep -q "PASS: test_deadline_pass_simple_add" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_deadline_pass_simple_mul" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_deadline_pass_no_args" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_deadline_pass_with_loop" /tmp/_nuc_step.log || return 1
    grep -q "test result: PASS (4 tests)" /tmp/_nuc_step.log || return 1
}

v030_deadline_overrun() {
    rm -f target/v030_overrun_check.exe target/v030_overrun_check
    "$BIN" build tests/fixtures/v030_deadline_overrun.nr -o "v030_overrun_check" >/tmp/_nuc_step.log 2>&1
    local exe=""
    if [ -x target/v030_overrun_check.exe ]; then exe=target/v030_overrun_check.exe; fi
    if [ -z "$exe" ] && [ -x target/v030_overrun_check ]; then exe=target/v030_overrun_check; fi
    [ -n "$exe" ] || return 1
    "$exe" >/tmp/_nuc_run.log 2>&1
    local rc=$?
    [ "$rc" -ne 0 ] || return 1
    grep -qE 'error\[RT-004\]: #\[deadline\] overrun' /tmp/_nuc_run.log || return 1
}

t28_async_threads() {
    # v0.2.353 (T2.8): async runtime — threads-only commitment.
    "$BIN" test "tests/smoke/t28_async_threads.nr" >/tmp/_nuc_step.log 2>&1
    grep -q "PASS: test_async_basic_spawn_await" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_async_two_concurrent_tasks" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_async_await_in_arithmetic" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_async_zero_arg_fn" /tmp/_nuc_step.log || return 1
    grep -q "test result: PASS (4 tests)" /tmp/_nuc_step.log || return 1
}

t27_doc_html() {
    # v0.2.352 (T2.7): nuc doc --html emits standalone HTML doc.
    local hdr
    hdr="$(mktemp 2>/dev/null || echo /tmp/_t27_doc.html)"
    rm -f "$hdr"
    "$BIN" doc tests/fixtures/t27_doc_input.nr --out "$hdr" >/tmp/_nuc_step.log 2>&1
    grep -qE 'wrote .*HTML' /tmp/_nuc_step.log || return 1
    [ -f "$hdr" ] || return 1
    grep -q "<!doctype html>" "$hdr" || return 1
    grep -q '<title>tests/fixtures/t27_doc_input.nr</title>' "$hdr" || return 1
    grep -q '<h2 id="dbl"><code>dbl</code></h2>' "$hdr" || return 1
    grep -q '<h2 id="add"><code>add</code></h2>' "$hdr" || return 1
    grep -q '<h2 id="helper_no_doc"><code>helper_no_doc</code></h2>' "$hdr" || return 1
    grep -q '<a href="#dbl">' "$hdr" || return 1
    grep -q 'Doubles its argument' "$hdr" || return 1
    grep -qE 'fn dbl\(x: i64\) -&gt; i64' "$hdr" || return 1
    rm -f "$hdr"
}

t25_lifetime_params() {
    # v0.2.351 (T2.5): lifetime tokens 'a, 'static lex as kind 98 +
    # parse in generic params, reference types, generic instantiations.
    # 4 #[test] cases. Advisory metadata only.
    "$BIN" test "tests/smoke/t25_lifetime_params.nr" >/tmp/_nuc_step.log 2>&1
    grep -q "PASS: test_no_lifetime_baseline" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_single_lifetime" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_two_lifetimes" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_mixed_lifetime_and_type_param" /tmp/_nuc_step.log || return 1
    grep -q "test result: PASS (4 tests)" /tmp/_nuc_step.log || return 1
}

t24_trait_objects() {
    # v0.2.350 (T2.4): trait object 2-cell handle runtime helpers.
    # 5 #[test] cases covering manual dispatch + polymorphic collection.
    "$BIN" test "tests/smoke/t24_trait_objects.nr" >/tmp/_nuc_step.log 2>&1
    grep -q "PASS: test_dyn_box_make_type_data" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_dyn_box_dispatch_a" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_dyn_box_dispatch_b" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_dyn_box_polymorphic_collection" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_dyn_box_unknown_tag_returns_default" /tmp/_nuc_step.log || return 1
    grep -q "test result: PASS (5 tests)" /tmp/_nuc_step.log || return 1
}

t23_closure_literals() {
    # v0.2.349 (T2.3): closure literals lifted into synthesized
    # top-level fns. 4 #[test] cases including a 3-step pipeline.
    "$BIN" test "tests/smoke/t23_closure_literals.nr" >/tmp/_nuc_step.log 2>&1
    grep -q "PASS: test_map_with_closure" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_filter_with_closure" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_fold_with_closure" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_chain_with_closures" /tmp/_nuc_step.log || return 1
    grep -q "test result: PASS (4 tests)" /tmp/_nuc_step.log || return 1
}

t22_iter_methods() {
    # v0.2.348 (T2.2): Vec method-call dispatch for iterator methods
    # routes to typed `vec_*_i64` runtime helpers. 5 #[test] cases
    # including a `.map().filter().fold()` chain.
    "$BIN" test "tests/smoke/t22_iter_methods.nr" >/tmp/_nuc_step.log 2>&1
    grep -q "PASS: test_map" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_filter" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_fold_and_sum" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_min_max" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_chain" /tmp/_nuc_step.log || return 1
    grep -q "test result: PASS (5 tests)" /tmp/_nuc_step.log || return 1
}

t21_range_patterns() {
    # v0.2.347 (T2.1): inclusive `LO..=HI` and exclusive `LO..HI`
    # range patterns wired through to existing __range / __range_bad
    # lowering. Synced across both compilers. 3 #[test] cases.
    "$BIN" test "tests/smoke/t21_range_patterns.nr" >/tmp/_nuc_step.log 2>&1
    grep -q "PASS: test_range_inclusive_boundaries" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_range_exclusive_normalizes" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_range_falls_through_to_wildcard" /tmp/_nuc_step.log || return 1
    grep -q "test result: PASS (3 tests)" /tmp/_nuc_step.log || return 1
}

t26_format_macros() {
    # v0.2.346 (T2.6): source-level macro expansion. 6 #[test] cases
    # cover int placeholder, two placeholders, {:s} str passthrough,
    # literal-only, {{ }} escapes, {:b} bool spec.
    "$BIN" test "tests/smoke/t26_format_macros.nr" >/tmp/_nuc_step.log 2>&1
    grep -q "PASS: test_format_basic_int" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_format_two_placeholders" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_format_str_passthrough" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_format_literal_only" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_format_escaped_braces" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_format_bool_spec" /tmp/_nuc_step.log || return 1
    grep -q "test result: PASS (6 tests)" /tmp/_nuc_step.log || return 1
}

t16_gen_headers_structs() {
    # v0.2.345 (T1.6): nuc gen-headers walks the source for #[repr(C)]
    # structs, emits typedef structs in the C header, and accepts
    # struct names in extern fn signatures. Non-repr(C) structs
    # (PrivateInternal in the fixture) must be excluded.
    local hdr
    hdr="$(mktemp 2>/dev/null || echo /tmp/_t16_struct_ffi.h)"
    rm -f "$hdr"
    "$BIN" gen-headers tests/fixtures/t16_struct_ffi.nr -o "$hdr" >/tmp/_nuc_step.log 2>&1
    grep -qE 'wrote 2 #\[repr\(C\)\] struct\(s\), 2 extern decl\(s\), 0 #\[export\] decl\(s\)' /tmp/_nuc_step.log || return 1
    [ -f "$hdr" ] || return 1
    grep -q "typedef struct Point2D" "$hdr" || return 1
    grep -q "double x;" "$hdr" || return 1
    grep -q "typedef struct Color" "$hdr" || return 1
    grep -q "uint8_t r;" "$hdr" || return 1
    grep -q "double distance(Point2D a, Point2D b);" "$hdr" || return 1
    grep -q "void fill_pixel(Color c, int64_t count);" "$hdr" || return 1
    if grep -q "PrivateInternal" "$hdr"; then return 1; fi
    rm -f "$hdr"
}

t14_export_static() {
    # v0.2.344 (T1.4): registry export-static produces the
    # GitHub-Pages-publishable static-site shape per RFC-0019 §6.
    # Uses the checked-in fixture at tests/fixtures/t14_registry/
    # (2 packages: foo with 2 versions, bar with 1 version).
    local out_dir
    out_dir="$(mktemp -d 2>/dev/null || echo /tmp/_t14_verify_out)"
    rm -rf "$out_dir"
    "$BIN" registry export-static "$out_dir" --registry tests/fixtures/t14_registry >/tmp/_nuc_step.log 2>&1
    grep -q "packages exported: 2" /tmp/_nuc_step.log || return 1
    grep -q "versions exported: 3" /tmp/_nuc_step.log || return 1
    grep -qE "files copied:\s*7" /tmp/_nuc_step.log || return 1
    [ -f "$out_dir/index.json" ] || return 1
    [ -f "$out_dir/foo/index.json" ] || return 1
    [ -f "$out_dir/foo/0.2.0/Nucleor.toml" ] || return 1
    [ -f "$out_dir/bar/1.0.0/Nucleor.toml" ] || return 1
    grep -q '"schema_version":"1.0"' "$out_dir/index.json" || return 1
    grep -q '"type":"nucleor_registry_index"' "$out_dir/index.json" || return 1
    grep -q '"name":"foo"' "$out_dir/index.json" || return 1
    grep -q '"latest":"0.2.0"' "$out_dir/index.json" || return 1
    grep -q '"count":2' "$out_dir/index.json" || return 1
    rm -rf "$out_dir"
}

t15d_mod003() {
    # v0.2.343 (T1.5d): undefined-symbol clang errors that match
    # privatized fn names get lifted into MOD-003 with origin path
    # and the `add pub` hint. Builds the err fixture (which calls
    # lib_helper from outside lib_optin.nr) and asserts the friendly
    # diagnostic appears in stderr.
    "$BIN" build "tests/err/err_priv_cross_module.nr" -o "_t15d_check" --no-cache >/tmp/_nuc_step.log 2>&1
    grep -q "error\[MOD-003\]: cannot call private fn 'lib_helper'" /tmp/_nuc_step.log || return 1
    grep -q "declared in:.*lib_optin\.nr" /tmp/_nuc_step.log || return 1
    grep -q 'hint: add `pub` to the fn declaration' /tmp/_nuc_step.log || return 1
    grep -q "MOD-003 violation(s)" /tmp/_nuc_step.log || return 1
}

t15c_privatization() {
    # v0.2.342 (T1.5c): resolver-layer name privatization with opt-in
    # semantics. Imports two libs:
    #   - lib_optin.nr  (pub fn → opt-in active, lib_helper privatized)
    #   - lib_legacy.nr (no pub fn → opt-out, legacy_fn stays callable)
    # Asserts pub fn AND opt-out non-pub fn both stay callable
    # cross-module. Negative case (cross-module non-pub call from
    # opt-in lib must FAIL) is covered by the err-fixture
    # tests/err/err_priv_cross_module.nr in the main negative sweep.
    "$BIN" test "tests/smoke/t15c_privatization.nr" >/tmp/_nuc_step.log 2>&1
    grep -q "PASS: test_cross_module_pub_call_opt_in_lib" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_cross_module_non_pub_call_opt_out_lib" /tmp/_nuc_step.log || return 1
    grep -q "test result: PASS (2 tests)" /tmp/_nuc_step.log || return 1
}

t15b_pub_introspection() {
    # v0.2.341 (T1.5b): the parser emits a kind-76 marker before each
    # `pub`-prefixed top-level item; `nuc summary` reads the markers
    # and prefixes `pub fn` accordingly. Smoke fixture verifies both
    # the summary surface AND that intra-module fn calls are
    # unaffected (3 #[test] cases all PASS). Cross-module enforcement
    # arrives in T1.5c.
    "$BIN" summary "tests/smoke/t15b_pub_introspection.nr" >/tmp/_nuc_step.log 2>&1
    grep -q "pub fn pub_alpha()" /tmp/_nuc_step.log || return 1
    grep -q "pub fn pub_gamma()" /tmp/_nuc_step.log || return 1
    grep -q "^fn priv_beta()" /tmp/_nuc_step.log || return 1
    grep -q "^fn priv_delta()" /tmp/_nuc_step.log || return 1
    "$BIN" test "tests/smoke/t15b_pub_introspection.nr" >/tmp/_nuc_step.log 2>&1
    grep -q "PASS: test_pub_fn_callable" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_non_pub_fn_still_callable_pre_enforcement" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_mixed_pub_arithmetic" /tmp/_nuc_step.log || return 1
    grep -q "test result: PASS (3 tests)" /tmp/_nuc_step.log || return 1
}

t15a_mod_block_form() {
    # v0.2.340 (T1.5a): the resolver inlines `mod foo { ... }` block
    # contents alongside the existing `mod foo;` file-rooted desugaring.
    # Brace scanner is string- and line-comment-aware. This step runs
    # the smoke fixture via `nuc test` and asserts all three cases PASS.
    "$BIN" test "tests/smoke/t15a_mod_block_form.nr" >/tmp/_nuc_step.log 2>&1
    grep -q "PASS: test_mod_block_helper_visible_outside" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_mod_block_brace_in_string" /tmp/_nuc_step.log || return 1
    grep -q "PASS: test_mod_block_brace_in_comment_does_not_close_early" /tmp/_nuc_step.log || return 1
    grep -q "test result: PASS (3 tests)" /tmp/_nuc_step.log || return 1
}

t17_bootstrap_seed_matches() {
    # v0.2.339 (T1.7): the Linux verify gate clang-links
    # bootstrap/nucleor_s1_seed.ll against the platform-portable C
    # runtime to produce its own bin/nucleor. The seed must match what
    # the current compiler emits for compiler/nucleor_s1_compiler.nr,
    # otherwise the Linux gate would cross-fail every time the IR
    # shape changed without the developer also refreshing the seed.
    # Refresh workflow: see bootstrap/README.md.
    local seed="bootstrap/nucleor_s1_seed.ll"
    [ -f "$seed" ] || return 1
    "$BIN" build "compiler/nucleor_s1_compiler.nr" -o "_seed_check" >/tmp/_nuc_step.log 2>&1
    local fresh="target/_seed_check.ll"
    [ -f "$fresh" ] || return 1
    local seed_sha
    local fresh_sha
    seed_sha="$(sha256sum "$seed"  | awk '{print $1}')"
    fresh_sha="$(sha256sum "$fresh" | awk '{print $1}')"
    [ "$seed_sha" = "$fresh_sha" ]
}

# Shared body for the per-source memory-budget steps. Builds the
# named source under NUC_TRACE_ALLOC=1, parses the TOTAL TRACKED
# line, and asserts it stays under `budget_mb`. Diagnostic guidance
# on failure points at the underlying NUC_TRACE_ALLOC command so
# the developer can see the per-category breakdown.
_memory_budget_for() {
    local src="$1"
    local budget_mb="$2"
    local label="$3"
    local out_name="$4"
    local out
    rm -rf "$ROOT/.nuc_cache" 2>/dev/null || true
    out=$(NUC_TRACE_ALLOC=1 "$BIN" build "$src" -o "$out_name" 2>&1)
    local mb
    mb=$(echo "$out" | awk '/TOTAL TRACKED/ { for (i=1; i<=NF; i++) if ($i ~ /MB\)$/) { gsub(/[(]|MB\)/, "", $(i-1)); print $(i-1); exit } }')
    if [ -z "$mb" ]; then
        echo "       ERROR: could not parse TOTAL TRACKED from NUC_TRACE_ALLOC output" | sed 's/^/       /'
        return 1
    fi
    if [ "$mb" -gt "$budget_mb" ]; then
        echo "       FAIL: ${label} compile used ${mb} MB; budget ${budget_mb} MB" | sed 's/^/       /'
        echo "       Recent changes may have re-introduced an allocate-then-discard pattern." | sed 's/^/       /'
        echo "       Run NUC_TRACE_ALLOC=1 bin/nucleor.exe build ${src} --no-cache" | sed 's/^/       /'
        echo "       to see per-category breakdown." | sed 's/^/       /'
        return 1
    fi
    echo "       (${label}: ${mb} MB / ${budget_mb} MB budget)" | sed 's/^/       /'
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

mojibake_clean() {
    # v0.2.91 — flag cp1252-as-utf8 mojibake byte sequences across
    # the source/doc surface. Catches the drift class that bit
    # rod_manifest.toml in v0.2.58 and vqe_h2.nr in v0.2.90.
    bash "$ROOT/tools/check_mojibake.sh" >/tmp/_nuc_step.log 2>&1
}

# --- Run gate -----------------------------------------------------------
step "binary present" check_binary
step "compiler ABI tables synced" compiler_tables_synced
step "tools-suite rebuild" tools_rebuild
step "no UTF-8 mojibake in source/docs" mojibake_clean
step "tests/err/*.nr have EXPECT headers" err_tests_have_expect_smoke
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
step "self-host memory budget (<= 100 MB)" self_host_memory_budget
step "tools-suite memory budget (<= 200 MB)" tools_suite_memory_budget
step "T1.5a mod block-form inline" t15a_mod_block_form
step "T1.5b pub introspection (summary surfaces visibility)" t15b_pub_introspection
step "T1.5c privatization (cross-module call surfaces succeed)" t15c_privatization
step "T1.5d MOD-003 surfaces with origin + pub hint" t15d_mod003
step "T1.4 nuc registry export-static (GH-Pages schema)" t14_export_static
step "T1.6 gen-headers emits #[repr(C)] struct typedefs" t16_gen_headers_structs
step "T2.6 println!/print!/format! macros expand correctly" t26_format_macros
step "T2.1 range patterns in match (1..=9 / 1..10)" t21_range_patterns
step "T2.2 Vec iterator methods (.map/.filter/.fold/.sum/.min/.max)" t22_iter_methods
step "T2.3 closure literals |args| body (no-capture)" t23_closure_literals
step "T2.4 trait objects (Box<dyn Trait> 2-cell handle helpers)" t24_trait_objects
step "T2.5 lifetime parameters parse cleanly (advisory metadata)" t25_lifetime_params
step "T2.7 nuc doc --html emits styled standalone HTML" t27_doc_html
step "T2.8 async (threads-only): async fn / async_spawn / .await" t28_async_threads
step "T3.2 #[no_panic] passes when body has no panic-prone calls" t32_no_panic_clean
step "T3.3 static WCET v1 estimator emits warning[RT-004]" t33_wcet_estimator
step "T3.5 RT-007 fires when #[deadline] lacks no_alloc/no_panic" t35_rt007_unguarded_deadline
step "T3.4 #[export] surfaces in nuc gen-headers" t34_export_decls
step "T3.6 #[no_dyn] passes when body has no dynamic dispatch" t36_no_dyn_clean
step "T3.7 RT body checks strip strings and line comments" t37_rt_string_skip
step "T3.8 RT-006 fires on RT attr + async fn" t38_rt006_async_attr
step "T3.12 #[allow_fn] suppresses one RT diag for one fn" t320_allow_fn_per_fn
step "T3.17 #[allow_fn(RT-004)] suppresses static WCET warning per-fn" t317_allow_fn_rt004
step "T3.18 #[deny_fn(RT-007)] promotes warning to error (strict)" t321_deny_fn_promotes_strict
step "T3.19 #[allow_fn(RT-001)] cannot demote error tier (strict)" t323_allow_fn_error_tier_strict
step "T3.20 DIAG-001 fires for #[allow]/#[deny] unknown-prefix codes" t320_diag001_unknown_code
step "T3.21 #[allow(DIAG-001)] suppresses DIAG-001 itself" t321_diag001_self_suppress
step "T3.23 diag-code drift (s1 is_known_diag_code vs smoke list)" t323_diag_code_drift
step "T3.24 spec-doc drift (canonical codes vs Nucleor_Error_Codes.md)" t324_spec_doc_drift
step "T3.25 examples-list drift (examples/*.nr vs examples.list)" t325_examples_list_drift
step "T3.26 cli-help cmds drift (verify.sh ⇄ verify.ps1)" t326_cli_help_cmds_drift
step "T3.27 #[export] workaround produces correct dot product" t327_export_workaround_dot
step "T3.28 inline f64 ops on struct-field operands (v0.3.53 fix)" t328_struct_field_fp_ops
step "T3.29 inline f64 ops on fn-call results (v0.3.54 fix)" t329_fn_call_fp_ops
step "T3.30 inline f64 ops on Vec indexing (v0.3.55 fix)" t330_vec_index_fp_ops
step "T3.31 mixed-operand f64 binops (v0.3.56 lock)" t331_mixed_fp_ops
step "T3.9 RT-005 fires on FFI call from RT fn body" t39_rt005_ffi_call
step "T3.15 #[ffi_no_alloc] marker silences RT-005 for that extern" t324_ffi_no_alloc_marker
step "T3.16 #[deadline] needs BOTH ffi_no_* markers (intersection rule)" t326_ffi_intersection
step "T3.10 RT-008 fires on direct recursion in deadline fn" t310_rt008_recursion
step "T3.11 bare arena_* builtins link + run end-to-end" t311_arena_builtin_smoke
step "v0.3.0 #[deadline=N] runtime check passes within budget" v030_deadline_pass
step "v0.3.0 #[deadline=N] overrun aborts with RT-004" v030_deadline_overrun
step "T1.7 bootstrap seed matches current compiler" t17_bootstrap_seed_matches

# --- Cleanup ------------------------------------------------------------
# Default: wipe target + .nuc_cache so the next run starts cold (matches
# CI semantics — fresh module-graph cache). Set KEEP_CACHE=1 in the env
# to skip cleanup; the next run will reuse the module-graph cache and
# the self-host rebuild step alone drops from ~20s to ~2s. Use during
# active iteration; never in CI.
if [ "${KEEP_CACHE:-0}" != "1" ]; then
    rm -rf "$ROOT/target" "$ROOT/.nuc_cache" 2>/dev/null || true
fi

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
