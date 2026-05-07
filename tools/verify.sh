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
VERIFY_PARALLEL_JOBS="${NUC_VERIFY_JOBS:-4}"
VERIFY_PARALLEL_LIST="${NUC_VERIFY_PARALLEL_LIST:-0}"
# v0.5.26: bisect-narrow protocol modes (Tier-2 + Tier-4 from
# parallel-1's APPEND-PROTO).
#   --rerun-failed [csv]  : skip steps whose last CSV status was PASS;
#                           run FAIL/SKIP/missing. CSV defaults to the
#                           current agent's verify_timings.<name>.csv.
#   --only "<step name>"  : run only the step whose name matches
#                           exactly (other steps emit SKIP).
RERUN_FAILED=0
RERUN_FAILED_CSV=""
ONLY_STEP=""
# v0.5.29: Tier-3 bisect-narrow `--range FROM-TO` (ordered index slice).
# Runs only steps whose 1-based index falls in [FROM, TO] inclusive.
# Hierarchical: [1-348] + [349-696] = full 696, [1-174] = first half of
# [1-348], etc. This is the primitive tools/bisect_mem.sh uses to recurse
# into the offending half on a memory excursion without ever running the
# full sequential set as a routine gate. 0/0 = disabled (full set).
RANGE_FROM=0
RANGE_TO=0
while [ $# -gt 0 ]; do
    case "$1" in
        --no-color)
            NO_COLOR_FLAG="1"
            shift
            ;;
        -j|--jobs)
            if [ $# -lt 2 ]; then echo "ERROR: $1 requires a worker count"; exit 1; fi
            VERIFY_PARALLEL_JOBS="$2"
            shift 2
            ;;
        --sequential-fixtures)
            VERIFY_PARALLEL_JOBS=0
            shift
            ;;
        --list-parallel-fixtures)
            VERIFY_PARALLEL_LIST=1
            shift
            ;;
        --rerun-failed)
            RERUN_FAILED=1
            if [ $# -ge 2 ] && [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
                RERUN_FAILED_CSV="$2"
                shift 2
            else
                shift
            fi
            ;;
        --only)
            if [ $# -lt 2 ]; then echo "ERROR: --only requires a step name"; exit 1; fi
            ONLY_STEP="$2"
            shift 2
            ;;
        --range)
            if [ $# -lt 2 ]; then echo "ERROR: --range requires FROM-TO (e.g. 1-348)"; exit 1; fi
            case "$2" in
                [1-9]*-[1-9]*)
                    RANGE_FROM="${2%-*}"
                    RANGE_TO="${2##*-}"
                    case "$RANGE_FROM$RANGE_TO" in
                        *[!0-9]*) echo "ERROR: --range FROM-TO must be integers (got '$2')"; exit 1 ;;
                    esac
                    if [ "$RANGE_FROM" -lt 1 ] || [ "$RANGE_TO" -lt "$RANGE_FROM" ]; then
                        echo "ERROR: --range needs 1<=FROM<=TO (got $RANGE_FROM-$RANGE_TO)"; exit 1
                    fi
                    ;;
                *)
                    echo "ERROR: --range expects FROM-TO with 1<=FROM<=TO (got '$2')"; exit 1
                    ;;
            esac
            shift 2
            ;;
        --help|-h)
            cat <<'EOH'
verify.sh — Nucleor smoke gate

Usage: bash tools/verify.sh [OPTIONS]

  --no-color                         Disable ANSI color in output.
  -j, --jobs N                       Parallel-fixture worker count (default 4).
                                     0 = sequential.
  --sequential-fixtures              Force sequential fixture runs (=  -j 0).
  --list-parallel-fixtures           Print parallel fixture step list, exit.
  --rerun-failed [CSV]               v0.5.26: skip steps that PASSED in last
                                     CSV run; run only FAIL/SKIP/missing.
                                     Default CSV: tools/verify_timings.<agent>.csv
                                     (NUC_VERIFY_AGENT) or .csv if unset.
  --only "<step name>"               v0.5.26: run only the step whose name
                                     matches exactly. Other steps emit SKIP.
  --range FROM-TO                    v0.5.29: run only the global-step-index
                                     range [FROM, TO] inclusive. Hierarchical
                                     halves: [1-348]+[349-696]=full set on a
                                     696-step gate; [1-174]=first half of
                                     [1-348]. Used by tools/bisect_mem.sh to
                                     find a memory excursion in O(log N)
                                     half-runs without ever running the full
                                     sequential gate as a routine pass.
  --help                             This text.

Environment:
  NUC_VERIFY_AGENT=<name>            Per-agent CSV namespacing
                                     (writes tools/verify_timings.<name>.csv).
  NUC_VERIFY_JOBS=N                  Same as -j N.
  NUC_VERIFY_CSV=<path>              Override CSV path entirely.
  NUC_VERIFY_TMPDIR=<path>           Override per-step log dir.
  NUCLEOR_INT_STRICT_INTRIN=1        Run env-on (strict-intrin overflow checks).

Bisect-narrow protocol (v0.5.29):
  Tier 1 (routine):     bash tools/verify.sh                         # concurrent + CSV
  Tier 2 (after fail):  bash tools/verify.sh --rerun-failed          # rerun non-PASS
  Tier 3 (mem hunt):    bash tools/bisect_mem.sh [--threshold MB]    # log-N half-runs
  Tier 3 (manual):      bash tools/verify.sh --range 1-348           # ordered slice
  Tier 4 (single step): bash tools/verify.sh --only "<step name>"
  See tools/VERIFY_TIMING_RECIPE.md for the full protocol.
  Goal: never run the full sequential gate as a routine ship — let
  Tier 1 catch time spikes via per-step CSV, let Tier 3 catch memory
  spikes by recursive halving.
EOH
            exit 0
            ;;
        *)
            echo "unknown arg: $1"
            exit 1
            ;;
    esac
done
case "$VERIFY_PARALLEL_JOBS" in
    ''|*[!0-9]*)
        echo "ERROR: NUC_VERIFY_JOBS/-j must be a non-negative integer"
        exit 1
        ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NUC_VERIFY_TMPDIR_OWNED=0
if [ -z "${NUC_VERIFY_TMPDIR:-}" ]; then
    NUC_VERIFY_TMPDIR="$(mktemp -d 2>/dev/null || echo "/tmp/nuc_verify_$$")"
    NUC_VERIFY_TMPDIR_OWNED=1
else
    mkdir -p "$NUC_VERIFY_TMPDIR" 2>/dev/null || true
fi
NUC_VERIFY_STEP_LOG="$NUC_VERIFY_TMPDIR/step.log"
NUC_VERIFY_EX_OUT_LOG="$NUC_VERIFY_TMPDIR/example.out"
NUC_VERIFY_RUN_LOG="$NUC_VERIFY_TMPDIR/run.log"
cleanup_verify_tmpdir() {
    if [ "$NUC_VERIFY_TMPDIR_OWNED" = "1" ]; then
        rm -rf "$NUC_VERIFY_TMPDIR" 2>/dev/null || true
    fi
}
trap cleanup_verify_tmpdir EXIT
case "$(uname -s)" in
    CYGWIN*|MINGW*|MSYS*)
        if [ -x "$ROOT/bin/nucleor.exe" ]; then BIN="$ROOT/bin/nucleor.exe"; else BIN="$ROOT/bin/nucleor"; fi
        ;;
    *)
        if [ -x "$ROOT/bin/nucleor" ]; then BIN="$ROOT/bin/nucleor"; elif [ -x "$ROOT/bin/nucleor.exe" ]; then BIN="$ROOT/bin/nucleor.exe"; else BIN="$ROOT/bin/nucleor"; fi
        ;;
esac
case "$(uname -s)" in
    Linux*)
        case "$BIN" in
            *.exe)
                export NUCLEOR_STDLIB="${NUCLEOR_STDLIB:-$ROOT}"
                if [ "$NUC_VERIFY_TMPDIR_OWNED" = "1" ]; then
                    rm -rf "$NUC_VERIFY_TMPDIR" 2>/dev/null || true
                    NUC_VERIFY_TMPDIR="$ROOT/target/.verify_tmp/nuc_verify_$$"
                    mkdir -p "$NUC_VERIFY_TMPDIR" || exit 1
                    NUC_VERIFY_STEP_LOG="$NUC_VERIFY_TMPDIR/step.log"
                    NUC_VERIFY_EX_OUT_LOG="$NUC_VERIFY_TMPDIR/example.out"
                    NUC_VERIFY_RUN_LOG="$NUC_VERIFY_TMPDIR/run.log"
                fi
                ;;
        esac
        ;;
esac

grep() {
    if [ "$#" -ge 2 ]; then
        local last_arg="${@: -1}"
        if [ "$last_arg" = "$NUC_VERIFY_STEP_LOG" ] || [ "$last_arg" = "$NUC_VERIFY_RUN_LOG" ] || [ "$last_arg" = "$NUC_VERIFY_EX_OUT_LOG" ]; then
            local normalized="$NUC_VERIFY_TMPDIR/.grep_normalized_$$"
            tr -d '\r' < "$last_arg" > "$normalized" || return 2
            command grep "${@:1:$(($# - 1))}" "$normalized"
            local rc=$?
            rm -f "$normalized"
            return "$rc"
        fi
    fi
    if [ "$#" -ge 1 ]; then
        local maybe_file="${@: -1}"
        if [ -e "$maybe_file" ]; then
            command grep "$@"
            return "$?"
        fi
    fi
    if [ -p /dev/stdin ]; then
        local normalized_stdin="$NUC_VERIFY_TMPDIR/.grep_stdin_normalized_$$"
        tr -d '\r' > "$normalized_stdin" || return 2
        command grep "$@" "$normalized_stdin"
        local rc=$?
        rm -f "$normalized_stdin"
        return "$rc"
    fi
    command grep "$@"
}

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

# v0.4.22 — per-step timing CSV. Set NUC_VERIFY_CSV=path to enable.
# Defaults to tools/verify_timings.csv. Each row: index,seconds,status,name.
# Header is written once at first step; subsequent runs append a separator
# row "---,---,RUN,<ISO timestamp>" so multiple runs share one file.
#
# v0.5.17 — agent-namespaced default. With 3 agents (main / parallel-1 /
# probe) potentially running verify concurrently, a shared CSV path
# races. Setting NUC_VERIFY_AGENT=<name> changes the default to
# `tools/verify_timings.<name>.csv` so each agent has its own log.
# Set explicitly via NUC_VERIFY_CSV to override either default.
# tools/check_perf_regression.ps1 reads all per-agent CSVs.
if [ -z "${NUC_VERIFY_CSV:-}" ]; then
    if [ -n "${NUC_VERIFY_AGENT:-}" ]; then
        NUC_VERIFY_CSV="$(cd "$(dirname "$0")/.." && pwd)/tools/verify_timings.${NUC_VERIFY_AGENT}.csv"
    else
        NUC_VERIFY_CSV="$(cd "$(dirname "$0")/.." && pwd)/tools/verify_timings.csv"
    fi
fi
NUC_VERIFY_CSV_ENABLED=1
if [ ! -f "$NUC_VERIFY_CSV" ]; then
    if ! { echo 'run_iso,index,seconds,status,name' > "$NUC_VERIFY_CSV"; } 2>/dev/null; then
        NUC_VERIFY_CSV_ENABLED=0
    fi
fi
NUC_VERIFY_CSV_RUN_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"

# Cross-platform monotonic milliseconds (bash $EPOCHREALTIME on bash 5+;
# fallback to date +%s%3N on GNU date; final fallback to seconds * 1000).
_now_ms() {
    if [ -n "${EPOCHREALTIME:-}" ]; then
        # 1700000000.123456 -> 1700000000123 (strip µs, keep ms)
        echo "${EPOCHREALTIME//./}" | cut -c1-13
    else
        local ms
        ms="$(date +%s%3N 2>/dev/null)"
        if [ -n "$ms" ] && [ "${ms: -4}" != "%3N0" ]; then echo "$ms"; else echo "$(($(date +%s) * 1000))"; fi
    fi
}

step() {
    local name="$1"; shift
    STEP_INDEX=$((STEP_INDEX + 1))
    local prefix
    prefix="$(printf '[%3d/%d]' "$STEP_INDEX" "$STEP_TOTAL")"
    local rc start end secs status csv_name
    # v0.5.26: bisect-narrow modes. --only skips non-matching steps; emit
    # SKIP without running. --rerun-failed skips steps whose LAST CSV
    # status was PASS; new (missing-from-CSV) and FAIL/SKIP rerun.
    if [ -n "$ONLY_STEP" ] && [ "$name" != "$ONLY_STEP" ]; then
        echo "$prefix $(yellow 'SKIP')  $name  (--only filter)"
        TOTAL_SKIP=$((TOTAL_SKIP + 1))
        return
    fi
    # v0.5.29: --range FROM-TO ordered slice. Skip steps outside [FROM, TO].
    if [ "$RANGE_TO" -gt 0 ]; then
        if [ "$STEP_INDEX" -lt "$RANGE_FROM" ] || [ "$STEP_INDEX" -gt "$RANGE_TO" ]; then
            echo "$prefix $(yellow 'SKIP')  $name  (--range $RANGE_FROM-$RANGE_TO filter)"
            TOTAL_SKIP=$((TOTAL_SKIP + 1))
            return
        fi
    fi
    if [ "$RERUN_FAILED" = "1" ]; then
        local _rrf_csv="${RERUN_FAILED_CSV:-$NUC_VERIFY_CSV}"
        if [ -n "$_rrf_csv" ] && [ -f "$_rrf_csv" ]; then
            # CSV format: run_iso,index,seconds,status,name (name is quoted).
            # Find LAST row matching this step name; check status field.
            local _quoted_name="\"${name//\"/\"\"}\""
            local _last_status
            _last_status=$(grep -F ",$_quoted_name" "$_rrf_csv" 2>/dev/null | tail -1 | awk -F, '{print $4}')
            if [ "$_last_status" = "PASS" ]; then
                echo "$prefix $(yellow 'SKIP')  $name  (--rerun-failed: last PASS)"
                TOTAL_SKIP=$((TOTAL_SKIP + 1))
                return
            fi
        fi
    fi
    start=$(_now_ms)
    "$@"
    rc=$?
    end=$(_now_ms)
    secs=$(awk -v s="$start" -v e="$end" 'BEGIN{ printf "%.3f", (e - s) / 1000.0 }')
    case "$rc" in
        0)  echo "$prefix $(green 'OK  ')  $name  ($(printf '%6.2fs' "$secs"))"; status=PASS; TOTAL_PASS=$((TOTAL_PASS + 1)) ;;
        2)  echo "$prefix $(yellow 'SKIP')  $name  ($(printf '%6.2fs' "$secs"))"; status=SKIP; TOTAL_SKIP=$((TOTAL_SKIP + 1)) ;;
        *)  echo "$prefix $(red   'FAIL')  $name  ($(printf '%6.2fs' "$secs"))"; status=FAIL; TOTAL_FAIL=$((TOTAL_FAIL + 1)); FAILURES+=("$name") ;;
    esac
    if [ "$NUC_VERIFY_CSV_ENABLED" = "1" ]; then
        # Quote name to survive commas/quotes; double any embedded ".
        csv_name="\"${name//\"/\"\"}\""
        printf '%s,%d,%s,%s,%s\n' "$NUC_VERIFY_CSV_RUN_ISO" "$STEP_INDEX" "$secs" "$status" "$csv_name" >> "$NUC_VERIFY_CSV" 2>/dev/null || true
    fi
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
        line="${line%$'\r'}"
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
TEST_SKIP_REGEX='_aux\.nr$|import_dedupe_lib\.nr$'
ERR_SKIP_REGEX='err_str_char_at_strict_oob\.nr$|err_t4_strict_inference\.nr$|err_numg2_math_abs_imin\.nr$|err_numg2_math_gcd_imin\.nr$|err_numg2_math_pow_int_overflow\.nr$'
TEST_COUNT=0
for d in "${TEST_DIRS[@]}"; do
    if [ -d "tests/$d" ]; then
        c=$(find "tests/$d" -maxdepth 1 -name '*.nr' 2>/dev/null | grep -vE "$TEST_SKIP_REGEX" | wc -l | tr -d ' ')
        TEST_COUNT=$((TEST_COUNT + c))
    fi
done
ERR_COUNT=$(find "tests/err" -maxdepth 1 -name '*.nr' 2>/dev/null | grep -vE "$ERR_SKIP_REGEX" | wc -l | tr -d ' ')

# Step count: derive dynamically from the `step "..."` line count
# in this file, then add the dynamic dirs (examples + tests + err).
# v0.4.90 fix: was hardcoded `20 + ... + 134` which drifted as new
# steps were added (showed [511/493] for the last 18 steps). Now
# self-counting so future additions don't need a manual bump.
STEP_TOTAL_FIXED=$(grep -c '^step "' "${BASH_SOURCE[0]:-$0}")
STEP_TOTAL=$((STEP_TOTAL_FIXED + ${#EXAMPLES[@]} + TEST_COUNT + ERR_COUNT))

# --- Step bodies --------------------------------------------------------
check_binary() {
    case "$BIN" in
        *.exe) [ -f "$BIN" ] || return 1 ;;
        *)     [ -x "$BIN" ] || return 1 ;;
    esac
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
    contract_path=$(echo "$out" | sed -n 's/^[[:space:]]*Contract:[[:space:]]*//p' | tr -d '\r')
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
    local rexec="./target/showcase_robotic_arm"
    [ -x "$rexec.exe" ] && rexec="$rexec.exe"
    local rrun
    rrun=$("$rexec" 2>&1 || true)
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

verify_reproducible_smoke() {
    # PERF-5 / RFC-NRT-003: keep the SLSA reproducibility invariant
    # inside the canonical bash gate. This exercises the linked-binary
    # byte compare path as well as IR hash equality.
    "$BIN" verify-reproducible "tests/fixtures/t477_provenance_section.nr" >$NUC_VERIFY_STEP_LOG 2>&1 || {
        tail -20 $NUC_VERIFY_STEP_LOG | sed 's/^/       /'
        return 1
    }
    grep -q "PASS: byte-identical IR" $NUC_VERIFY_STEP_LOG || {
        tail -20 $NUC_VERIFY_STEP_LOG | sed 's/^/       /'
        return 1
    }
    grep -q "EXE diff: byte-identical" $NUC_VERIFY_STEP_LOG || {
        tail -20 $NUC_VERIFY_STEP_LOG | sed 's/^/       /'
        return 1
    }
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
    # v0.5.31: replaced per-file `head -3 | grep` (2 forks per file × ~100
    # files ≈ 200 spawns, 10-24s wall on Windows) with bash builtin scan.
    # Reads first 3 lines without forking; matches via case/glob.
    local missing=()
    local f line1 line2 line3
    for f in "$ROOT"/tests/err/*.nr; do
        line1=""; line2=""; line3=""
        { IFS= read -r line1 || true; IFS= read -r line2 || true; IFS= read -r line3 || true; } < "$f" 2>/dev/null
        case "$line1$line2$line3" in
            *"// EXPECT:"*) ;;
            *) missing+=("$(basename "$f")") ;;
        esac
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
        "NR034" "NR035" "NR036" "NR040" "NR050" "NR051" "NR070" "NR090"
        # RFC-0001 RT
        "RT-001" "RT-002" "RT-003" "RT-004" "RT-005" "RT-006" "RT-007" "RT-008" "RT-009"
        "ASYNC-001"
        # RFC-0002 allocators
        "ALLOC-001" "ALLOC-002" "ALLOC-003"
        # RFC-0003 typed frames
        "FRAME-001" "FRAME-002" "FRAME-003"
        # OWN series — borrow checker (expansion of NR031, since v0.2.119;
        # OWN-013 added v0.2.131 — spawn-capture for non-Send DeviceBuffer)
        "OWN-001" "OWN-002" "OWN-003" "OWN-004" "OWN-005" "OWN-006"
        "OWN-007" "OWN-008" "OWN-009" "OWN-010" "OWN-011" "OWN-012"
        "OWN-013"
        # RFC-0035 Sendable + actor isolation
        "RACE-001" "RACE-002" "RACE-003" "RACE-004" "RACE-005"
        "RACE-006" "RACE-007" "RACE-008" "RACE-009" "RACE-010"
        # GOV series — governance policies (since v0.2.131)
        "GOV-001" "GOV-002"
        # TNT series — taint analysis (expansion of NR033, since v0.2.120)
        "TNT-001"
        # TYP series — type checker (expansion of NR030, since v0.2.119)
        "TYP-001" "TYP-002" "TYP-003" "TYP-004" "TYP-005"
        "TYP-006" "TYP-007" "TYP-008" "TYP-009" "TYP-010" "TYP-011" "TYP-012" "TYP-013"
        "TYP-026" "TYP-027"
        # FMT series — format macro expansion
        "FMT-002" "FMT-003"
        # TRAIT series — trait dispatch and conversions
        "TRAIT-001"
        # RFC-0004 assume!
        "ASSUME-001" "ASSUME-002" "ASSUME-003" "ASSUME-004" "ASSUME-005"
        # RFC-0005 units
        "UNIT-001" "UNIT-002" "UNIT-003" "UNIT-004" "UNIT-005"
        # RFC-0006 contracts
        "CONTRACT-001" "CONTRACT-002" "CONTRACT-003" "CONTRACT-004"
        "CONTRACT-005" "CONTRACT-006" "CONTRACT-007" "CONTRACT-008"
        "CONTRACT-009" "CONTRACT-010" "CONTRACT-011"
        # RFC-0007 atomic
        "ATOMIC-001" "ATOMIC-002" "ATOMIC-003" "ATOMIC-004" "ATOMIC-005"
        "ATOMIC-006"
        # RFC-0008 ISR
        "ISR-001" "ISR-002" "ISR-003" "ISR-004" "ISR-005" "ISR-006" "ISR-007" "ISR-008"
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
        "NUM-016" "NUM-017" "NUM-018" "NUM-019" "NUM-020" "NUM-021"
        # NUM-021 (v0.4.119/v0.6 E3) — literal / const-expression overflow.
        # NUM-022/023 (v0.4.137/v0.4.140) — int-vs-float arith mismatch
        # and `f64 as str` cast rejection. NUM-024 (v0.4.228) — opt-in
        # cross-width call-site audit (NUCLEOR_AUDIT_NUM024=1) for
        # RFC-0015 phase 3c.1 surfacing of i64-into-iN-param sites.
        "NUM-022" "NUM-023" "NUM-024"
        # Router / hot-path performance diagnostics
        "PERF-1" "PERF-2" "PERF-3"
        # RFC-0016 Result/Option/match (v0.2; 007..010 for v0.4 RFC-0023)
        "MATCH-001" "MATCH-002" "MATCH-003" "MATCH-004" "MATCH-005" "MATCH-006"
        "MATCH-007" "MATCH-008" "MATCH-009" "MATCH-010"
        "MATCH-011" "MATCH-012" "MATCH-013" "MATCH-014"
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
        "LAW-001" "LAW-002" "LAW-003" "LAW-004" "LAW-006" "LAW-007" "LAW-008"
        # RFC-0032 effects
        "EFF-001" "EFF-002" "EFF-003" "EFF-004" "EFF-005"
        # RFC-0020 DIAG (minted v0.3.36 — first DIAG-NNN code)
        "DIAG-001"
    )
    # v0.5.31: rewritten from per-code subprocess fan-out (xargs -P 2
    # with `echo $out | grep` and `echo $out | sed` checks inside the
    # worker) to a single-process loop using bash builtins. The old
    # path forked ~7 processes per code × 197 codes / 2 parallelism =
    # ~700 process spawns; on Windows that's ~75-120 seconds wall.
    # Investigation found "nuc explain CODE" itself runs in ~40ms;
    # the entire cost was bash/grep/sed fork+exec overhead, not work.
    # The new loop runs in ~5-10s on the same machine.
    #
    # Test logic is preserved exactly: each code must produce
    # non-empty output containing the code itself, plus non-empty
    # lines 2 (cause) and 3 (hint).
    local fails=""
    local code out l2 l3
    for code in "${codes[@]}"; do
        out=$("$BIN" explain "$code" 2>&1)
        case "$out" in
            *"unknown error code"*) fails="${fails}FAIL:${code}:unknown"$'\n'; continue ;;
        esac
        case "$out" in
            *"$code"*) ;;
            *)         fails="${fails}FAIL:${code}:no-self"$'\n'; continue ;;
        esac
        # Pull lines 2 and 3 with bash parameter expansion — no sed fork.
        l2="${out#*$'\n'}"     # drop line 1
        l3="${l2#*$'\n'}"      # drop line 2 (l3 = body from line 3 onward)
        l2="${l2%%$'\n'*}"     # keep only line 2
        l3="${l3%%$'\n'*}"     # keep only line 3
        [ -z "$l2" ] && { fails="${fails}FAIL:${code}:no-cause"$'\n'; continue; }
        [ -z "$l3" ] && { fails="${fails}FAIL:${code}:no-hint"$'\n'; continue; }
    done
    if [ -n "$fails" ]; then
        printf '%s' "$fails" | head -5 | sed 's/^/       /'
        return 1
    fi
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

prepare_local_runtime() {
    local workdir="$1"
    rm -rf "$workdir/stdlib"
    mkdir -p "$workdir/stdlib" || return 1
    cp -R "$ROOT/stdlib/runtime" "$workdir/stdlib/" || return 1
    return 0
}

prepare_local_tools() {
    local workdir="$1"
    if [ -f "$ROOT/bin/nucleor_tools.exe" ]; then
        cp "$ROOT/bin/nucleor_tools.exe" "$workdir/nucleor_tools.exe" || return 1
    elif [ -f "$ROOT/bin/nucleor_tools" ]; then
        cp "$ROOT/bin/nucleor_tools" "$workdir/nucleor_tools" || return 1
    fi
    return 0
}

verify_bin_path() {
    local p="$1"
    case "$p" in
        "$ROOT"/*) printf '%s\n' "${p#"$ROOT"/}" ;;
        *) printf '%s\n' "$p" ;;
    esac
}

verify_tmp_file() {
    printf '%s\n' "$NUC_VERIFY_TMPDIR/$1"
}

verify_tmp_dir() {
    local d="$NUC_VERIFY_TMPDIR/$1"
    rm -rf "$d"
    mkdir -p "$d" || return 1
    printf '%s\n' "$d"
}

nuc_build_with_env() {
    local env_assign="$1"
    local src="$2"
    local out="$3"
    shift 3
    if command -v wslpath >/dev/null 2>&1; then
        case "$(uname -s):$BIN" in
            Linux*:*.exe)
                local root_win src_arg cmd extra
                root_win="$(wslpath -w "$ROOT")"
                src_arg="$(verify_bin_path "$src")"
                src_arg="${src_arg//\//\\}"
                cmd="cd /d $root_win && set $env_assign&& bin\\nucleor.exe build $src_arg -o $out"
                for extra in "$@"; do cmd="$cmd $extra"; done
                cmd.exe /C "$cmd"
                return "$?"
                ;;
        esac
    fi
    env "$env_assign" "$BIN" build "$(verify_bin_path "$src")" -o "$out" "$@"
}

# nuc init scaffolding smoke (added v0.2.66) — verifies the
# new-user-first-command produces a working project. Catches
# regressions in the init template (Nucleor.toml fields,
# src/main.nr scaffold) that the example/test gate misses.
cli_init_smoke() {
    local sandbox="$NUC_VERIFY_TMPDIR/_nuc_init_smoke_$$"
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
        prepare_local_runtime "$PWD" || exit 1
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
    local sandbox="$NUC_VERIFY_TMPDIR/_nuc_test_smoke_$$"
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
        prepare_local_runtime "$PWD" || exit 1
        prepare_local_tools "$PWD" || exit 1
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

cli_check_laws_smoke() {
    local out
    out=$("$BIN" test "$(verify_bin_path "tests/features/law_check_true_smoke.nr")" --check-laws --no-cache 2>&1) || {
        printf '%s\n' "$out" | tail -20
        return 1
    }
    echo "$out" | grep -q "info\\[CHECK-LAWS\\]" || return 1
    echo "$out" | grep -q "__nucleor_law_check_" || return 1
    echo "$out" | grep -q "test result: PASS" || return 1

    out=$("$BIN" test "$(verify_bin_path "tests/features/law_check_distributive_true_smoke.nr")" --check-laws --no-cache 2>&1) || {
        printf '%s\n' "$out" | tail -20
        return 1
    }
    echo "$out" | grep -q "info\\[CHECK-LAWS\\]" || return 1
    echo "$out" | grep -q "__nucleor_law_check_" || return 1
    echo "$out" | grep -q "test result: PASS" || return 1

    out=$("$BIN" test "$(verify_bin_path "tests/features/law_check_false_smoke.nr")" --check-laws --no-cache 2>&1) && {
        printf '%s\n' "$out" | tail -20
        return 1
    }
    echo "$out" | grep -q "error\\[LAW-001\\]" || return 1

    out=$("$BIN" test "$(verify_bin_path "tests/features/law_schema_alias_zero_smoke.nr")" --check-laws --no-cache 2>&1) && {
        printf '%s\n' "$out" | tail -20
        return 1
    }
    echo "$out" | grep -q "error\\[LAW-006\\]" || return 1

    out=$("$BIN" test "$(verify_bin_path "tests/features/law_schema_alias_distributive_smoke.nr")" --check-laws --no-cache 2>&1) && {
        printf '%s\n' "$out" | tail -20
        return 1
    }
    echo "$out" | grep -q "error\\[LAW-007\\]" || return 1

    out=$("$BIN" test "$(verify_bin_path "tests/features/law_schema_unknown_smoke.nr")" --check-laws --no-cache 2>&1) && {
        printf '%s\n' "$out" | tail -20
        return 1
    }
    echo "$out" | grep -q "error\\[LAW-008\\]" || return 1

    out=$("$BIN" test "$(verify_bin_path "tests/features/law_schema_inverse_unsupported_smoke.nr")" --check-laws --no-cache 2>&1) && {
        printf '%s\n' "$out" | tail -20
        return 1
    }
    echo "$out" | grep -q "error\\[LAW-001\\]" || return 1

    # R14 Phase 3b broad property pack (local-claude2 v0842) — bounded
    # `@law(inverse = g)` is generated under --check-laws. Positive
    # smoke must PASS and emit __nucleor_law_check_*; malformed
    # `inverse =` (no partner) must FAIL closed with LAW-001 + the
    # partner-fn-name diagnostic.
    out=$("$BIN" test "$(verify_bin_path "tests/features/law_inverse_bounded_smoke.nr")" --check-laws --no-cache 2>&1) || {
        printf '%s\n' "$out" | tail -20
        return 1
    }
    echo "$out" | grep -q "info\\[CHECK-LAWS\\]" || return 1
    echo "$out" | grep -q "__nucleor_law_check_" || return 1
    echo "$out" | grep -q "test result: PASS" || return 1

    out=$("$BIN" test "$(verify_bin_path "tests/features/law_schema_malformed_inverse_smoke.nr")" --check-laws --no-cache 2>&1) && {
        printf '%s\n' "$out" | tail -20
        return 1
    }
    echo "$out" | grep -q "error\\[LAW-001\\]" || return 1
    echo "$out" | grep -q "partner function name" || return 1

    out=$("$BIN" test "$(verify_bin_path "tests/features/law_schema_approximate_unsupported_smoke.nr")" --check-laws --no-cache 2>&1) && {
        printf '%s\n' "$out" | tail -20
        return 1
    }
    echo "$out" | grep -q "error\\[LAW-004\\]" || return 1

    out=$("$BIN" test "$(verify_bin_path "tests/features/law_schema_f64_unsupported_smoke.nr")" --check-laws --no-cache 2>&1) && {
        printf '%s\n' "$out" | tail -20
        return 1
    }
    echo "$out" | grep -q "error\\[LAW-004\\]" || return 1
    return 0
}

# nuc lock smoke (added v0.2.68) — RFC-0019 package manager phase 1
# is a v0.2 deliverable. Verifies the lockfile generator reads
# Nucleor.toml, walks the (trivial in this case) dependency graph,
# and writes Nucleor.lock with the expected fields.
cli_lock_smoke() {
    local sandbox="$NUC_VERIFY_TMPDIR/_nuc_lock_smoke_$$"
    rm -rf "$sandbox"
    mkdir -p "$sandbox" || return 1
    (
        cd "$sandbox" || exit 1
        "$BIN" init lockproj >/dev/null 2>&1 || exit 1
        cd lockproj || exit 1
        prepare_local_tools "$PWD" || exit 1
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
    local sandbox="$NUC_VERIFY_TMPDIR/_nuc_doc_smoke_$$"
    rm -rf "$sandbox"
    mkdir -p "$sandbox" || return 1
    (
        cd "$sandbox" || exit 1
        prepare_local_tools "$PWD" || exit 1
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
    if [ "$ex" = "13_test_framework" ]; then
        "$BIN" test "examples/13_test_framework.nr" >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
        grep -q "test result: PASS" $NUC_VERIFY_STEP_LOG || return 1
        return 0
    fi
    "$BIN" build "examples/$ex.nr" -o "$ex" >$NUC_VERIFY_STEP_LOG 2>&1
    if [ ! -x "target/$ex" ] && [ ! -x "target/$ex.exe" ]; then
        tail -1 $NUC_VERIFY_STEP_LOG | sed 's/^/       /'
        return 1
    fi
    # Capture stdout to $NUC_VERIFY_EX_OUT_LOG so we can shape-check it.
    # Catches the silent-regression case where an example builds + exits
    # 0 but produces wrong/no output (added v0.2.61).
    if [ -x "target/$ex" ]; then
        "target/$ex" >$NUC_VERIFY_EX_OUT_LOG 2>&1
    else
        "target/$ex.exe" >$NUC_VERIFY_EX_OUT_LOG 2>&1
    fi
    local rc=$?
    if [ "$rc" -ne 0 ]; then
        tail -1 $NUC_VERIFY_EX_OUT_LOG | sed 's/^/       /'
        return 1
    fi
    # Non-empty stdout shape check (added v0.2.61) — catches silent
    # regressions where the binary builds + exits 0 but prints nothing.
    if [ ! -s $NUC_VERIFY_EX_OUT_LOG ]; then
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
    if [ "$dir" = "features" ] && [ -z "$RUST_BRIDGE_LIB" ]; then
        case "$tname" in
            rust_bridge_*) return 2 ;;
        esac
    fi
    "$BIN" build "tests/$dir/$tname.nr" -o "$tname" >$NUC_VERIFY_STEP_LOG 2>&1
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

_write_parallel_fixture_worker() {
    local worker="$NUC_VERIFY_TMPDIR/parallel_fixture_worker.sh"
    cat > "$worker" <<'EOS'
#!/usr/bin/env bash
set -u
ROOT="$1"
BIN="$2"
TMP="$3"
RUST_BRIDGE_LIB="$4"
idx="$5"
kind="$6"
dir="$7"
tname="$8"

cd "$ROOT" 2>/dev/null || exit 0
result="$TMP/parallel.$idx.result"
steplog="$TMP/parallel.$idx.log"
label="negative $tname"
if [ "$kind" = "test" ]; then label="test $dir/$tname"; fi

now_ms() {
    if [ -n "${EPOCHREALTIME:-}" ]; then
        echo "${EPOCHREALTIME//./}" | cut -c1-13
    else
        local ms
        ms="$(date +%s%3N 2>/dev/null)"
        if [ -n "$ms" ] && [ "${ms: -4}" != "%3N0" ]; then echo "$ms"; else echo "$(($(date +%s) * 1000))"; fi
    fi
}

finish() {
    local status="$1" dt="$2" reason="${3:-}"
    printf '%s|%s|%s|%s\n' "$status" "$label" "$dt" "$reason" > "$result"
    exit 0
}

t0="$(now_ms)"
if [ "$kind" = "test" ]; then
    if [ "$tname" = "rust_interop" ] && [ -z "$RUST_BRIDGE_LIB" ]; then
        t1="$(now_ms)"
        dt="$(awk -v s="$t0" -v e="$t1" 'BEGIN{ printf "%.3f", (e - s) / 1000.0 }')"
        finish SKIP "$dt" "rust bridge unavailable"
    fi
    if [ "$dir" = "features" ] && [ -z "$RUST_BRIDGE_LIB" ]; then
        case "$tname" in
            rust_bridge_*)
                t1="$(now_ms)"
                dt="$(awk -v s="$t0" -v e="$t1" 'BEGIN{ printf "%.3f", (e - s) / 1000.0 }')"
                finish SKIP "$dt" "rust bridge unavailable"
                ;;
        esac
    fi
    out_name="_pv_${dir}_${tname}"
    "$BIN" build "tests/$dir/$tname.nr" -o "$out_name" > "$steplog" 2>&1
    exe="target/$out_name"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    if [ ! -x "$exe" ]; then
        t1="$(now_ms)"
        dt="$(awk -v s="$t0" -v e="$t1" 'BEGIN{ printf "%.3f", (e - s) / 1000.0 }')"
        finish FAIL "$dt" "build_failed"
    fi
    if [ "$dir" = "rods" ] && [ "$tname" = "socket" ] && [ "${NUC_VERIFY_RUN_SOCKET:-0}" != "1" ]; then
        t1="$(now_ms)"
        dt="$(awk -v s="$t0" -v e="$t1" 'BEGIN{ printf "%.3f", (e - s) / 1000.0 }')"
        finish SKIP "$dt" "socket runtime disabled; set NUC_VERIFY_RUN_SOCKET=1"
    fi
    out="$("$exe" 2>&1)"
    rc=$?
    t1="$(now_ms)"
    dt="$(awk -v s="$t0" -v e="$t1" 'BEGIN{ printf "%.3f", (e - s) / 1000.0 }')"
    if [ "$dir" = "features" ]; then
        if [ "$rc" -eq 139 ] || [ "$rc" -eq 138 ] || [ "$rc" -eq -1073741819 ] || [ "$rc" -eq -1073740940 ]; then
            finish FAIL "$dt" "crash_exit_$rc"
        fi
        finish PASS "$dt" ""
    fi
    echo "$out" | grep -qE '^OK ' && finish PASS "$dt" "" || finish FAIL "$dt" "missing_OK_marker"
fi

out_name="_pv_err_${tname}"
out="$("$BIN" build "tests/err/$tname.nr" -o "$out_name" --no-cache 2>&1)"
t1="$(now_ms)"
dt="$(awk -v s="$t0" -v e="$t1" 'BEGIN{ printf "%.3f", (e - s) / 1000.0 }')"
echo "$out" | grep -qiE 'error\b|error\[|warning\b|warning\[' \
    && finish PASS "$dt" "" \
    || finish FAIL "$dt" "no_error_or_warning_emitted"
EOS
    chmod +x "$worker" 2>/dev/null || true
    echo "$worker"
}

run_parallel_fixture_steps() {
    local workers="$1"
    local steps_file="$NUC_VERIFY_TMPDIR/parallel_steps.list"
    local idx=0 d f tname ename
    : > "$steps_file"
    for d in "${TEST_DIRS[@]}"; do
        if [ -d "tests/$d" ]; then
            for f in $(find "tests/$d" -maxdepth 1 -name '*.nr' 2>/dev/null | grep -vE "$TEST_SKIP_REGEX" | sort); do
                tname=$(basename "$f" .nr)
                idx=$((idx + 1))
                printf '%d test %s %s\n' "$idx" "$d" "$tname" >> "$steps_file"
            done
        fi
    done
    if [ -d "tests/err" ]; then
        for f in $(find "tests/err" -maxdepth 1 -name '*.nr' 2>/dev/null | grep -vE "$ERR_SKIP_REGEX" | sort); do
            ename=$(basename "$f" .nr)
            idx=$((idx + 1))
            printf '%d negative _ %s\n' "$idx" "$ename" >> "$steps_file"
        done
    fi

    if [ "$idx" -eq 0 ]; then
        return 0
    fi
    # v0.5.26: apply bisect-narrow filters to the parallelizable subset.
    # --only filters by exact label match (worker label form is
    # "test <dir>/<tname>" or "negative <ename>"). --rerun-failed
    # filters by last CSV status != PASS. Both rebuild steps_file in
    # place so the xargs/result-tally code below operates only on the
    # filtered subset. We renumber the kept entries to keep the [N/T]
    # display line numbers contiguous.
    if [ -n "$ONLY_STEP" ] || [ "$RERUN_FAILED" = "1" ] || [ "$RANGE_TO" -gt 0 ]; then
        local _filt="$NUC_VERIFY_TMPDIR/parallel_steps.filtered.list"
        local _rrf_csv="${RERUN_FAILED_CSV:-$NUC_VERIFY_CSV}"
        local _base="$STEP_INDEX"
        : > "$_filt"
        local _new_idx=0 _src_idx=0
        local _line _kind _ldir _lname _label _last_status _quoted _global_idx
        while IFS= read -r _line; do
            # _line shape: "<old-idx> <kind> <dir> <tname>"
            read -r _ _kind _ldir _lname <<<"$_line"
            if [ "$_kind" = "test" ]; then
                _label="test $_ldir/$_lname"
            else
                _label="negative $_lname"
            fi
            _src_idx=$((_src_idx + 1))
            _global_idx=$((_base + _src_idx))
            local _keep=1
            if [ -n "$ONLY_STEP" ] && [ "$_label" != "$ONLY_STEP" ]; then _keep=0; fi
            if [ "$_keep" = "1" ] && [ "$RERUN_FAILED" = "1" ] && [ -n "$_rrf_csv" ] && [ -f "$_rrf_csv" ]; then
                _quoted="\"${_label//\"/\"\"}\""
                _last_status=$(grep -F ",$_quoted" "$_rrf_csv" 2>/dev/null | tail -1 | awk -F, '{print $4}')
                if [ "$_last_status" = "PASS" ]; then _keep=0; fi
            fi
            # v0.5.29: --range FROM-TO uses the GLOBAL step index (top-level
            # run-count + this fixture's offset within the parallel block).
            # That keeps [1..STEP_TOTAL] a single ordered axis the bisect
            # orchestrator can halve hierarchically.
            if [ "$_keep" = "1" ] && [ "$RANGE_TO" -gt 0 ]; then
                if [ "$_global_idx" -lt "$RANGE_FROM" ] || [ "$_global_idx" -gt "$RANGE_TO" ]; then
                    _keep=0
                fi
            fi
            if [ "$_keep" = "1" ]; then
                _new_idx=$((_new_idx + 1))
                printf '%d %s %s %s\n' "$_new_idx" "$_kind" "$_ldir" "$_lname" >> "$_filt"
            fi
        done < "$steps_file"
        mv "$_filt" "$steps_file"
        idx="$_new_idx"
        if [ "$idx" -eq 0 ]; then
            echo "       parallel fixtures: 0 steps (filtered out by --only / --rerun-failed / --range)"
            return 0
        fi
    fi
    if ! command -v xargs >/dev/null 2>&1; then
        echo "       xargs missing; falling back to sequential fixture loops"
        return 2
    fi

    local worker base_index start end wall pass fail skip tsum
    worker="$(_write_parallel_fixture_worker)"
    base_index="$STEP_INDEX"
    start=$(_now_ms)
    echo "$(dim '---') parallel fixtures: $idx steps, $workers workers"
    xargs -n 4 -P "$workers" "$worker" "$ROOT" "$BIN" "$NUC_VERIFY_TMPDIR" "$RUST_BRIDGE_LIB" < "$steps_file"
    end=$(_now_ms)
    wall=$(awk -v s="$start" -v e="$end" 'BEGIN{ printf "%.3f", (e - s) / 1000.0 }')

    pass=0
    fail=0
    skip=0
    tsum=0
    local i result status label dt reason prefix csv_name
    for i in $(seq 1 "$idx"); do
        result="$NUC_VERIFY_TMPDIR/parallel.$i.result"
        if [ ! -f "$result" ]; then
            status=FAIL
            label="parallel fixture #$i"
            dt="0.000"
            reason="result_missing"
        else
            IFS="|" read -r status label dt reason < "$result"
        fi
        tsum=$(awk -v a="$tsum" -v b="$dt" 'BEGIN{printf "%.3f", a+b}')
        prefix="$(printf '[%3d/%d]' "$((base_index + i))" "$STEP_TOTAL")"
        case "$status" in
            PASS)
                pass=$((pass + 1))
                [ "$VERIFY_PARALLEL_LIST" = "1" ] && echo "$prefix $(green 'OK  ')  $label  ($(printf '%6.2fs' "$dt"))"
                ;;
            SKIP)
                skip=$((skip + 1))
                [ "$VERIFY_PARALLEL_LIST" = "1" ] && echo "$prefix $(yellow 'SKIP')  $label  ($(printf '%6.2fs' "$dt"))"
                ;;
            *)
                fail=$((fail + 1))
                echo "$prefix $(red 'FAIL')  $label  ($(printf '%6.2fs' "$dt"))"
                [ -n "$reason" ] && echo "       $reason"
                FAILURES+=("$label")
                ;;
        esac
        if [ "$NUC_VERIFY_CSV_ENABLED" = "1" ]; then
            csv_name="\"${label//\"/\"\"}\""
            printf '%s,%d,%s,%s,%s\n' "$NUC_VERIFY_CSV_RUN_ISO" "$((base_index + i))" "$dt" "$status" "$csv_name" >> "$NUC_VERIFY_CSV" 2>/dev/null || true
        fi
    done

    STEP_INDEX=$((base_index + idx))
    TOTAL_PASS=$((TOTAL_PASS + pass))
    TOTAL_FAIL=$((TOTAL_FAIL + fail))
    TOTAL_SKIP=$((TOTAL_SKIP + skip))
    printf "       parallel fixtures: PASS %d" "$pass"
    [ "$skip" -gt 0 ] && printf ", SKIP %d" "$skip"
    printf ", FAIL %d, wall %.2fs, sum %.2fs, speedup %.2fx\n" \
        "$fail" "$wall" "$tsum" "$(awk -v a="$tsum" -v b="$wall" 'BEGIN{ if (b > 0) printf "%.2f", a/b; else printf "0.00" }')"
    return 0
}

self_host_rebuild() {
    "$BIN" build "compiler/nucleor_s1_compiler.nr" -o "verify_compiler" >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/verify_compiler" ] || [ -x "target/verify_compiler.exe" ]
}

# v0.2.161 — guard against memory regressions in the self-host compile.
# On Windows this measures peak process-tree RSS and kills the build if
# it crosses the budget. That tracks the real crash risk from compiler
# and clang overlap. On Linux hosts without the PowerShell sampler, it
# uses tools/run_capped.sh for a /proc process-tree RSS e-stop. Other
# POSIX hosts fail unsupported instead of passing a soft allocation proxy.
#
# Budget history:
# - v0.2.161: 400 MB cap, 185 MB baseline (2.2x headroom).
# - Track L (v0.5.0): bumped to 1024 MB. Per-call e-stop, but the
#   ceiling was used as a comfort blanket — drift accumulated to 587 MB
#   on main, 818 MB on v06-track-effects-types.
# - v0.5.14 (2026-05-01): ratchet back down. Current main self-host
#   peak is 587 MB env-off / 704 MB env-on. Tools-suite is 490 MB
#   env-off / 470 MB env-on. Set tight ceilings (640 / 540) so any
#   new ship that adds memory gets caught immediately. Bumping the
#   ceiling MUST come with a documented investigation in the same
#   ship; raising it as a comfort blanket is what got us here.
#   See `docs/milestones/MEMORY_DRIFT_2026-05-01.md`.
self_host_memory_budget() {
    # v0.5.14: tight 770 MB cap. Observed peaks across 3 samples:
    # 587 / 670 / 703 MB env-off, 704 MB env-on. Sample variance
    # is ~100 MB driven by clang's working-set timing dependence
    # on OS scheduler state; budget at peak + 67 MB to absorb it.
    # User directive: stay below 800 MB. To raise this number,
    # ship a memory investigation in the same PR.
    _memory_budget_for "compiler/nucleor_s1_compiler.nr" 770 "self-host" "verify_budget"
}

tools_suite_memory_budget() {
    # v0.5.14: tight 580 MB cap. Initial 540 MB cap from a single
    # measurement was too tight — second sample landed at 529 MB
    # (only 11 MB headroom). 580 MB is current measured peak (529)
    # + 50 MB headroom. Same raise-rule as self-host.
    _memory_budget_for "compiler/nucleor_tools_suite.nr" 580 "tools-suite" "verify_tools_budget"
}

t33_wcet_estimator() {
    "$BIN" build "tests/fixtures/t33_wcet_overrun.nr" -o "_t33_wcet_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE 'warning\[RT-004\]: heuristic deadline estimate [0-9]+ us' $NUC_VERIFY_STEP_LOG || return 1
    grep -q 'exceeds #\[deadline = 1 us\]' $NUC_VERIFY_STEP_LOG || return 1
    grep -q 'default loop multiplier 100x' $NUC_VERIFY_STEP_LOG || return 1
}

t35_rt007_unguarded_deadline() {
    # T3.5 (v0.3.3): warn when #[deadline] has neither #[no_alloc]
    # nor #[no_panic] — alloc/panic break WCET determinism.
    "$BIN" build "tests/fixtures/t35_rt007.nr" -o "_t35_rt007_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE 'warning\[RT-007\]:' $NUC_VERIFY_STEP_LOG || return 1
    grep -q 'has #\[deadline\] but neither #\[no_alloc\] nor #\[no_panic\]' $NUC_VERIFY_STEP_LOG || return 1
}

t34_export_decls() {
    # T3.4 (v0.3.4): #[export] attribute → C forward declaration
    # in `nuc gen-headers` output. Lets external C code call into
    # Nucleor-compiled fns through the unmangled LLVM symbol.
    local hdr hdr_arg
    hdr="$(verify_tmp_file "_t34_export.h")"
    hdr_arg="$(verify_bin_path "$hdr")"
    rm -f "$hdr"
    "$BIN" gen-headers "tests/fixtures/t34_export.nr" -o "$hdr_arg" >$NUC_VERIFY_STEP_LOG 2>&1
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
    "$BIN" test "tests/smoke/t36_no_dyn_clean.nr" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -q "PASS: test_no_dyn_pid_static_dispatch" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_no_dyn_fk_static_dispatch" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "test result: PASS (2 tests)" $NUC_VERIFY_STEP_LOG || return 1
}

t311_arena_builtin_smoke() {
    # T3.11 (v0.3.11): #[test]-framework coverage for the bare
    # arena_new / arena_alloc / arena_reset / arena_destroy
    # builtin path. The runtime fix shipped in v0.2.154 but
    # never received #[test] coverage (the existing
    # tests/lang/arena_builtin.nr is a main-fn shape).
    "$BIN" test "tests/smoke/t311_arena_builtin.nr" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -q "PASS: test_arena_round_trip" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "test result: PASS (1 test)" $NUC_VERIFY_STEP_LOG || return 1
}

t310_rt008_recursion() {
    # T3.10 (v0.3.9): RT-008 — direct self-recursion in a
    # #[deadline] fn warns. Bounded recursion opts out via
    # #[max_depth = N]. Two paired fixtures: unbounded fires
    # RT-008, bounded stays clean.
    "$BIN" build "tests/fixtures/t310_rt008_recursion.nr" -o "_t310_rt008_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE "warning\[RT-008\]: 'fib_unbounded' has #\[deadline\] and recursively calls itself" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "add #\[max_depth" $NUC_VERIFY_STEP_LOG || return 1
    "$BIN" build "tests/fixtures/t310_rt008_bounded.nr" -o "_t310_bounded_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    if grep -q "RT-008" $NUC_VERIFY_STEP_LOG; then return 1; fi
    return 0
}

rfc0014_max_depth_full_ship() {
    "$BIN" build "tests/features/rfc0014_max_depth_bounded.nr" -o "_rfc0014_max_depth" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    grep -q "__nucleor_max_depth_enter" "target/_rfc0014_max_depth.ll" || return 1
    local exe="target/_rfc0014_max_depth"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    local out
    out=$("$exe" 2>&1) || return 1
    echo "$out" | grep -q "OK rfc0014_max_depth_bounded" || return 1

    local pf pexe pout ok
    for pf in \
        "rfc0014_max_depth_param_flow" \
        "rfc0014_max_depth_stride" \
        "rfc0014_max_depth_helper_guard" \
        "rfc0014_max_depth_no_recurse_callback" \
        "rfc0014_max_depth_scc"; do
        "$BIN" build "tests/features/$pf.nr" -o "_$pf" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
        pexe="target/_$pf"
        [ -x "$pexe.exe" ] && pexe="$pexe.exe"
        pout=$("$pexe" 2>&1) || return 1
        ok="OK $pf"
        echo "$pout" | grep -q "$ok" || return 1
    done

    "$BIN" build "tests/fixtures/rfc0014_max_depth_runtime_overrun.nr" -o "_rfc0014_depth_overrun" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    local overrun_exe="target/_rfc0014_depth_overrun"
    [ -x "$overrun_exe.exe" ] && overrun_exe="$overrun_exe.exe"
    local overrun_out
    overrun_out=$("$overrun_exe" 2>&1)
    echo "$overrun_out" | grep -q "DEPTH-003" || return 1

    local f code
    for pair in \
        "err_depth_001_unbounded DEPTH-001" \
        "err_depth_002_overflow DEPTH-002" \
        "err_depth_003_cycle DEPTH-003" \
        "err_depth_004_invalid_context DEPTH-004" \
        "err_depth_005_stack_budget DEPTH-005" \
        "err_depth_001_callback_unknown DEPTH-001" \
        "err_depth_001_non_monotonic DEPTH-001" \
        "err_depth_001_helper_unproven DEPTH-001" \
        "err_depth_002_stride_bound DEPTH-002" \
        "err_depth_003_scc_unproven DEPTH-003"; do
        f="${pair% *}"
        code="${pair#* }"
        "$BIN" build "tests/err/$f.nr" -o "_$f" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
        grep -q "$code" $NUC_VERIFY_STEP_LOG || return 1
    done
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
    "$BIN" build "tests/fixtures/t324_ffi_no_alloc.nr" -o "_t324_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE "warning\[RT-005\]: FFI call 'host_unsafe'" $NUC_VERIFY_STEP_LOG || return 1
    if grep -qE "warning\[RT-005\]: FFI call 'host_safe'" $NUC_VERIFY_STEP_LOG; then return 1; fi
}

t333_effects_with_positive() {
    # RFC-0033 first-pass: parse function/extern/fn-pointer type
    # `with [...]` clauses without changing legacy lowering.
    "$BIN" build "tests/features/effects_with_positive.nr" -o "_t333_effects_positive" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    local exe="target/_t333_effects_positive"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1 || return 1
}

t333_effects_with_no_alloc() {
    "$BIN" build "tests/err/err_effects_with_no_alloc_vec.nr" -o "_t333_effects_no_alloc" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE "error\[RT-001\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "busy" $NUC_VERIFY_STEP_LOG || return 1
}

t333_effects_with_no_panic() {
    "$BIN" build "tests/err/err_effects_with_no_panic.nr" -o "_t333_effects_no_panic" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE "error\[RT-002\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "bad_op" $NUC_VERIFY_STEP_LOG || return 1
}

rt_transitive_same_file_closure() {
    "$BIN" build "tests/err/err_no_alloc_transitive_two_hop.nr" -o "_rt_no_alloc_two_hop" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE "error\[RT-001\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "format_wrapper" $NUC_VERIFY_STEP_LOG || return 1

    "$BIN" build "tests/err/err_no_panic_transitive_same_file.nr" -o "_rt_no_panic_transitive" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE "error\[RT-002\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "guard_wrapper" $NUC_VERIFY_STEP_LOG || return 1

    "$BIN" build "tests/features/rt_transitive_clean_helper_chain_smoke.nr" -o "_rt_transitive_clean_helper_chain" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    local exe="target/_rt_transitive_clean_helper_chain"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1 || return 1
}

t333_effects_with_no_dyn() {
    "$BIN" build "tests/err/err_effects_with_no_dyn.nr" -o "_t333_effects_no_dyn" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE "error\[RT-003\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "poll" $NUC_VERIFY_STEP_LOG || return 1
}

t333_effects_with_alloc_call() {
    "$BIN" build "tests/err/err_effects_with_alloc_call.nr" -o "_t333_effects_alloc_call" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE "error\[EFF-003\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "may_alloc" $NUC_VERIFY_STEP_LOG || return 1
}

r05_requires_body_builtin() {
    "$BIN" build "tests/err/err_requires_row_builtin_io_mismatch.nr" -o "_r05_requires_body_builtin" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE "error\[EFF-001\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "body of" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "io.write" $NUC_VERIFY_STEP_LOG || return 1
}

r05_requires_transitive_builtin() {
    "$BIN" build "tests/err/err_requires_row_transitive_builtin_io.nr" -o "_r05_requires_transitive_builtin" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE "error\[EFF-001\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "call chain" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "io.write" $NUC_VERIFY_STEP_LOG || return 1
}

r05_requires_transitive_builtin_ok() {
    "$BIN" build "tests/features/requires_row_transitive_builtin_ok.nr" -o "_r05_requires_transitive_builtin_ok" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    local exe="target/_r05_requires_transitive_builtin_ok"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1 || return 1
}

r05_restricts_depth8_chain() {
    "$BIN" build "tests/err/err_restricts_block_transitive_depth8_chain.nr" -o "_r05_restricts_depth8_chain" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE "error\[EFF-003\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "net.connect" $NUC_VERIFY_STEP_LOG || return 1
}

r05_restricts_depth8_clean() {
    "$BIN" build "tests/features/restricts_block_transitive_depth8_clean_smoke.nr" -o "_r05_restricts_depth8_clean" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    local exe="target/_r05_restricts_depth8_clean"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1 || return 1
}

t333_effects_with_ffi() {
    "$BIN" build "tests/fixtures/t333_effects_with_ffi.nr" -o "_t333_effects_ffi" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE "warning\[RT-005\]: FFI call 'host_unsafe'" $NUC_VERIFY_STEP_LOG || return 1
    if grep -qE "warning\[RT-005\]: FFI call 'host_safe'" $NUC_VERIFY_STEP_LOG; then return 1; fi
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
    "$BIN" build "tests/fixtures/t326_ffi_intersection.nr" -o "_t326_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE "warning\[RT-005\]: FFI call 'h_alloc_only'" $NUC_VERIFY_STEP_LOG || return 1
    grep -qE "warning\[RT-005\]: FFI call 'h_panic_only'" $NUC_VERIFY_STEP_LOG || return 1
    if grep -qE "warning\[RT-005\]: FFI call 'h_both'" $NUC_VERIFY_STEP_LOG; then return 1; fi
}

t39_rt005_ffi_call() {
    # T3.9 (v0.3.8): RT-005 — extern fn call from inside an
    # RT-marked fn body warns. v1 is text-scan: every literal
    # `<extern_name>(` substring in the stripped body fires.
    # Until #[ffi_no_*] annotations land, every FFI call is
    # treated as RT-unsafe.
    "$BIN" build "tests/fixtures/t39_rt005_ffi.nr" -o "_t39_rt005_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE "warning\[RT-005\]: FFI call 'host_telemetry'" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "from #\[no_alloc\] fn 'rt_path'" $NUC_VERIFY_STEP_LOG || return 1
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
    list_set=$(grep -v '^#' "$ROOT/tools/examples.list" | tr -d '\r' | grep -v '^$' | sort -u)
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
    "$BIN" build "tests/fixtures/t321_diag001_self_suppress.nr" -o "_t321_diag001_self_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "0" ] || return 1
    if grep -qE 'warning\[DIAG-001\]' $NUC_VERIFY_STEP_LOG; then return 1; fi
    if grep -qE 'error\[DIAG-001\]' $NUC_VERIFY_STEP_LOG; then return 1; fi
    return 0
}

t356_indexed_lhs_diagnostic() {
    # T3.56: originally a v0.3.81 negative regression -- v[i] = X
    # pre-v0.3.81 segfaulted the compiler. v0.3.124 replaced the
    # diag-only stub with real indexed-assignment codegen via
    # vec_set lowering. The fixture returns the post-assignment
    # value of v[1] which is 999 -- proves the assignment landed.
    # Bash truncates exit status to 8 bits, so we compare against
    # 231 (= 999 mod 256). The .ps1 mirror compares against 999
    # directly because PowerShell preserves the full DWORD.
    # Bash mirror lagged the .ps1 update; v0.3.140 sync.
    "$BIN" build "tests/fixtures/t356_indexed_lhs_diagnostic.nr" -o "_t356_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local exe
    if [ -x "target/_t356_check" ]; then exe="target/_t356_check"; else exe="target/_t356_check.exe"; fi
    [ -x "$exe" ] || return 1
    "$exe" >/dev/null 2>&1
    [ "$?" -eq 231 ] || return 1
    return 0
}

t414_num002_promoted() {
    "$BIN" build "tests/fixtures/repro_v70a_num002_promoted.nr" -o "_t414_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\[NUM-002\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "out of range" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t_v06_const_overflow_diagnostics() {
    "$BIN" build "tests/err/err_const_i64_add_overflow.nr" -o "_t_v06_const_overflow" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "1" ] || return 1
    grep -q "error\[NUM-021\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "constant expression" $NUC_VERIFY_STEP_LOG || return 1
    "$BIN" build "tests/err/err_const_i8_expr_out_of_range.nr" -o "_t_v06_const_range" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "1" ] || return 1
    grep -q "error\[NUM-002\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "constant expression value" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t417_str_from_i64_contract() {
    # v0.4.72: str_from_i64 added as truthful internal entry; str_from_int
    # kept as i32-signature wrapper. Adopters using `str_from_int(...)` in
    # .nr source still go through __nucleor_int_to_str (runtime helper
    # alias). This step asserts the wrapper still BUILDS and the binary
    # RUNS. (Format dispatch for str_from_int return-type detection is a
    # pre-existing limitation, not a v0.4.72 regression.)
    "$BIN" build "tests/fixtures/repro_v72_str_from_i64_contract.nr" -o "_t417_check" --no-cache >/tmp/_nuc_step.log 2>&1
    [ "$?" = "0" ] || return 1
    local exe
    if [ -f "target/_t417_check.exe" ]; then exe="target/_t417_check.exe"; else exe="target/_t417_check"; fi
    [ -f "$exe" ] || return 1
    "$exe" >/tmp/_nuc_step.log 2>&1
    [ "$?" = "0" ] || return 1
    return 0
}

t416_bool_bitwise_guard() {
    "$BIN" build "tests/fixtures/repro_v71_bool_bitwise_guard.nr" -o "_t416_check" --no-cache >/tmp/_nuc_step.log 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\[TYP-002\]" /tmp/_nuc_step.log || return 1
    grep -q "bitwise" /tmp/_nuc_step.log || return 1
    return 0
}

t415_format_arg_count() {
    "$BIN" build "tests/fixtures/repro_v70b_format_arg_count.nr" -o "_t415_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "more.*placeholders than args" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t418_generic_option_payload_type() {
    "$BIN" build "tests/fixtures/repro_generic_option_payload_type.nr" -o "_t418_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\\[TYP-008\\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "bad" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t419_generic_result_payload_type() {
    "$BIN" build "tests/fixtures/repro_generic_result_payload_type.nr" -o "_t419_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\\[TYP-008\\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "bad" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t420_vec_element_type_propagation() {
    "$BIN" build "tests/fixtures/repro_vec_element_type_propagation.nr" -o "_t420_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\\[TYP-008\\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "bad_index" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "bad_get" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "bad_first" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t421_div_by_literal_zero() {
    # v0.4.74 NUM-009 — `/0` and `%0` literal halt at compile time
    # (was runtime SIGFPE pre-fix).
    "$BIN" build "tests/fixtures/repro_v74_div_by_literal_zero.nr" -o "_t421_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\\[NUM-009\\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "literal zero" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t422_shift_out_of_range() {
    # v0.4.75 NUM-008 — `1 << 64` and `1 << -1` halt at compile time
    # (was LLVM poison / silent miscompute pre-fix).
    "$BIN" build "tests/fixtures/repro_v75_shift_out_of_range.nr" -o "_t422_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\\[NUM-008\\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "out of range" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t447_shift_var_rhs_bounds() {
    # v0.4.146 NUM-008/runtime panic - let-bound const RHS halts at
    # compile time; non-const variable RHS routes through panic helper.
    "$BIN" build "tests/err/err_shift_var_rhs_const.nr" -o "_t447_const_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\\[NUM-008\\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "shift amount" $NUC_VERIFY_STEP_LOG || return 1

    "$BIN" build "tests/fixtures/repro_v146_shift_var_rhs_runtime_panic.nr" -o "_t447_runtime_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    rc=$?
    [ "$rc" = "0" ] || return 1
    local exe="target/_t447_runtime_check"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    local out
    out=$("$exe" 2>&1)
    local rt_rc=$?
    [ "$rt_rc" != "0" ] || return 1
    echo "$out" | grep -q "i64 shl out-of-range" || return 1
    echo "$out" | grep -q "shift amount must be 0..63" || return 1
    return 0
}

t423_float_in_int_context() {
    # v0.4.76 NUM-018 — `let x: i64 = 3.14;` halts at compile time
    # (was silent IEEE-754-bits-as-i64 miscompute pre-fix).
    "$BIN" build "tests/fixtures/repro_v76_float_in_int_context.nr" -o "_t423_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\\[NUM-018\\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "float literal" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t424_not_on_int() {
    # v0.4.76 TYP-002 ext — `let r: bool = !x;` for x: i64 halts
    # (was silent xor-with-1 miscompute pre-fix).
    "$BIN" build "tests/fixtures/repro_v76_not_on_int.nr" -o "_t424_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\\[TYP-002\\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "unary" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t425_neg_to_unsigned() {
    # v0.4.77 NUM-019 — `let x: u32 = -5;` halts at compile time
    # (was silent two's-complement-wrap to u32::MAX-4 pre-fix).
    "$BIN" build "tests/fixtures/repro_v77_neg_to_unsigned.nr" -o "_t425_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\\[NUM-019\\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "negative literal" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t426_parse_error_halts() {
    # v0.4.78 NR020 — parse errors halt the build (pre-fix they
    # printed and recovered, producing a likely-broken binary that
    # ran to exit=0). Repro uses `@` binding pattern not yet
    # supported by the parser.
    "$BIN" build "tests/fixtures/repro_v78_parse_error_halts.nr" -o "_t426_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" != "0" ] || return 1
    grep -q "NR020" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "parse error" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t427_match_tuple_pat_halts() {
    # v0.4.79 — tuple destructure pattern in match (was silent
    # downgrade-to-wildcard pre-fix).
    "$BIN" build "tests/fixtures/repro_v79_match_tuple_pat.nr" -o "_t427_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" != "0" ] || return 1
    grep -q "tuple/slice pattern requires Vec" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t428_let_at_module_scope_halts() {
    # v0.4.79 — `let` at module scope (was silent skip-to-`;` pre-fix).
    "$BIN" build "tests/fixtures/repro_v79_let_at_module_scope.nr" -o "_t428_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" != "0" ] || return 1
    grep -q "at module scope" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "let" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t429_int_lit_as_handle_halts() {
    # v0.4.80 — `vec_len(42)` literal-int-as-Vec-handle (was print
    # WARNING + continue → guaranteed runtime SIGSEGV).
    "$BIN" build "tests/fixtures/repro_v80_int_lit_as_handle.nr" -o "_t429_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" != "0" ] || return 1
    grep -q "int literal" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "Vec handle" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t430_uninit_immutable_let_halts() {
    # v0.4.83 TYP-008 ext — `let x: i64;` (immutable, no init)
    # halts at compile time (was silent zero-read miscompute).
    "$BIN" build "tests/fixtures/repro_v83_uninit_immutable_let.nr" -o "_t430_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\\[TYP-008\\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "without initializer" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t431_struct_field_type_mismatch_halts() {
    # v0.4.84 TYP-008 ext — `Point { x: "hello", y: 2 }` (str into
    # i64 field) halts at compile time (was silent ptr-as-i64
    # miscompute pre-fix).
    "$BIN" build "tests/fixtures/repro_v84_struct_field_type_mismatch.nr" -o "_t431_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\\[TYP-008\\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "struct-field type mismatch" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t432_vec_push_wrong_type_halts() {
    # v0.4.85 TYP-008 ext — Vec<i64>.push("str") halts at compile
    # time (was silent str-ptr-as-i64-cell miscompute pre-fix).
    "$BIN" build "tests/fixtures/repro_v85_vec_push_wrong_type.nr" -o "_t432_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\\[TYP-008\\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "Vec<i64>.push" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t433_vec_set_wrong_type_halts() {
    # v0.4.86 TYP-008 ext — Vec<i64>.set(0, "str") halts at compile
    # time (extends v0.4.85 to .set and .insert with elem arg at
    # position 1 instead of 0).
    "$BIN" build "tests/fixtures/repro_v86_vec_set_wrong_type.nr" -o "_t433_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\\[TYP-008\\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "Vec<i64>.set" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t4_strict_inference_rejects_empty_type() {
    # E3 / T-4: in default-off mode the v0.8.79 canary keeps
    # compiling, but NUC_STRICT_INFERENCE=1 must reject empty-type
    # inference holes instead of treating "" as compatible with any
    # annotated type.
    nuc_build_with_env "NUC_STRICT_INFERENCE=1" "tests/err/err_t4_strict_inference.nr" "_t4_strict_inference" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "1" ] || return 1
    grep -q "error\\[TYP-027\\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "type inference failed" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t4_strict_core_helper_rtypes_compile() {
    # T-4 Phase 2b partial: core runtime helpers that return concrete
    # scalar/string values must stay known under strict inference.
    nuc_build_with_env "NUC_STRICT_INFERENCE=1" "tests/features/t4_strict_core_helper_rtypes.nr" "_t4_strict_core_helper_rtypes" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    local exe="target/_t4_strict_core_helper_rtypes"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    return 0
}

t4_strict_io_path_helper_rtypes_compile() {
    # T-4 Phase 2b partial: direct IO/env/path runtime helpers must
    # carry concrete scalar/string return types under strict inference.
    nuc_build_with_env "NUC_STRICT_INFERENCE=1" "tests/features/t4_strict_io_path_helper_rtypes.nr" "_t4_strict_io_path_helper_rtypes" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    local exe="target/_t4_strict_io_path_helper_rtypes"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    return 0
}

t4_strict_format_string_helper_rtypes_compile() {
    # T-4 Phase 2b partial: format, parse, and string utility helpers
    # must carry concrete scalar/string return types under strict inference.
    nuc_build_with_env "NUC_STRICT_INFERENCE=1" "tests/features/t4_strict_format_string_helper_rtypes.nr" "_t4_strict_format_string_helper_rtypes" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    local exe="target/_t4_strict_format_string_helper_rtypes"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    return 0
}

t4_strict_remaining_helper_rtypes_compile() {
    # T-4 Phase 2b partial: direct numeric/f64 runtime helpers must
    # carry concrete scalar return types under strict inference.
    nuc_build_with_env "NUC_STRICT_INFERENCE=1" "tests/features/t4_strict_remaining_helper_rtypes.nr" "_t4_strict_remaining_helper_rtypes" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    local exe="target/_t4_strict_remaining_helper_rtypes"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    return 0
}

numg2_runtime_panic_guards() {
    # v0.8.80/81 NUM-G2 runtime guard locks. These are runtime-panic
    # fixtures, so they live outside the generic compile-time err
    # sweep and are exercised explicitly here.
    "$BIN" build "tests/err/err_numg2_math_abs_imin.nr" -o "_err_numg2_math_abs_imin" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local exe_abs="target/_err_numg2_math_abs_imin"
    [ -x "$exe_abs.exe" ] && exe_abs="$exe_abs.exe"
    local out_abs
    out_abs=$("$exe_abs" 2>&1)
    [ "$?" = "1" ] || return 1
    echo "$out_abs" | grep -q "math_abs(i64::MIN)" || return 1

    "$BIN" build "tests/err/err_numg2_math_gcd_imin.nr" -o "_err_numg2_math_gcd_imin" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local exe_gcd="target/_err_numg2_math_gcd_imin"
    [ -x "$exe_gcd.exe" ] && exe_gcd="$exe_gcd.exe"
    local out_gcd
    out_gcd=$("$exe_gcd" 2>&1)
    [ "$?" = "1" ] || return 1
    echo "$out_gcd" | grep -q "math_abs(i64::MIN)" || return 1

    "$BIN" build "tests/err/err_numg2_math_pow_int_overflow.nr" -o "_err_numg2_math_pow_int_overflow" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local exe_pow="target/_err_numg2_math_pow_int_overflow"
    [ -x "$exe_pow.exe" ] && exe_pow="$exe_pow.exe"
    local out_pow
    out_pow=$("$exe_pow" 2>&1)
    [ "$?" = "1" ] || return 1
    echo "$out_pow" | grep -q "integer overflow" || return 1
    return 0
}

t445_parse_primary_narrow_panic() {
    # v0.4.99 §_p — parse_primary fall-through panics for non-recovery
    # tokens. Pgs_smoke continues to work (token 51 = `)` is in the
    # recovery-marker set).
    "$BIN" build "tests/fixtures/repro_v99_parse_primary_narrow_panic.nr" -o "_t445_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" != "0" ] || return 1
    grep -q "NR020" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t460_question_from_conversion() {
    "$BIN" build "tests/fixtures/repro_question_from_conversion.nr" -o "_t460_question_from" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    target/_t460_question_from.exe >$NUC_VERIFY_STEP_LOG.run 2>&1
    local rc1=$?
    if [ "$rc1" -ne 107 ]; then return 1; fi

    "$BIN" build "tests/fixtures/repro_into_explicit.nr" -o "_t460_into_explicit" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    target/_t460_into_explicit.exe >$NUC_VERIFY_STEP_LOG.run 2>&1
    local rc2=$?
    if [ "$rc2" -ne 12 ]; then return 1; fi

    "$BIN" build "tests/err/err_question_missing_from_conversion.nr" -o "_t460_missing_from" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc3=$?
    if [ "$rc3" -eq 0 ]; then return 1; fi
    grep -q "error\\[TRAIT-001\\]" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t446_rich_pattern_forms() {
    for case in \
        repro_match_full_or_patterns \
        repro_match_at_binding \
        repro_match_struct_destructure \
        repro_match_slice \
        repro_match_tuple_destructure
    do
        "$BIN" build "tests/fixtures/${case}.nr" -o "_t446_${case}" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
        local exe="target/_t446_${case}"
        [ -x "$exe.exe" ] && exe="$exe.exe"
        [ -x "$exe" ] || return 1
        "$exe" >>$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    done

    "$BIN" build "tests/err/err_match_or_binding_mismatch.nr" -o "_t446_or_mismatch" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" != "0" ] || return 1
    grep -q "MATCH-008" $NUC_VERIFY_STEP_LOG || return 1

    "$BIN" build "tests/err/err_match_pattern_wrong_type.nr" -o "_t446_wrong_type" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" != "0" ] || return 1
    grep -q "tuple/slice pattern requires Vec" $NUC_VERIFY_STEP_LOG || return 1

    "$BIN" build "tests/err/err_match_at_binding_collision.nr" -o "_t446_at_collision" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" != "0" ] || return 1
    grep -q "MATCH-010" $NUC_VERIFY_STEP_LOG || return 1

    "$BIN" build "tests/err/err_match_slice_overlap.nr" -o "_t446_slice_overlap" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" != "0" ] || return 1
    grep -q "MATCH-009" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t444_debug_vec_str_and_option() {
    # v0.4.98 — extends v0.4.97 Vec debug dispatch by element type.
    "$BIN" build "tests/fixtures/repro_v98_debug_vec_str_and_option.nr" -o "_t444_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "0" ] || return 1
    local exe="target/_t444_check"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    local out
    out=$("$exe" 2>&1)
    echo "$out" | sed -n '1p' | grep -q '^\[\"a\", \"b\", \"c\"\]$' || return 1
    echo "$out" | sed -n '2p' | grep -q "^\\[Some(1), None, Some(3)\\]$" || return 1
    return 0
}

t443_recursive_debug() {
    # v0.4.97 audit doc-#1 §10b — recursive Debug for Vec/Option/Result.
    "$BIN" build "tests/fixtures/repro_v97_recursive_debug.nr" -o "_t443_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "0" ] || return 1
    local exe="target/_t443_check"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    local out
    out=$("$exe" 2>&1)
    echo "$out" | sed -n '1p' | grep -q "^\\[1, 2, 3\\]$" || return 1
    echo "$out" | sed -n '2p' | grep -q "^Some(42)$" || return 1
    echo "$out" | sed -n '3p' | grep -q "^None$" || return 1
    echo "$out" | sed -n '4p' | grep -q "^Ok(99)$" || return 1
    echo "$out" | sed -n '5p' | grep -q "^Err(7)$" || return 1
    return 0
}

t441_var_div_zero_runtime_panic() {
    # v0.4.95 — variable-divisor zero now panics with clean message
    # (was silent SIGFPE / exit 127).
    # v0.6.53 NUM-021 gap 3 + v0.6.50 gap 4: when the divisor is a
    # const-tracked let-binding (`let z: i64 = 0; let q: i64 = 10 / z;`),
    # the const-fold path catches the div-by-zero at COMPILE time with
    # NUM-021 (strictly better than the v0.4.95 runtime panic — catches
    # earlier). The v0.4.95 runtime path still fires for non-trackable
    # divisors (e.g. read from input). Test updated to verify the new
    # compile-time catch.
    local out
    out=$("$BIN" build "tests/fixtures/repro_v95_var_div_by_zero_runtime_panic.nr" -o "_t441_check" --no-cache 2>&1)
    local rc=$?
    [ "$rc" != "0" ] || return 1
    echo "$out" | grep -q "NUM-021" || return 1
    return 0
}

t_saturating_block_per_op() {
    # Saturating blocks lower add/sub/mul per operation,
    # not as a final i32 clamp after wrapped inner arithmetic.
    "$BIN" build "tests/fixtures/repro_saturating_block_per_op.nr" -o "_sat_block_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "0" ] || return 1
    grep -q "__nucleor_saturating_add_i64" "target/_sat_block_check.ll" || return 1
    grep -q "__nucleor_saturating_sub_i64" "target/_sat_block_check.ll" || return 1
    grep -q "__nucleor_saturating_mul_i64" "target/_sat_block_check.ll" || return 1
    local exe="target/_sat_block_check"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    local out
    out=$("$exe" 2>&1)
    echo "$out" | grep -q "OK saturating block per op" || return 1
    return 0
}

strict_intrin_fixture_overflows() {
    local src="$1"
    local out="$2"
    local needle="$3"
    NUCLEOR_INT_STRICT_INTRIN=1 NUCLEOR_INT_STRICT_ARITH=1 "$BIN" build "$src" -o "$out" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "0" ] || return 1
    grep -q "$needle" "target/${out}.ll" || return 1
    local exe="target/${out}"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1
    local rt_rc=$?
    [ "$rt_rc" != "0" ] || return 1
    return 0
}

t_rfc0006_invariant_ctor_runtime() {
    # v0.4.253 RFC-0006 — invariant emit on constructor exit.
    # A constructor is an impl-block fn whose first param is NOT
    # self AND whose return type matches the parent type (or is
    # Self). At exit, sym["self"] gets bound to the rv before
    # the invariant predicate is lowered, so `self.field` resolves.
    "$BIN" build "tests/features/rfc0006_invariant_ctor.nr" -o "_t_rfc6_ctor" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local exe="target/_t_rfc6_ctor"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    local out
    out=$("$exe" 2>&1)
    [ "$?" = "0" ] || return 1
    echo "$out" | grep -q "OK rfc0006_invariant_ctor" || return 1
    # Negative side: constructor returns a violating instance.
    local tmp_neg="$NUC_VERIFY_TMPDIR/rfc6_ctor_violate.nr"
    printf '%s\n' "struct Counter { value: i64 }" "#[invariant(self.value >= 0)]" "impl Counter { fn bad() -> Counter { Counter { value: 0 - 5 } } }" "fn main() -> i64 { let c: Counter = Counter::bad(); print_int(c.value); 0 }" > "$tmp_neg"
    "$BIN" build "$(verify_bin_path "$tmp_neg")" -o "_t_rfc6_ctor_violate" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local nexe="target/_t_rfc6_ctor_violate"
    [ -x "$nexe.exe" ] && nexe="$nexe.exe"
    [ -x "$nexe" ] || return 1
    local nout
    nout=$("$nexe" 2>&1)
    [ "$?" = "1" ] || return 1
    echo "$nout" | grep -q "CONTRACT-003: invariant violated" || return 1
    return 0
}

t_rfc0006_dbc_mode_runtime() {
    # v0.4.252 RFC-0006 — NUCLEOR_DBC_MODE build-mode strip-out.
    # Builds the same source 3 times under debug / safe-release /
    # release modes and asserts the appropriate contracts fire
    # (or don't).
    local src="$NUC_VERIFY_TMPDIR/rfc6_dbc_mode.nr"
    printf '%s\n' "struct Box { v: i64 }" "#[invariant(self.v >= 0)]" "impl Box { fn get(self: Box) -> i64 { self.v } }" "#[require(x > 0)]" "fn pos(x: i64) -> i64 { x }" "fn main() -> i64 { let b: Box = Box { v: 0 - 5 }; let bv: i64 = b.get(); let p: i64 = pos(0 - 3); print_int(bv + p); 0 }" > "$src"
    # Debug mode (default): invariant fires first.
    Remove_Item="" "$BIN" build "$(verify_bin_path "$src")" -o "_t_rfc6_dbc_debug" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local debug_exe="target/_t_rfc6_dbc_debug"
    [ -x "$debug_exe.exe" ] && debug_exe="$debug_exe.exe"
    local debug_out
    debug_out=$("$debug_exe" 2>&1)
    echo "$debug_out" | grep -q "CONTRACT-003: invariant violated" || return 1
    # Safe-release: invariant elided, require fires.
    nuc_build_with_env "NUCLEOR_DBC_MODE=safe-release" "$src" "_t_rfc6_dbc_sr" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local sr_exe="target/_t_rfc6_dbc_sr"
    [ -x "$sr_exe.exe" ] && sr_exe="$sr_exe.exe"
    local sr_out
    sr_out=$("$sr_exe" 2>&1)
    echo "$sr_out" | grep -q "CONTRACT-001: require precondition violated" || return 1
    # Release: all elided, exits 0 with garbage value.
    nuc_build_with_env "NUCLEOR_DBC_MODE=release" "$src" "_t_rfc6_dbc_rel" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local rel_exe="target/_t_rfc6_dbc_rel"
    [ -x "$rel_exe.exe" ] && rel_exe="$rel_exe.exe"
    local rel_out
    rel_out=$("$rel_exe" 2>&1)
    [ "$?" = "0" ] || return 1
    if echo "$rel_out" | grep -qE "CONTRACT-(001|002|003)"; then return 1; fi
    return 0
}

t_rfc0006_old_expr_runtime() {
    # v0.4.251 RFC-0006 — `old(expr)` snapshot in #[ensure].
    # Builds the basic fixture (3 fns mixing inc/double/clamp
    # with old-references) and asserts exit 0 + OK marker. Then
    # synthesizes a violation (bad_inc returns x+2 not x+1, but
    # ensure says `result == old(x) + 1`) inline and asserts
    # CONTRACT-002 panic.
    "$BIN" build "tests/features/rfc0006_old_expr.nr" -o "_t_rfc6_old" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local exe="target/_t_rfc6_old"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    local out
    out=$("$exe" 2>&1)
    [ "$?" = "0" ] || return 1
    echo "$out" | grep -q "OK rfc0006_old_expr" || return 1
    local tmp_neg="$NUC_VERIFY_TMPDIR/rfc6_old_violate.nr"
    printf '%s\n' "#[ensure(result == old(x) + 1)]" "fn bad_inc(x: i64) -> i64 { x + 2 }" "fn main() -> i64 { let a: i64 = bad_inc(5); print_int(a); 0 }" > "$tmp_neg"
    "$BIN" build "$(verify_bin_path "$tmp_neg")" -o "_t_rfc6_old_violate" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local nexe="target/_t_rfc6_old_violate"
    [ -x "$nexe.exe" ] && nexe="$nexe.exe"
    [ -x "$nexe" ] || return 1
    local nout
    nout=$("$nexe" 2>&1)
    [ "$?" = "1" ] || return 1
    echo "$nout" | grep -q "CONTRACT-002: ensure postcondition violated" || return 1
    return 0
}

t_rfc0007_atomic_bool() {
    # v0.4.281 AtomicBool ordered ops (load/store/CAS) shipped via
    # delegation to AtomicI64 handle. Probe-agent finding 2026-05-01:
    # AtomicBool shipped in v0.4.273 with constructor+drop only.
    "$BIN" build "tests/features/rfc0007_atomic_bool.nr" -o "_t_ab" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local exe="target/_t_ab"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    local out
    out=$("$exe" 2>&1)
    [ "$?" = "0" ] || return 1
    echo "$out" | grep -q "OK rfc0007_atomic_bool" || return 1
    return 0
}

t_atomic_006_in_closure() {
    # v0.4.280 — closure body that calls atomic_* helpers crashed
    # the compiler (probe-agent finding 2026-05-01). ATOMIC-006
    # halts cleanly with a temporary "not yet supported" message
    # until the closure sym-table inheritance ship lands.
    "$BIN" build "tests/err/err_atomic_006_in_closure.nr" -o "_t_a006" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "1" ] || return 1
    grep -q "ATOMIC-006" $NUC_VERIFY_STEP_LOG || return 1
    grep -qv "vec_get OOB" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t_rfc0034_compile_time_params_parser() {
    # RFC-0034 first-pass parser substrate: `fn f<T>[N: usize](...)`
    # parses cleanly while the value-level compile-time params are erased
    # until semantic environments and call-site specialization land.
    "$BIN" build "tests/features/rfc0034_compile_time_params_parser.nr" -o "_t_rfc0034_ctparams" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local exe="target/_t_rfc0034_ctparams"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    local out
    out=$("$exe" 2>&1)
    [ "$?" = "0" ] || return 1
    echo "$out" | grep -q "OK rfc0034_compile_time_params_parser" || return 1
    "$BIN" build "tests/err/err_rfc0034_compile_time_param_missing_colon.nr" -o "_t_rfc0034_ctparams_bad" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "1" ] || return 1
    grep -q "error\\[NR020\\]" $NUC_VERIFY_STEP_LOG || return 1
    "$BIN" build "tests/err/err_rfc0034_compile_time_param_negative_usize_default.nr" -o "_t_rfc0034_ctparams_negative_usize_default" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "1" ] || return 1
    grep -q "error\\[NR020\\]" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t_str_char_at_strict_basic() {
    # v0.4.279 str_char_at_strict — in-bounds reads return same
    # as default str_char_at. Adopter opt-in for bounds-checked
    # access when caller doesn't already enforce bounds.
    "$BIN" build "tests/features/str_char_at_strict_basic.nr" -o "_t_scas" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local exe="target/_t_scas"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    local out
    out=$("$exe" 2>&1)
    [ "$?" = "0" ] || return 1
    echo "$out" | grep -q "OK str_char_at_strict_basic" || return 1
    return 0
}

t_str_char_at_strict_oob() {
    # v0.4.279 str_char_at_strict — OOB index panics. Mirrors
    # str_substring_strict (v0.3.220).
    "$BIN" build "tests/err/err_str_char_at_strict_oob.nr" -o "_t_scas_oob" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local exe="target/_t_scas_oob"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    local out
    out=$("$exe" 2>&1)
    [ "$?" = "1" ] || return 1
    echo "$out" | grep -q "str_char_at_strict OOB" || return 1
    return 0
}

t_match_014_negative_range_bounds() {
    "$BIN" build "tests/err/err_match_range_negative_lower_bound.nr" -o "_t_m014a" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "1" ] || return 1
    grep -q "MATCH-014" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "guard" $NUC_VERIFY_STEP_LOG || return 1
    "$BIN" build "tests/err/err_match_range_negative_upper_bound.nr" -o "_t_m014b" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "1" ] || return 1
    grep -q "MATCH-014" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "guard" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t_str_substring_strict_basic() {
    # v0.6 migration fixture: in-bounds strict substring returns the
    # same slice shape as the fast helper while documenting the safe
    # opt-in path for untrusted bounds.
    "$BIN" build "tests/features/str_substring_strict_basic.nr" -o "_t_sss" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local exe="target/_t_sss"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    local out
    out=$("$exe" 2>&1)
    [ "$?" = "0" ] || return 1
    echo "$out" | grep -q "OK str_substring_strict_basic" || return 1
    return 0
}

t_rfc0006_undefined_ident_reject() {
    # v0.4.283 — undefined ident in #[require] / #[ensure]
    # predicate must reject at compile time. Probe-agent finding
    # 2026-05-01: pre-fix, #[require(undefined_var > 0)] surfaced
    # a misleading clang-link "undefined function `undefined_var()`"
    # error. CONTRACT-011 halts at parse time naming the actual
    # unbound ident.
    "$BIN" build "tests/err/err_contract_undefined_ident.nr" -o "_t_uid" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "1" ] || return 1
    grep -q "CONTRACT-011" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "undefined_var" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t_rfc0006_old_in_require_reject() {
    # v0.4.277 — `old(...)` in `#[require]` must reject at compile
    # time. Probe-agent finding 2026-05-01: pre-fix, the build
    # surfaced a misleading clang-link "undefined function `old()`"
    # error. CONTRACT-010 now halts at compile entry naming the
    # semantic mismatch + the workaround.
    "$BIN" build "tests/err/err_contract_old_in_require.nr" -o "_t_oir" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "1" ] || return 1
    grep -q "CONTRACT-010" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "fn f" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t_match_012_single_line() {
    # v0.4.276 MATCH-012 — probe-agent finding 2026-04-30: dual
    # print+panic emitted the diag text TWICE. Folded into a single
    # panic. Verify MATCH-012 appears in the output, build exits 1,
    # and the count of MATCH-012 mentions on stderr is exactly one
    # (no duplicate from the now-removed print).
    "$BIN" build "tests/err/err_match_012_struct_pattern_literal.nr" -o "_t_m12" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "1" ] || return 1
    local count
    count=$(grep -c "MATCH-012" $NUC_VERIFY_STEP_LOG)
    [ "$count" = "1" ] || return 1
    return 0
}

t_rfc0006_dbc_mode_invalid_reject() {
    # v0.4.275 RFC-0006 — NUCLEOR_DBC_MODE validation. Probe-agent
    # finding 2026-05-01: unrecognized values silently fell into
    # a partial-strip bucket. CONTRACT-009 now halts at compile
    # entry naming the bad value and the recognized set.
    nuc_build_with_env "NUCLEOR_DBC_MODE=off" "tests/err/err_dbc_mode_invalid.nr" "_t_rfc6_dbcmode" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "1" ] || return 1
    grep -q "CONTRACT-009" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "off" $NUC_VERIFY_STEP_LOG || return 1
    # Sanity: a recognized value still builds.
    nuc_build_with_env "NUCLEOR_DBC_MODE=release" "tests/err/err_dbc_mode_invalid.nr" "_t_rfc6_dbcmode_ok" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    return 0
}

t_rfc0006_result_in_void_fn_reject() {
    # v0.4.272 RFC-0006 — `#[ensure(... result ...)]` on a void fn
    # must reject at compile time. Probe-agent finding 2026-05-01:
    # void fn has no return value to bind `result` against; pre-fix
    # the ensure ran against alloca-init garbage with confusing
    # outcomes (result == 0 "passes" by luck; result > 0 panics
    # CONTRACT-002 at runtime).
    "$BIN" build "tests/err/err_contract_result_in_void_fn.nr" -o "_t_rfc6_void" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "1" ] || return 1
    grep -q "CONTRACT-008" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "void_fn" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t_rfc0006_old_vec_aliasing_reject() {
    # v0.4.271 RFC-0006 — `old(<heap-typed-expr>)` must be rejected
    # at compile time. The probe agent (2026-05-01) found that under
    # the i64-everywhere ABI, Vec/String/HashMap/HashSet/BTreeMap/
    # BTreeSet/VecDeque/Box are pointers, so `old(v)` snapshots the
    # POINTER, not the buffer — silent-miscompute on adopter's
    # canonical RFC-0006 ensure pattern. v0.4.271 emits CONTRACT-006
    # at compile time with a halt; the build must fail with the
    # expected diag text.
    "$BIN" build "tests/err/err_contract_old_vec_aliasing.nr" -o "_t_rfc6_old_vec" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local ec="$?"
    [ "$ec" = "1" ] || return 1
    grep -q "CONTRACT-006" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "Vec<i64>" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t_rfc0006_no_check_runtime() {
    # v0.4.258 RFC-0006 — #[no_check] per-fn opt-out.
    # Builds the basic fixture: a fn that has #[no_check] and a
    # #[require(x > 0)] is called with -5 — would normally trip
    # CONTRACT-001 but the marker bypasses the check; another fn
    # has #[no_check] + #[ensure(result >= 100)] returning 7 —
    # would trip CONTRACT-002 but is bypassed. Asserts exit 0.
    # Then synthesizes a violation: same code WITHOUT #[no_check]
    # and asserts CONTRACT-001 fires (proving the marker is what
    # suppressed the check).
    "$BIN" build "tests/features/rfc0006_no_check.nr" -o "_t_rfc6_nochk" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local exe="target/_t_rfc6_nochk"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    local out
    out=$("$exe" 2>&1)
    [ "$?" = "0" ] || return 1
    echo "$out" | grep -q "OK rfc0006_no_check" || return 1
    # Negative side: drop the #[no_check] on the require, prove
    # the contract DOES fire — confirms the marker was load-bearing.
    local tmp_neg="$NUC_VERIFY_TMPDIR/rfc6_nochk_violate.nr"
    printf '%s\n' "#[require(x > 0)]" "fn hot(x: i64) -> i64 { x * 2 }" "fn main() -> i64 { let a: i64 = hot(0 - 5); print_int(a); 0 }" > "$tmp_neg"
    "$BIN" build "$(verify_bin_path "$tmp_neg")" -o "_t_rfc6_nochk_violate" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local nexe="target/_t_rfc6_nochk_violate"
    [ -x "$nexe.exe" ] && nexe="$nexe.exe"
    [ -x "$nexe" ] || return 1
    local nout
    nout=$("$nexe" 2>&1)
    [ "$?" = "1" ] || return 1
    echo "$nout" | grep -q "CONTRACT-001: require precondition violated" || return 1
    return 0
}

t_rfc0006_multi_attrs_runtime() {
    # v0.4.250 RFC-0006 — multiple #[require] / #[ensure] per fn.
    # Builds the basic fixture (3 fns with multi-attrs, all
    # passing) and asserts exit 0 + OK marker. Then synthesizes
    # a violation (second require fails) inline; asserts CONTRACT-001.
    "$BIN" build "tests/features/rfc0006_multi_attrs.nr" -o "_t_rfc6_multi" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local exe="target/_t_rfc6_multi"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    local out
    out=$("$exe" 2>&1)
    [ "$?" = "0" ] || return 1
    echo "$out" | grep -q "OK rfc0006_multi_attrs" || return 1
    local tmp_neg="$NUC_VERIFY_TMPDIR/rfc6_multi_violate.nr"
    printf '%s\n' "#[require(x > 0)]" "#[require(x < 100)]" "fn safe(x: i64) -> i64 { x * 2 }" "fn main() -> i64 { let a: i64 = safe(500); print_int(a); 0 }" > "$tmp_neg"
    "$BIN" build "$(verify_bin_path "$tmp_neg")" -o "_t_rfc6_multi_violate" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local nexe="target/_t_rfc6_multi_violate"
    [ -x "$nexe.exe" ] && nexe="$nexe.exe"
    [ -x "$nexe" ] || return 1
    local nout
    nout=$("$nexe" 2>&1)
    [ "$?" = "1" ] || return 1
    echo "$nout" | grep -q "CONTRACT-001: require precondition violated" || return 1
    return 0
}

t_rfc0006_invariant_runtime() {
    # v0.4.248 RFC-0006 — `#[invariant(EXPR)]` runtime check at
    # impl-method entry. Builds the basic fixture (Counter with
    # value >= 0 invariant; calls .get() and .doubled() on
    # well-formed instances) and asserts exit 0 + OK marker.
    # Then synthesizes a violation (Counter { value: -5 }) inline
    # and asserts CONTRACT-003 panic, exit 1.
    "$BIN" build "tests/features/rfc0006_invariant_basic.nr" -o "_t_rfc6_inv" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local exe="target/_t_rfc6_inv"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    local out
    out=$("$exe" 2>&1)
    [ "$?" = "0" ] || return 1
    echo "$out" | grep -q "OK rfc0006_invariant_basic" || return 1
    local tmp_neg="$NUC_VERIFY_TMPDIR/rfc6_inv_violate.nr"
    printf '%s\n' "struct Counter { value: i64 }" "#[invariant(self.value >= 0)]" "impl Counter { fn get(self: Counter) -> i64 { self.value } }" "fn main() -> i64 { let c: Counter = Counter { value: 0 - 5 }; let v: i64 = c.get(); print_int(v); 0 }" > "$tmp_neg"
    "$BIN" build "$(verify_bin_path "$tmp_neg")" -o "_t_rfc6_inv_violate" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local nexe="target/_t_rfc6_inv_violate"
    [ -x "$nexe.exe" ] && nexe="$nexe.exe"
    [ -x "$nexe" ] || return 1
    local nout
    nout=$("$nexe" 2>&1)
    [ "$?" = "1" ] || return 1
    echo "$nout" | grep -q "CONTRACT-003: invariant violated" || return 1
    return 0
}

t_rfc0006_ensure_midbody_runtime() {
    # v0.4.247 — `#[ensure(EXPR)]` at explicit mid-body return X;
    # sites. Pre-fix, only implicit-tail returns got the check;
    # explicit return mid-body bypassed silently. Locks coverage.
    "$BIN" build "tests/features/rfc0006_ensure_midbody.nr" -o "_t_rfc6_emid" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local exe="target/_t_rfc6_emid"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    local out
    out=$("$exe" 2>&1)
    [ "$?" = "0" ] || return 1
    echo "$out" | grep -q "OK rfc0006_ensure_midbody" || return 1
    # Negative side: ensure violation via mid-body return.
    local tmp_neg="$NUC_VERIFY_TMPDIR/rfc6_emid_violate.nr"
    printf '%s\n' "#[ensure(result >= 0)]" "fn neg_ret(x: i64) -> i64 { if x < 0 { return 0 - 1; }; x }" "fn main() -> i64 { let a: i64 = neg_ret(0 - 5); print_int(a); 0 }" > "$tmp_neg"
    "$BIN" build "$(verify_bin_path "$tmp_neg")" -o "_t_rfc6_emid_violate" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local nexe="target/_t_rfc6_emid_violate"
    [ -x "$nexe.exe" ] && nexe="$nexe.exe"
    [ -x "$nexe" ] || return 1
    local nout
    nout=$("$nexe" 2>&1)
    [ "$?" = "1" ] || return 1
    echo "$nout" | grep -q "CONTRACT-002: ensure postcondition violated" || return 1
    return 0
}

t_rfc0006_ensure_runtime() {
    # v0.4.246 RFC-0006 — `#[ensure(EXPR)]` runtime check.
    # Builds the basic fixture (all returns satisfy their postconditions)
    # and asserts exit 0 + OK marker. Then builds a synthetic violation
    # fixture inline and asserts exit 1 + CONTRACT-002 message.
    "$BIN" build "tests/features/rfc0006_ensure_basic.nr" -o "_t_rfc6_ens" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local exe="target/_t_rfc6_ens"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    local out
    out=$("$exe" 2>&1)
    [ "$?" = "0" ] || return 1
    echo "$out" | grep -q "OK rfc0006_ensure_basic" || return 1
    local tmp_neg="$NUC_VERIFY_TMPDIR/rfc6_ens_violate.nr"
    printf '%s\n' "#[ensure(result > 100)]" "fn small(x: i64) -> i64 { x + 1 }" "fn main() -> i64 { let a: i64 = small(5); print_int(a); 0 }" > "$tmp_neg"
    "$BIN" build "$(verify_bin_path "$tmp_neg")" -o "_t_rfc6_ens_violate" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local nexe="target/_t_rfc6_ens_violate"
    [ -x "$nexe.exe" ] && nexe="$nexe.exe"
    [ -x "$nexe" ] || return 1
    local nout
    nout=$("$nexe" 2>&1)
    local nrc=$?
    [ "$nrc" = "1" ] || return 1
    echo "$nout" | grep -q "CONTRACT-002: ensure postcondition violated" || return 1
    return 0
}

t_rfc0006_require_runtime() {
    # v0.4.245 RFC-0006 Design by Contract — runtime require check.
    # Builds the basic fixture (every call satisfies its precondition)
    # and asserts exit 0 + OK marker. Then builds a synthetic violation
    # fixture inline and asserts exit 1 + CONTRACT-001 panic message.
    "$BIN" build "tests/features/rfc0006_require_basic.nr" -o "_t_rfc6_basic" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local exe="target/_t_rfc6_basic"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    local out
    out=$("$exe" 2>&1)
    [ "$?" = "0" ] || return 1
    echo "$out" | grep -q "OK rfc0006_require_basic" || return 1
    # Negative side: build the same fixture's logic with a violating
    # call. Generated inline so the fixture file itself can stay
    # passing-only.
    local tmp_neg="$NUC_VERIFY_TMPDIR/rfc6_violate.nr"
    printf '%s\n' "#[require(x > 0)]" "fn pos(x: i64) -> i64 { x * 2 }" "fn main() -> i64 { let a: i64 = pos(0 - 5); print_int(a); 0 }" > "$tmp_neg"
    "$BIN" build "$(verify_bin_path "$tmp_neg")" -o "_t_rfc6_violate" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local nexe="target/_t_rfc6_violate"
    [ -x "$nexe.exe" ] && nexe="$nexe.exe"
    [ -x "$nexe" ] || return 1
    local nout
    nout=$("$nexe" 2>&1)
    local nrc=$?
    [ "$nrc" = "1" ] || return 1
    echo "$nout" | grep -q "CONTRACT-001: require precondition violated" || return 1
    return 0
}

t_wrap_block_no_trap() {
    # v0.4.242 — regression gate for v0.4.239's wrap-block fix.
    # Pre-v0.4.239, parse_primary routed `wrapping { ... }` through
    # parse_passthrough_block_expr (no mode flag), so the kind-52
    # mode-1 handler that sets sym["__arith_mode"]=1 never fired.
    # With v0.4.238's NUCLEOR_INT_STRICT_INTRIN=1 default, every
    # `wrapping { a + b }` block emitted the trap path and panicked
    # at runtime on real overflow — the exact opposite of intent.
    # v0.4.239 routed wrapping through parse_wrapped_block_expr(...,1).
    # This gate locks the fix: build overflow_wrapping fixture, run,
    # assert exit 0 + correct wrapped value (i32::MIN as decimal).
    "$BIN" build "tests/features/overflow_wrapping.nr" -o "_t_wrap_block" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local exe="target/_t_wrap_block"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    local rout
    rout=$("$exe" 2>&1)
    local rc=$?
    [ "$rc" = "0" ] || return 1
    # i32::MIN = -2147483648 (the wrapped value of i32::MAX + 1)
    echo "$rout" | grep -qE "(^|[^0-9])-2147483648($|[^0-9])" || return 1
    # Defense in depth: any "PANIC: integer overflow" in output is a
    # regression of the v0.4.239 fix.
    if echo "$rout" | grep -q "PANIC: integer overflow"; then return 1; fi
    return 0
}

t_strict_intrin_narrow_widths() {
    # Track E: strict-intrinsic mode wins over legacy strict helper mode
    # for +/-/*, and emits the concrete LLVM overflow intrinsic matching
    # the signed narrowed width or u64 unsigned ABI width.
    strict_intrin_fixture_overflows "tests/fixtures/strict_intrin_i8_add_overflow.nr" "_strict_intrin_i8_add" "llvm.sadd.with.overflow.i8" || return 1
    strict_intrin_fixture_overflows "tests/fixtures/strict_intrin_i16_sub_overflow.nr" "_strict_intrin_i16_sub" "llvm.ssub.with.overflow.i16" || return 1
    strict_intrin_fixture_overflows "tests/fixtures/strict_intrin_i32_mul_overflow.nr" "_strict_intrin_i32_mul" "llvm.smul.with.overflow.i32" || return 1
    strict_intrin_fixture_overflows "tests/fixtures/strict_intrin_u64_add_overflow.nr" "_strict_intrin_u64_add" "llvm.uadd.with.overflow.i64" || return 1
    strict_intrin_fixture_overflows "tests/fixtures/strict_intrin_u64_sub_overflow.nr" "_strict_intrin_u64_sub" "llvm.usub.with.overflow.i64" || return 1
    strict_intrin_fixture_overflows "tests/fixtures/strict_intrin_u64_mul_overflow.nr" "_strict_intrin_u64_mul" "llvm.umul.with.overflow.i64" || return 1
    NUCLEOR_INT_STRICT_INTRIN=1 NUCLEOR_INT_STRICT_ARITH=1 "$BIN" build "tests/fixtures/strict_intrin_explicit_modes_precedence.nr" -o "_strict_intrin_modes_precedence" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "0" ] || return 1
    grep -q "__nucleor_saturating_add_i64" "target/_strict_intrin_modes_precedence.ll" || return 1
    local exe="target/_strict_intrin_modes_precedence"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1
    [ "$?" = "0" ] || return 1
    return 0
}

t440_str_index_halts() {
    # v0.4.94 TYP-011 — `s[i]` for s:str halts (was silent vec_get
    # on str pointer → OOB panic / garbage).
    "$BIN" build "tests/fixtures/repro_v94_str_index_halts.nr" -o "_t440_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\\[TYP-011\\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "does not support direct indexing" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t439_result_or_else() {
    # v0.4.93 — Result.or_else(f) recovery method.
    "$BIN" build "tests/fixtures/repro_v93_result_or_else.nr" -o "_t439_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "0" ] || return 1
    local exe="target/_t439_check"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    local out
    out=$("$exe" 2>&1)
    echo "$out" | sed -n '1p' | grep -q "^70$" || return 1
    echo "$out" | sed -n '2p' | grep -q "^42$" || return 1
    return 0
}

t438_option_result_fn_arg_methods() {
    # v0.4.92 — Option/Result fn-arg methods (.map/.and_then/.unwrap_or_else).
    "$BIN" build "tests/fixtures/repro_v92_option_result_fn_arg_methods.nr" -o "_t438_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "0" ] || return 1
    local exe="target/_t438_check"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    local out
    out=$("$exe" 2>&1)
    echo "$out" | sed -n '1p' | grep -q "^10$" || return 1
    echo "$out" | sed -n '2p' | grep -q "^99$" || return 1
    echo "$out" | sed -n '3p' | grep -q "^42$" || return 1
    echo "$out" | sed -n '4p' | grep -q "^77$" || return 1
    return 0
}

t437_option_result_method_dispatch() {
    # v0.4.90 CRITICAL — typed Option<T>/Result<T,E> receivers can
    # now call .unwrap/.is_some/.is_none/.unwrap_or/.is_ok/.is_err
    # (was hitting v0.4.53 false panic — these methods were
    # completely unusable v0.4.53..v0.4.89).
    "$BIN" build "tests/fixtures/repro_v90_option_result_method_dispatch.nr" -o "_t437_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "0" ] || return 1
    local exe="target/_t437_check"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    local out
    out=$("$exe" 2>&1)
    echo "$out" | sed -n '1p' | grep -q "^42$" || return 1
    echo "$out" | sed -n '2p' | grep -q "^1$"  || return 1
    echo "$out" | sed -n '3p' | grep -q "^0$"  || return 1
    echo "$out" | sed -n '4p' | grep -q "^10$" || return 1
    echo "$out" | sed -n '5p' | grep -q "^1$"  || return 1
    echo "$out" | sed -n '6p' | grep -q "^0$"  || return 1
    echo "$out" | sed -n '7p' | grep -q "^7$"  || return 1
    echo "$out" | sed -n '8p' | grep -q "^9$"  || return 1
    return 0
}

t442_format_struct_display_debug() {
    # v0.4.91 — user structs no longer silently fall through to
    # int_to_str for bare `{}`. Display routes through impl fmt;
    # Debug derives structural text.
    "$BIN" build "tests/fixtures/repro_v91_format_struct_display.nr" -o "_t438_display" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local exe1="target/_t438_display"
    [ -x "$exe1.exe" ] && exe1="$exe1.exe"
    [ -x "$exe1" ] || return 1
    local out1
    out1=$("$exe1" 2>&1)
    echo "$out1" | tail -1 | grep -q "^Point(3, 4)$" || return 1

    "$BIN" build "tests/fixtures/repro_v91_format_struct_debug.nr" -o "_t438_debug" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" = "0" ] || return 1
    local exe2="target/_t438_debug"
    [ -x "$exe2.exe" ] && exe2="$exe2.exe"
    [ -x "$exe2" ] || return 1
    local out2
    out2=$("$exe2" 2>&1)
    echo "$out2" | tail -1 | grep -q '^Sample { name: "alpha", count: 7, ok: true }$' || return 1

    "$BIN" build "tests/err/err_format_struct_no_display.nr" -o "_t438_err" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\\[FMT-002\\]" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t436_str_more_methods_dispatch() {
    # v0.4.89 — extends v0.4.88 str dispatch to to_lower/to_upper/
    # trim/trim_start/trim_end/substring/char_at (7 more methods,
    # all helpers exist, only dispatch was missing).
    "$BIN" build "tests/fixtures/repro_v89_str_more_methods.nr" -o "_t436_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "0" ] || return 1
    local out
    out=$("target/_t436_check.exe" 2>&1 || "target/_t436_check" 2>&1)
    echo "$out" | head -1 | grep -q "^Hello, World$" || return 1
    echo "$out" | head -2 | tail -1 | grep -q "^HELLO, WORLD$" || return 1
    echo "$out" | head -3 | tail -1 | grep -q "^hello, world$" || return 1
    echo "$out" | head -4 | tail -1 | grep -q "^HELLO$" || return 1
    echo "$out" | head -5 | tail -1 | grep -q "^72$" || return 1
    return 0
}

t435_str_method_dispatch() {
    # v0.4.88 dispatch fix — `s.len()` (and contains/replace/split/
    # starts_with/ends_with) now route to str_* runtime helpers
    # (was vec_len silently reading garbage / vec_contains undef).
    "$BIN" build "tests/fixtures/repro_v88_str_method_dispatch.nr" -o "_t435_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "0" ] || return 1
    local out
    out=$("target/_t435_check.exe" 2>&1 || "target/_t435_check" 2>&1)
    echo "$out" | head -1 | grep -q "^12$" || return 1
    return 0
}

t434_vec_insert_remove_dispatch() {
    # v0.4.87 dispatch-name drift fix — `v.insert(idx, val)` and
    # `v.remove(idx)` now alias to vec_insert_at / vec_remove_at
    # (was `undefined value '@vec_insert'` clang link failure).
    "$BIN" build "tests/fixtures/repro_v87_vec_insert_remove_dispatch.nr" -o "_t434_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "0" ] || return 1
    local out
    out=$("target/_t434_check.exe" 2>&1 || "target/_t434_check" 2>&1)
    echo "$out" | head -1 | grep -q "^1$" || return 1
    echo "$out" | head -2 | tail -1 | grep -q "^99$" || return 1
    echo "$out" | head -3 | tail -1 | grep -q "^1$" || return 1
    echo "$out" | head -4 | tail -1 | grep -q "^2$" || return 1
    return 0
}

t413_eq_typo_guard() {
    "$BIN" build "tests/fixtures/repro_v69_eq_typo_guard.nr" -o "_t413_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "condition position has" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "==" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t412_vec_ord_pointer_guard() {
    # T3.112 (v0.4.68): NUC-FEEDBACK silent-miscompute close for Vec
    # ordering ops <, <=, >, >=. v0.4.61 only caught arith + ==/!=;
    # ordering ops were silently ptr-comparing. v0.4.68 extends.
    "$BIN" build "tests/fixtures/repro_v68_vec_ord_pointer_guard.nr" -o "_t412_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\[TYP-011\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "Vec < Vec" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t411_str_ord_pointer_guard() {
    # T3.111 (v0.4.67): NUC-FEEDBACK silent-miscompute close for str
    # ordering ops <, <=, >, >=. v0.4.52 only caught ==/!=; the
    # ordering ops were silently doing pointer compare. v0.4.67
    # extends to ops 32/33/34/35 with str/str operands.
    "$BIN" build "tests/fixtures/repro_v67_str_ord_pointer_guard.nr" -o "_t411_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\[TYP-011\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "str < str" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "str_cmp" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t410_mixed_str_int_arith_guard() {
    # T3.110 (v0.4.66): NUC-FEEDBACK silent-coerce close for mixed
    # str/int arithmetic. `x += "string"` desugars to `x + "string"`
    # binop. Pre-fix only str+str fired TYP-011; mixed str+int
    # silently i64-added the str pointer to x. v0.4.66 catches arith
    # ops 20-24 with exactly one side being str.
    "$BIN" build "tests/fixtures/repro_v66_mixed_str_int_arith_guard.nr" -o "_t410_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\[TYP-011\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "mixed-type arithmetic" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t409_field_assign_typecheck() {
    # T3.109 (v0.4.65): NUC-FEEDBACK silent-coerce close for struct
    # field assignment. `p.x = "string"` on Point with x: i64 silently
    # stored str ptr as i64. v0.4.65 emits TYP-009 in the kind-21
    # assign handler when LHS is kind-9 (field access).
    "$BIN" build "tests/fixtures/repro_v65_field_assign_typecheck.nr" -o "_t409_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\[TYP-009\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "field assignment type mismatch" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t408_indexed_assign_typecheck() {
    # T3.108 (v0.4.64): NUC-FEEDBACK silent-coerce close for indexed
    # assignment. `v[0] = "string"` on Vec<i64> silently stored the
    # str ptr as i64. v0.4.64 emits TYP-009 in the kind-21 assign
    # handler when LHS is kind-10 indexing on a kind-3 Vec<T> var.
    "$BIN" build "tests/fixtures/repro_v64_indexed_assign_typecheck.nr" -o "_t408_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\[TYP-009\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "indexed assignment type mismatch" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t407_struct_extra_field_guard() {
    # T3.107 (v0.4.63): NUC-FEEDBACK silent-extra-field close.
    # `Point { x: 1, y: 2, z: 3 }` for a 2-field Point silently dropped z.
    # v0.4.63 emits TYP-013 in check_expr's kind-34 with field-name lookup
    # via struct_field_idx.
    "$BIN" build "tests/fixtures/repro_v63_struct_extra_field_guard.nr" -o "_t407_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\[TYP-013\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "unknown field" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "z" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t406_struct_missing_field_guard() {
    # T3.106 (v0.4.62): NUC-FEEDBACK silent-default-zero close.
    # `Point { x: 1, y: 2 }` for a 3-field struct silently defaulted
    # the missing field to 0. v0.4.62 emits TYP-012 in check_expr's
    # kind-34 handler.
    "$BIN" build "tests/fixtures/repro_v62_struct_missing_field_guard.nr" -o "_t406_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\[TYP-012\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "missing field" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "Point" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t405_vec_eq_arith_guard() {
    # T3.105 (v0.4.61): Vec<T> arithmetic and ==/!= silent miscompute
    # close (deferral #1). Source-scan fallback recovers Vec<T> from
    # `let v: Vec<T> = vec![...]` even when tenv stores "" — the path
    # that crashed the compiler in v0.4.55 now ships cleanly.
    "$BIN" build "tests/fixtures/repro_v61_vec_eq_arith_guard.nr" -o "_t405_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\[TYP-011\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "Vec == Vec" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "vec_len" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t404_undefined_fn_warn() {
    # T3.104 (v0.4.60): undefined-fn-call warning at type-check.
    # Closes deferral #2. Filters: __-prefix (closure-gen), uppercase
    # first char (Type-prefixed), and sym_get-existence (fn-pointer
    # var). Severity is warning so MOD-003 cross-module path still
    # takes precedence at link time.
    "$BIN" build "tests/fixtures/repro_v60_undefined_fn_warn.nr" -o "_t404_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -q "warning\[TYP-005\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "undefined function" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "nonexistent_function" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t403_match_expr_exhaustive_guard() {
    # T3.103 (v0.4.59): MATCH-001 now also fires when the match is in
    # expression position (let n = match c { ... };). v0.4.56 only
    # caught match-as-statement; check_expr was missing the kind-38
    # handler. This closes #306.
    "$BIN" build "tests/fixtures/repro_v59_match_expr_exhaustive_guard.nr" -o "_t403_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\[MATCH-001\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "in expression context" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "Workaround" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t402_str_arith_guard() {
    # T3.102 (v0.4.58): NUC-FEEDBACK silent-segfault guard for the
    # other arithmetic ops on str (-, *, /, %). v0.4.51 closed `+`;
    # v0.4.58 extends to the rest with TYP-011 + a clear message.
    "$BIN" build "tests/fixtures/repro_v58_str_arith_guard.nr" -o "_t402_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\[TYP-011\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "str - str" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "str_concat" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t401_match_exhaustive_stmt_guard() {
    # T3.101 (v0.4.56): NUC-FEEDBACK silent-miscompute close —
    # non-exhaustive match (statement form) on enum now halts with
    # MATCH-001 error instead of silently returning 0. Diagnostic
    # severity promoted from "warning" to "error" (the code was
    # already in the error-tier code list).
    "$BIN" build "tests/fixtures/repro_v56_match_exhaustive_stmt_guard.nr" -o "_t401_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\[MATCH-001\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "non-exhaustive match" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "Workaround" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t400_slice_syntax_guard() {
    # T3.100 (v0.4.55): NUC-FEEDBACK silent-segfault guard for slice
    # syntax `expr[lo..hi]`. Pre-fix the parser printed a parse-error
    # line but silently continued, building a broken binary that
    # SIGSEGVed at runtime. v0.4.55 detects the .. / ..= token after
    # the index expression and panics with a str_substring hint.
    "$BIN" build "tests/fixtures/repro_v55_slice_syntax_guard.nr" -o "_t400_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "slice syntax" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "str_substring" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t399_question_on_non_option_guard() {
    # T3.99 (v0.4.54): NUC-FEEDBACK silent-segfault guard for `?` on
    # non-Option/Result receivers. Pre-v0.4.54 `let x: i64 = f()?;`
    # where f returns bare i64 silently SIGSEGVed (?-lower called
    # vec_get on the i64 value). v0.4.54 emits TYP-011 at type-check
    # naming the call + return type and pointing at the workaround.
    "$BIN" build "tests/fixtures/repro_v54_question_on_non_option_guard.nr" -o "_t399_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\[TYP-011\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "operator requires receiver" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "Result<T,E>" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t398_unwrap_on_non_option_guard() {
    # T3.98 (v0.4.53): NUC-FEEDBACK silent-undefined-symbol guard.
    # `x.unwrap()` on a bare i64 (or any non-Option/Result receiver)
    # used to fall through to `vec_unwrap(x)` and fail late at
    # clang link with `undefined value '@vec_unwrap'`. v0.4.53
    # halts the build at the dispatch site with a clear hint.
    "$BIN" build "tests/fixtures/repro_v53_unwrap_on_non_option_guard.nr" -o "_t398_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "Option/Result method" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "vec_unwrap" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "match expr" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t397_str_eq_pointer_guard() {
    # Superseded by v0.6.87: str/String equality is now content equality.
    v0687_str_string_eq_auto_dispatch
}

t396_str_plus_str_guard() {
    # T3.96 (v0.4.51): NUC-FEEDBACK silent-segfault guard for `str + str`.
    # Pre-fix the binop lower emitted i64_add on the two str pointers,
    # producing a garbage pointer that crashed in print_str. v0.4.51
    # emits TYP-011 with a str_concat hint and halts the build.
    "$BIN" build "tests/fixtures/repro_v51_str_plus_str_guard.nr" -o "_t396_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "error\[TYP-011\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "str_concat" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t395_iflet_first_guard() {
    # T3.95 (v0.4.50): NUC-FEEDBACK silent-segfault guard.
    # `if let Some(x) = v.first()` SILENTLY SEGFAULTED pre-v0.4.50
    # because v.first() returns a bare i64 (not Option<T>). The
    # parse-time guard now panics the compiler with a workaround
    # hint pointing at `vec_len(v) > 0`. Mirrored for while-let
    # at parse_while_stmt.
    "$BIN" build "tests/fixtures/repro_v50_iflet_first_guard.nr" -o "_t395_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" = "1" ] || return 1
    grep -q "silently segfaults" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "vec_len" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t394_or_patterns() {
    # T3.94 (v0.4.49): RFC-0023 partial — `A | B | C => body` or-patterns
    # for int literals + wildcards. Pre-v0.4.49 the parser silently
    # miscomputed (printed parse errors but continued, build succeeded,
    # match returned the wildcard arm for every input).
    "$BIN" build "tests/fixtures/repro_v49_or_patterns.nr" -o "_t394_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local exe
    if [ -f "target/_t394_check.exe" ]; then exe="target/_t394_check.exe"; else exe="target/_t394_check"; fi
    [ -f "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    # main returns total = 100+100+200+200+200+0 = 800; bash truncates to 8 bits => 800 mod 256 = 32.
    [ "$rc" = "32" ] || return 1
    grep -qx "800" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t393_vec_get_as_cast_guard() {
    # T3.93 (v0.4.48): NUC-FEEDBACK-002 silent-miscompute guard extended
    # to the fn-call form `vec_get(v, i) as f32` (and vec_first/vec_last/
    # vec_pop). Same hazard + diagnostic + hint as the [i] form.
    "$BIN" build "tests/fixtures/repro_v48_vec_get_as_cast_guard.nr" -o "_t393_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -q "error\[NUM-006\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "vec_get(v, ...)" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "f32_from_bits" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t392_vec_narrow_float_as_cast_guard() {
    # T3.92 (v0.4.47): NUC-FEEDBACK-002 silent-miscompute guard.
    # `v[i] as f32` on a Vec<f32> is a numeric i64→f32 conversion,
    # NOT a bit-reinterpret of the f32 bit pattern stored in the
    # cell. Pre-v0.4.47 the compiler accepted it and the result was
    # garbage (e.g. 1069547520.0_f32 instead of 1.5_f32). v0.4.47
    # emits NUM-006 pointing at the correct surface
    # (f32_from_bits / f16_to_f32 / bf16_to_f32 / etc.).
    "$BIN" build "tests/fixtures/repro_v47_vec_narrow_float_as_cast_guard.nr" -o "_t392_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -q "error\[NUM-006\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "f32_from_bits" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t391_format_debug() {
    # T3.91 (v0.4.41): RFC-0028 phase 5 follow-on — `{:?}` Debug
    # formatter. Strings wrap in quotes ("..."), primitives pass
    # through to Display. The high-value case for adopters is
    # debugging strings.
    "$BIN" build "tests/fixtures/repro_v41_format_debug.nr" -o "_t391_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local exe
    if [ -f "target/_t391_check.exe" ]; then exe="target/_t391_check.exe"; else exe="target/_t391_check"; fi
    [ -f "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    grep -qx '"hello"' $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "42" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "true" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "3.14" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "hello" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t390_format_fill_char() {
    # T3.90 (v0.4.40): RFC-0028 phase 5 — custom fill char `{:*<10}`,
    # `{:->8}`, `{:.<10.3}` etc. The pad helpers accept the fill char
    # directly; this has worked since v0.4.29 but was never pinned.
    # Pinning now to prevent future regression.
    "$BIN" build "tests/fixtures/repro_v40_format_fill_char.nr" -o "_t390_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local exe
    if [ -f "target/_t390_check.exe" ]; then exe="target/_t390_check.exe"; else exe="target/_t390_check"; fi
    [ -f "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    grep -qx "\[42\*\*\*\*\*\*\*\*\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "\[\*\*\*\*\*\*\*\*42\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "\[\*\*\*\*42\*\*\*\*\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "\[hi------\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "\[------hi\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "\[3.142.....\]" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t389_format_sci() {
    # T3.89 (v0.4.38): RFC-0028 phase 5 — `{:e}` / `{:E}` scientific
    # notation for f64. Default 6-digit precision; `{:.Ne}` overrides.
    "$BIN" build "tests/fixtures/repro_v38_format_sci.nr" -o "_t389_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local exe
    if [ -f "target/_t389_check.exe" ]; then exe="target/_t389_check.exe"; else exe="target/_t389_check"; fi
    [ -f "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    grep -qx "3.141593e+00" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "3.141593E+00" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "1.234568e+06" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "1.234000e-06" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "\-1.500000e+00" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "3.142e+00" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "3e+00" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "3.142E+00" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t388_format_hex_upper() {
    # T3.88 (v0.4.37): RFC-0028 phase 5 — `{:X}` upper-case hex.
    # Pre-fix produced same lowercase output as `{:x}`. Now uses
    # __nucleor_int_to_hex_upper.
    "$BIN" build "tests/fixtures/repro_v37_format_hex_upper.nr" -o "_t388_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local exe
    if [ -f "target/_t388_check.exe" ]; then exe="target/_t388_check.exe"; else exe="target/_t388_check"; fi
    [ -f "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    grep -qx "ff" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "FF" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "faf" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "FAF" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "0xFF" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t387_unknown_struct_panic() {
    # T3.87 (v0.4.36): `Foo { x: 1 }` where Foo is undeclared used to
    # lower to `lx_new(-1, blk)` → `%r.-1` invalid IR. Clang caught it
    # but pointed at LLVM, not source. Now panics at compiler level.
    "$BIN" build "tests/fixtures/repro_v36_unknown_struct_panic.nr" -o "_t387_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" -ne 0 ] || return 1
    grep -q "unknown struct UndeclaredStruct" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PANIC: nucleor: unknown struct UndeclaredStruct" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t386_print_multiarg_panic() {
    # T3.86 (v0.4.35): bare `print(a, b)` (multi-arg) printed only the
    # first arg silently — extras dropped from the binary. Now panics.
    # Adopters wanting multi-arg should use print!/println! macros.
    "$BIN" build "tests/fixtures/repro_v35_print_multiarg_panic.nr" -o "_t386_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" -ne 0 ] || return 1
    grep -q "print() takes exactly 1 argument" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PANIC: nucleor: print() takes exactly 1 arg" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t383_let_tuple_destructure_panic() {
    # T3.83 (v0.4.33a): `let (a, b) = ...` used to silently drop
    # bindings. It is now a supported positive path; assert runtime value.
    "$BIN" build "tests/fixtures/repro_v33a_let_tuple_panic.nr" -o "_t383_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local exe
    if [ -x "target/_t383_check" ]; then exe="target/_t383_check"; else exe="target/_t383_check.exe"; fi
    [ -x "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_STEP_LOG.run 2>&1
    [ "$?" -eq 12 ] || return 1
    return 0
}

t384_trait_assoc_const_panic() {
    # T3.84 (v0.4.33b): `const MAX: i64;` in a trait body printed ERROR
    # but the const decl was silently dropped from the trait surface.
    # Now panics. NEGATIVE test.
    "$BIN" build "tests/fixtures/repro_v33b_trait_const_panic.nr" -o "_t384_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" -ne 0 ] || return 1
    grep -q "associated constants in traits are not yet supported" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PANIC: nucleor: associated constants in traits" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t385_impl_assoc_const_panic() {
    # T3.85 (v0.4.33c): `const STEP: i64 = 1;` in an impl body — same
    # silent-drop pattern as the trait body. Now panics. NEGATIVE test.
    "$BIN" build "tests/fixtures/repro_v33c_impl_const_panic.nr" -o "_t385_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" -ne 0 ] || return 1
    grep -q "associated constants in impl blocks are not yet supported" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PANIC: nucleor: associated constants in impl blocks" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t381_closure_mutate_capture_writeback() {
    # T3.81 (v0.4.32a): closure mutating captured outer var used to
    # silently no-op at runtime — closure mutated its local copy and
    # the caller's value stayed unchanged. Now writes back.
    "$BIN" build "tests/fixtures/repro_v32a_closure_mutate_panic.nr" -o "_t381_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local exe
    if [ -x "target/_t381_check" ]; then exe="target/_t381_check"; else exe="target/_t381_check.exe"; fi
    [ -x "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" -eq 5 ] || return 1
    return 0
}

t382_nested_field_assign_panic() {
    # T3.82 (v0.4.32b): `outer.inner.field = X` used to print ERROR but
    # the build succeeded with the assignment DROPPED (return cur).
    # Adopter binary ran with inner field unchanged at runtime. Now panics.
    "$BIN" build "tests/fixtures/repro_v32b_nested_field_panic.nr" -o "_t382_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" -ne 0 ] || return 1
    grep -q "nested struct field assignment is not yet supported" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PANIC: nucleor: nested struct field assignment" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t380_assoc_fn_unsupported_panic() {
    # T3.80 (v0.4.31): unsupported `Type::method(...)` associated-fn
    # used to lower to const_int(0) and continue — silent miscompute,
    # binary returned 0 with no link/runtime failure. Now panics. This
    # fixture is a NEGATIVE test: build must exit non-zero AND log must
    # mention the panic banner.
    "$BIN" build "tests/fixtures/repro_v31_assoc_fn_panic.nr" -o "_t380_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    [ "$rc" -ne 0 ] || return 1
    grep -q "unsupported associated-fn call" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PANIC: nucleor: unsupported associated-fn call" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t379_format_force_sign_spec() {
    # T3.79 (v0.4.30): RFC-0028 phase 5 — `{:+}` force-sign on integers.
    # Pre-v0.4.30 the spec was parsed but emission was deferred (would
    # have double-evaluated arg_expr). Now routes to a runtime helper
    # `int_to_str_force_sign` that takes the arg once.
    "$BIN" build "tests/fixtures/repro_v30_format_force_sign.nr" -o "_t379_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local exe
    if [ -f "target/_t379_check.exe" ]; then exe="target/_t379_check.exe"; else exe="target/_t379_check"; fi
    [ -f "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    grep -qx "+42" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "\-7" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "+0" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "\[   +42\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "\[+42   \]" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t378_format_radix_spec() {
    # T3.78 (v0.4.29): RFC-0028 phase 5 — radix specs (x/X/o/b) +
    # alternate form (#) + combination with width/align/zero-pad.
    # Asserts the canonical cases produced by repro_v29_format_radix.nr.
    # Also pins the deliberate semantic shift: pre-v0.4.29 `:b` printed
    # bool ("true"/"false"); post-v0.4.29 it prints binary radix to match
    # Rust ("1010" for the value 10).
    "$BIN" build "tests/fixtures/repro_v29_format_radix.nr" -o "_t378_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local exe
    if [ -f "target/_t378_check.exe" ]; then exe="target/_t378_check.exe"; else exe="target/_t378_check"; fi
    [ -f "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    grep -qx "ff" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "10" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "1010" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "0xff" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "0o10" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "0b1010" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "\[      ff\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "\[ff      \]" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "\[000000ff\]" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t377_format_width_spec() {
    # T3.77 (v0.4.28): RFC-0028 phase 5 — width / align / zero-pad specs
    # actually pad/align the formatted value. Asserts the canonical
    # cases produced by repro_v28_format_width.nr.
    "$BIN" build "tests/fixtures/repro_v28_format_width.nr" -o "_t377_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local exe
    if [ -f "target/_t377_check.exe" ]; then exe="target/_t377_check.exe"; else exe="target/_t377_check"; fi
    [ -f "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    grep -qx "\[    42\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "\[42    \]" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "\[  42  \]" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "\[00042\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "\[hi      \]" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "\[      hi\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "\[   hi   \]" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "\[     3.142\]" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "\[3.142     \]" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "\[  3.142   \]" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t376_format_precision_spec() {
    # T3.76 (v0.4.27): RFC-0028 phase 5 — `{:.N}` precision spec actually
    # rounds the float instead of being parsed-but-ignored. Pre-fix
    # `println!("{:.3}", 3.14159265)` printed "3.14159" (default %g);
    # post-fix prints "3.142". Asserts a few cases.
    "$BIN" build "tests/fixtures/repro_v27_format_precision.nr" -o "_t376_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local exe
    if [ -f "target/_t376_check.exe" ]; then exe="target/_t376_check.exe"; else exe="target/_t376_check"; fi
    [ -f "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    grep -qx "3.142" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "3" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "3.141593" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "2.72" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "\-1.5000" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t375_v24_silent_miscomputes() {
    # T3.75 (v0.4.24): regression for the 3 silent miscomputes closed in v0.4.24:
    #   1. `1.0f32` literal stored 0 in Vec<f32> (lexer dropped f32 suffix)
    #   2. `-1.5f32` evaluated to -3.0 (binop_float_type missing kind 73)
    #   3. `println!("{:.3}", f64)` printed bit pattern (unknown spec → int_to_str)
    "$BIN" build "tests/fixtures/repro_v24_silent_miscomputes.nr" -o "_t375_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local exe
    if [ -f "target/_t375_check.exe" ]; then exe="target/_t375_check.exe"; else exe="target/_t375_check"; fi
    [ -f "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    grep -qx "PASS f32_lit_1.0" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "PASS f32_lit_2.5" $NUC_VERIFY_STEP_LOG || return 1
    grep -qx "PASS f32_neg_-1.5" $NUC_VERIFY_STEP_LOG || return 1
    # v0.4.27 RFC-0028 phase 5 implements {:.N} precision; was "3.14159".
    grep -qx "spec_check 3.142" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t374_env_get_or() {
    # T3.74 (v0.3.98): regression test for env_get_or runtime helper.
    # Pre-v0.3.98, env_get_or wasn't registered, failing at clang link.
    # Post: returns the default fallback string (len 7 = "default").
    "$BIN" build "tests/fixtures/t374_env_get_or.nr" -o "_t374_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t374_check" ] || [ -x "target/_t374_check.exe" ] || return 1
    local exe
    if [ -x "target/_t374_check" ]; then exe="target/_t374_check"; else exe="target/_t374_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local code=$?
    [ "$code" -eq 7 ] || return 1
    return 0
}

t373_bitwise_op_diagnostic() {
    # T3.73 (v0.3.97 → v0.3.103): originally a negative regression for
    # the bitwise op diagnostic (pre-v0.3.97 `a & b` silently dropped
    # the RHS). v0.3.103 replaced the diag-only stub with real bitwise
    # codegen via a new `parse_bitwise` precedence tier and LLVM xor/and/or
    # ops. The fixture became positive — exits 0 iff all three operators
    # produce correct results across constant-fold and runtime paths.
    # The bash mirror lagged the .ps1 update; v0.3.139 sync.
    "$BIN" build "tests/fixtures/t373_bitwise_op_diagnostic.nr" -o "_t373_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local exe
    if [ -x "target/_t373_check" ]; then exe="target/_t373_check"; else exe="target/_t373_check.exe"; fi
    [ -x "$exe" ] || return 1
    "$exe" >/dev/null 2>&1
    [ "$?" -eq 0 ] || return 1
    return 0
}

t372_mut_closure_capture_diagnostic() {
    # T3.72: mut closure capture writeback. This used to diagnose after
    # v0.3.96 because writeback did not exist; now it must run and return
    # the updated captured total.
    "$BIN" build "tests/fixtures/t372_mut_closure_capture_diagnostic.nr" -o "_t372_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local exe
    if [ -x "target/_t372_check" ]; then exe="target/_t372_check"; else exe="target/_t372_check.exe"; fi
    [ -x "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" -eq 12 ] || return 1
    return 0
}

t371_extended_macro_set() {
    # T3.71 (v0.3.95): regression test for extended macro set
    # (assert_eq!, assert_ne!, todo!, unimplemented!, unreachable!).
    "$BIN" build "tests/fixtures/t371_extended_macro_set.nr" -o "_t371_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t371_check" ] || [ -x "target/_t371_check.exe" ] || return 1
    local exe
    if [ -x "target/_t371_check" ]; then exe="target/_t371_check"; else exe="target/_t371_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local code=$?
    [ "$code" -eq 0 ] || return 1
    return 0
}

t370_panic_assert_macros() {
    # T3.70 (v0.3.94): regression test for panic!/assert!/dbg! macros.
    # Pre-v0.3.94, these failed at clang link (`@panic undefined`,
    # `@assert undefined`) because the macro `!` was parsed as
    # negate-then-parens. Post: textual rewrite drops the `!`.
    "$BIN" build "tests/fixtures/t370_panic_assert_macros.nr" -o "_t370_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t370_check" ] || [ -x "target/_t370_check.exe" ] || return 1
    local exe
    if [ -x "target/_t370_check" ]; then exe="target/_t370_check"; else exe="target/_t370_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local code=$?
    [ "$code" -eq 0 ] || return 1
    return 0
}

t369_mut_ref_param_diagnostic() {
    # T3.69 (v0.3.93): negative regression for &mut T param diagnostic.
    # Pre-v0.3.93, &mut T params silently passed by value so any
    # mutation via *x = ... was a no-op (HIGH-BLAST silent miscompute).
    # v0.3.93: parse_fn_decl emits a clear diagnostic.
    # v0.4.25: ALSO hard-aborts the build via panic when the inner type
    # is a primitive scalar (i8/i16/.../f64/bool/char), so adopters
    # can't ship the silent-miscompute binary. `&mut Struct/Enum` keeps
    # compiling cleanly. Verify gate asserts diagnostic + panic + non-zero rc.
    "$BIN" build "tests/fixtures/t369_mut_ref_param_diagnostic.nr" -o "_t369_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local rc=$?
    grep -q "&mut reference parameter" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "would silently NOT propagate" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PANIC: &mut <scalar> parameter not implemented" $NUC_VERIFY_STEP_LOG || return 1
    [ "$rc" -ne 0 ] || return 1
    return 0
}

t368_dyn_keyword_parse() {
    # T3.68 (v0.3.92/v0.4.117): parser acceptance plus
    # Box<dyn Trait> binding/call-argument coercion from Box<Concrete>.
    "$BIN" build "tests/fixtures/t368_dyn_keyword_parse.nr" -o "_t368_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t368_check" ] || [ -x "target/_t368_check.exe" ] || return 1
    local exe
    if [ -x "target/_t368_check" ]; then exe="target/_t368_check"; else exe="target/_t368_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local code=$?
    [ "$code" -eq 47 ] || return 1
    return 0
}

t367_question_op_chain() {
    # T3.67 (v0.3.91): regression test for the `?` operator chain.
    # Pre-v0.3.91, ir_br_cond labels were swapped — Ok early-returned
    # instead of Err. Every chain after the first ? was dead code.
    "$BIN" build "tests/fixtures/t367_question_op_chain.nr" -o "_t367_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t367_check" ] || [ -x "target/_t367_check.exe" ] || return 1
    local exe
    if [ -x "target/_t367_check" ]; then exe="target/_t367_check"; else exe="target/_t367_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local code=$?
    [ "$code" -eq 100 ] || return 1
    return 0
}

t366_struct_init_shorthand() {
    # T3.66 (v0.3.90): regression test for mixed shorthand struct
    # init `Point { x: 5, y }` (y as shorthand for `y: y`).
    # Pre-v0.3.90, parse_struct_init expected `:` after every field
    # name. Post: shorthand synthesizes a var-ref expr with the same
    # name. Pure-shorthand `Point { x, y }` not yet supported (the
    # parse_primary trigger needs the `IDENT :` shape).
    "$BIN" build "tests/fixtures/t366_struct_init_shorthand.nr" -o "_t366_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t366_check" ] || [ -x "target/_t366_check.exe" ] || return 1
    local exe
    if [ -x "target/_t366_check" ]; then exe="target/_t366_check"; else exe="target/_t366_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local code=$?
    [ "$code" -eq 0 ] || return 1
    return 0
}

t365_trait_generic_method() {
    # T3.65 (v0.3.89): regression test for trait method with generic
    # param. Pre-v0.3.89, `fn count<T>(self)` in trait body cascaded
    # into 22+ parse errors. Post: generic-param shape consumed.
    "$BIN" build "tests/fixtures/t365_trait_generic_method.nr" -o "_t365_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t365_check" ] || [ -x "target/_t365_check.exe" ] || return 1
    local exe
    if [ -x "target/_t365_check" ]; then exe="target/_t365_check"; else exe="target/_t365_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local code=$?
    [ "$code" -eq 3 ] || return 1
    return 0
}

t364_vec_iter_chain() {
    # T3.64 (v0.3.88): regression test for vec.iter().X() chains.
    # Pre-v0.3.88, .iter() was unwired and the chain failed at clang
    # link with `unresolved external symbol __nucleor_vec_iter`.
    # Post: .iter() routes to vec_iter_i64 (identity pass-through).
    "$BIN" build "tests/fixtures/t364_vec_iter_chain.nr" -o "_t364_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t364_check" ] || [ -x "target/_t364_check.exe" ] || return 1
    local exe
    if [ -x "target/_t364_check" ]; then exe="target/_t364_check"; else exe="target/_t364_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local code=$?
    [ "$code" -eq 0 ] || return 1
    return 0
}

t363_struct_like_enum_variant() {
    # T3.63 (v0.3.87): regression test for struct-like enum variant
    # construction `EnumName::Variant { field: val }`. Pre-v0.3.87
    # this failed at clang link with `@r undefined` because the
    # parser treated `{ r: 5 }` as a block expression after the
    # zero-arg variant call. Post: struct-init form parsed and
    # values pushed in source order.
    "$BIN" build "tests/fixtures/t363_struct_like_enum_variant.nr" -o "_t363_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t363_check" ] || [ -x "target/_t363_check.exe" ] || return 1
    local exe
    if [ -x "target/_t363_check" ]; then exe="target/_t363_check"; else exe="target/_t363_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local code=$?
    [ "$code" -eq 0 ] || return 1
    return 0
}

t362_match_multi_capture() {
    # T3.62 (v0.3.86): regression test for multi-capture enum patterns
    # `Variant(a, b, c)`. Pre-v0.3.86, parser only read ONE binding
    # and expected `)`, cascading into parse errors. Post: parses
    # all comma-separated bindings, encodes them as `|`-separated for
    # the existing match_bind_payloads helper.
    "$BIN" build "tests/fixtures/t362_match_multi_capture.nr" -o "_t362_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t362_check" ] || [ -x "target/_t362_check.exe" ] || return 1
    local exe
    if [ -x "target/_t362_check" ]; then exe="target/_t362_check"; else exe="target/_t362_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local code=$?
    [ "$code" -eq 0 ] || return 1
    return 0
}

t361_assoc_const_diagnostic() {
    # T3.61 (v0.3.85 + v0.4.33): negative regression for trait/impl
    # associated constants. Pre-v0.3.85, `const NAME: T;` in trait or
    # impl body cascaded into 18+ parse errors. v0.3.85 added clean
    # diagnostics in both parse_trait_decl and parse_impl_block (kept
    # parsing for multi-error UX). v0.4.33 promoted both to hard panic
    # (was silent fall-through — the const decl was dropped from the
    # surface and the build succeeded). The trait-body site fires
    # first in this fixture, so we now assert the trait diagnostic
    # plus the panic banner. (The impl-body site has its own panic
    # path covered by T3.85.)
    "$BIN" build "tests/fixtures/t361_assoc_const_diagnostic.nr" -o "_t361_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ "$?" -ne 0 ] || return 1
    grep -q "associated constants in traits" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PANIC: nucleor: associated constants in traits" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t360_match_arm_assign() {
    # T3.60 (v0.3.84): regression test for match-arm assignment bodies.
    # Pre-v0.3.84, `pat => x = v,` silently dropped the `= v` and
    # wrapped the LHS as a no-op expr-stmt. Programs compiled but
    # mis-computed.
    "$BIN" build "tests/fixtures/t360_match_arm_assign.nr" -o "_t360_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t360_check" ] || [ -x "target/_t360_check.exe" ] || return 1
    local exe
    if [ -x "target/_t360_check" ]; then exe="target/_t360_check"; else exe="target/_t360_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local code=$?
    [ "$code" -eq 0 ] || return 1
    return 0
}

t359_fn_pointer_type() {
    # T3.59 (v0.3.83): regression test for fn-pointer type syntax
    # `fn(T) -> R` in parameter positions. Pre-v0.3.83, parse_type
    # didn't recognize `fn` as a type-starter and cascaded into 26+
    # parse errors. Post: parsed as i64 (Nucleor fn-ptr ABI).
    "$BIN" build "tests/fixtures/t359_fn_pointer_type.nr" -o "_t359_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t359_check" ] || [ -x "target/_t359_check.exe" ] || return 1
    local exe
    if [ -x "target/_t359_check" ]; then exe="target/_t359_check"; else exe="target/_t359_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local code=$?
    [ "$code" -eq 0 ] || return 1
    return 0
}

t358_trait_default_methods() {
    # T3.58 (v0.3.82): regression test for trait default-method support.
    # Pre-v0.3.82, calling a trait method that the impl didn't override
    # fell through to `vec_<mname>` and failed at clang link with
    # "use of undefined value". Post: synthesized fns from trait
    # defaults dispatch correctly, including Self substitution for
    # nested self.method() calls.
    "$BIN" build "tests/fixtures/t358_trait_default_methods.nr" -o "_t358_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t358_check" ] || [ -x "target/_t358_check.exe" ] || return 1
    local exe
    if [ -x "target/_t358_check" ]; then exe="target/_t358_check"; else exe="target/_t358_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local code=$?
    [ "$code" -eq 0 ] || return 1
    return 0
}

t357_tuple_let_diagnostic() {
    # T3.57 (v0.3.81): negative regression. Typed tuple-let patterns
    # remain unsupported, but must fail as a parser diagnostic, not crash.
    "$BIN" build "tests/fixtures/t357_tuple_let_diagnostic.nr" -o "_t357_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local code=$?
    [ "$code" -ne 139 ] && [ "$code" -ne 134 ] && [ "$code" -ne -1073741819 ] || return 1
    [ "$code" -ne 0 ] || return 1
    grep -q "error\\[NR020\\]" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t355_nested_field_assign_diagnostic() {
    # T3.55 (v0.3.80): negative regression for nested struct field
    # assignment safety net. Pre-v0.3.80, `outer.inner.field = X`
    # segfaulted the compiler with ACCESS_VIOLATION
    # (exit -1073741819). Post: clean diagnostic, no crash.
    "$BIN" build "tests/fixtures/t355_nested_field_assign_diagnostic.nr" -o "_t355_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local code=$?
    # Must NOT crash with access violation:
    [ "$code" -ne 139 ] && [ "$code" -ne 134 ] || return 1
    grep -q "nested struct field assignment is not yet supported" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "Workaround:" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t354_match_arm_return() {
    # T3.54 (v0.3.79): regression test for stmt-style match-arm bodies
    # (`return EXPR`, `break`, `continue`). Pre-v0.3.79, the parser
    # only accepted block `{ stmts }` or single expression as arm body,
    # so `Status::Ok => return 42,` produced cascading parse errors.
    # Pins enum-no-data, enum-with-data, wildcard, all with return arms.
    "$BIN" build "tests/fixtures/t354_match_arm_return.nr" -o "_t354_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t354_check" ] || [ -x "target/_t354_check.exe" ] || return 1
    local exe
    if [ -x "target/_t354_check" ]; then exe="target/_t354_check"; else exe="target/_t354_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local code=$?
    [ "$code" -eq 0 ] || return 1
    return 0
}

t353_inline_closure_capture() {
    # T3.53 (v0.3.78): regression test for inline closure with capture
    # at .map / .filter call sites. Pre-v0.3.78, the textual closure
    # preprocessor hoisted arg-position closures into top-level fns
    # without capture detection, producing cryptic clang link errors
    # like "use of undefined value '@factor'". v0.3.78 routes
    # arg-position closures through the AST kind 42 path (which has
    # full capture support since v0.3.72). Pins five shapes; expected
    # exit 0 (non-zero = which check failed).
    "$BIN" build "tests/fixtures/t353_inline_closure_capture.nr" -o "_t353_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t353_check" ] || [ -x "target/_t353_check.exe" ] || return 1
    local exe
    if [ -x "target/_t353_check" ]; then exe="target/_t353_check"; else exe="target/_t353_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local code=$?
    [ "$code" -eq 0 ] || return 1
    return 0
}

t352_compound_assignment() {
    # T3.52 (v0.3.77): regression test for compound-assignment desugar.
    # Pre-v0.3.77, `x += 5;` lexed as two tokens (+, =) and the parser
    # silently dropped the statement. Post-v0.3.77, lexer emits compound-op
    # tokens (kind 110-114) and parser desugars `LHS op= RHS` to
    # `LHS = LHS op RHS`. Pins all five forms (+=/-=/*=//=/%=) on bare
    # var and struct-field LHS. Expected exit 3.
    "$BIN" build "tests/fixtures/t352_compound_assignment.nr" -o "_t352_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t352_check" ] || [ -x "target/_t352_check.exe" ] || return 1
    local exe
    if [ -x "target/_t352_check" ]; then exe="target/_t352_check"; else exe="target/_t352_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local code=$?
    [ "$code" -eq 3 ] || return 1
    return 0
}

t351_shadowing() {
    # T3.51 (v0.3.76): regression test for shadowing semantics.
    # Pre-v0.3.76, `let x: T = expr_using_x;` after a prior `let x`
    # bound the new slot to `vname` BEFORE lowering the RHS, so the
    # RHS resolved `x` to the new uninitialized alloca and produced
    # garbage. Pins five shapes (same-type / cross-type / sequential
    # / inline-arith / no-old-use). Returns 1+2+4+8+16=31 if every
    # shadow resolves correctly.
    "$BIN" build "tests/fixtures/t351_shadowing.nr" -o "_t351_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t351_check" ] || [ -x "target/_t351_check.exe" ] || return 1
    local exe
    if [ -x "target/_t351_check" ]; then exe="target/_t351_check"; else exe="target/_t351_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local code=$?
    [ "$code" -eq 31 ] || return 1
    return 0
}

t350_module_stmt_keyword_diagnostic() {
    # T3.50 (v0.3.75): negative regression test for module-scope
    # statement-level keywords. Build may succeed (no downstream
    # cascade) but the diagnostic MUST appear in stderr — that's
    # the production-readiness contract.
    "$BIN" build "tests/fixtures/t350_module_stmt_keyword_diagnostic.nr" -o "_t350_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -q "statement-level keyword at module scope" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "Move statement-level constructs into a fn body" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t349_trait_method_vec_index() {
    # T3.49 (v0.3.74): regression test for indexed_element_full_type
    # kind==8 (trait method call) resolution. Pre-v0.3.74, indexing
    # a trait-method-call result inline (`s.samples()[i]`) where the
    # method returns Vec<f64> dispatched to integer add on packed
    # f64 bit patterns. Pins compile + run + value (1.0+2.0+3.0=6).
    "$BIN" build "tests/fixtures/t349_trait_method_vec_index.nr" -o "_t349_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t349_check" ] || [ -x "target/_t349_check.exe" ] || return 1
    local exe
    if [ -x "target/_t349_check" ]; then exe="target/_t349_check"; else exe="target/_t349_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local code=$?
    [ "$code" -eq 6 ] || return 1
    return 0
}

t348_module_let_diagnostic() {
    # T3.48 (v0.3.73): negative regression test for module-scope `let`
    # diagnostic. Pre-v0.3.73, the parser silently dropped `let NAME:T=V;`
    # at module scope and downstream codegen emitted broken @NAME refs.
    # Asserts: (1) the build fails, (2) the diagnostic text mentioning
    # "module scope" + "const" appears in stderr.
    "$BIN" build "tests/fixtures/t348_module_let_diagnostic.nr" -o "_t348_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local code=$?
    [ "$code" -ne 0 ] || return 1
    grep -q "let.* not allowed at module scope" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "Use .const NAME" $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t347_closure_capture() {
    # T3.47 (v0.3.72): regression test for closure-with-capture
    # link-time correctness. Pre-v0.3.72, every closure that
    # captured an outer variable failed at clang link
    # ("unresolved external symbol __nucleor_capture_set/get") --
    # the codegen emitted those calls but the runtime never
    # defined the helpers. v0.3.72 adds the helpers (8192x32
    # capture table). Pins compile + link + run for four shapes:
    # single capture, multi-capture, capture-reused-in-body,
    # multiple distinct closures (slot non-aliasing).
    # Expected exit code 15 (1+2+4+8).
    "$BIN" build "tests/fixtures/t347_closure_capture.nr" -o "_t347_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t347_check" ] || [ -x "target/_t347_check.exe" ] || return 1
    local exe
    if [ -x "target/_t347_check" ]; then exe="target/_t347_check"; else exe="target/_t347_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local code=$?
    [ "$code" -eq 15 ] || return 1
    return 0
}

t346_assoc_fn_collections() {
    # T3.46 (v0.3.71): regression test for Rust-style associated-fn
    # aliases on the lowercase collection helpers. Pre-v0.3.71,
    # `HashMap::new()` etc hit "unhandled expr kind 12" + broken
    # `%r.-1` IR. Pins compile-and-run for the five aliases
    # (HashMap/HashSet/BTreeMap/BTreeSet) plus the lowercase form
    # baseline. Expected exit code 31 (1+2+4+8+16).
    "$BIN" build "tests/fixtures/t346_assoc_fn_collections.nr" -o "_t346_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t346_check" ] || [ -x "target/_t346_check.exe" ] || return 1
    local exe
    if [ -x "target/_t346_check" ]; then exe="target/_t346_check"; else exe="target/_t346_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local code=$?
    [ "$code" -eq 31 ] || return 1
    return 0
}

t345_kalman_synthesis() {
    # T3.45 (v0.3.70): production-coverage lock for the v0.3.65-69
    # nested-composition arc. Builds examples/24_rt_kalman_step.nr
    # which combines 3x3 matrix-vector multiply (nested indexing),
    # Vec<V3> trajectory, struct trait method, and cast inline,
    # then asserts all six output values are mathematically correct.
    "$BIN" build "examples/24_rt_kalman_step.nr" -o "_t345_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t345_check" ] || [ -x "target/_t345_check.exe" ] || return 1
    local exe
    if [ -x "target/_t345_check" ]; then exe="target/_t345_check"; else exe="target/_t345_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE '^5\.0+$'    $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^7\.0+$'    $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^6\.0+$'    $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^25\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^50\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^16\.66[67]' $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t344_method_returning_struct() {
    # T3.44 (v0.3.69): regression test for trait method calls
    # returning structs followed by immediate field access
    # (`v.rotated().x`). Asserts var/fn-call/inline-binop
    # receivers all resolve correctly.
    "$BIN" build "tests/fixtures/t344_method_returning_struct.nr" -o "_t344_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t344_check" ] || [ -x "target/_t344_check.exe" ] || return 1
    local exe
    if [ -x "target/_t344_check" ]; then exe="target/_t344_check"; else exe="target/_t344_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local count_2
    count_2=$(grep -cE '^2\.0+$' $NUC_VERIFY_STEP_LOG)
    [ "$count_2" = "2" ] || return 1
    grep -qE '^5\.0+$' $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t343_nested_indexing() {
    # T3.43 (v0.3.68): regression test for nested indexing
    # (`grid[i][j]`) inline f64 binops. Closes the kind 10
    # operand cell of the composition matrix in BOTH resolvers.
    "$BIN" build "tests/fixtures/t343_nested_indexing.nr" -o "_t343_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t343_check" ] || [ -x "target/_t343_check.exe" ] || return 1
    local exe
    if [ -x "target/_t343_check" ]; then exe="target/_t343_check"; else exe="target/_t343_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE '^1\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^5\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^6\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^3\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t342_fncall_indexing() {
    # T3.42 (v0.3.67): regression test for indexing on fn-call
    # result inside inline f64 binops. Asserts:
    #   make_vec()[0] + make_vec()[1] = 7
    #   make_vec()[0] * make_vec()[2] = 15
    #   make_vstruct()[0].x + make_vstruct()[1].y = 5 (cross-resolver)
    "$BIN" build "tests/fixtures/t342_fncall_indexing.nr" -o "_t342_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t342_check" ] || [ -x "target/_t342_check.exe" ] || return 1
    local exe
    if [ -x "target/_t342_check" ]; then exe="target/_t342_check"; else exe="target/_t342_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE '^7\.0+$'    $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^15\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^5\.0+$'    $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t341_method_on_indexed_field() {
    # T3.41 (v0.3.66): regression test for method calls on
    # indexed struct field receivers (`p.rects[0].area()`).
    # Mirrors v0.3.65 in expr_struct_type. Asserts both
    # method × scalar and method × method patterns compute.
    "$BIN" build "tests/fixtures/t341_method_on_indexed_field.nr" -o "_t341_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t341_check" ] || [ -x "target/_t341_check.exe" ] || return 1
    local exe
    if [ -x "target/_t341_check" ]; then exe="target/_t341_check"; else exe="target/_t341_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE '^6\.0+$'    $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^22\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t340_nested_index_field() {
    # T3.40 (v0.3.65): regression test for nested-operand
    # indexing -- self.samples[i] (Vec/array indexing on a struct
    # field) inside inline f64 binops. Asserts trait method bodies
    # compute correctly for both Vec<f64> and [f64;N] fields.
    "$BIN" build "tests/fixtures/t340_nested_index_field.nr" -o "_t340_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t340_check" ] || [ -x "target/_t340_check.exe" ] || return 1
    local exe
    if [ -x "target/_t340_check" ]; then exe="target/_t340_check"; else exe="target/_t340_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE '^4\.0+$'    $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^2\.50+$'   $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t339_sensor_fusion_synthesis() {
    # T3.39 (v0.3.64): production-coverage lock for the v0.3.51 →
    # v0.3.63 codegen-fix arc. Builds examples/23_rt_sensor_fusion.nr
    # which combines ALL the operand kinds the arc covered (Vec<f64>,
    # [f64; N], struct fields, trait methods, fn-call results,
    # as-casts) and asserts the four output values are
    # mathematically correct. Catches any regression that breaks
    # the cross-shape composition.
    "$BIN" build "examples/23_rt_sensor_fusion.nr" -o "_t339_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t339_check" ] || [ -x "target/_t339_check.exe" ] || return 1
    local exe
    if [ -x "target/_t339_check" ]; then exe="target/_t339_check"; else exe="target/_t339_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE '^25\.0+$'      $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^3\.50+$'      $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^0\.60+$'      $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^4\.66[67]'    $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t338_fixed_array_of_struct() {
    # T3.38 (v0.3.63): regression test for fixed-array-of-struct
    # field access (`arr[0].x` where arr: [V; N]). Mirrors v0.3.59
    # for Vec<struct>. Asserts three patterns compile + compute.
    "$BIN" build "tests/fixtures/t338_fixed_array_of_struct.nr" -o "_t338_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t338_check" ] || [ -x "target/_t338_check.exe" ] || return 1
    local exe
    if [ -x "target/_t338_check" ]; then exe="target/_t338_check"; else exe="target/_t338_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE '^1\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^5\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^6\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t337_fixed_array_fp_ops() {
    # T3.37 (v0.3.62): regression test for fixed-size array
    # indexing in inline f64 binops, fixed by extending the
    # kind==10 branch in binop_float_type to also handle
    # `[T; N]` (not just `Vec<T>`).
    "$BIN" build "tests/fixtures/t337_fixed_array_fp_ops.nr" -o "_t337_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t337_check" ] || [ -x "target/_t337_check.exe" ] || return 1
    local exe
    if [ -x "target/_t337_check" ]; then exe="target/_t337_check"; else exe="target/_t337_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE '^5\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^-3\.0+$'  $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^4\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^2\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^20\.0+$'  $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t336_cast_fp_ops() {
    # T3.36 (v0.3.61): regression test for as-cast-result-in-
    # binop codegen, fixed by adding kind==99 branch to
    # binop_float_type. Asserts five cast-mixed forms compute
    # correctly:
    #   (i as f64) * 2.0          = 8    (cast × literal)
    #   (i as f64) + f            = 7    (cast × var)
    #   (i as f64) + (m() as f64) = 11   (cast × cast different)
    #   (i as f64) * make_two()   = 8    (cast × fn-call)
    #   (m() as f64) + (m() as f64) = 14 (cast × cast same — original bug)
    "$BIN" build "tests/fixtures/t336_cast_fp_ops.nr" -o "_t336_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t336_check" ] || [ -x "target/_t336_check.exe" ] || return 1
    local exe
    if [ -x "target/_t336_check" ]; then exe="target/_t336_check"; else exe="target/_t336_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local count_8
    count_8=$(grep -cE '^8\.0+$' $NUC_VERIFY_STEP_LOG)
    [ "$count_8" = "2" ] || return 1
    grep -qE '^7\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^11\.0+$'  $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^14\.0+$'  $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t335_trait_method_fp_ops() {
    # T3.35 (v0.3.60): regression test for trait-method-result-in-
    # binop codegen, fixed by extending binop_float_type with
    # kind==8 (method call) branch + populating fn_decls with
    # trait-impl mangled methods. Asserts r.area() composes
    # correctly inline:
    #   r1.area() + r2.area()   = 22.0
    #   r1.area() * 2.0         = 24.0
    #   r1.area() * r2.area()   = 120.0
    "$BIN" build "tests/fixtures/t335_trait_method_fp_ops.nr" -o "_t335_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t335_check" ] || [ -x "target/_t335_check.exe" ] || return 1
    local exe
    if [ -x "target/_t335_check" ]; then exe="target/_t335_check"; else exe="target/_t335_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE '^22\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^24\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^120\.0+$'  $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t334_vec_of_struct_field() {
    # T3.34 (v0.3.59): regression test for Vec-of-struct
    # field-access codegen, fixed by adding kind==10 branch
    # to expr_struct_type. Asserts path[i].x patterns compile
    # AND compute correctly.
    "$BIN" build "tests/fixtures/t334_vec_of_struct_field.nr" -o "_t334_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t334_check" ] || [ -x "target/_t334_check.exe" ] || return 1
    local exe
    if [ -x "target/_t334_check" ]; then exe="target/_t334_check"; else exe="target/_t334_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE '^1\.0+$' $NUC_VERIFY_STEP_LOG || return 1
    local count
    count=$(grep -cE '^6\.0+$' $NUC_VERIFY_STEP_LOG)
    [ "$count" = "2" ] || return 1
    return 0
}

t333_chained_field_on_fn_call() {
    # T3.33 (v0.3.58): regression test for chained field access
    # on fn-call result, fixed by adding kind==7 branch to
    # expr_struct_type. Asserts builder/factory pattern
    # `make_v().x + make_v().y` compiles AND computes correctly.
    "$BIN" build "tests/fixtures/t333_chained_field_on_fn_call.nr" -o "_t333_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t333_check" ] || [ -x "target/_t333_check.exe" ] || return 1
    local exe
    if [ -x "target/_t333_check" ]; then exe="target/_t333_check"; else exe="target/_t333_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local count
    count=$(grep -cE '^4\.0+$' $NUC_VERIFY_STEP_LOG)
    [ "$count" = "2" ] || return 1
    grep -qE '^3\.50+$' $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t332_unary_minus_f64() {
    # T3.32 (v0.3.57): regression test for the f64 unary-minus
    # codegen bug fixed in v0.3.57. Asserts -x on the four
    # operand kinds produces correct values:
    #   var: -3   field: -3   vec[i]: -2.5   fn-call: -5
    "$BIN" build "tests/fixtures/t332_unary_minus_f64.nr" -o "_t332_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t332_check" ] || [ -x "target/_t332_check.exe" ] || return 1
    local exe
    if [ -x "target/_t332_check" ]; then exe="target/_t332_check"; else exe="target/_t332_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    local count
    count=$(grep -cE '^-3\.0+$' $NUC_VERIFY_STEP_LOG)
    [ "$count" = "2" ] || return 1
    grep -qE '^-2\.50+$' $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^-5\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t331_mixed_fp_ops() {
    # T3.31 (v0.3.56): production-coverage lock for f64 inline
    # binops with MIXED operand kinds. Asserts five cross-kind
    # ops compute correctly post v0.3.53/54/55:
    #   field × fn-call → 3    (cast) × field  → 21
    #   field × vec[i]  → 6    (cast) × vec[i] → 20
    #   fn-call × vec[i] → 5
    "$BIN" build "tests/fixtures/t331_mixed_fp_ops.nr" -o "_t331_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t331_check" ] || [ -x "target/_t331_check.exe" ] || return 1
    local exe
    if [ -x "target/_t331_check" ]; then exe="target/_t331_check"; else exe="target/_t331_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE '^3\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^6\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^5\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^21\.0+$'  $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^20\.0+$'  $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t330_vec_index_fp_ops() {
    # T3.30 (v0.3.55): regression test for the f64 inline
    # binop-on-Vec-indexing codegen bug fixed in v0.3.55.
    # Asserts five ops on Vec<f64>[i] produce correct values:
    #   add: 1+4=5    sub: 1-4=-3   mul: 1*4=4   div: 8/4=2
    #   nested: v[0]*v[1] + v[2]*v[5] + v[4]*v[6] = 32
    "$BIN" build "tests/fixtures/t330_vec_index_fp_ops.nr" -o "_t330_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t330_check" ] || [ -x "target/_t330_check.exe" ] || return 1
    local exe
    if [ -x "target/_t330_check" ]; then exe="target/_t330_check"; else exe="target/_t330_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE '^5\.0+$'    $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^-3\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^4\.0+$'    $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^2\.0+$'    $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^32\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    return 0
}

t329_fn_call_fp_ops() {
    # T3.29 (v0.3.54): regression test for the f64 inline
    # binop-on-fn-call codegen bug fixed in v0.3.54.
    # Asserts five ops on fn-call results compute correctly:
    #   add: 1+4=5    sub: 1-4=-3   mul: 1*4=4   div: 8/4=2
    #   nested: 1*4 + 2*5 + 3*6 = 32
    "$BIN" build "tests/fixtures/t329_fn_call_fp_ops.nr" -o "_t329_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t329_check" ] || [ -x "target/_t329_check.exe" ] || return 1
    local exe
    if [ -x "target/_t329_check" ]; then exe="target/_t329_check"; else exe="target/_t329_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE '^5\.0+$'    $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^-3\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^4\.0+$'    $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^2\.0+$'    $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^32\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
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
    "$BIN" build "tests/fixtures/t328_struct_field_fp_ops.nr" -o "_t328_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t328_check" ] || [ -x "target/_t328_check.exe" ] || return 1
    local exe
    if [ -x "target/_t328_check" ]; then exe="target/_t328_check"; else exe="target/_t328_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE '^5\.0+$'    $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^-3\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^4\.0+$'    $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^2\.0+$'    $NUC_VERIFY_STEP_LOG || return 1
    grep -qE '^32\.0+$'   $NUC_VERIFY_STEP_LOG || return 1
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
    "$BIN" build "examples/22_rt_export.nr" -o "_t327_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    [ -x "target/_t327_check" ] || [ -x "target/_t327_check.exe" ] || return 1
    local exe
    if [ -x "target/_t327_check" ]; then exe="target/_t327_check"; else exe="target/_t327_check.exe"; fi
    "$exe" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE '32\.0+' $NUC_VERIFY_STEP_LOG || return 1
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
    "$BIN" build "tests/fixtures/t320_diag001_unknown_code.nr" -o "_t320_diag001_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local count
    count=$(grep -cE 'warning\[DIAG-001\]' $NUC_VERIFY_STEP_LOG)
    [ "$count" = "5" ] || return 1
    grep -qE "'WAT-001'"      $NUC_VERIFY_STEP_LOG || return 1
    grep -qE "'BOGUS-002'"    $NUC_VERIFY_STEP_LOG || return 1
    grep -qE "'GIBBERISH-003'" $NUC_VERIFY_STEP_LOG || return 1
    grep -qE "'NONSENSE-004'" $NUC_VERIFY_STEP_LOG || return 1
    grep -qE "'RT-099'"       $NUC_VERIFY_STEP_LOG || return 1
    # Control: RT-007 must NOT trigger DIAG-001.
    if grep -qE "'RT-007'" $NUC_VERIFY_STEP_LOG; then return 1; fi
    # v0.3.46 shape-prefix assertions. Each pairing locks the
    # diag's attribute-shape body text against the offending
    # code, so a future swap (e.g., file-wide emitting per-fn
    # text) is caught.
    grep -qE "'WAT-001' in #\[allow\(\.\.\.\)\]"           $NUC_VERIFY_STEP_LOG || return 1
    grep -qE "'BOGUS-002' in #\[deny\(\.\.\.\)\]"          $NUC_VERIFY_STEP_LOG || return 1
    grep -qE "'GIBBERISH-003' in #\[allow_fn\(\.\.\.\)\] on fn 'first_unknown'"     $NUC_VERIFY_STEP_LOG || return 1
    grep -qE "'NONSENSE-004' in #\[deny_fn\(\.\.\.\)\] on fn 'second_unknown'"      $NUC_VERIFY_STEP_LOG || return 1
    grep -qE "'RT-099' in #\[allow_fn\(\.\.\.\)\] on fn 'within_series_typo'"       $NUC_VERIFY_STEP_LOG || return 1
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
    "$BIN" build "tests/err/err_t323_allow_fn_no_error_suppress.nr" -o "_t323_strict_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE 'error\[RT-001\]' $NUC_VERIFY_STEP_LOG || return 1
    if grep -qE 'warning\[RT-001\]' $NUC_VERIFY_STEP_LOG; then return 1; fi
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
    "$BIN" build "tests/err/err_t321_deny_fn.nr" -o "_t321_strict_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE 'error\[RT-007\]' $NUC_VERIFY_STEP_LOG || return 1
    if grep -qE 'warning\[RT-007\]' $NUC_VERIFY_STEP_LOG; then return 1; fi
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
    "$BIN" build "tests/fixtures/t317_allow_fn_rt004.nr" -o "_t317_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE 'warning\[RT-004\]' $NUC_VERIFY_STEP_LOG || return 1
    local count
    count=$(grep -cE 'warning\[RT-004\]' $NUC_VERIFY_STEP_LOG)
    [ "$count" = "1" ] || return 1
}

t320_allow_fn_per_fn() {
    # T3.12 (v0.3.20): per-fn #[allow_fn(CODE)] suppresses
    # one diagnostic for the next fn declaration only. The
    # fixture has two #[deadline]-marked fns that would each
    # fire RT-007; only the second has #[allow_fn(RT-007)],
    # so RT-007 should mention unguarded_one but NOT
    # unguarded_two.
    "$BIN" build "tests/fixtures/t320_allow_fn.nr" -o "_t320_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE 'warning\[RT-007\]' $NUC_VERIFY_STEP_LOG || return 1
    # Inner-fn name carries a content-hash; we can't grep for
    # the user-facing wrapper directly. Assert exactly ONE
    # RT-007 warning fired (file-wide allow would suppress
    # both; per-fn must suppress only one).
    local count
    count=$(grep -cE 'warning\[RT-007\]' $NUC_VERIFY_STEP_LOG)
    [ "$count" = "1" ] || return 1
}

t38_rt006_async_attr() {
    # T3.8 (v0.3.7): #[no_alloc] / #[no_panic] / #[no_dyn] /
    # #[deadline] on an `async fn` is rejected with RT-006
    # because async cannot honor any RT contract. Negative
    # fixtures err_rt006_async_no_alloc.nr +
    # err_rt006_async_deadline.nr cover both spellings; this
    # step asserts the no_alloc variant fires the exact text.
    "$BIN" build "tests/err/err_rt006_async_no_alloc.nr" -o "_t38_rt006_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE 'error\[RT-006\]: RT attribute' $NUC_VERIFY_STEP_LOG || return 1
    grep -q "on async fn 'poll_loop'" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "async is non-deterministic" $NUC_VERIFY_STEP_LOG || return 1
}

t37_rt_string_skip() {
    # T3.7 (v0.3.6): RT-001/002/003 v1 checkers strip `"..."`
    # string literals + `// ...` line comments before scanning,
    # so a forbidden name appearing inside a quoted/commented
    # region no longer false-triggers. Three #[no_alloc/panic/dyn]
    # fns that contain forbidden tokens ONLY in stripped regions
    # + 3 #[test] cases that PASS prove the strip pass works.
    "$BIN" test "tests/smoke/t37_rt_string_skip.nr" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -q "PASS: test_alloc_name_in_string_compiles" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_panic_name_in_comment_compiles" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_dyn_token_in_string_compiles" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "test result: PASS (3 tests)" $NUC_VERIFY_STEP_LOG || return 1
}

t32_no_panic_clean() {
    "$BIN" test "tests/smoke/t32_no_panic_clean.nr" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -q "PASS: test_no_panic_pure_arithmetic" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_no_panic_loop_with_arithmetic" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "test result: PASS (2 tests)" $NUC_VERIFY_STEP_LOG || return 1
}

v030_deadline_pass() {
    "$BIN" test "tests/smoke/v030_deadline_runtime.nr" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -q "PASS: test_deadline_pass_simple_add" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_deadline_pass_simple_mul" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_deadline_pass_no_args" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_deadline_pass_with_loop" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "test result: PASS (4 tests)" $NUC_VERIFY_STEP_LOG || return 1
}

v030_deadline_overrun() {
    rm -f target/v030_overrun_check.exe target/v030_overrun_check
    "$BIN" build tests/fixtures/v030_deadline_overrun.nr -o "v030_overrun_check" >$NUC_VERIFY_STEP_LOG 2>&1
    local exe=""
    if [ -x target/v030_overrun_check.exe ]; then exe=target/v030_overrun_check.exe; fi
    if [ -z "$exe" ] && [ -x target/v030_overrun_check ]; then exe=target/v030_overrun_check; fi
    [ -n "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1
    local rc=$?
    [ "$rc" -ne 0 ] || return 1
    grep -qE 'error\[RT-004\]: #\[deadline\] overrun' $NUC_VERIFY_RUN_LOG || return 1
}

# v0.5.10: probe-agent finding 2026-05-01-i32-min-div-neg-one-windows-exception.
# Pre-fix `i32::MIN / -1` surfaced as Windows STATUS_INTEGER_OVERFLOW
# (rc=-1073741675) — opaque process exit, no Nucleor-side message.
# Post-fix the narrow-arith path routes through `__nucleor_panic_div_i32`
# which catches the corner with a clean PANIC. Asserts non-zero rc
# (specifically NOT the Windows exception code) AND the expected stderr.
# v0.6.33: probe finding 2026-05-02-result-option-unwrap-diag-and-
# correctness-gaps. Two regression-locks:
#   gap 1 — Option::None.unwrap() panics with the canonical Rust
#           message instead of leaking the internal Vec OOB diag.
#   gap 2 — Result::Err(x).unwrap() panics with the canonical Rust
#           message instead of silently leaking the err payload as
#           if it were the ok payload (CRITICAL pre-fix bug).
v0634_result_unwrap_err_basic() {
    rm -f target/v0634_uerr_basic.exe target/v0634_uerr_basic
    "$BIN" build tests/fixtures/result_unwrap_err_basic.nr -o "v0634_uerr_basic" >$NUC_VERIFY_STEP_LOG 2>&1
    local exe=""
    if [ -x target/v0634_uerr_basic.exe ]; then exe=target/v0634_uerr_basic.exe; fi
    if [ -z "$exe" ] && [ -x target/v0634_uerr_basic ]; then exe=target/v0634_uerr_basic; fi
    [ -n "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1
    local rc=$?
    [ "$rc" -eq 0 ] || return 1
    grep -qE '^oops$' $NUC_VERIFY_RUN_LOG || return 1
}

v0634_result_unwrap_err_on_ok_panics() {
    rm -f target/v0634_uerr_panic.exe target/v0634_uerr_panic
    "$BIN" build tests/fixtures/result_unwrap_err_on_ok_panics.nr -o "v0634_uerr_panic" >$NUC_VERIFY_STEP_LOG 2>&1
    local exe=""
    if [ -x target/v0634_uerr_panic.exe ]; then exe=target/v0634_uerr_panic.exe; fi
    if [ -z "$exe" ] && [ -x target/v0634_uerr_panic ]; then exe=target/v0634_uerr_panic; fi
    [ -n "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1
    local rc=$?
    [ "$rc" -ne 0 ] || return 1
    grep -qE "called .Result::unwrap_err\(\). on an .Ok. value" $NUC_VERIFY_RUN_LOG || return 1
}

v0643_unary_neg_min_panics() {
    rm -f target/v0643_neg_check.exe target/v0643_neg_check
    "$BIN" build tests/fixtures/v0643_unary_neg_min_panics.nr -o "v0643_neg_check" >$NUC_VERIFY_STEP_LOG 2>&1
    local exe=""
    if [ -x target/v0643_neg_check.exe ]; then exe=target/v0643_neg_check.exe; fi
    if [ -z "$exe" ] && [ -x target/v0643_neg_check ]; then exe=target/v0643_neg_check; fi
    [ -n "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1
    local rc=$?
    [ "$rc" -ne 0 ] || return 1
    grep -qE "i64 neg overflow" $NUC_VERIFY_RUN_LOG || return 1
}

v0648_str_helper_amp_accepted() {
    rm -f target/v0648_amp_check.exe target/v0648_amp_check
    "$BIN" build tests/fixtures/v0648_str_helper_amp_accepted.nr -o "v0648_amp_check" >$NUC_VERIFY_STEP_LOG 2>&1
    local exe=""
    if [ -x target/v0648_amp_check.exe ]; then exe=target/v0648_amp_check.exe; fi
    if [ -z "$exe" ] && [ -x target/v0648_amp_check ]; then exe=target/v0648_amp_check; fi
    [ -n "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1
    local rc=$?
    [ "$rc" -eq 0 ] || return 1
    grep -qE "^5$" $NUC_VERIFY_RUN_LOG || return 1
    grep -qE "^hello world$" $NUC_VERIFY_RUN_LOG || return 1
    grep -qE "^ell$" $NUC_VERIFY_RUN_LOG || return 1
}

v0649_imin_literal_accepts() {
    rm -f target/v0649_imin_check.exe target/v0649_imin_check
    "$BIN" build tests/fixtures/v0649_imin_literal_accepts.nr -o "v0649_imin_check" >$NUC_VERIFY_STEP_LOG 2>&1
    local exe=""
    if [ -x target/v0649_imin_check.exe ]; then exe=target/v0649_imin_check.exe; fi
    if [ -z "$exe" ] && [ -x target/v0649_imin_check ]; then exe=target/v0649_imin_check; fi
    [ -n "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1
    local rc=$?
    [ "$rc" -eq 0 ] || return 1
    grep -qE "^-9223372036854775808$" $NUC_VERIFY_RUN_LOG || return 1
    grep -qE "^-9223372036854775807$" $NUC_VERIFY_RUN_LOG || return 1
}

v0652_neg_zero_ieee_sign() {
    rm -f target/v0652_negz_check.exe target/v0652_negz_check
    "$BIN" build tests/fixtures/v0652_neg_zero_ieee_sign.nr -o "v0652_negz_check" >$NUC_VERIFY_STEP_LOG 2>&1
    local exe=""
    if [ -x target/v0652_negz_check.exe ]; then exe=target/v0652_negz_check.exe; fi
    if [ -z "$exe" ] && [ -x target/v0652_negz_check ]; then exe=target/v0652_negz_check; fi
    [ -n "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1
    local rc=$?
    [ "$rc" -eq 0 ] || return 1
    grep -qE "^-inf$" $NUC_VERIFY_RUN_LOG || return 1
    grep -qE "^-5\.000000$" $NUC_VERIFY_RUN_LOG || return 1
    grep -qE "^-3\.000000$" $NUC_VERIFY_RUN_LOG || return 1
}

v0656_unreachable_macro_panics() {
    rm -f target/v0656_unreach_check.exe target/v0656_unreach_check
    "$BIN" build tests/fixtures/v0656_unreachable_macro_panics.nr -o "v0656_unreach_check" >$NUC_VERIFY_STEP_LOG 2>&1
    local exe=""
    if [ -x target/v0656_unreach_check.exe ]; then exe=target/v0656_unreach_check.exe; fi
    if [ -z "$exe" ] && [ -x target/v0656_unreach_check ]; then exe=target/v0656_unreach_check; fi
    [ -n "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1
    local rc=$?
    [ "$rc" -ne 0 ] || return 1
    grep -qE "internal error: entered unreachable code" $NUC_VERIFY_RUN_LOG || return 1
}

v0666_char_literal_typed() {
    rm -f target/v0666_char_check.exe target/v0666_char_check
    "$BIN" build tests/fixtures/v0666_char_literal_typed.nr -o "v0666_char_check" >$NUC_VERIFY_STEP_LOG 2>&1
    local exe=""
    if [ -x target/v0666_char_check.exe ]; then exe=target/v0666_char_check.exe; fi
    if [ -z "$exe" ] && [ -x target/v0666_char_check ]; then exe=target/v0666_char_check; fi
    [ -n "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1
    local rc=$?
    [ "$rc" -eq 0 ] || return 1
    grep -qE "^97$" $NUC_VERIFY_RUN_LOG || return 1
    grep -qE "^10$" $NUC_VERIFY_RUN_LOG || return 1
}

v0667_type_alias_resolves() {
    rm -f target/v0667_alias_check.exe target/v0667_alias_check
    "$BIN" build tests/fixtures/v0667_type_alias_resolves.nr -o "v0667_alias_check" >$NUC_VERIFY_STEP_LOG 2>&1
    local exe=""
    if [ -x target/v0667_alias_check.exe ]; then exe=target/v0667_alias_check.exe; fi
    if [ -z "$exe" ] && [ -x target/v0667_alias_check ]; then exe=target/v0667_alias_check; fi
    [ -n "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1
    local rc=$?
    [ "$rc" -eq 0 ] || return 1
    grep -qE "^result:$" $NUC_VERIFY_RUN_LOG || return 1
    grep -qE "^44$" $NUC_VERIFY_RUN_LOG || return 1
}

v0673_tuple_struct_decl_named_field_workaround() {
    rm -f target/v0673_tup_check.exe target/v0673_tup_check
    "$BIN" build tests/fixtures/v0673_tuple_struct_decl_named_field_workaround.nr -o "v0673_tup_check" >$NUC_VERIFY_STEP_LOG 2>&1
    local exe=""
    if [ -x target/v0673_tup_check.exe ]; then exe=target/v0673_tup_check.exe; fi
    if [ -z "$exe" ] && [ -x target/v0673_tup_check ]; then exe=target/v0673_tup_check; fi
    [ -n "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1
    local rc=$?
    [ "$rc" -eq 0 ] || return 1
    grep -qE "^5$" $NUC_VERIFY_RUN_LOG || return 1
    grep -qE "^10$" $NUC_VERIFY_RUN_LOG || return 1
    grep -qE "^label$" $NUC_VERIFY_RUN_LOG || return 1
    grep -qE "^42$" $NUC_VERIFY_RUN_LOG || return 1
}

v0674_tuple_struct_full() {
    rm -f target/v0674_tup_check.exe target/v0674_tup_check
    "$BIN" build tests/fixtures/v0674_tuple_struct_full.nr -o "v0674_tup_check" >$NUC_VERIFY_STEP_LOG 2>&1
    local exe=""
    if [ -x target/v0674_tup_check.exe ]; then exe=target/v0674_tup_check.exe; fi
    if [ -z "$exe" ] && [ -x target/v0674_tup_check ]; then exe=target/v0674_tup_check; fi
    [ -n "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1
    local rc=$?
    [ "$rc" -eq 0 ] || return 1
    grep -qE "^5$" $NUC_VERIFY_RUN_LOG || return 1
    grep -qE "^10$" $NUC_VERIFY_RUN_LOG || return 1
    grep -qE "^hello$" $NUC_VERIFY_RUN_LOG || return 1
    grep -qE "^42$" $NUC_VERIFY_RUN_LOG || return 1
    grep -qE "^99$" $NUC_VERIFY_RUN_LOG || return 1
}

v0681_ufcs_dispatch() {
    rm -f target/v0681_ufcs_check.exe target/v0681_ufcs_check
    "$BIN" build tests/fixtures/v0681_ufcs_dispatch.nr -o "v0681_ufcs_check" >$NUC_VERIFY_STEP_LOG 2>&1
    local exe=""
    if [ -x target/v0681_ufcs_check.exe ]; then exe=target/v0681_ufcs_check.exe; fi
    if [ -z "$exe" ] && [ -x target/v0681_ufcs_check ]; then exe=target/v0681_ufcs_check; fi
    [ -n "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1
    local rc=$?
    [ "$rc" -eq 0 ] || return 1
    grep -q "hi from W" $NUC_VERIFY_RUN_LOG || return 1
}

v0687_str_string_eq_auto_dispatch() {
    rm -f target/v0687_eq_check.exe target/v0687_eq_check
    "$BIN" build tests/fixtures/v0687_str_string_eq_auto_dispatch.nr -o "v0687_eq_check" >$NUC_VERIFY_STEP_LOG 2>&1
    local exe=""
    if [ -x target/v0687_eq_check.exe ]; then exe=target/v0687_eq_check.exe; fi
    if [ -z "$exe" ] && [ -x target/v0687_eq_check ]; then exe=target/v0687_eq_check; fi
    [ -n "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1
    local rc=$?
    [ "$rc" -eq 0 ] || return 1
    grep -q "11" $NUC_VERIFY_RUN_LOG || return 1
    grep -q "22" $NUC_VERIFY_RUN_LOG || return 1
    grep -q "33" $NUC_VERIFY_RUN_LOG || return 1
    grep -q "44" $NUC_VERIFY_RUN_LOG || return 1
}

v0688_assert_eq_routes_through_eq() {
    rm -f target/v0688_assert_check.exe target/v0688_assert_check
    "$BIN" build tests/fixtures/v0688_assert_eq_routes_through_eq.nr -o "v0688_assert_check" >$NUC_VERIFY_STEP_LOG 2>&1
    local exe=""
    if [ -x target/v0688_assert_check.exe ]; then exe=target/v0688_assert_check.exe; fi
    if [ -z "$exe" ] && [ -x target/v0688_assert_check ]; then exe=target/v0688_assert_check; fi
    [ -n "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1
    local rc=$?
    [ "$rc" -eq 0 ] || return 1
    grep -q "11" $NUC_VERIFY_RUN_LOG || return 1
    grep -q "22" $NUC_VERIFY_RUN_LOG || return 1
    grep -q "33" $NUC_VERIFY_RUN_LOG || return 1
}

v0633_option_unwrap_none_panics() {
    rm -f target/v0633_opt_check.exe target/v0633_opt_check
    "$BIN" build tests/fixtures/option_unwrap_none_panics.nr -o "v0633_opt_check" >$NUC_VERIFY_STEP_LOG 2>&1
    local exe=""
    if [ -x target/v0633_opt_check.exe ]; then exe=target/v0633_opt_check.exe; fi
    if [ -z "$exe" ] && [ -x target/v0633_opt_check ]; then exe=target/v0633_opt_check; fi
    [ -n "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1
    local rc=$?
    [ "$rc" -ne 0 ] || return 1
    grep -qE "called .Option::unwrap\(\). on a .None. value" $NUC_VERIFY_RUN_LOG || return 1
    grep -qv "vec_get OOB" $NUC_VERIFY_RUN_LOG || return 1
    grep -qv "index out of bounds" $NUC_VERIFY_RUN_LOG || return 1
}

v0633_result_unwrap_err_panics() {
    rm -f target/v0633_res_check.exe target/v0633_res_check
    "$BIN" build tests/fixtures/result_unwrap_err_panics.nr -o "v0633_res_check" >$NUC_VERIFY_STEP_LOG 2>&1
    local exe=""
    if [ -x target/v0633_res_check.exe ]; then exe=target/v0633_res_check.exe; fi
    if [ -z "$exe" ] && [ -x target/v0633_res_check ]; then exe=target/v0633_res_check; fi
    [ -n "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1
    local rc=$?
    [ "$rc" -ne 0 ] || return 1
    grep -qE "called .Result::unwrap\(\). on an .Err. value" $NUC_VERIFY_RUN_LOG || return 1
}

v0510_i32_min_div_overflow() {
    rm -f target/v0510_i32div_check.exe target/v0510_i32div_check
    "$BIN" build tests/fixtures/v0510_i32_min_div_neg_one.nr -o "v0510_i32div_check" >$NUC_VERIFY_STEP_LOG 2>&1
    local exe=""
    if [ -x target/v0510_i32div_check.exe ]; then exe=target/v0510_i32div_check.exe; fi
    if [ -z "$exe" ] && [ -x target/v0510_i32div_check ]; then exe=target/v0510_i32div_check; fi
    [ -n "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1
    local rc=$?
    [ "$rc" -ne 0 ] || return 1
    [ "$rc" -ne -1073741675 ] || return 1
    grep -qE 'PANIC: i32 div overflow: i32::MIN / -1' $NUC_VERIFY_RUN_LOG || return 1
}

# v0.5.12: probe-agent finding 2026-05-01-str-to-int-silent-zero-on-invalid.
# Lenient `str_to_int` returns 0 on parse failure (silent); strict
# variant panics with a clean Nucleor message. Asserts non-zero rc
# and stderr contains the strict-prefix.
v0512_str_to_int_strict_panic() {
    rm -f target/v0512_strict_check.exe target/v0512_strict_check
    "$BIN" build tests/fixtures/v0512_str_to_int_strict_panics.nr -o "v0512_strict_check" >$NUC_VERIFY_STEP_LOG 2>&1
    local exe=""
    if [ -x target/v0512_strict_check.exe ]; then exe=target/v0512_strict_check.exe; fi
    if [ -z "$exe" ] && [ -x target/v0512_strict_check ]; then exe=target/v0512_strict_check; fi
    [ -n "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1
    local rc=$?
    [ "$rc" -ne 0 ] || return 1
    grep -qE 'PANIC: str_to_int_strict:' $NUC_VERIFY_RUN_LOG || return 1
}

v0717_governance_rod_phase2a() {
    # RFC-0060 Phase 2a: governance rod registry round-trip. Locks the
    # AuthorRecord surface (constructor + register + count + get + JSON
    # serialization). Phase 2b (policy) and 2c (evidence/sign) build on
    # this without re-exercising the registry shape.
    rm -f target/v0717_gov.exe target/v0717_gov
    "$BIN" build tests/rods/governance_smoke.nr -o "v0717_gov" >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    local exe=""
    if [ -x target/v0717_gov.exe ]; then exe=target/v0717_gov.exe; fi
    if [ -z "$exe" ] && [ -x target/v0717_gov ]; then exe=target/v0717_gov; fi
    [ -n "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1 || return 1
    grep -q "OK governance_smoke" $NUC_VERIFY_RUN_LOG || return 1
    grep -q '"by":"joseph_wescott"' $NUC_VERIFY_RUN_LOG || return 1
    grep -q '"commit":"ef3d45cc"'   $NUC_VERIFY_RUN_LOG || return 1
}

v0714_where_clause_multi_param_bounds() {
    # v0.7.14 / probe Q3+Q4 fold-in: lock the parser surface for
    # `fn f<T,U>(...) where T: A + B + C, U: D` — multi-trait bound on
    # one type-param + multi-param where clause in the same signature.
    rm -f target/v0714_where.exe target/v0714_where
    "$BIN" build tests/features/where_clause_multi_param_bounds.nr -o "v0714_where" >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    local exe=""
    if [ -x target/v0714_where.exe ]; then exe=target/v0714_where.exe; fi
    if [ -z "$exe" ] && [ -x target/v0714_where ]; then exe=target/v0714_where; fi
    [ -n "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1 || return 1
    grep -q "OK where_clause_multi_param_bounds" $NUC_VERIFY_RUN_LOG || return 1
}

t28_async_threads() {
    # v0.2.353 (T2.8): async runtime — threads-only commitment.
    "$BIN" test "tests/smoke/t28_async_threads.nr" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -q "PASS: test_async_basic_spawn_await" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_async_two_concurrent_tasks" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_async_await_in_arithmetic" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_async_zero_arg_fn" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "test result: PASS (4 tests)" $NUC_VERIFY_STEP_LOG || return 1
}

t27_doc_html() {
    # v0.2.352 (T2.7): nuc doc --html emits standalone HTML doc.
    # Auto-detection of HTML mode keys off the `.html` extension on the
    # --out filename. Pre-v0.3.148, this bash mirror used mktemp which
    # produces a random extension-less filename so the doc emitter
    # silently fell back to Markdown (visible only as the wrote-banner
    # saying "with index + signatures" instead of "HTML"). Test failed
    # at the first grep. The .ps1 mirror uses an explicit _t27_doc.html
    # filename and worked correctly. v0.3.148 sync.
    local hdr hdr_arg
    hdr="$(verify_tmp_file "_t27_doc_$$.html")"
    hdr_arg="$(verify_bin_path "$hdr")"
    rm -f "$hdr"
    "$BIN" doc tests/fixtures/t27_doc_input.nr --out "$hdr_arg" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE 'wrote .*HTML' $NUC_VERIFY_STEP_LOG || return 1
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
    "$BIN" test "tests/smoke/t25_lifetime_params.nr" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -q "PASS: test_no_lifetime_baseline" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_single_lifetime" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_two_lifetimes" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_mixed_lifetime_and_type_param" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "test result: PASS (4 tests)" $NUC_VERIFY_STEP_LOG || return 1
}

t24_trait_objects() {
    # v0.2.350 (T2.4): trait object 2-cell handle runtime helpers.
    # 5 #[test] cases covering manual dispatch + polymorphic collection.
    "$BIN" test "tests/smoke/t24_trait_objects.nr" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -q "PASS: test_dyn_box_make_type_data" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_dyn_box_dispatch_a" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_dyn_box_dispatch_b" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_dyn_box_polymorphic_collection" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_dyn_box_unknown_tag_returns_default" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "test result: PASS (5 tests)" $NUC_VERIFY_STEP_LOG || return 1
}

t23_closure_literals() {
    # v0.2.349 (T2.3): closure literals lifted into synthesized
    # top-level fns. 4 #[test] cases including a 3-step pipeline.
    "$BIN" test "tests/smoke/t23_closure_literals.nr" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -q "PASS: test_map_with_closure" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_filter_with_closure" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_fold_with_closure" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_chain_with_closures" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "test result: PASS (4 tests)" $NUC_VERIFY_STEP_LOG || return 1
}

t22_iter_methods() {
    # v0.2.348 (T2.2): Vec method-call dispatch for iterator methods
    # routes to typed `vec_*_i64` runtime helpers. 5 #[test] cases
    # including a `.map().filter().fold()` chain.
    "$BIN" test "tests/smoke/t22_iter_methods.nr" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -q "PASS: test_map" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_filter" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_fold_and_sum" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_min_max" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_chain" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "test result: PASS (5 tests)" $NUC_VERIFY_STEP_LOG || return 1
}

t21_range_patterns() {
    # v0.2.347 (T2.1): inclusive `LO..=HI` and exclusive `LO..HI`
    # range patterns wired through to existing __range / __range_bad
    # lowering. Run through the main compiler; tools-suite parser parity is
    # tracked separately because it still has a reduced frontend.
    "$BIN" build "tests/smoke/t21_range_patterns.nr" -o "_t21_range_patterns" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    local exe="target/_t21_range_patterns"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_STEP_LOG.run 2>&1 || return 1
    grep -q "OK t21_range_patterns" $NUC_VERIFY_STEP_LOG.run || return 1
}

t26_format_macros() {
    # v0.2.346 (T2.6): source-level macro expansion. 6 #[test] cases
    # cover int placeholder, two placeholders, {:s} str passthrough,
    # literal-only, {{ }} escapes, {:b} bool spec.
    "$BIN" test "tests/smoke/t26_format_macros.nr" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -q "PASS: test_format_basic_int" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_format_two_placeholders" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_format_str_passthrough" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_format_literal_only" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_format_escaped_braces" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_format_binary_radix" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "test result: PASS (6 tests)" $NUC_VERIFY_STEP_LOG || return 1
}

t16_gen_headers_structs() {
    # v0.2.345 (T1.6): nuc gen-headers walks the source for #[repr(C)]
    # structs, emits typedef structs in the C header, and accepts
    # struct names in extern fn signatures. Non-repr(C) structs
    # (PrivateInternal in the fixture) must be excluded.
    local hdr hdr_arg
    hdr="$(verify_tmp_file "_t16_struct_ffi.h")"
    hdr_arg="$(verify_bin_path "$hdr")"
    rm -f "$hdr"
    "$BIN" gen-headers tests/fixtures/t16_struct_ffi.nr -o "$hdr_arg" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -qE 'wrote 2 #\[repr\(C\)\] struct\(s\), 2 extern decl\(s\), 0 #\[export\] decl\(s\)' $NUC_VERIFY_STEP_LOG || return 1
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
    local out_dir out_arg
    out_dir="$(verify_tmp_dir "_t14_verify_out")" || return 1
    out_arg="$(verify_bin_path "$out_dir")"
    "$BIN" registry export-static "$out_arg" --registry tests/fixtures/t14_registry >$NUC_VERIFY_STEP_LOG 2>&1
    grep -q "packages exported: 2" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "versions exported: 3" $NUC_VERIFY_STEP_LOG || return 1
    grep -qE "files copied:[[:space:]]*7" $NUC_VERIFY_STEP_LOG || return 1
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
    "$BIN" build "tests/err/err_priv_cross_module.nr" -o "_t15d_check" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    grep -q "error\[MOD-003\]: cannot call private fn 'lib_helper'" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "declared in:.*lib_optin\.nr" $NUC_VERIFY_STEP_LOG || return 1
    grep -q 'hint: add `pub` to the fn declaration' $NUC_VERIFY_STEP_LOG || return 1
    grep -q "MOD-003 violation(s)" $NUC_VERIFY_STEP_LOG || return 1
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
    "$BIN" test "tests/smoke/t15c_privatization.nr" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -q "PASS: test_cross_module_pub_call_opt_in_lib" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_cross_module_non_pub_call_opt_out_lib" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "test result: PASS (2 tests)" $NUC_VERIFY_STEP_LOG || return 1
}

t15b_pub_introspection() {
    # v0.2.341 (T1.5b): the parser emits a kind-76 marker before each
    # `pub`-prefixed top-level item; `nuc summary` reads the markers
    # and prefixes `pub fn` accordingly. Smoke fixture verifies both
    # the summary surface AND that intra-module fn calls are
    # unaffected (3 #[test] cases all PASS). Cross-module enforcement
    # arrives in T1.5c.
    "$BIN" summary "tests/smoke/t15b_pub_introspection.nr" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -q "pub fn pub_alpha()" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "pub fn pub_gamma()" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "^fn priv_beta()" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "^fn priv_delta()" $NUC_VERIFY_STEP_LOG || return 1
    "$BIN" test "tests/smoke/t15b_pub_introspection.nr" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -q "PASS: test_pub_fn_callable" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_non_pub_fn_still_callable_pre_enforcement" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_mixed_pub_arithmetic" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "test result: PASS (3 tests)" $NUC_VERIFY_STEP_LOG || return 1
}

t15a_mod_block_form() {
    # v0.2.340 (T1.5a): the resolver inlines `mod foo { ... }` block
    # contents alongside the existing `mod foo;` file-rooted desugaring.
    # Brace scanner is string- and line-comment-aware. This step runs
    # the smoke fixture via `nuc test` and asserts all three cases PASS.
    "$BIN" test "tests/smoke/t15a_mod_block_form.nr" >$NUC_VERIFY_STEP_LOG 2>&1
    grep -q "PASS: test_mod_block_helper_visible_outside" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_mod_block_brace_in_string" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "PASS: test_mod_block_brace_in_comment_does_not_close_early" $NUC_VERIFY_STEP_LOG || return 1
    grep -q "test result: PASS (3 tests)" $NUC_VERIFY_STEP_LOG || return 1
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
    # The bootstrap seed is canonicalized to the default strict-intrin
    # IR. Env-off verification still exercises the legacy path elsewhere,
    # but this fixed-point artifact must be compared in its canonical mode.
    env -u NUCLEOR_INT_STRICT_ARITH NUCLEOR_INT_STRICT_INTRIN=1 "$BIN" build "compiler/nucleor_s1_compiler.nr" -o "_seed_check" >$NUC_VERIFY_STEP_LOG 2>&1
    local fresh="target/_seed_check.ll"
    [ -f "$fresh" ] || return 1
    local seed_sha
    local fresh_sha
    seed_sha="$(sha256sum "$seed"  | awk '{print $1}')"
    fresh_sha="$(sha256sum "$fresh" | awk '{print $1}')"
    [ "$seed_sha" = "$fresh_sha" ]
}

t18_self_host_compiler_fixed_point() {
    bash "$ROOT/tools/check_self_host_md5.sh" >$NUC_VERIFY_STEP_LOG 2>&1
}

posix_perf_regression_monitor() {
    local check="$ROOT/tools/check_perf_regression.sh"
    local out
    local rc
    [ -f "$check" ] || return 1
    # No explicit --baseline by default: tools/check_perf_regression.sh
    # now picks tools/perf_baseline_linux.json on true Linux (non-WSL),
    # falling back to tools/perf_baseline.json elsewhere. Setting
    # NUC_VERIFY_POSIX_PERF_BASELINE pins a specific baseline.
    if [ -n "${NUC_VERIFY_POSIX_PERF_BASELINE:-}" ]; then
        out=$(bash "$check" \
            --baseline "$NUC_VERIFY_POSIX_PERF_BASELINE" \
            --cold-samples "${NUC_VERIFY_POSIX_PERF_COLD_SAMPLES:-3}" \
            --hot-samples "${NUC_VERIFY_POSIX_PERF_HOT_SAMPLES:-3}" \
            --budget-mb "${NUC_VERIFY_POSIX_PERF_BUDGET_MB:-1000}" \
            --warning-mb "${NUC_VERIFY_POSIX_PERF_WARNING_MB:-800}" \
            --timeout-sec "${NUC_VERIFY_POSIX_PERF_TIMEOUT_SEC:-180}" \
            --sample-ms "${NUC_VERIFY_POSIX_PERF_SAMPLE_MS:-100}" 2>&1)
        rc=$?
        echo "$out" | sed 's/^/       /'
        if [ "$rc" -eq 96 ]; then
            return 2
        fi
        return "$rc"
    fi
    out=$(bash "$check" \
        --cold-samples "${NUC_VERIFY_POSIX_PERF_COLD_SAMPLES:-3}" \
        --hot-samples "${NUC_VERIFY_POSIX_PERF_HOT_SAMPLES:-3}" \
        --budget-mb "${NUC_VERIFY_POSIX_PERF_BUDGET_MB:-1000}" \
        --warning-mb "${NUC_VERIFY_POSIX_PERF_WARNING_MB:-800}" \
        --timeout-sec "${NUC_VERIFY_POSIX_PERF_TIMEOUT_SEC:-180}" \
        --sample-ms "${NUC_VERIFY_POSIX_PERF_SAMPLE_MS:-100}" 2>&1)
    rc=$?
    echo "$out" | sed 's/^/       /'
    if [ "$rc" -eq 96 ]; then
        return 2
    fi
    return "$rc"
}

# Shared body for the per-source memory-budget steps.
_memory_budget_for() {
    local src="$1"
    local budget_mb="$2"
    local label="$3"
    local out_name="$4"
    local out
    local rc
    local force_posix_rss="${NUC_VERIFY_FORCE_POSIX_RSS:-0}"
    rm -rf "$ROOT/.nuc_cache" 2>/dev/null || true
    # Windows agents may run this bash script from Git Bash, MSYS, or
    # WSL. Prefer the PowerShell process-tree sampler whenever a
    # PowerShell host is visible unless validation explicitly forces the
    # Linux /proc path.
    local psbin=""
    # Prefer PowerShell 7 when available. Windows PowerShell's 100ms
    # process-tree sampling loop can inflate wall time by multiple seconds
    # on this gate even when the compiler itself stays in the 3s regime.
    if [ "$force_posix_rss" != "1" ]; then
        if command -v pwsh >/dev/null 2>&1; then
            psbin="pwsh"
        elif command -v pwsh.exe >/dev/null 2>&1; then
            psbin="pwsh.exe"
        elif command -v powershell.exe >/dev/null 2>&1; then
            psbin="powershell.exe"
        fi
    fi
    if [ -n "$psbin" ]; then
        local ps1="$ROOT/tools/measure_peak_build.ps1"
        local ps1_arg="$ps1"
        if command -v cygpath >/dev/null 2>&1; then
            ps1_arg="$(cygpath -w "$ps1")"
        elif command -v wslpath >/dev/null 2>&1; then
            ps1_arg="$(wslpath -w "$ps1")"
        fi
        if [ "$psbin" = "powershell.exe" ]; then
            out=$("$psbin" -NoProfile -ExecutionPolicy Bypass -File "$ps1_arg" -Source "$src" -OutName "$out_name" -BudgetMb "$budget_mb" 2>&1)
        else
            out=$("$psbin" -NoProfile -File "$ps1_arg" -Source "$src" -OutName "$out_name" -BudgetMb "$budget_mb" 2>&1)
        fi
        rc=$?
        echo "$out" | sed 's/^/       /'
        return $rc
    fi
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*)
            if [ "$force_posix_rss" != "1" ] && command -v powershell.exe >/dev/null 2>&1; then
                local ps1="$ROOT/tools/measure_peak_build.ps1"
                local ps1_arg="$ps1"
                if command -v cygpath >/dev/null 2>&1; then
                    ps1_arg="$(cygpath -w "$ps1")"
                fi
                out=$(powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$ps1_arg" -Source "$src" -OutName "$out_name" -BudgetMb "$budget_mb" 2>&1)
                rc=$?
                echo "$out" | sed 's/^/       /'
                return $rc
            fi
            ;;
    esac

    local capped="$ROOT/tools/run_capped.sh"
    if [ -f "$capped" ]; then
        out=$(bash "$capped" --budget-mb "$budget_mb" --warning-mb "$((budget_mb * 9 / 10))" --sample-ms "${NUC_VERIFY_RSS_SAMPLE_MS:-100}" --label "$label" -- "$BIN" build "$src" -o "$out_name" 2>&1)
        rc=$?
        echo "$out" | sed 's/^/       /'
        if [ "$rc" -eq 96 ]; then
            echo "       ERROR: no supported real process-tree RSS e-stop is available for ${label}; refusing soft-green NUC_TRACE_ALLOC fallback." | sed 's/^/       /'
        fi
        return $rc
    fi

    echo "       ERROR: tools/run_capped.sh missing and no PowerShell RSS sampler is available for ${label}; refusing soft-green NUC_TRACE_ALLOC fallback." | sed 's/^/       /'
    return 1
}

tools_rebuild() {
    # v0.2.79 — rebuild the tools binary so the explain registry,
    # `nuc test` harness writer, and other tools-suite logic are
    # tested against the current source. Without this, a pull that
    # updates compiler/nucleor_tools_suite.nr would leave the
    # user's stale bin/nucleor_tools.exe in place and the
    # cli_explain_full_smoke step would fail spuriously (or, worse,
    # pass against the stale binary while the new code was broken).
    "$BIN" build "compiler/nucleor_tools_suite.nr" -o "nucleor_tools" >$NUC_VERIFY_STEP_LOG 2>&1
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

registry_remote_cli_smoke() {
    local tools_bin="$ROOT/target/nucleor_tools"
    if [ ! -x "$tools_bin" ]; then tools_bin="$ROOT/target/nucleor_tools.exe"; fi
    if [ ! -x "$tools_bin" ]; then tools_bin="$ROOT/bin/nucleor_tools"; fi
    if [ ! -x "$tools_bin" ]; then tools_bin="$ROOT/bin/nucleor_tools.exe"; fi
    if [ ! -x "$tools_bin" ]; then tools_bin="$BIN"; fi
    local tmp
    tmp="$(verify_tmp_dir "_r12_registry_remote")" || return 1
    (
        cd "$tmp" || exit 1
        "$tools_bin" registry remote list >list0.txt 2>&1 || exit 1
        grep -q "remotes: 0" list0.txt || exit 1
        "$tools_bin" registry remote add origin https://example.invalid/nucleor >add.txt 2>&1 || exit 1
        grep -q "added registry remote: origin" add.txt || exit 1
        [ -f ".nucleor/registry-remotes.txt" ] || exit 1
        grep -Eq "origin[[:space:]]+https://example[.]invalid/nucleor" ".nucleor/registry-remotes.txt" || exit 1
        "$tools_bin" registry remote list >list1.txt 2>&1 || exit 1
        grep -Eq "origin[[:space:]]+https://example[.]invalid/nucleor" list1.txt || exit 1
        if "$tools_bin" registry remote add origin https://example.invalid/again >dup.txt 2>&1; then exit 1; fi
        grep -q "already exists" dup.txt || exit 1
        if "$tools_bin" registry remote remove missing >missing.txt 2>&1; then exit 1; fi
        grep -q "not found" missing.txt || exit 1
        "$tools_bin" registry remote remove origin >remove.txt 2>&1 || exit 1
        grep -q "removed registry remote: origin" remove.txt || exit 1
        "$tools_bin" registry remote list >list2.txt 2>&1 || exit 1
        grep -q "remotes: 0" list2.txt || exit 1
    )
    local rc=$?
    rm -rf "$tmp"
    return $rc
}

compiler_tables_synced() {
    bash "$ROOT/tools/check_compiler_drift.sh" >$NUC_VERIFY_STEP_LOG 2>&1
}

rod_void_abi_clean() {
    bash "$ROOT/tools/check_rod_void_abi.sh" >$NUC_VERIFY_STEP_LOG 2>&1
}

num024_audit_zero() {
    # v0.4.232 — regression gate for v0.4.230's str_from_int signature
    # fix. The NUM-024 cross-width call-site audit (opt-in via
    # NUCLEOR_AUDIT_NUM024=1) reported 1734 hits in compiler / 1291 in
    # tools-suite before v0.4.230, all driven by `str_from_int(n: i32)`
    # being called with i64 magnitudes. Widening the param to i64
    # eliminated all 3025 hits across both sources at zero IR cost.
    # This gate ratchets that win — any future change that introduces
    # a new declared-iN param called with a wider source-level type
    # will fail this step.
    rm -rf "$ROOT/.nuc_cache" "$ROOT/target/.nuc_cache" 2>/dev/null || true
    local s_count t_count
    s_count=$(NUCLEOR_AUDIT_NUM024=1 "$BIN" build "compiler/nucleor_s1_compiler.nr" -o "_audit_s_check" 2>&1 | grep -c "NUM-024" || true)
    rm -rf "$ROOT/.nuc_cache" "$ROOT/target/.nuc_cache" 2>/dev/null || true
    t_count=$(NUCLEOR_AUDIT_NUM024=1 "$BIN" build "compiler/nucleor_tools_suite.nr" -o "_audit_t_check" 2>&1 | grep -c "NUM-024" || true)
    if [ "$s_count" -ne 0 ] || [ "$t_count" -ne 0 ]; then
        echo "       FAIL: NUM-024 audit regressed — compiler=$s_count tools-suite=$t_count (expect 0/0)" | sed 's/^/       /'
        echo "       Re-run locally with NUCLEOR_AUDIT_NUM024=1 to see the call sites." | sed 's/^/       /'
        return 1
    fi
    return 0
}

cache_v2_correctness() {
    rm -rf "$ROOT/target/.nuc_cache_v2" "$ROOT/.nuc_cache" 2>/dev/null || true

    local out1 out2 out3 out4 out5 out6 out7 out8 tmp_src sha_unset sha_strict sha_unset_again
    _cache_v2_contains_text() {
        case "$1" in
            *"$2"*) return 0 ;;
            *) return 1 ;;
        esac
    }
    _cache_v2_fail() {
        printf '       FAIL: %s\n' "$1"
        printf '%s\n' "$2" | sed 's/^/       /'
    }
    _cache_v2_build_strict_arith_smoke() {
        local strict_arith="$1"
        if command -v wslpath >/dev/null 2>&1; then
            case "$(uname -s):$BIN" in
                Linux*:*.exe)
                    local root_win cmd
                    root_win="$(wslpath -w "$ROOT")"
                    cmd="cd /d $root_win && set NUCLEOR_INT_STRICT_INTRIN=1&& "
                    if [ "$strict_arith" = "1" ]; then
                        cmd="${cmd}set NUCLEOR_INT_STRICT_ARITH=1&& "
                    else
                        cmd="${cmd}set NUCLEOR_INT_STRICT_ARITH=&& "
                    fi
                    cmd="${cmd}bin\\nucleor.exe build tests\\features\\cache_strict_arith_key_smoke.nr -o _cache_strict_arith_key --no-link --cache-stats"
                    cmd.exe /C "$cmd"
                    return "$?"
                    ;;
            esac
        fi
        if [ "$strict_arith" = "1" ]; then
            NUCLEOR_INT_STRICT_ARITH=1 NUCLEOR_INT_STRICT_INTRIN=1 "$BIN" build "tests/features/cache_strict_arith_key_smoke.nr" -o "_cache_strict_arith_key" --no-link --cache-stats
        else
            env -u NUCLEOR_INT_STRICT_ARITH NUCLEOR_INT_STRICT_INTRIN=1 "$BIN" build "tests/features/cache_strict_arith_key_smoke.nr" -o "_cache_strict_arith_key" --no-link --cache-stats
        fi
    }
    out1=$("$BIN" build "tests/features/cache_v2_round_trip.nr" -o "_cache_v2_round_trip" --no-link --cache-stats 2>&1) || {
        echo "$out1" | sed 's/^/       /'
        return 1
    }
    echo "$out1" | grep -q "cache: miss -> stored" || { echo "$out1" | sed 's/^/       /'; return 1; }
    echo "$out1" | grep -q "cache stats: hits=0 misses=1" || { echo "$out1" | sed 's/^/       /'; return 1; }

    out2=$("$BIN" build "tests/features/cache_v2_round_trip.nr" -o "_cache_v2_round_trip" --no-link --cache-stats 2>&1) || {
        echo "$out2" | sed 's/^/       /'
        return 1
    }
    echo "$out2" | grep -q "cache: hit" || { echo "$out2" | sed 's/^/       /'; return 1; }
    echo "$out2" | grep -q "cache stats: hits=1 misses=0" || { echo "$out2" | sed 's/^/       /'; return 1; }
    [ -d "$ROOT/target/.nuc_cache_v2" ] || { echo "       FAIL: target/.nuc_cache_v2 was not created"; return 1; }

    "$BIN" clean --cache >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    [ ! -d "$ROOT/target/.nuc_cache_v2" ] || { echo "       FAIL: nuc clean --cache did not remove target/.nuc_cache_v2"; return 1; }

    mkdir -p "$ROOT/target"
    tmp_src="target/_cache_v2_invalidation.nr"
    cp "$ROOT/tests/features/cache_v2_invalidation.nr" "$ROOT/$tmp_src"
    rm -rf "$ROOT/target/.nuc_cache_v2" "$ROOT/.nuc_cache" 2>/dev/null || true

    out3=$("$BIN" build "$tmp_src" -o "_cache_v2_invalidation" --no-link --cache-stats 2>&1) || {
        echo "$out3" | sed 's/^/       /'
        return 1
    }
    echo "$out3" | grep -q "cache: miss -> stored" || { echo "$out3" | sed 's/^/       /'; return 1; }

    touch "$ROOT/$tmp_src"
    out4=$("$BIN" build "$tmp_src" -o "_cache_v2_invalidation" --no-link --cache-stats 2>&1) || {
        echo "$out4" | sed 's/^/       /'
        return 1
    }
    echo "$out4" | grep -q "cache: hit" || { echo "$out4" | sed 's/^/       /'; return 1; }

    printf '\n// cache v2 content mutation\n' >> "$ROOT/$tmp_src"
    out5=$("$BIN" build "$tmp_src" -o "_cache_v2_invalidation" --no-link --cache-stats 2>&1) || {
        echo "$out5" | sed 's/^/       /'
        return 1
    }
    echo "$out5" | grep -q "cache: miss -> stored" || { echo "$out5" | sed 's/^/       /'; return 1; }

    # R10-D4 Phase 2: strict-arith is a behavior-changing codegen env.
    # Flipping it must change the cache key, then flipping back must
    # hit the original cache entry.
    rm -rf "$ROOT/target/.nuc_cache_v2" "$ROOT/.nuc_cache" 2>/dev/null || true
    out6=$(_cache_v2_build_strict_arith_smoke 0 2>&1) || {
        echo "$out6" | sed 's/^/       /'
        return 1
    }
    out6=${out6//$'\r'/}
    _cache_v2_contains_text "$out6" "cache: miss -> stored" || { _cache_v2_fail "strict-arith unset build did not store a miss" "$out6"; return 1; }
    _cache_v2_contains_text "$out6" "cache stats: hits=0 misses=1" || { _cache_v2_fail "strict-arith unset build had unexpected cache stats" "$out6"; return 1; }
    sha_unset=$(printf '%s\n' "$out6" | sed -n 's/.*sha=\([^,)]*\).*/\1/p' | tr -d '[:space:]' | tail -1)
    [ -n "$sha_unset" ] || { _cache_v2_fail "could not parse unset strict-arith cache sha" "$out6"; return 1; }

    out7=$(_cache_v2_build_strict_arith_smoke 1 2>&1) || {
        echo "$out7" | sed 's/^/       /'
        return 1
    }
    out7=${out7//$'\r'/}
    _cache_v2_contains_text "$out7" "cache: miss -> stored" || { _cache_v2_fail "strict-arith enabled build did not store a miss" "$out7"; return 1; }
    _cache_v2_contains_text "$out7" "cache stats: hits=0 misses=1" || { _cache_v2_fail "strict-arith enabled build had unexpected cache stats" "$out7"; return 1; }
    sha_strict=$(printf '%s\n' "$out7" | sed -n 's/.*sha=\([^,)]*\).*/\1/p' | tr -d '[:space:]' | tail -1)
    [ -n "$sha_strict" ] || { _cache_v2_fail "could not parse strict-arith cache sha" "$out7"; return 1; }
    [ "$sha_unset" != "$sha_strict" ] || {
        echo "       FAIL: NUCLEOR_INT_STRICT_ARITH did not change cache sha ($sha_unset)"
        return 1
    }

    out8=$(_cache_v2_build_strict_arith_smoke 0 2>&1) || {
        echo "$out8" | sed 's/^/       /'
        return 1
    }
    out8=${out8//$'\r'/}
    _cache_v2_contains_text "$out8" "cache: hit" || { _cache_v2_fail "strict-arith unset rebuild did not hit the original cache entry" "$out8"; return 1; }
    _cache_v2_contains_text "$out8" "cache stats: hits=1 misses=0" || { _cache_v2_fail "strict-arith unset rebuild had unexpected cache stats" "$out8"; return 1; }
    sha_unset_again=$(printf '%s\n' "$out8" | sed -n 's/.*sha=\([^,)]*\).*/\1/p' | tr -d '[:space:]' | tail -1)
    [ "$sha_unset_again" = "$sha_unset" ] || {
        echo "       FAIL: strict-arith unset did not return to original cache sha ($sha_unset_again vs $sha_unset)"
        return 1
    }
    return 0
}

mojibake_clean() {
    # v0.2.91 — flag cp1252-as-utf8 mojibake byte sequences across
    # the source/doc surface. Catches the drift class that bit
    # rod_manifest.toml in v0.2.58 and vqe_h2.nr in v0.2.90.
    bash "$ROOT/tools/check_mojibake.sh" >$NUC_VERIFY_STEP_LOG 2>&1
}

rfc0007_atomic_ir_smoke() {
    rm -rf "$ROOT/.nuc_cache" "$ROOT/target/.nuc_cache" 2>/dev/null || true
    "$BIN" build "tests/features/rfc0007_atomic_basic.nr" -o "_rfc0007_atomic_basic" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
    local ll="target/_rfc0007_atomic_basic.ll"
    local exe="target/_rfc0007_atomic_basic"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -f "$ll" ] || return 1
    [ -x "$exe" ] || return 1
    grep -q "load atomic i64" "$ll" || return 1
    grep -q "store atomic i64" "$ll" || return 1
    grep -q "cmpxchg ptr" "$ll" || return 1
    grep -q "atomicrmw add ptr" "$ll" || return 1
    grep -q "atomicrmw sub ptr" "$ll" || return 1
    grep -q "atomicrmw and ptr" "$ll" || return 1
    grep -q "atomicrmw or ptr" "$ll" || return 1
    grep -q "atomicrmw xor ptr" "$ll" || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1
}

rfc0007_queue_smoke() {
    rm -rf "$ROOT/.nuc_cache" "$ROOT/target/.nuc_cache" 2>/dev/null || true
    local fixture exe out
    for fixture in rfc0007_queue_spsc rfc0007_queue_mpsc rfc0007_queue_capacity rfc0007_queue_bench; do
        "$BIN" build "tests/features/$fixture.nr" -o "_$fixture" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
        exe="target/_$fixture"
        [ -x "$exe.exe" ] && exe="$exe.exe"
        [ -x "$exe" ] || return 1
        out=$("$exe" 2>&1)
        printf '%s\n' "$out" >$NUC_VERIFY_RUN_LOG
        printf '%s\n' "$out" | grep -q "OK $fixture" || return 1
        if [ "$fixture" = "rfc0007_queue_bench" ]; then
            printf '%s\n' "$out" | grep -q "mpsc_4prod:" || return 1
            printf '%s\n' "$out" | grep -q "mutex_queue_4prod:" || return 1
        fi
    done
}

rfc0008_isr_first_pass() {
    rm -rf "$ROOT/.nuc_cache" "$ROOT/target/.nuc_cache" 2>/dev/null || true
    "$BIN" build "tests/features/rfc0008_isr_minimal.nr" -o "_rfc0008_isr_minimal" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    local ll="target/_rfc0008_isr_minimal.ll"
    local exe="target/_rfc0008_isr_minimal"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -f "$ll" ] || return 1
    grep -q "nucleor.isr target=cortex-m4f fn @systick_handler interrupt_cc" "$ll" || return 1
    [ -x "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1 || return 1
    grep -q "OK rfc0008_isr_minimal" $NUC_VERIFY_RUN_LOG || return 1

    "$BIN" build "tests/features/rfc0008_isr_no_alloc_no_panic.nr" -o "_rfc0008_isr_safe" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    local safe_exe="target/_rfc0008_isr_safe"
    [ -x "$safe_exe.exe" ] && safe_exe="$safe_exe.exe"
    "$safe_exe" >$NUC_VERIFY_RUN_LOG 2>&1 || return 1
    grep -q "OK rfc0008_isr_no_alloc_no_panic" $NUC_VERIFY_RUN_LOG || return 1

    local pair f code
    for pair in \
        "err_isr_001_returns_value ISR-001" \
        "err_isr_001_takes_param ISR-001" \
        "err_isr_002_with_deadline ISR-002" \
        "err_isr_003_unsupported_target ISR-003" \
        "err_isr_inherits_no_alloc RT-001" \
        "err_isr_inherits_no_panic RT-002"; do
        f="${pair% *}"
        code="${pair#* }"
        "$BIN" build "tests/err/$f.nr" -o "_$f" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
        grep -q "$code" $NUC_VERIFY_STEP_LOG || return 1
    done
    return 0
}

rfc0035_sendable_actor_first_pass() {
    rm -rf "$ROOT/.nuc_cache" "$ROOT/target/.nuc_cache" 2>/dev/null || true
    "$BIN" build "tests/features/rfc0035_sendable_marker.nr" -o "_rfc0035_sendable_marker" --no-link --no-cache >$NUC_VERIFY_STEP_LOG 2>&1 || return 1

    "$BIN" build "tests/features/rfc0035_actor_decl_parser.nr" -o "_rfc0035_actor_decl_parser" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    local exe="target/_rfc0035_actor_decl_parser"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    "$exe" >$NUC_VERIFY_RUN_LOG 2>&1 || return 1
    grep -q "OK rfc0035_actor_decl_parser" $NUC_VERIFY_RUN_LOG || return 1

    local pair f code
    for pair in \
        "err_rfc0035_not_sendable_spawn RACE-008" \
        "err_rfc0035_non_sendable_spawn RACE-001" \
        "err_rfc0035_actor_field_escape RACE-003" \
        "err_rfc0035_mut_ref_spawn RACE-005"; do
        f="${pair% *}"
        code="${pair#* }"
        "$BIN" build "tests/err/$f.nr" -o "_$f" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1
        grep -q "$code" $NUC_VERIFY_STEP_LOG || return 1
    done
    return 0
}

vec_inline_runtime_smoke() {
    rm -rf "$ROOT/.nuc_cache" "$ROOT/target/.nuc_cache" 2>/dev/null || true
    "$BIN" build "tests/features/vec_extend_self_inline.nr" -o "_vec_extend_self_inline" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    local exe="target/_vec_extend_self_inline"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    local out
    out=$("$exe" 2>&1)
    printf '%s\n' "$out" >$NUC_VERIFY_RUN_LOG
    printf '%s\n' "$out" | grep -q "OK vec_extend_self_inline"
    "$BIN" build "tests/rods/mem_inline_free.nr" -o "_mem_inline_free" --no-cache >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    exe="target/_mem_inline_free"
    [ -x "$exe.exe" ] && exe="$exe.exe"
    [ -x "$exe" ] || return 1
    out=$("$exe" 2>&1)
    printf '%s\n' "$out" >>$NUC_VERIFY_RUN_LOG
    printf '%s\n' "$out" | grep -q "OK mem_inline_free"
}

rfc0042_auto_drop_ir_smoke() {
    local ll="target/_rfc0042_auto_drop_vec.ll"
    "$BIN" build "tests/features/rfc0042_auto_drop_vec.nr" -o "_rfc0042_auto_drop_vec" --no-link --no-cache >$NUC_VERIFY_STEP_LOG 2>&1 || return 1
    [ -f "$ll" ] || return 1
    local calls
    calls=$(grep -c "call void @__nucleor_vec_free" "$ll" || true)
    if [ "$calls" != "4" ]; then
        echo "       expected exactly 4 emitted vec_free calls for RFC-0042 fixture, got $calls" | sed 's/^/       /'
        return 1
    fi
    return 0
}

# --- Run gate -----------------------------------------------------------
step "binary present" check_binary
step "compiler ABI tables synced" compiler_tables_synced
step "rod extern void-return ABI parity" rod_void_abi_clean
step "tools-suite rebuild" tools_rebuild
step "R12-D2 registry remote add/list/remove" registry_remote_cli_smoke
step "NUM-024 cross-width audit (compiler+tools-suite must report 0)" num024_audit_zero
step "no UTF-8 mojibake in source/docs" mojibake_clean
step "tests/err/*.nr have EXPECT headers" err_tests_have_expect_smoke
step "RFC-0007 atomics lower to LLVM atomic IR" rfc0007_atomic_ir_smoke
step "RFC-0007 queues run SPSC/MPSC/capacity/benchmark fixtures" rfc0007_queue_smoke
step "RFC-0008 ISR attribute first-pass contract and IR marker" rfc0008_isr_first_pass
step "RFC-0035 Sendable + actor first-pass substrate" rfc0035_sendable_actor_first_pass
step "NVec inline runtime ownership regressions" vec_inline_runtime_smoke
step "RFC-0042 auto_drop emits owned-local cleanup once" rfc0042_auto_drop_ir_smoke
step "CLI: nuc help advertises every dispatched command" cli_help_coverage_smoke
step "CLI: nuc zen/mco/registry/stage-dump/fix (utilities)" cli_utility_smoke
step "CLI: --json variants emit machine-readable JSON" cli_json_smoke
step "CLI: --version / -v / -V / version aliases" cli_version_smoke
step "RFC-NRT-003: nuc verify-reproducible passes on sample fixture" verify_reproducible_smoke
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
step "CLI: nuc test --check-laws validates laws and schema" cli_check_laws_smoke

for ex in "${EXAMPLES[@]}"; do
    step "example $ex" build_example "$ex"
done

if [ "$VERIFY_PARALLEL_JOBS" -gt 0 ]; then
    run_parallel_fixture_steps "$VERIFY_PARALLEL_JOBS"
    parallel_rc=$?
else
    parallel_rc=2
fi
if [ "$parallel_rc" = "2" ]; then
    for d in "${TEST_DIRS[@]}"; do
        if [ -d "tests/$d" ]; then
            for f in $(find "tests/$d" -maxdepth 1 -name '*.nr' 2>/dev/null | grep -vE "$TEST_SKIP_REGEX" | sort); do
                tname=$(basename "$f" .nr)
                step "test $d/$tname" build_test "$d" "$tname"
            done
        fi
    done

    if [ -d "tests/err" ]; then
        for f in $(find "tests/err" -maxdepth 1 -name '*.nr' 2>/dev/null | grep -vE "$ERR_SKIP_REGEX" | sort); do
            ename=$(basename "$f" .nr)
            step "negative $ename" build_negative "$ename"
        done
    fi
fi

step "self-host rebuild closes" self_host_rebuild
step "self-host memory budget (<= 770 MB; tight cap, see docs/milestones/MEMORY_DRIFT_2026-05-01.md)" self_host_memory_budget
step "tools-suite memory budget (<= 580 MB; tight cap, see docs/milestones/MEMORY_DRIFT_2026-05-01.md)" tools_suite_memory_budget
step "T1.8 POSIX perf + memory regression monitor" posix_perf_regression_monitor
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
step "T3.2b RT transitive same-file closure catches helper chains" rt_transitive_same_file_closure
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
step "T3.32 unary minus on f64 operand kinds (v0.3.57 fix)" t332_unary_minus_f64
step "T3.33 chained field access on fn-call result (v0.3.58 fix)" t333_chained_field_on_fn_call
step "T3.34 Vec-of-struct field access (v0.3.59 fix)" t334_vec_of_struct_field
step "T3.35 trait method results in inline f64 binops (v0.3.60 fix)" t335_trait_method_fp_ops
step "T3.36 as-cast results in inline f64 binops (v0.3.61 fix)" t336_cast_fp_ops
step "T3.37 fixed-array [T;N] f64 indexing (v0.3.62 fix)" t337_fixed_array_fp_ops
step "T3.38 fixed-array-of-struct field access (v0.3.63 fix)" t338_fixed_array_of_struct
step "T3.39 sensor-fusion synthesis (v0.3.51-63 production lock)" t339_sensor_fusion_synthesis
step "T3.40 nested-operand indexing (self.samples[i], v0.3.65 fix)" t340_nested_index_field
step "T3.41 method on indexed struct field (p.rects[0].area(), v0.3.66 fix)" t341_method_on_indexed_field
step "T3.42 indexing on fn-call result (make_vec()[i], v0.3.67 fix)" t342_fncall_indexing
step "T3.43 nested indexing (grid[i][j], v0.3.68 fix — matrix CLOSED)" t343_nested_indexing
step "T3.44 method-result-returning-struct field access (v0.3.69 fix)" t344_method_returning_struct
step "T3.45 Kalman synthesis (v0.3.65-69 nested-composition lock)" t345_kalman_synthesis
step "T3.46 assoc-fn collection aliases (HashMap/HashSet/BTreeMap/BTreeSet/VecDeque ::new)" t346_assoc_fn_collections
step "T3.47 closure-capture link correctness (runtime helpers __nucleor_capture_set/get)" t347_closure_capture
step "T3.48 module-scope let diagnostic (parser previously dropped silently)" t348_module_let_diagnostic
step "T3.49 trait-method-call indexed operand f64 dispatch (s.samples()[i])" t349_trait_method_vec_index
step "T3.50 module-scope stmt-keyword diagnostic (return/if/while/for/match/loop/break/continue)" t350_module_stmt_keyword_diagnostic
step "T3.51 let-shadowing semantics (RHS sees outer binding, not new uninit slot)" t351_shadowing
step "T3.52 compound assignment desugar (+= -= *= /= %=)" t352_compound_assignment
step "T3.53 inline closure-with-capture at .map/.filter call sites (T2.1/2/3 partial close)" t353_inline_closure_capture
step "T3.54 match-arm stmt bodies (return/break/continue) — T1.2 partial close" t354_match_arm_return
step "T3.55 nested struct field assign safety net (pre-v0.3.80 segfault → clean diagnostic)" t355_nested_field_assign_diagnostic
step "T3.56 indexed-LHS assign safety net (pre-v0.3.81 segfault → clean diagnostic)" t356_indexed_lhs_diagnostic
step "T3.57 tuple-destructure let safety net (pre-v0.3.81 segfault → clean diagnostic)" t357_tuple_let_diagnostic
step "T3.58 trait default-method support (impls inherit defaults; Self substitution)" t358_trait_default_methods
step "T3.59 fn-pointer type syntax 'fn(T) -> R' in param positions" t359_fn_pointer_type
step "T3.60 match-arm assignment body ('pat => x = v')" t360_match_arm_assign
step "T3.61 trait/impl associated-const diagnostic (pre-v0.3.85 cascaded parse errors)" t361_assoc_const_diagnostic
step "T3.62 match multi-capture enum patterns 'Variant(a, b, c)'" t362_match_multi_capture
step "T3.63 struct-like enum variant construction 'Variant { field: val }'" t363_struct_like_enum_variant
step "T3.64 vec.iter().X() chain (Rust idiom — identity pass-through)" t364_vec_iter_chain
step "T3.65 trait method with generic param 'fn count<T>(self)'" t365_trait_generic_method
step "T3.66 mixed-shorthand struct init 'Point { x: 5, y }'" t366_struct_init_shorthand
step "T3.67 ? operator chain (Ok/Err labels were swapped pre-v0.3.91)" t367_question_op_chain
step "T3.68 Box<dyn Trait> binding/call accepts Box<Concrete> with impl" t368_dyn_keyword_parse
step "T3.69 &mut T param diagnostic (HIGH-BLAST silent miscompute pre-v0.3.93)" t369_mut_ref_param_diagnostic
step "T3.70 panic!/assert!/dbg! macro forms (textual ! strip)" t370_panic_assert_macros
step "T3.71 extended macro set (assert_eq!/assert_ne!/todo!/unimplemented!/unreachable!)" t371_extended_macro_set
step "T3.72 mut closure capture writeback (FnMut direct closure call)" t372_mut_closure_capture_diagnostic
step "T3.73 bitwise op diagnostic (HIGH-BLAST silent miscompute pre-v0.3.97)" t373_bitwise_op_diagnostic
step "T3.74 env_get_or runtime helper" t374_env_get_or
step "T3.75 v0.4.24 silent miscomputes (f32 lit + neg + format spec dispatch)" t375_v24_silent_miscomputes
step "T3.76 v0.4.27 RFC-0028 phase 5 — {:.N} precision spec for floats" t376_format_precision_spec
step "T3.77 v0.4.28 RFC-0028 phase 5 — width / align / zero-pad spec" t377_format_width_spec
step "T3.78 v0.4.29 RFC-0028 phase 5 — radix (x/X/o/b) + alternate form (#)" t378_format_radix_spec
step "T3.79 v0.4.30 RFC-0028 phase 5 — force-sign (:+) for integers" t379_format_force_sign_spec
step "T3.80 v0.4.31 unsupported assoc-fn no longer silent-zeros" t380_assoc_fn_unsupported_panic
step "T3.81 v0.4.32a closure mutate-capture writeback" t381_closure_mutate_capture_writeback
step "T3.82 v0.4.32b nested struct field assign no longer silently dropped" t382_nested_field_assign_panic
step "T3.83 v0.4.33a let tuple-destructure no longer silent-drops bindings" t383_let_tuple_destructure_panic
step "T3.84 v0.4.33b trait assoc-const no longer silent-drops decl" t384_trait_assoc_const_panic
step "T3.85 v0.4.33c impl assoc-const no longer silent-drops decl" t385_impl_assoc_const_panic
step "T3.86 v0.4.35 print() multi-arg no longer silent-drops extras" t386_print_multiarg_panic
step "T3.87 v0.4.36 unknown struct in init no longer cryptic %r.-1" t387_unknown_struct_panic
step "T3.88 v0.4.37 RFC-0028 phase 5 — :X upper-case hex digits" t388_format_hex_upper
step "T3.89 v0.4.38 RFC-0028 phase 5 — :e/:E scientific notation" t389_format_sci
step "T3.90 v0.4.40 RFC-0028 phase 5 — custom fill char (closes phase 5)" t390_format_fill_char
step "T3.91 v0.4.41 RFC-0028 phase 5+ — :? Debug formatter (str quoting)" t391_format_debug
step "T3.92 v0.4.47 NUC-FEEDBACK-002 — Vec<f32>/[i] as f32 silent-miscompute guard" t392_vec_narrow_float_as_cast_guard
step "T3.93 v0.4.48 NUC-FEEDBACK-002 — vec_get(v, i) as f32 fn-call form silent-miscompute guard" t393_vec_get_as_cast_guard
step "T3.94 v0.4.49 RFC-0023 partial — int-literal/wildcard or-patterns (silent miscompute close)" t394_or_patterns
step "T3.95 v0.4.50 NUC-FEEDBACK — if-let Some on .first/.last/.pop silent-segfault guard" t395_iflet_first_guard
step "T3.96 v0.4.51 NUC-FEEDBACK — str + str silent-segfault guard (use str_concat)" t396_str_plus_str_guard
step "T3.97 v0.4.52 NUC-FEEDBACK — str == str pointer-comparison silent-miscompute guard (use str_eq)" t397_str_eq_pointer_guard
step "T3.98 v0.4.53 NUC-FEEDBACK — Option/Result method on non-Option receiver silent-link-error guard" t398_unwrap_on_non_option_guard
step "T3.99 v0.4.54 NUC-FEEDBACK — '?' on non-Option/Result receiver silent-segfault guard" t399_question_on_non_option_guard
step "T3.100 v0.4.55 NUC-FEEDBACK — slice expression 'expr[lo..hi]' silent-segfault guard" t400_slice_syntax_guard
step "T3.101 v0.4.56 NUC-FEEDBACK — non-exhaustive match (stmt form) silent-miscompute close — MATCH-001 promoted to error" t401_match_exhaustive_stmt_guard
step "T3.102 v0.4.58 NUC-FEEDBACK — str -/*//% silent-segfault guard (extends v0.4.51 + close)" t402_str_arith_guard
step "T3.103 v0.4.59 NUC-FEEDBACK — non-exhaustive match in EXPR context halts (closes deferral #306)" t403_match_expr_exhaustive_guard
step "T3.104 v0.4.60 NUC-FEEDBACK — undefined fn call surfaces at type-check (closes deferral #2)" t404_undefined_fn_warn
step "T3.105 v0.4.61 NUC-FEEDBACK — Vec<T> arithmetic + ==/!= silent miscompute (closes deferral #1)" t405_vec_eq_arith_guard
step "T3.106 v0.4.62 NUC-FEEDBACK — struct init missing-field silent-default-zero (TYP-012)" t406_struct_missing_field_guard
step "T3.107 v0.4.63 NUC-FEEDBACK — struct init unknown-field silent-drop (TYP-013)" t407_struct_extra_field_guard
step "T3.108 v0.4.64 NUC-FEEDBACK — indexed assignment type-mismatch (TYP-009)" t408_indexed_assign_typecheck
step "T3.109 v0.4.65 NUC-FEEDBACK — field assignment type-mismatch (TYP-009)" t409_field_assign_typecheck
step "T3.110 v0.4.66 NUC-FEEDBACK — mixed str/int arithmetic (TYP-011, also catches += desugar)" t410_mixed_str_int_arith_guard
step "T3.111 v0.4.67 NUC-FEEDBACK — str ordering ops <, <=, >, >= ptr-compare (TYP-011)" t411_str_ord_pointer_guard
step "T3.112 v0.4.68 NUC-FEEDBACK — Vec ordering ops <, <=, >, >= ptr-compare (TYP-011)" t412_vec_ord_pointer_guard
step "T3.113 v0.4.69 NUC-FEEDBACK — '=' vs '==' typo guard in while/if conditions" t413_eq_typo_guard
step "T3.114 v0.4.70 audit S1 — NUM-002 literal-out-of-range promoted to error" t414_num002_promoted
step "v0.6 E3 NUM-021 const integer expression overflow diagnostic" t_v06_const_overflow_diagnostics
step "T3.115 v0.4.70 audit S10 — format placeholder/arg count mismatch halt at preprocess" t415_format_arg_count
step "T3.116 v0.4.71 audit S1 — bool with bitwise/shift ops (TYP-002 extended)" t416_bool_bitwise_guard
step "T3.117 v0.4.72 doc-#2 §5 — str_from_i64(i64) contract honesty (str_from_int kept as wrapper)" t417_str_from_i64_contract
step "T3.118 v0.4.73 audit S2 — generic Option payload type propagates into match arm" t418_generic_option_payload_type
step "T3.119 v0.4.73 audit S2 — generic Result payload type propagates into match arm" t419_generic_result_payload_type
step "T3.120 v0.4.73 audit S2 — Vec element type propagates through index, vec_get, first" t420_vec_element_type_propagation
step "T3.121 v0.4.74 NUM-009 — division/remainder by literal zero (silent runtime SIGFPE → compile-time halt)" t421_div_by_literal_zero
step "T3.122 v0.4.75 NUM-008 — shift amount out of range for i64 (LLVM poison → compile-time halt)" t422_shift_out_of_range
step "T3.123 v0.4.76 NUM-018 — float literal in integer-typed binding (silent IEEE-bits-as-i64 → halt)" t423_float_in_int_context
step "T3.124 v0.4.76 TYP-002 — unary `!` on non-bool (silent xor-with-1 → halt)" t424_not_on_int
step "T3.125 v0.4.77 NUM-019 — negative literal in unsigned binding (silent two's-complement-wrap → halt)" t425_neg_to_unsigned
step "T3.126 v0.4.78 NR020 — parse error halts (was print-and-recover → broken binary)" t426_parse_error_halts
step "T3.127 v0.4.79 — tuple destructure pattern in match halts (was silent downgrade to wildcard)" t427_match_tuple_pat_halts
step "T3.128 v0.4.79 — let at module scope halts (was silent skip)" t428_let_at_module_scope_halts
step "T3.129 v0.4.80 — int literal as Vec/tokenizer handle halts (was print WARNING + guaranteed runtime SIGSEGV)" t429_int_lit_as_handle_halts
step "T3.130 v0.4.83 TYP-008 ext — immutable let without initializer halts (was silent zero-read)" t430_uninit_immutable_let_halts
step "T3.131 v0.4.84 TYP-008 ext — struct field type mismatch on literal RHS halts (was silent ptr-as-i64 miscompute)" t431_struct_field_type_mismatch_halts
step "T3.132 v0.4.85 TYP-008 ext — Vec<T>.push(literal) wrong type halts (was silent str-ptr-as-i64-cell miscompute)" t432_vec_push_wrong_type_halts
step "T3.133 v0.4.86 TYP-008 ext — Vec<T>.set/.insert(idx, literal) wrong type halts (extends v0.4.85)" t433_vec_set_wrong_type_halts
step "v0.8 E3 T-4 strict inference rejects empty type" t4_strict_inference_rejects_empty_type
step "v0.8 T-4 strict inference accepts core helper return types" t4_strict_core_helper_rtypes_compile
step "v0.8 T-4 strict inference accepts IO/path helper return types" t4_strict_io_path_helper_rtypes_compile
step "v0.8 T-4 strict inference accepts format/string helper return types" t4_strict_format_string_helper_rtypes_compile
step "v0.8 T-4 strict inference accepts numeric/f64 helper return types" t4_strict_remaining_helper_rtypes_compile
step "v0.8 NUM-G2 math runtime panic guards" numg2_runtime_panic_guards
step "T3.134 v0.4.87 dispatch fix — v.insert/v.remove now route to vec_insert_at/vec_remove_at (was clang link failure)" t434_vec_insert_remove_dispatch
step "T3.135 v0.4.88 dispatch fix — s.len/contains/replace/split/starts_with/ends_with route to str_* (was silent vec_* miscompute)" t435_str_method_dispatch
step "T3.136 v0.4.89 — extend str dispatch to to_lower/to_upper/trim/trim_start/trim_end/substring/char_at (7 more methods)" t436_str_more_methods_dispatch
step "T3.137 v0.4.90 CRITICAL — Option/Result method dispatch (was unusable v0.4.53..v0.4.89 due to false non-Option panic)" t437_option_result_method_dispatch
step "T3.138 v0.4.92 — Option/Result fn-arg methods (.map/.and_then/.unwrap_or_else)" t438_option_result_fn_arg_methods
step "T3.139 v0.4.93 — Result.or_else(f) recovery method" t439_result_or_else
step "T3.140 v0.4.94 TYP-011 — s[i] on str halts (was silent vec_get on str pointer → OOB/garbage)" t440_str_index_halts
step "T3.141 v0.4.95 — variable-divisor zero panics with clean message (was silent SIGFPE / exit 127)" t441_var_div_zero_runtime_panic
step "T3.142 v0.4.96 RFC-0028 — struct Display/Debug format dispatch + FMT-002 (audit doc-#1 §10)" t442_format_struct_display_debug
step "T3.143 v0.4.97 — recursive Debug for Vec<i64>/Option<i64>/Result<i64,i64> (audit doc-#1 §10b)" t443_recursive_debug
step "T3.144 v0.4.98 — Vec debug element-type dispatch: Vec<str> + Vec<Option<i64>>" t444_debug_vec_str_and_option
step "T3.145 v0.4.99 §_p — parse_primary fall-through panics for non-recovery tokens (audit doc-#1)" t445_parse_primary_narrow_panic
step "T3.146 v0.4.115 RFC-0016 §3.7 — ? applies From<SrcErr> for DstErr conversion; explicit Into<T> parses" t460_question_from_conversion
step "T3.147 v0.4.119 rich match patterns — enum or, @, struct, slice, tuple, MATCH-008/009/010" t446_rich_pattern_forms
step "T3.148 v0.4.146 NUM-008 — variable shift RHS halts when const, panics cleanly at runtime otherwise" t447_shift_var_rhs_bounds
step "RFC-0034 compile-time [] parameter parser first pass" t_rfc0034_compile_time_params_parser
step "T3.saturating block add/sub/mul lower per operation" t_saturating_block_per_op
step "T3.strict intrinsic overflow i8/i16/i32/u64 + env precedence" t_strict_intrin_narrow_widths
step "v0.4.239 regression — wrapping {} block must not trap under strict default" t_wrap_block_no_trap
step "v0.4.245 RFC-0006 — #[require(EXPR)] runtime check fires (CONTRACT-001)" t_rfc0006_require_runtime
step "v0.4.246 RFC-0006 — #[ensure(EXPR)] runtime check fires (CONTRACT-002)" t_rfc0006_ensure_runtime
step "v0.4.247 RFC-0006 — #[ensure(EXPR)] mid-body return support" t_rfc0006_ensure_midbody_runtime
step "v0.4.248 RFC-0006 — #[invariant(EXPR)] impl-block runtime check (CONTRACT-003)" t_rfc0006_invariant_runtime
step "v0.4.250 RFC-0006 — multiple #[require] / #[ensure] attributes per fn" t_rfc0006_multi_attrs_runtime
step "v0.4.251 RFC-0006 — old(expr) snapshot in #[ensure]" t_rfc0006_old_expr_runtime
step "v0.4.252 RFC-0006 — NUCLEOR_DBC_MODE strip-out (debug/safe-release/release)" t_rfc0006_dbc_mode_runtime
step "v0.4.253 RFC-0006 — #[invariant] constructor exit-emit" t_rfc0006_invariant_ctor_runtime
step "v0.4.258 RFC-0006 — #[no_check] per-fn opt-out marker" t_rfc0006_no_check_runtime
step "v0.4.271 RFC-0006 — old() over heap-aliased types reject (CONTRACT-006)" t_rfc0006_old_vec_aliasing_reject
step "v0.4.272 RFC-0006 — result in void-fn #[ensure] reject (CONTRACT-008)" t_rfc0006_result_in_void_fn_reject
step "v0.4.275 RFC-0006 — invalid NUCLEOR_DBC_MODE reject (CONTRACT-009)" t_rfc0006_dbc_mode_invalid_reject
step "v0.4.276 MATCH-012 single-line panic (no print+panic stutter)" t_match_012_single_line
step "v0.4.277 RFC-0006 — old() in #[require] reject (CONTRACT-010)" t_rfc0006_old_in_require_reject
step "v0.4.283 RFC-0006 — undefined ident in contract reject (CONTRACT-011)" t_rfc0006_undefined_ident_reject
step "v0.4.279 str_char_at_strict in-bounds works" t_str_char_at_strict_basic
step "v0.4.279 str_char_at_strict OOB panics" t_str_char_at_strict_oob
step "v0.6 MATCH-014 negative range-pattern bounds diagnostic" t_match_014_negative_range_bounds
step "v0.6 str_substring_strict migration fixture" t_str_substring_strict_basic
step "v0.4.280 ATOMIC-006 closure+atomic compiler-meltdown halt" t_atomic_006_in_closure
step "v0.4.281 RFC-0007 AtomicBool ordered ops (load/store/CAS)" t_rfc0007_atomic_bool
step "v0.5 Track L content-addressed cache v2 correctness" cache_v2_correctness
step "T3.9 RT-005 fires on FFI call from RT fn body" t39_rt005_ffi_call
step "T3.15 #[ffi_no_alloc] marker silences RT-005 for that extern" t324_ffi_no_alloc_marker
step "T3.33 RFC-0033 with-effects syntax parses" t333_effects_with_positive
step "T3.33 RFC-0033 with [no_alloc] maps to RT-001" t333_effects_with_no_alloc
step "T3.33 RFC-0033 with [no_panic] maps to RT-002" t333_effects_with_no_panic
step "T3.33 RFC-0033 with [no_dyn] maps to RT-003" t333_effects_with_no_dyn
step "T3.33 RFC-0033 Alloc call rejected from no_alloc" t333_effects_with_alloc_call
step "R05 requires row rejects builtin body effects" r05_requires_body_builtin
step "R05 requires row rejects transitive builtin helper effects" r05_requires_transitive_builtin
step "R05 requires row permits declared transitive builtin family" r05_requires_transitive_builtin_ok
step "R05 restricts block rejects depth-8 helper chain" r05_restricts_depth8_chain
step "R05 restricts block permits clean depth-8 helper chain" r05_restricts_depth8_clean
step "T3.33 RFC-0033 extern with [no_alloc] feeds RT-005" t333_effects_with_ffi
step "T3.16 #[deadline] needs BOTH ffi_no_* markers (intersection rule)" t326_ffi_intersection
step "T3.10 RT-008 fires on direct recursion in deadline fn" t310_rt008_recursion
step "RFC-0014 max_depth static analysis + runtime wrapper" rfc0014_max_depth_full_ship
step "T3.11 bare arena_* builtins link + run end-to-end" t311_arena_builtin_smoke
step "v0.3.0 #[deadline=N] runtime check passes within budget" v030_deadline_pass
step "v0.3.0 #[deadline=N] overrun aborts with RT-004" v030_deadline_overrun
step "v0.6.43 unary-neg(i64::MIN) panics by default (sister to + and * overflow)" v0643_unary_neg_min_panics
step "v0.6.48 str runtime helpers accept &s (parity with bare s)" v0648_str_helper_amp_accepted
step "v0.6.49 canonical i64::MIN literal -9223372036854775808 accepted (was NUM-021 false-fire)" v0649_imin_literal_accepts
step "v0.6.52 IEEE 754 negative-zero sign bit preserved through unary minus" v0652_neg_zero_ieee_sign
step "v0.6.56 unreachable!() macro expands to canonical Rust panic message" v0656_unreachable_macro_panics
step "v0.6.66 char-typed binding accepts char-literal init (was wrong-class TYP-008)" v0666_char_literal_typed
step "v0.6.67 type alias resolves at use sites (was TYP-006/TYP-008)" v0667_type_alias_resolves
step "v0.6.73 tuple-struct decl accepts paren-form, synthesizes __0/__1 fields" v0673_tuple_struct_decl_named_field_workaround
step "v0.6.74 tuple-struct ctor + positional access (full V1.1)" v0674_tuple_struct_full
step "v0.6.81 UFCS dispatch parses and routes through trait impl" v0681_ufcs_dispatch
step "v0.6.87 str/String == auto-dispatches to content equality" v0687_str_string_eq_auto_dispatch
step "v0.6.88 assert_eq!/assert_ne! route through equality" v0688_assert_eq_routes_through_eq
step "v0.6.33 Option::None.unwrap() panics with canonical message (no Vec leak)" v0633_option_unwrap_none_panics
step "v0.6.33 Result::Err(x).unwrap() panics with canonical message (no silent ok-leak)" v0633_result_unwrap_err_panics
step "v0.6.34 Result::Err(x).unwrap_err() returns err payload (was TYP-005 link fail)" v0634_result_unwrap_err_basic
step "v0.6.34 Result::Ok(x).unwrap_err() panics with canonical message" v0634_result_unwrap_err_on_ok_panics
step "v0.5.10 i32::MIN / -1 panics cleanly (not Windows STATUS_INTEGER_OVERFLOW)" v0510_i32_min_div_overflow
step "v0.5.12 str_to_int_strict panics on invalid input" v0512_str_to_int_strict_panic
step "v0.7.14 where-clause multi-trait + multi-param bound parses and runs" v0714_where_clause_multi_param_bounds
step "v0.7.18 governance rod Phase 2a — AuthorRecord registry round-trip (RFC-0060)" v0717_governance_rod_phase2a
step "T1.7 bootstrap seed matches current compiler" t17_bootstrap_seed_matches
step "T1.8 self-host compiler IR fixed point" t18_self_host_compiler_fixed_point

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
