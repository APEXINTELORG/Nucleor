#!/usr/bin/env bash
# memory_drift_profile.sh — measure peak RSS for the s1 compiler source
# AT each tagged commit, compiled with the CURRENT bin/nucleor.exe.
# Isolates source-size growth from compiler-internal-state growth.
#
# Historical memory-drift profiling helper.
# Output: CSV at tools/memory_drift_profile.csv with columns
#   tag, s1_bytes, s1_lines, peak_mb, wall_s, status
#
# Usage: ./tools/memory_drift_profile.sh [tag1 tag2 ...]
# With no args: defaults to the canonical anchor set.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ $# -gt 0 ]; then
    TAGS="$@"
else
    # v0.5.21 (probe-finding 2026-05-01-memory-drift-per-ship-attribution):
    # extended default anchor set to capture pre/post boundaries of each
    # major arc per probe's hypothesis table:
    # - v0.4.243: pre-RFC-0006 DbC arc baseline
    # - v0.4.260: post-DbC mid-arc (existing)
    # - v0.4.272: post-DbC, pre-RFC-0007 atomics
    # - v0.4.282: pre-v0.5.0 cut (existing)
    # - v0.4.286: post-Track-I cherry-pick (just before v0.5.0)
    # - v0.5.0:   atomic Track I + Track L cut (existing)
    # - v0.5.7+:  major main-agent ships
    TAGS="v0.4.243 v0.4.260 v0.4.272 v0.4.282 v0.4.286 v0.5.0 v0.5.7 v0.5.13 v0.5.14 v0.5.15 v0.5.20"
fi

OUT="$ROOT/tools/memory_drift_profile.csv"
TMP="$ROOT/target/_drift_probe"
mkdir -p "$TMP"

echo "tag,s1_bytes,s1_lines,peak_mb,wall_s,status" > "$OUT"

for tag in $TAGS; do
    src="$TMP/s1_${tag//./_}.nr"
    if ! git show "$tag:compiler/nucleor_s1_compiler.nr" > "$src" 2>/dev/null; then
        echo "  $tag: SOURCE_MISSING"
        echo "$tag,0,0,0,0,SOURCE_MISSING" >> "$OUT"
        continue
    fi
    bytes=$(wc -c < "$src")
    lines=$(wc -l < "$src")
    out_name="_drift_${tag//./_}"
    if command -v powershell.exe >/dev/null 2>&1; then
        log=$(powershell.exe -NoProfile -ExecutionPolicy Bypass \
            -File "$ROOT/tools/measure_peak_build.ps1" \
            -Source "target/_drift_probe/s1_${tag//./_}.nr" \
            -OutName "$out_name" \
            -BudgetMb 1500 2>&1)
        peak=$(echo "$log" | grep -oE 'peak [0-9]+ MB' | head -1 | grep -oE '[0-9]+')
        wall=$(echo "$log" | grep -oE 'wall [0-9]+\.[0-9]+s' | head -1 | grep -oE '[0-9]+\.[0-9]+')
        if echo "$log" | grep -q "^OK:"; then status="OK"
        else status="FAIL"; fi
        peak="${peak:-0}"
        wall="${wall:-0}"
        printf "  %-10s  bytes=%-8s lines=%-6s peak=%-5s MB  wall=%-7s s  %s\n" "$tag" "$bytes" "$lines" "$peak" "$wall" "$status"
        echo "$tag,$bytes,$lines,$peak,$wall,$status" >> "$OUT"
    else
        echo "  $tag: NO_POWERSHELL"
        echo "$tag,$bytes,$lines,0,0,NO_POWERSHELL" >> "$OUT"
    fi
done

echo ""
echo "CSV written to: $OUT"
