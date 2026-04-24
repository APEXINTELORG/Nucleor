#!/usr/bin/env bash
# run_numerics_matrix.sh — runs the T1.1 numerics test matrix.
#
# Walks tests/lang/numerics_matrix/p*/ subdirectories. For each
# .nr file: builds, runs, classifies as PASS / FAIL / BUILD_ERROR.
#
# Always exits 0 — informational, not a CI gate.
#
# Usage: bash tools/run_numerics_matrix.sh

set -u

# T1.1 safety: cap virtual memory at 2 GB so a runaway compile or test
# fails fast (mirrors verify.sh). Override via NUCLEOR_MEM_CAP_KB env.
: "${NUCLEOR_MEM_CAP_KB:=2097152}"
if [ "${NUCLEOR_MEM_CAP_KB}" != "0" ]; then
    ulimit -v "${NUCLEOR_MEM_CAP_KB}" 2>/dev/null || true
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MATRIX="$ROOT/tests/lang/numerics_matrix"
NUCLEOR="$ROOT/bin/nucleor.exe"
TGT="$ROOT/target"

if [[ ! -x "$NUCLEOR" && ! -f "$NUCLEOR" ]]; then
    echo "ERROR: $NUCLEOR not found. Build the compiler first." >&2
    exit 0
fi

# Add LLVM clang to PATH on Windows-Git-Bash if missing.
if ! command -v clang >/dev/null 2>&1; then
    if [[ -x "/c/Program Files/LLVM/bin/clang.exe" ]]; then
        export PATH="/c/Program Files/LLVM/bin:$PATH"
    fi
fi

total=0; pass=0; fail=0; berr=0
declare -A ph_pass ph_fail ph_berr

for ph_dir in "$MATRIX"/p*/; do
    [[ -d "$ph_dir" ]] || continue
    ph_name=$(basename "$ph_dir")
    ph_pass[$ph_name]=0; ph_fail[$ph_name]=0; ph_berr[$ph_name]=0
    for f in "$ph_dir"/*.nr; do
        [[ -e "$f" ]] || continue
        total=$((total+1))
        base=$(basename "$f" .nr)
        rel="${f#$ROOT/}"
        # Build.
        if ! "$NUCLEOR" build "$rel" >/dev/null 2>&1; then
            berr=$((berr+1)); ph_berr[$ph_name]=$((${ph_berr[$ph_name]}+1))
            printf '[%-12s] %-30s BUILD_ERROR\n' "$ph_name" "$base"
            continue
        fi
        exe="$TGT/$base.exe"
        if [[ ! -f "$exe" ]]; then
            berr=$((berr+1)); ph_berr[$ph_name]=$((${ph_berr[$ph_name]}+1))
            printf '[%-12s] %-30s NO_EXE\n' "$ph_name" "$base"
            continue
        fi
        if "$exe" >/dev/null 2>&1; then
            pass=$((pass+1)); ph_pass[$ph_name]=$((${ph_pass[$ph_name]}+1))
            printf '[%-12s] %-30s PASS\n' "$ph_name" "$base"
        else
            fail=$((fail+1)); ph_fail[$ph_name]=$((${ph_fail[$ph_name]}+1))
            printf '[%-12s] %-30s FAIL\n' "$ph_name" "$base"
        fi
    done
done

echo ""
echo "===== Numerics matrix summary ====="
printf '%-12s %5s %5s %5s %5s\n' "Phase" "PASS" "FAIL" "BERR" "TOT"
for ph_dir in "$MATRIX"/p*/; do
    [[ -d "$ph_dir" ]] || continue
    n=$(basename "$ph_dir")
    p=${ph_pass[$n]:-0}; f=${ph_fail[$n]:-0}; b=${ph_berr[$n]:-0}
    t=$((p+f+b))
    printf '%-12s %5d %5d %5d %5d\n' "$n" "$p" "$f" "$b" "$t"
done
echo ""
printf 'TOTAL: pass=%d  fail=%d  build_error=%d  total=%d\n' "$pass" "$fail" "$berr" "$total"
exit 0
