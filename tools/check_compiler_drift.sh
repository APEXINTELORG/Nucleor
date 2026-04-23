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

# --- Manifest freshness check (added v0.2.42) ---
# Per the v0.2.33 going-forward constraint: every commit that adds a
# helper must also regenerate docs/rfcs/helper_manifest.toml. Re-run
# the generator and diff against the committed file.
MANIFEST="$ROOT/docs/rfcs/helper_manifest.toml"
GEN="$ROOT/tools/gen_helper_manifest.py"

if [ -f "$GEN" ] && [ -f "$MANIFEST" ]; then
    if ! command -v python >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
        echo "WARN: python not in PATH — skipping manifest freshness check"
        exit 0
    fi
    PYTHON=python
    command -v python >/dev/null 2>&1 || PYTHON=python3
    # Snapshot the committed manifest, regenerate, diff, then restore.
    SNAPSHOT="$TMP/manifest_committed.toml"
    cp "$MANIFEST" "$SNAPSHOT"
    "$PYTHON" "$GEN" >/dev/null 2>&1 || {
        echo "FAIL: gen_helper_manifest.py crashed."
        cp "$SNAPSHOT" "$MANIFEST"
        exit 1
    }
    if ! diff -q "$SNAPSHOT" "$MANIFEST" >/dev/null 2>&1; then
        echo ""
        echo "FAIL: docs/rfcs/helper_manifest.toml is stale."
        echo "Re-run the generator and commit the result:"
        echo "  python tools/gen_helper_manifest.py"
        echo "  git add docs/rfcs/helper_manifest.toml"
        # Restore so the working tree isn't muddled by the diff probe
        cp "$SNAPSHOT" "$MANIFEST"
        exit 1
    fi
    echo "OK: docs/rfcs/helper_manifest.toml is up to date"
fi

exit 0
