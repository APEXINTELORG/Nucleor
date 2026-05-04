#!/usr/bin/env bash
# tools/bisect_mem.sh — narrow a memory excursion to a small step
# region using concurrent half-runs (and quadrant-runs for interaction-
# bound cases), THEN pass that narrowed region to a final low-concurrency
# attribution pass.
#
# This implements the user's design:
#   1. Full concurrent run, peak-mem sampled (run_with_peakmem.ps1).
#      1 GB e-stop is always armed. CSV gets per-step time + run-summary
#      peak_mb. tools/check_mem_regression.sh decides if the run drifted.
#   2. If excursion: split [1, N] into halves, run each CONCURRENT (not
#      sequential — concurrent is fast and we are localizing a region).
#      Whichever half blows the e-stop or trips the stats threshold is
#      the offending half. Recurse.
#   3. If neither half blows but the full set did: split into 4 quadrants
#      (two halves of each half), run each concurrent. Combination that
#      blows is interaction-bound.
#   4. When narrowed region size <= MIN_REGION (default 16): run that
#      region with -j 2 (low concurrency, preserves some interaction)
#      OR sequential (-j 0) if --sequential-final. Per-step memory is
#      attributed in this final pass.
#
# The full sequential gate over 700 steps NEVER runs as part of this
# protocol. That is the entire point.
#
# Usage:
#   bash tools/bisect_mem.sh                              # full flow
#   bash tools/bisect_mem.sh --start 1-696                # skip Phase 1
#   bash tools/bisect_mem.sh --estop-mb 1024              # kill ceiling
#   bash tools/bisect_mem.sh --excursion-mb 750           # bisect trigger
#   bash tools/bisect_mem.sh --min-region 16              # final-pass size
#   bash tools/bisect_mem.sh --sequential-final           # -j 0 on region
#
# Exits 0 if no excursion detected. Non-zero with culprit region printed
# if excursion bottomed out.

set -euo pipefail

ESTOP_MB=1024            # hard ceiling (real-time kill)
# v0.8.83 PERF-11 — bisect trigger raised from 600 MB to 750 MB.
# Per tools/perf_baseline.json: cold_peak_memory_mb baseline is
# 679 MB, cold_max_allowed_memory_mb (baseline +10%) is 747 MB.
# Old 600 MB threshold tripped on every run (false-positive).
# 750 MB matches the baseline ceiling with negligible rounding.
EXCURSION_MB=750         # bisect trigger (subset peak >= this → recurse)
MIN_REGION=16            # bottom-out size for final attribution pass
MAX_DEPTH=10
START_RANGE=""
SEQUENTIAL_FINAL=0
POLL_MS=1000

while [ $# -gt 0 ]; do
    case "$1" in
        --estop-mb)        ESTOP_MB="$2"; shift 2 ;;
        --excursion-mb)    EXCURSION_MB="$2"; shift 2 ;;
        --min-region)      MIN_REGION="$2"; shift 2 ;;
        --max-depth)       MAX_DEPTH="$2"; shift 2 ;;
        --start)           START_RANGE="$2"; shift 2 ;;
        --sequential-final) SEQUENTIAL_FINAL=1; shift ;;
        --poll-ms)         POLL_MS="$2"; shift 2 ;;
        --help|-h)         sed -n '2,38p' "$0"; exit 0 ;;
        *) echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
    esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PWSH="pwsh"
command -v pwsh >/dev/null 2>&1 || PWSH="powershell.exe"

# Run a verify slice + sampler. Sets globals:
#   PEAK_MB, SUB_EXIT, SUB_WALL, KILLED ("True"|"False"), LAST_INDEX
run_subset() {
    local range="$1" jobs_arg="$2"   # jobs_arg empty = default; "0" = sequential
    local fwd="--range $range"
    [ -n "$jobs_arg" ] && fwd="$fwd -j $jobs_arg"
    local logf
    logf="$(mktemp -t bisect.XXXXXX.log)"
    "$PWSH" -NoProfile -ExecutionPolicy Bypass \
        -File tools/run_with_peakmem.ps1 \
        -VerifyArgs "$fwd" \
        -EstopMb "$ESTOP_MB" \
        -PollMs "$POLL_MS" 2>&1 | tee "$logf" >/dev/null
    local final
    final=$(grep -E '^PEAKMEM_MB=' "$logf" | tail -1)
    rm -f "$logf"
    if [ -z "$final" ]; then
        echo "ERROR: peakmem sampler emitted no result line" >&2
        return 2
    fi
    PEAK_MB=$(echo "$final" | sed -n 's/.*PEAKMEM_MB=\([0-9]*\).*/\1/p')
    SUB_EXIT=$(echo "$final" | sed -n 's/.*EXIT=\([0-9]*\).*/\1/p')
    SUB_WALL=$(echo "$final" | sed -n 's/.*WALL_S=\([0-9.]*\).*/\1/p')
    KILLED=$(echo "$final" | sed -n 's/.*KILLED=\(True\|False\).*/\1/p')
    LAST_INDEX=$(echo "$final" | sed -n 's/.*LAST_INDEX=\([0-9]*\).*/\1/p')
    return 0
}

is_excursion() {
    # $1 = peak_mb. Returns 0 if subset blew threshold or got killed.
    local pk="$1"
    if [ "$KILLED" = "True" ]; then return 0; fi
    if [ "$pk" -ge "$EXCURSION_MB" ]; then return 0; fi
    return 1
}

resolve_steps_in_range() {
    # $1 = "FROM-TO". Print step names from the last summary-row's run_iso
    # whose index falls in [FROM, TO].
    local r="$1" from="${1%-*}" to="${1##*-}"
    local csv="${NUC_VERIFY_CSV:-tools/verify_timings.${NUC_VERIFY_AGENT:-main}.csv}"
    if [ ! -f "$csv" ]; then echo "(CSV missing)"; return; fi
    local last_iso
    last_iso=$(awk -F, '$5 == "\"__run_summary__\"" { last=$1 } END { print last }' "$csv")
    awk -F, -v iso="$last_iso" -v lo="$from" -v hi="$to" \
        '$1 == iso && $2+0 >= lo && $2+0 <= hi && $5 != "\"__run_summary__\"" { print "  ["$2"] "$5 }' "$csv"
}

bisect_recurse() {
    local range="$1" depth="$2"
    local from="${range%-*}" to="${range##*-}"
    local size=$((to - from + 1))
    local indent
    indent=$(printf '%*s' "$((depth * 2))" '')

    echo ""
    echo "${indent}=== bisect depth=$depth range=$range size=$size ==="

    if [ "$size" -le "$MIN_REGION" ]; then
        echo "${indent}region narrowed to $size steps; running final attribution pass"
        local final_jobs=""
        [ "$SEQUENTIAL_FINAL" = "1" ] && final_jobs="0" || final_jobs="2"
        run_subset "$range" "$final_jobs"
        echo "${indent}  → final peak=${PEAK_MB} MB, exit=${SUB_EXIT}, killed=${KILLED}, last_index=${LAST_INDEX}"
        echo ""
        echo "${indent}>>> NARROWED REGION  $range <<<"
        resolve_steps_in_range "$range"
        if [ "$KILLED" = "True" ]; then
            echo ""
            echo "${indent}!! e-stop tripped during final pass at step index $LAST_INDEX"
            echo "${indent}   that index is the offender (or one of them)"
        fi
        return 1
    fi

    if [ "$depth" -ge "$MAX_DEPTH" ]; then
        echo "${indent}!! max depth reached at range=$range"
        return 1
    fi

    local mid=$((from + (size / 2) - 1))
    local left="${from}-${mid}"
    local right="$((mid + 1))-${to}"

    echo "${indent}left half:  $left"
    run_subset "$left" ""
    local lp="$PEAK_MB" lk="$KILLED"
    echo "${indent}  → peak=${lp} MB, killed=${lk}"

    echo "${indent}right half: $right"
    run_subset "$right" ""
    local rp="$PEAK_MB" rk="$KILLED"
    echo "${indent}  → peak=${rp} MB, killed=${rk}"

    local left_blew=0 right_blew=0
    if [ "$lk" = "True" ] || [ "$lp" -ge "$EXCURSION_MB" ]; then left_blew=1; fi
    if [ "$rk" = "True" ] || [ "$rp" -ge "$EXCURSION_MB" ]; then right_blew=1; fi

    if [ "$left_blew" = "1" ] && [ "$right_blew" = "0" ]; then
        bisect_recurse "$left" $((depth + 1)); return $?
    fi
    if [ "$right_blew" = "1" ] && [ "$left_blew" = "0" ]; then
        bisect_recurse "$right" $((depth + 1)); return $?
    fi
    if [ "$left_blew" = "1" ] && [ "$right_blew" = "1" ]; then
        echo "${indent}both halves blew → likely two offenders OR each half independently big"
        echo "${indent}recursing into the larger-peak half first"
        if [ "$lp" -ge "$rp" ]; then
            bisect_recurse "$left"  $((depth + 1)) || true
            bisect_recurse "$right" $((depth + 1)) || true
        else
            bisect_recurse "$right" $((depth + 1)) || true
            bisect_recurse "$left"  $((depth + 1)) || true
        fi
        return 1
    fi

    # Neither half blew but the parent set did → interaction-bound.
    # Re-split the parent into 4 quadrants and run each concurrent.
    echo "${indent}neither half blew → INTERACTION-BOUND in $range; quadrant split"
    local q1l="$from" q1r="$((from + size/4 - 1))"
    local q2l="$((q1r + 1))" q2r="$mid"
    local q3l="$((mid + 1))" q3r="$((mid + size/4))"
    local q4l="$((q3r + 1))" q4r="$to"
    local qranges=("$q1l-$q1r" "$q2l-$q2r" "$q3l-$q3r" "$q4l-$q4r")
    local qpeaks=() qkills=()
    for q in "${qranges[@]}"; do
        echo "${indent}  quadrant $q"
        run_subset "$q" ""
        echo "${indent}    → peak=${PEAK_MB} MB, killed=${KILLED}"
        qpeaks+=("$PEAK_MB")
        qkills+=("$KILLED")
    done
    # Pick highest-peak quadrant that blew. If none blew, declare unsolvable.
    local maxp=0 maxq=""
    for i in "${!qranges[@]}"; do
        if [ "${qkills[$i]}" = "True" ] || [ "${qpeaks[$i]}" -ge "$EXCURSION_MB" ]; then
            if [ "${qpeaks[$i]}" -gt "$maxp" ]; then
                maxp="${qpeaks[$i]}"; maxq="${qranges[$i]}"
            fi
        fi
    done
    if [ -z "$maxq" ]; then
        echo "${indent}!! no quadrant of $range blows on its own — excursion only triggers"
        echo "${indent}   when the full $range runs together. May need higher worker count or"
        echo "${indent}   a different concurrency level to reproduce in isolation. Bottoming."
        echo ""
        echo "${indent}>>> INTERACTION-BOUND REGION  $range <<<"
        resolve_steps_in_range "$range"
        return 1
    fi
    bisect_recurse "$maxq" $((depth + 1))
    return $?
}

echo "=== bisect_mem.sh ==="
echo "  e-stop:        $ESTOP_MB MB (real-time, always armed)"
echo "  excursion:     $EXCURSION_MB MB (subset peak that triggers recursion)"
echo "  min-region:    $MIN_REGION steps (final-pass attribution size)"
echo "  max-depth:     $MAX_DEPTH"
echo "  poll:          ${POLL_MS}ms"
echo "  final mode:    $( [ "$SEQUENTIAL_FINAL" = "1" ] && echo 'sequential (-j 0)' || echo 'low-concurrency (-j 2)' )"

if [ -n "$START_RANGE" ]; then
    INITIAL_RANGE="$START_RANGE"
    echo "  initial:       SKIP (--start $INITIAL_RANGE)"
else
    # Detect step total by looking at the most recent CSV summary row's
    # last_index, OR by running --range 1-1 and parsing [N/T].
    CSV="${NUC_VERIFY_CSV:-tools/verify_timings.${NUC_VERIFY_AGENT:-main}.csv}"
    STEP_TOTAL=""
    if [ -f "$CSV" ]; then
        STEP_TOTAL=$(awk -F, 'NR>1 { if ($2+0 > m) m=$2+0 } END { print m }' "$CSV")
    fi
    if [ -z "$STEP_TOTAL" ] || [ "$STEP_TOTAL" -lt 1 ]; then
        STEP_TOTAL=$(bash tools/verify.sh --range 1-1 2>&1 | grep -oE '\[[ ]*1/[0-9]+\]' | head -1 | grep -oE '[0-9]+]' | tr -d ']' | head -1)
    fi
    if [ -z "$STEP_TOTAL" ] || [ "$STEP_TOTAL" -lt 1 ]; then
        echo "ERROR: could not detect step total" >&2; exit 2
    fi
    echo "  steps:         1-$STEP_TOTAL"
    INITIAL_RANGE="1-$STEP_TOTAL"

    echo ""
    echo "--- Phase 1: full concurrent run, peak-mem sampled, e-stop armed ---"
    run_subset "$INITIAL_RANGE" ""
    echo ""
    echo "Phase 1: peak=${PEAK_MB} MB  killed=${KILLED}  exit=${SUB_EXIT}  wall=${SUB_WALL}s"
    if [ "$KILLED" != "True" ] && [ "$PEAK_MB" -lt "$EXCURSION_MB" ]; then
        echo ""
        echo ">>> No memory excursion (peak ${PEAK_MB} MB < ${EXCURSION_MB} MB)."
        echo "    Per-step time excursions still visible in the CSV — run"
        echo "    tools/check_mem_regression.sh to check time/memory drift vs baseline."
        exit 0
    fi
    echo ""
    echo ">>> Excursion (peak ${PEAK_MB} MB${KILLED:+, KILLED at index $LAST_INDEX}). Bisecting..."
    if [ "$KILLED" = "True" ] && [ "$LAST_INDEX" -gt 0 ]; then
        # If we got killed, narrow the search to [1, LAST_INDEX] — the
        # offender must be at or before that step.
        INITIAL_RANGE="1-$LAST_INDEX"
        echo "    narrowed initial range to $INITIAL_RANGE (e-stop fired at index $LAST_INDEX)"
    fi
fi

bisect_recurse "$INITIAL_RANGE" 0
exit $?
