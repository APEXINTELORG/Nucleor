#!/usr/bin/env bash
# tools/check_mem_regression.sh — read the verify_timings CSV, compute
# rolling per-step time and per-run memory stats, flag run-to-run drift.
#
# This is the "did this ship make it worse" detector. Independent of
# the 1 GB e-stop in run_with_peakmem.ps1 (which is the system-safety
# limit). Both signals matter:
#   - e-stop kill = system in immediate danger, halt now.
#   - excursion = today's run drifted from the historical mean.
#
# Excursion thresholds (configurable):
#   --time-sigma N   per-step time > mean + N*stddev = flag (default 2.5)
#   --mem-sigma N    run peak_mb > mean + N*stddev    = flag (default 2.0)
#   --mem-abs-mb N   run peak_mb > prior median + N MB = flag (default 100)
#                    (catches a single-run jump even when stddev is tiny)
#   --window K       only the last K runs feed the baseline (default 20)
#                    (rolling, not historical, so old runs don't anchor)
#   --warmup K       require >= K runs of history before flagging
#                    (default 5; first runs build the baseline only)
#
# Excludes runs marked killed=1 from the baseline (truncated → noise).
#
# Reads:  tools/verify_timings.<agent>.csv  (or NUC_VERIFY_CSV)
# Prints: nothing if clean. Excursion lines + non-zero exit if drifted.
#
# Usage:
#   bash tools/check_mem_regression.sh
#   NUC_VERIFY_AGENT=parallel1 bash tools/check_mem_regression.sh

set -euo pipefail

TIME_SIGMA="2.5"
MEM_SIGMA="2.0"
MEM_ABS_MB="100"
WINDOW="20"
WARMUP="5"

while [ $# -gt 0 ]; do
    case "$1" in
        --time-sigma) TIME_SIGMA="$2"; shift 2 ;;
        --mem-sigma)  MEM_SIGMA="$2";  shift 2 ;;
        --mem-abs-mb) MEM_ABS_MB="$2"; shift 2 ;;
        --window)     WINDOW="$2";     shift 2 ;;
        --warmup)     WARMUP="$2";     shift 2 ;;
        --help|-h) sed -n '2,30p' "$0"; exit 0 ;;
        *) echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
    esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CSV="${NUC_VERIFY_CSV:-tools/verify_timings.${NUC_VERIFY_AGENT:-main}.csv}"
if [ ! -f "$CSV" ]; then
    echo "ERROR: CSV not found: $CSV" >&2
    exit 2
fi

# Hand off to awk for the heavy lifting. awk handles fp arithmetic and
# multi-pass aggregation cleanly; bash here would be a mess.
awk -F, \
    -v time_sigma="$TIME_SIGMA" \
    -v mem_sigma="$MEM_SIGMA" \
    -v mem_abs_mb="$MEM_ABS_MB" \
    -v window="$WINDOW" \
    -v warmup="$WARMUP" \
    '
    function strip_quotes(s) {
        gsub(/^"/, "", s); gsub(/"$/, "", s); return s
    }
    function abs(x) { return x < 0 ? -x : x }
    function sqrt_(x) { return x <= 0 ? 0 : sqrt(x) }

    NR == 1 { next }   # skip header

    # Run-summary rows: name == "__run_summary__"; cols: run_iso,0,wall,status,name,peak_mb,killed,last_index
    {
        name = strip_quotes($5)
        if (name == "__run_summary__") {
            run_iso = $1
            status = $4
            peak_mb = $6 + 0
            killed = $7 + 0
            if (killed == 1) next   # skip truncated runs
            # Append to chronological list of run_iso (insertion order)
            run_list[++n_runs] = run_iso
            run_peak[run_iso] = peak_mb
            run_status[run_iso] = status
            next
        }
        # Per-step row: run_iso,index,seconds,status,name
        run_iso = $1
        idx = $2 + 0
        seconds = $3 + 0
        st = $4
        # Track per-step series (key by name)
        if (!(name in step_first_seen)) step_first_seen[name] = NR
        # Append: step_seconds[name] is a comma-separated chronological list
        if (st == "PASS" || st == "OK") {
            step_seconds[name] = step_seconds[name] "," seconds
            step_run[name] = step_run[name] "," run_iso
        }
    }

    END {
        # The "last run" we are checking is the most recent run_iso in run_list.
        if (n_runs < 1) {
            print "INFO: no completed runs in CSV"
            exit 0
        }
        last_run_iso = run_list[n_runs]
        last_peak    = run_peak[last_run_iso]

        # Build mem baseline from up to `window` runs preceding the last one.
        mem_n = 0; mem_sum = 0; mem_sumsq = 0
        med_count = 0
        first = (n_runs - 1) - window + 1
        if (first < 1) first = 1
        for (i = first; i <= n_runs - 1; i++) {
            rid = run_list[i]
            v = run_peak[rid]
            mem_sum   += v
            mem_sumsq += v * v
            mem_n     += 1
            med_arr[++med_count] = v
        }

        flagged = 0

        # Per-run memory check
        if (mem_n >= warmup) {
            mean = mem_sum / mem_n
            var  = (mem_sumsq / mem_n) - (mean * mean)
            sd   = sqrt_(var)
            # crude median
            for (a = 1; a <= med_count; a++)
                for (b = a+1; b <= med_count; b++)
                    if (med_arr[b] < med_arr[a]) { tmp = med_arr[a]; med_arr[a] = med_arr[b]; med_arr[b] = tmp }
            median = (med_count % 2 == 1) ? med_arr[(med_count+1)/2] : (med_arr[med_count/2] + med_arr[med_count/2+1]) / 2

            sigma_excursion = (last_peak > mean + mem_sigma * sd)
            abs_excursion   = (last_peak - median > mem_abs_mb)

            if (sigma_excursion || abs_excursion) {
                printf "MEM_EXCURSION  last_peak=%d MB  mean=%.1f MB  sd=%.1f MB  median=%.1f MB  baseline_n=%d\n", last_peak, mean, sd, median, mem_n
                if (sigma_excursion) printf "  → > mean + %.1f * sd  (%.1f MB above mean)\n", mem_sigma, last_peak - mean
                if (abs_excursion)   printf "  → > median + %d MB    (%.1f MB above median)\n", mem_abs_mb, last_peak - median
                flagged = 1
            } else {
                printf "MEM_OK  last_peak=%d MB  mean=%.1f MB  sd=%.1f MB  median=%.1f MB  baseline_n=%d\n", last_peak, mean, sd, median, mem_n
            }
        } else {
            printf "MEM_WARMUP  last_peak=%d MB  baseline_n=%d (need >= %d for excursion check)\n", last_peak, mem_n, warmup
        }

        # Per-step time check: for every step that ran in the last_run_iso,
        # compare its seconds to its rolling mean+sd from the prior `window` runs.
        # We need to iterate steps; we have step_seconds[name] as comma list of
        # all historical PASS seconds, and step_run[name] as parallel run_iso list.
        time_flagged = 0
        for (sname in step_seconds) {
            seq = step_seconds[sname]
            rseq = step_run[sname]
            # split into arrays
            n = split(seq, secs_arr, ",")
            split(rseq, run_arr, ",")
            # arrays are 1-indexed; first elem is empty due to leading comma
            # find this step in the last run
            last_secs = ""
            for (i = 2; i <= n; i++) {
                if (run_arr[i] == last_run_iso) { last_secs = secs_arr[i] }
            }
            if (last_secs == "") continue   # step did not run / was filtered out

            # build baseline from up to `window` PASS samples preceding the last run
            ssum = 0; ssumsq = 0; sn = 0
            for (i = 2; i <= n; i++) {
                if (run_arr[i] == last_run_iso) continue
                ssum   += secs_arr[i]
                ssumsq += secs_arr[i] * secs_arr[i]
                sn     += 1
            }
            if (sn > window) {
                # use only the last `window` (the trailing slice)
                start = n - window     # n includes the last_run sample(s); approximate
                if (start < 2) start = 2
                ssum = 0; ssumsq = 0; sn = 0
                for (i = start; i <= n; i++) {
                    if (run_arr[i] == last_run_iso) continue
                    ssum   += secs_arr[i]
                    ssumsq += secs_arr[i] * secs_arr[i]
                    sn     += 1
                }
            }
            if (sn < warmup) continue
            smean = ssum / sn
            svar  = (ssumsq / sn) - (smean * smean)
            ssd   = sqrt_(svar)
            if (last_secs > smean + time_sigma * ssd && last_secs > smean + 0.05) {
                # second predicate: ignore noise on sub-50ms steps
                printf "TIME_EXCURSION  step=\"%s\"  last=%.3fs  mean=%.3fs  sd=%.3fs  baseline_n=%d\n", sname, last_secs, smean, ssd, sn
                time_flagged += 1
            }
        }
        if (time_flagged > 0) {
            printf "  (%d step(s) drifted past mean + %.1f * sd)\n", time_flagged, time_sigma
            flagged = 1
        }

        if (flagged == 0 && (mem_n >= warmup)) {
            print "OK: no run-to-run regression"
        }
        exit (flagged ? 1 : 0)
    }
    ' "$CSV"
