#!/usr/bin/env bash
# check_compiler_drift.sh — verify the s1-compiler ↔ tools-suite ABI tables
# stay in sync. Without this check, the tools binary's compile_file_mode
# (used by `nuc test`, `nuc build-strict`, `nuc check`) silently drifts
# from the s1 emit path and produces unprefixed @<name> calls + missing
# IR `declare` statements that fail to link.
#
# History: v0.1.55 caught the symptom for `getenv`/`assert_ne`; v0.1.56
# bulk-synced 749 entries across get_rt_name (351), is_ptr_ret (11),
# is_ptr_arg (40), and IR `declare` (347).
#
# Exit 0 = synced. Exit 1 = drift detected; commit must add the missing
# entries to compiler/nucleor_tools_suite.nr (or remove from s1).
#
# Usage: ./tools/check_compiler_drift.sh

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S1="$ROOT/compiler/nucleor_s1_compiler.nr"
TOOLS="$ROOT/compiler/nucleor_tools_suite.nr"

[ -f "$S1" ] || { echo "ERROR: missing $S1"; exit 1; }
[ -f "$TOOLS" ] || { echo "ERROR: missing $TOOLS"; exit 1; }

TMP="$(mktemp -d)"
trap "rm -rf $TMP" EXIT

extract_get_rt_name() {
    grep -E 'if str_eq\(name, "[^"]+"\) \{ return "__nucleor_' "$1" \
        | sed -E 's/.*if str_eq\(name, "([^"]+)"\).*return "([^"]+)".*/\1\t\2/' \
        | sort -u
}

extract_fn_block_names() {
    # $1 = file, $2 = function name (e.g. is_ptr_ret)
    awk -v fn="$2" '
        $0 ~ "^fn " fn "\\b" { in_block = 1 }
        in_block && /str_eq\(name, "[^"]+"\)/ {
            if (match($0, /str_eq\(name, "([^"]+)"\)/, m)) print m[1]
        }
        in_block && /^\}/ { exit }
    ' "$1" | sort -u
}

extract_decls() {
    grep -E 'sb_append\(sb, "declare ' "$1" | sort -u
}

# --- Diff each table ---
extract_get_rt_name "$S1"    > "$TMP/s1_rt.txt"
extract_get_rt_name "$TOOLS" > "$TMP/tools_rt.txt"
extract_fn_block_names "$S1"    is_ptr_ret > "$TMP/s1_pr.txt"
extract_fn_block_names "$TOOLS" is_ptr_ret > "$TMP/tools_pr.txt"
extract_fn_block_names "$S1"    is_ptr_arg > "$TMP/s1_pa.txt"
extract_fn_block_names "$TOOLS" is_ptr_arg > "$TMP/tools_pa.txt"
extract_decls "$S1"    > "$TMP/s1_dec.txt"
extract_decls "$TOOLS" > "$TMP/tools_dec.txt"

drift_count=0
report_drift() {
    local name="$1" left="$2" right="$3"
    local missing
    missing=$(comm -23 "$left" "$right" | wc -l | tr -d ' ')
    if [ "$missing" -gt 0 ]; then
        echo "DRIFT in $name: $missing entries in s1 but missing from tools"
        comm -23 "$left" "$right" | sed 's/^/  + /' | head -20
        if [ "$missing" -gt 20 ]; then
            echo "  ... and $((missing - 20)) more"
        fi
        drift_count=$((drift_count + missing))
    fi
}

report_drift "get_rt_name"  "$TMP/s1_rt.txt"  "$TMP/tools_rt.txt"
report_drift "is_ptr_ret"   "$TMP/s1_pr.txt"  "$TMP/tools_pr.txt"
report_drift "is_ptr_arg"   "$TMP/s1_pa.txt"  "$TMP/tools_pa.txt"
report_drift "IR declare"   "$TMP/s1_dec.txt" "$TMP/tools_dec.txt"

if [ "$drift_count" -gt 0 ]; then
    echo ""
    echo "FAIL: $drift_count total entries drifted."
    echo "Add the missing rows to compiler/nucleor_tools_suite.nr — they"
    echo "must mirror nucleor_s1_compiler.nr or compile_file_mode (which"
    echo "powers \`nuc test\`, \`nuc build-strict\`, \`nuc check\`)"
    echo "will emit unprefixed @<name> calls and miss IR declares."
    exit 1
fi

echo "OK: tools-suite ABI tables match nucleor_s1_compiler.nr"

# --- Manifest freshness checks ---
# v0.2.42 added helper_manifest.toml enforcement.
# v0.2.47 generalized to any manifest under docs/rfcs/ that has a
# matching tools/gen_*_manifest.py generator. Each freshness check
# regenerates the manifest, diffs against the committed snapshot, and
# fails the gate if they differ.

# Resolve PYTHON once for all manifest checks.
PYTHON=""
if command -v python >/dev/null 2>&1; then
    PYTHON=python
elif command -v python3 >/dev/null 2>&1; then
    PYTHON=python3
fi

check_manifest() {
    local label="$1" gen_path="$2" manifest_path="$3"
    if [ ! -f "$gen_path" ] || [ ! -f "$manifest_path" ]; then
        return 0
    fi
    if [ -z "$PYTHON" ]; then
        echo "WARN: python not in PATH — skipping $label freshness check"
        return 0
    fi
    local snapshot="$TMP/$(basename "$manifest_path").snapshot"
    cp "$manifest_path" "$snapshot"
    "$PYTHON" "$gen_path" >/dev/null 2>&1 || {
        echo "FAIL: $(basename "$gen_path") crashed."
        cp "$snapshot" "$manifest_path"
        return 1
    }
    if ! diff -q "$snapshot" "$manifest_path" >/dev/null 2>&1; then
        echo ""
        echo "FAIL: $manifest_path is stale."
        echo "Re-run the generator and commit the result:"
        echo "  python $gen_path"
        echo "  git add $manifest_path"
        cp "$snapshot" "$manifest_path"
        return 1
    fi
    echo "OK: $(basename "$manifest_path") is up to date"
    return 0
}

# helper_manifest — Helpers.md going-forward constraint (v0.2.33+, gate v0.2.42)
check_manifest "helper_manifest" \
    "$ROOT/tools/gen_helper_manifest.py" \
    "$ROOT/docs/rfcs/helper_manifest.toml" || exit 1

# rod_manifest — companion gate enforcement (v0.2.47)
check_manifest "rod_manifest" \
    "$ROOT/tools/gen_rod_manifest.py" \
    "$ROOT/docs/rfcs/rod_manifest.toml" || exit 1

# RELEASES.md — tag-only index regenerated from CHANGELOG.md (v0.2.57)
check_manifest "RELEASES.md" \
    "$ROOT/tools/gen_releases_index.py" \
    "$ROOT/RELEASES.md" || exit 1

exit 0
