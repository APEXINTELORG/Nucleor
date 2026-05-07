#!/usr/bin/env bash
# verify_parallel.sh — concurrent runner for the parallelizable steps
# of the verify gate (per-fixture builds in tests/{lang,attrs,runtime,
# rods,features} and tests/err negatives). Skips the sequential
# structural gates (T1/T2/T3 fixed steps, drift, bootstrap fixed-point,
# self-host rebuild) — those run via the canonical tools/verify.sh.
#
# Goal of this script: measure concurrent wall-time vs the sequential
# gate to validate the v0.4.39 cli_explain parallelization pattern at
# scale before deciding whether to fold it into verify.sh proper.
#
# v1 design (kept deliberately minimal):
#   - Per-worker temp dir for $NUC_VERIFY_STEP_LOG so the bash
#     processes don't stomp each others' logs.
#   - bash background jobs + `wait -n` slot management (no GNU parallel
#     dep, works on the user's Windows / git-bash setup).
#   - Each step writes its outcome to a per-job result file; the parent
#     tallies at the end.
#   - Build outputs land in target/<tname>{.exe,.ll} which is
#     per-fixture and never collides since basenames are unique.
#   - Cache reads (.nuc_cache/) are content-hashed, so concurrent reads
#     of the SAME hash key are fine. Writes are atomic (mv after temp).
#
# Usage:
#   bash tools/verify_parallel.sh           # default W = nproc/2
#   bash tools/verify_parallel.sh -j 8      # 8 concurrent workers
#   bash tools/verify_parallel.sh --list    # show every step result

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BIN="${BIN:-./bin/nucleor.exe}"
[ -x "$BIN" ] || { echo "ERROR: missing $BIN"; exit 1; }

WORKERS="$(( $(nproc 2>/dev/null || echo 4) / 2 ))"
[ "$WORKERS" -lt 1 ] && WORKERS=1
LIST_ALL=0
while [ $# -gt 0 ]; do
    case "$1" in
        -j) WORKERS="$2"; shift 2 ;;
        --list) LIST_ALL=1; shift ;;
        *) echo "unknown arg: $1"; exit 1 ;;
    esac
done

TMP="$(mktemp -d -t nucverP.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

TEST_DIRS=(lang attrs runtime rods features)
# v0.4.170: mirror verify.sh's TEST_SKIP_REGEX so *_aux.nr helper
# files (used by mod_decl.nr etc. as imported helpers, no main()
# of their own) don't run as standalone tests and fail. Pre-fix
# the placeholder `^$` matched nothing and mod_decl_aux.nr was
# counted as a baseline-FAIL in verify_parallel for releases.
TEST_SKIP_REGEX='_aux\.nr$'
# Mirror verify.sh's intentionally skipped negative fixture list.
ERR_SKIP_REGEX='err_str_char_at_strict_oob\.nr$'

# Enumerate every step and its kind.
STEPS_FILE="$TMP/steps.list"
: > "$STEPS_FILE"
for d in "${TEST_DIRS[@]}"; do
    [ -d "tests/$d" ] || continue
    for f in $(find "tests/$d" -maxdepth 1 -name '*.nr' 2>/dev/null | grep -vE "$TEST_SKIP_REGEX" | sort); do
        tname=$(basename "$f" .nr)
        echo "test:$d:$tname" >> "$STEPS_FILE"
    done
done
if [ -d "tests/err" ]; then
    for f in $(find "tests/err" -maxdepth 1 -name '*.nr' 2>/dev/null | grep -vE "$ERR_SKIP_REGEX" | sort); do
        ename=$(basename "$f" .nr)
        echo "negative::$ename" >> "$STEPS_FILE"
    done
fi

TOTAL=$(wc -l < "$STEPS_FILE")
echo "verify_parallel: $TOTAL parallelizable steps, $WORKERS workers"

# One worker = one job. Drives a single step, writes ok/fail to a result
# file. The result file name encodes the step number so we can tally in
# stable order at the end.
run_step() {
    local idx="$1" line="$2"
    local kind dir tname
    IFS=":" read -r kind dir tname <<< "$line"
    local steplog="$TMP/step.$idx.log"
    local result="$TMP/step.$idx.result"
    local label
    if [ "$kind" = "test" ]; then label="test $dir/$tname"; else label="negative $tname"; fi

    local t0 t1 dt
    t0=$(date +%s.%N)
    if [ "$kind" = "test" ]; then
        "$BIN" build "tests/$dir/$tname.nr" -o "$tname" > "$steplog" 2>&1
        local exe="target/$tname"
        [ -f "$exe.exe" ] && exe="$exe.exe"
        if [ ! -f "$exe" ]; then
            t1=$(date +%s.%N); dt=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.2f", b-a}')
            echo "FAIL|$label|$dt|build_failed" > "$result"
            return
        fi
        local out exit
        out=$("$exe" </dev/null 2>&1); exit=$?
        t1=$(date +%s.%N); dt=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.2f", b-a}')
        if [ "$dir" = "features" ]; then
            if [ "$exit" -eq 139 ] || [ "$exit" -eq 138 ] || [ "$exit" -eq -1073741819 ] || [ "$exit" -eq -1073740940 ]; then
                echo "FAIL|$label|$dt|crash_exit_$exit" > "$result"
            else
                echo "OK|$label|$dt|" > "$result"
            fi
        else
            echo "$out" | grep -qE '^OK ' && echo "OK|$label|$dt|" > "$result" || echo "FAIL|$label|$dt|missing_OK_marker" > "$result"
        fi
    else
        local out
        out=$("$BIN" build "tests/err/$tname.nr" -o "$tname" --no-cache 2>&1)
        t1=$(date +%s.%N); dt=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.2f", b-a}')
        echo "$out" | grep -qiE 'error\b|error\[|warning\b|warning\[' \
            && echo "OK|$label|$dt|" > "$result" \
            || echo "FAIL|$label|$dt|no_error_or_warning_emitted" > "$result"
    fi
}

# Drive jobs with a worker pool. `wait -n` blocks until ANY job finishes,
# then we slot the next one in. This caps concurrency at $WORKERS.
JOBS=0
IDX=0
T0=$(date +%s.%N)
while IFS= read -r line; do
    IDX=$((IDX + 1))
    if [ "$JOBS" -ge "$WORKERS" ]; then
        wait -n
        JOBS=$((JOBS - 1))
    fi
    run_step "$IDX" "$line" &
    JOBS=$((JOBS + 1))
done < "$STEPS_FILE"
wait
T1=$(date +%s.%N)
WALL=$(awk -v a="$T0" -v b="$T1" 'BEGIN{printf "%.2f", b-a}')

# Tally
PASS=0; FAIL=0; TSUM=0
FAILS=()
for i in $(seq 1 "$IDX"); do
    [ -f "$TMP/step.$i.result" ] || { FAIL=$((FAIL+1)); FAILS+=("step #$i: result missing"); continue; }
    IFS="|" read -r status label dt reason < "$TMP/step.$i.result"
    TSUM=$(awk -v a="$TSUM" -v b="$dt" 'BEGIN{printf "%.2f", a+b}')
    if [ "$status" = "OK" ]; then
        PASS=$((PASS + 1))
        [ "$LIST_ALL" -eq 1 ] && printf "  OK    %-50s  (%6.2fs)\n" "$label" "$dt"
    else
        FAIL=$((FAIL + 1))
        FAILS+=("$label  ($reason)")
    fi
done

echo "==="
printf "PASS:  %d\n" "$PASS"
printf "FAIL:  %d\n" "$FAIL"
printf "WALL:  %ss   (sum-of-step time: %ss → speedup ~%.2fx)\n" \
    "$WALL" "$TSUM" "$(awk -v a="$TSUM" -v b="$WALL" 'BEGIN{printf "%.2f", a/b}')"
if [ "$FAIL" -gt 0 ]; then
    echo "FAILURES:"
    for ff in "${FAILS[@]}"; do echo "  - $ff"; done
    exit 1
fi
exit 0
