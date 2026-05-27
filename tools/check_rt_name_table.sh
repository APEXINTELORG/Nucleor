#!/usr/bin/env bash
# check_rt_name_table.sh — drift gate for compiler/s1/get_rt_name.tsv
#
# Auditability artifact for the get_rt_name dispatch in
# compiler/s1/builtins.nr. The TSV is a flat 2-column view of the
# (nuc_name -> rt_name) table; this script extracts the same mapping
# from the live .nr source and fails if the two diverge.
#
# Why a TSV alongside instead of a generator:
#   - The .nr table is part of the bootstrap fixed-point loop.
#     Code-gen at build time adds a tool dependency to the seed regen.
#   - The TSV captures the mapping in a form a human reviewer can
#     diff against without parsing Nucleor source. That covers the
#     "the dispatch becomes auditable" half of the Tier 2 #4 goal
#     from docs/critique-analysis.md; the "file shrinks" half can
#     follow on a dedicated branch when the seed regen pipeline grows
#     a code-gen step.

set -euo pipefail

SRC=compiler/s1/builtins.nr
TSV=compiler/s1/get_rt_name.tsv

if [[ ! -f $SRC ]]; then
  echo "ERROR: $SRC not found"
  exit 1
fi
if [[ ! -f $TSV ]]; then
  echo "ERROR: $TSV not found; regenerate from $SRC via tools/check_rt_name_table.sh --regen"
  exit 1
fi

extract() {
  awk '
    /^fn get_rt_name/ {in_fn=1; next}
    in_fn && /^}/ {in_fn=0; exit}
    in_fn && /if str_eq\(name, "/ {
      line = $0
      if (match(line, /"[^"]+"/)) {
        n1 = substr(line, RSTART+1, RLENGTH-2)
        rest = substr(line, RSTART + RLENGTH)
        if (match(rest, /"[^"]+"/)) {
          n2 = substr(rest, RSTART+1, RLENGTH-2)
          print n1 "\t" n2
        }
      }
    }
  ' "$SRC" | awk 'BEGIN{seen[""]=1} {if(!seen[$0]){print; seen[$0]=1}}'
}

if [[ "${1:-}" == "--regen" ]]; then
  {
    echo "# nuc_name\trt_name"
    extract
  } > "$TSV"
  echo "Regenerated $TSV ($(wc -l < $TSV) lines)"
  exit 0
fi

LIVE=$(extract)
EXPECTED=$(grep -v '^#' "$TSV")

if [[ "$LIVE" == "$EXPECTED" ]]; then
  echo "OK: get_rt_name table matches TSV manifest ($(echo "$LIVE" | wc -l) entries)"
  exit 0
fi

echo "FAIL: get_rt_name table drifted from $TSV"
echo "--- live (from $SRC):"
echo "$LIVE" | head -3
echo "..."
echo "$LIVE" | tail -3
echo "--- expected (from $TSV):"
echo "$EXPECTED" | head -3
echo "..."
echo "$EXPECTED" | tail -3
echo
echo "Run 'bash tools/check_rt_name_table.sh --regen' if the source change is intentional."
exit 1
