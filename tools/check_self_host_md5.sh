#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="compiler/nucleor_s1_compiler.nr"
SEED="bootstrap/nucleor_s1_seed.ll"
S1_NAME="_self_host_md5_stage1"
S2_NAME="_self_host_md5_stage2"
S1_LOG="target/${S1_NAME}.build.log"
S2_LOG="target/${S2_NAME}.build.log"

usage() {
    cat <<'USAGE'
usage: tools/check_self_host_md5.sh [--seed PATH]

Builds the self-host compiler twice and verifies:
  1. stage1-emitted compiler IR equals stage2-emitted compiler IR
  2. stage2-emitted compiler IR equals bootstrap/nucleor_s1_seed.ll

Set NUCLEOR_SELF_HOST_KEEP=1 to keep generated target artifacts after failure.
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --seed)
            [ "$#" -ge 2 ] || { echo "FAIL: --seed requires a path" >&2; exit 2; }
            SEED="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "FAIL: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

cd "$ROOT"

BIN="bin/nucleor"
if [ -x "bin/nucleor.exe" ]; then
    BIN="bin/nucleor.exe"
fi

[ -x "$BIN" ] || { echo "FAIL: compiler binary not found: $BIN" >&2; exit 1; }
[ -f "$SRC" ] || { echo "FAIL: compiler source not found: $SRC" >&2; exit 1; }
[ -f "$SEED" ] || { echo "FAIL: bootstrap seed not found: $SEED" >&2; exit 1; }
command -v md5sum >/dev/null 2>&1 || { echo "FAIL: md5sum is required" >&2; exit 1; }
mkdir -p target || { echo "FAIL: could not create target directory" >&2; exit 1; }

cleanup() {
    if [ "${NUCLEOR_SELF_HOST_KEEP:-0}" != "1" ]; then
        rm -f \
            "target/${S1_NAME}" "target/${S1_NAME}.exe" \
            "target/${S1_NAME}.ll" "target/${S1_NAME}.ll.cachekey" \
            "$S1_LOG" \
            "target/${S2_NAME}" "target/${S2_NAME}.exe" \
            "target/${S2_NAME}.ll" "target/${S2_NAME}.ll.cachekey" \
            "$S2_LOG" \
            2>/dev/null || true
    fi
}
trap cleanup EXIT

rm -f \
    "target/${S1_NAME}" "target/${S1_NAME}.exe" \
    "target/${S1_NAME}.ll" "target/${S1_NAME}.ll.cachekey" \
    "$S1_LOG" \
    "target/${S2_NAME}" "target/${S2_NAME}.exe" \
    "target/${S2_NAME}.ll" "target/${S2_NAME}.ll.cachekey" \
    "$S2_LOG" \
    2>/dev/null || true

run_canonical_build() {
    local label="$1"
    local compiler="$2"
    local out_name="$3"
    local log="$4"

    if ! env -u NUCLEOR_INT_STRICT_ARITH NUCLEOR_INT_STRICT_INTRIN=1 \
        "$compiler" build "$SRC" -o "$out_name" --no-cache >"$log" 2>&1; then
        echo "FAIL: $label build failed" >&2
        tail -80 "$log" >&2 || true
        exit 1
    fi
}

echo "self-host-md5: building stage1 from $BIN"
run_canonical_build "stage1" "$BIN" "$S1_NAME" "$S1_LOG"

S1_EXE="target/${S1_NAME}.exe"
if [ ! -x "$S1_EXE" ]; then
    S1_EXE="target/${S1_NAME}"
fi
[ -x "$S1_EXE" ] || { echo "FAIL: stage1 compiler executable was not produced" >&2; exit 1; }
[ -f "target/${S1_NAME}.ll" ] || { echo "FAIL: stage1 compiler IR was not produced" >&2; exit 1; }

echo "self-host-md5: building stage2 from $S1_EXE"
run_canonical_build "stage2" "$S1_EXE" "$S2_NAME" "$S2_LOG"

[ -f "target/${S2_NAME}.ll" ] || { echo "FAIL: stage2 compiler IR was not produced" >&2; exit 1; }

hash_file() {
    md5sum "$1" | awk '{print $1}'
}

S1_LL="target/${S1_NAME}.ll"
S2_LL="target/${S2_NAME}.ll"
S1_MD5="$(hash_file "$S1_LL")"
S2_MD5="$(hash_file "$S2_LL")"
SEED_MD5="$(hash_file "$SEED")"

if [ "$S1_MD5" != "$S2_MD5" ]; then
    echo "FAIL: self-host compiler IR is not fixed-point" >&2
    echo "  stage1: $S1_LL md5=$S1_MD5" >&2
    echo "  stage2: $S2_LL md5=$S2_MD5" >&2
    echo "  rerun with NUCLEOR_SELF_HOST_KEEP=1 to preserve artifacts" >&2
    exit 1
fi

if [ "$S2_MD5" != "$SEED_MD5" ]; then
    echo "FAIL: bootstrap seed is stale relative to stage2 compiler IR" >&2
    echo "  stage2: $S2_LL md5=$S2_MD5" >&2
    echo "  seed:   $SEED md5=$SEED_MD5" >&2
    echo "  refresh workflow: see bootstrap/README.md" >&2
    exit 1
fi

echo "OK: self-host compiler IR fixed point holds md5=$S2_MD5"
echo "OK: bootstrap seed matches current self-host IR md5=$SEED_MD5"
