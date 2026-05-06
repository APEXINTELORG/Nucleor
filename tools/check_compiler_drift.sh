#!/usr/bin/env bash
# check_compiler_drift.sh — drift detector. Originally only checked the
# s1-compiler ↔ tools-suite ABI tables; grown to enforce **six things**
# as of v0.2.83:
#
#   1. s1 ↔ tools-suite ABI table parity (the original check; without
#      it the tools binary's compile_file_mode produces unprefixed
#      @<name> calls + missing IR `declare` statements that fail to
#      link).
#   2. s1 ↔ tools-suite compiler identity parity, plus checked-in
#      binary identity parity (prevents stale `nucleor --version`
#      hardcodes).
#   3. helper_manifest.toml freshness vs gen_helper_manifest.py output
#      (since v0.2.42 — Helpers.md going-forward constraint;
#      manifest mech v0.2.41, gate enforcement v0.2.42).
#   4. rod_manifest.toml freshness vs gen_rod_manifest.py output
#      (since v0.2.47).
#   5. RELEASES.md freshness vs gen_releases_index.py output
#      (since v0.2.57).
#   6. CHANGELOG ↔ git-tag parity — every git tag matching `v*` must
#      have a `## [version]` heading in CHANGELOG.md (since v0.2.83).
#
# (Mojibake clean is its own gate step in verify.sh, not part of this
# script — see tools/check_mojibake.sh added v0.2.91.)
#
# History: v0.1.55 caught the original drift symptom for `getenv` /
# `assert_ne`; v0.1.56 bulk-synced 749 entries across get_rt_name
# (351), is_ptr_ret (11), is_ptr_arg (40), and IR `declare` (347).
# Manifest + RELEASES + tag/CHANGELOG checks added v0.2.41–v0.2.83.
#
# Exit 0 = all six checks passed. Exit 1 = some drift detected; the
# script names the failing check and the fix command (typically
# re-run a generator and commit the result).
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

# v0.4.1 RFC-NRT-004 §F: parser-function token-shape parity.
# The original drift gate only enforced ABI-table parity. Parser-
# function divergence (e.g., parse_match_stmt missing the v0.3.79
# return/break/continue arm-body branches OR the v0.3.86 multi-binding
# loop) was un-detectable, leading to silent harness-path breakage:
# `nuc build` was correct on §A/§B/§C while `nuc test` was broken,
# because the harness routes through tools_suite's parser.
#
# The check below extracts a small set of "load-bearing token-shape
# witnesses" from a named parser function in each file and asserts
# both files contain the same set. The witnesses are token-id
# comparisons (`pk(tokens, cp) == NN`) inside the function body --
# these stay stable across cosmetic edits while still flipping
# clearly when a branch is added or removed. False positives are
# fine: they force a manual look at the fn, which is exactly what
# we want when the parser shape changes.
extract_fn_token_witnesses() {
    # $1 = file, $2 = function name
    awk -v fn="$2" '
        $0 ~ "^fn " fn "\\b" { in_block = 1 }
        in_block && /pk\(tokens,[^)]*\) == [0-9]+/ {
            n = split($0, parts, /pk\(tokens,[^)]*\) == /)
            for (i = 2; i <= n; i++) {
                if (match(parts[i], /[0-9]+/, m)) print m[0]
            }
        }
        in_block && /^\}/ { exit }
    ' "$1" | sort -u
}

check_parser_fn_drift() {
    local fn="$1"
    extract_fn_token_witnesses "$S1"    "$fn" > "$TMP/s1_${fn}.txt"
    extract_fn_token_witnesses "$TOOLS" "$fn" > "$TMP/tools_${fn}.txt"
    if [ ! -s "$TMP/s1_${fn}.txt" ] || [ ! -s "$TMP/tools_${fn}.txt" ]; then
        # one side missing the function entirely -- skip rather than
        # false-positive on optional-only-in-s1 helpers
        return 0
    fi
    local missing
    missing=$(comm -23 "$TMP/s1_${fn}.txt" "$TMP/tools_${fn}.txt" | wc -l | tr -d ' ')
    if [ "$missing" -gt 0 ]; then
        echo "DRIFT in parser fn '$fn': $missing token-id checks in s1 missing from tools_suite"
        comm -23 "$TMP/s1_${fn}.txt" "$TMP/tools_${fn}.txt" | sed 's/^/  + missing pk == /'
        echo "  Patch the matching parser branches in compiler/nucleor_tools_suite.nr"
        echo "  to mirror compiler/nucleor_s1_compiler.nr (RFC-NRT-004 §F class)."
        drift_count=$((drift_count + missing))
    fi
}

check_parser_fn_drift parse_match_stmt
check_parser_fn_drift parse_stmt
check_parser_fn_drift parse_expr

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

# v0.8.323: compiler identity drift guard. The CLI version string is
# embedded in compiler source, tools-suite source, the promoted binary,
# and bootstrap seed. Catch stale hardcodes before they reach GitHub.
extract_compiler_version_label() {
    grep -A12 -m1 '^fn compiler_version_label' "$1" \
        | sed -n 's/.*return "\([^"]*\)".*/\1/p' \
        | head -1
}

s1_version="$(extract_compiler_version_label "$S1")"
tools_version="$(extract_compiler_version_label "$TOOLS")"

if [ -z "$s1_version" ] || [ -z "$tools_version" ]; then
    echo "FAIL: could not extract compiler_version_label from compiler sources"
    exit 1
fi

if [ "$s1_version" != "$tools_version" ]; then
    echo "FAIL: compiler_version_label drift:"
    echo "  s1:          $s1_version"
    echo "  tools-suite: $tools_version"
    exit 1
fi

BIN="$ROOT/bin/nucleor"
if [ -x "$ROOT/bin/nucleor.exe" ]; then
    BIN="$ROOT/bin/nucleor.exe"
fi

if [ ! -x "$BIN" ]; then
    echo "FAIL: promoted compiler binary missing: expected bin/nucleor.exe or bin/nucleor"
    exit 1
fi

bin_version_out="$("$BIN" --version 2>/dev/null | head -1 || true)"
case "$bin_version_out" in
    "nucleor $s1_version "*)
        echo "OK: promoted compiler version matches source ($s1_version)"
        ;;
    *)
        echo "FAIL: promoted compiler binary version is stale:"
        echo "  expected: nucleor $s1_version ..."
        echo "  actual:   $bin_version_out"
        echo "Rebuild/promote bin/nucleor.exe and refresh bootstrap/nucleor_s1_seed.ll."
        exit 1
        ;;
esac

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
    local snapshot_norm="$TMP/$(basename "$manifest_path").snapshot.norm"
    local generated_norm="$TMP/$(basename "$manifest_path").generated.norm"
    tr -d '\r' < "$snapshot" > "$snapshot_norm"
    tr -d '\r' < "$manifest_path" > "$generated_norm"
    if ! diff -q "$snapshot_norm" "$generated_norm" >/dev/null 2>&1; then
        echo ""
        echo "FAIL: $manifest_path is stale."
        echo "Re-run the generator and commit the result:"
        echo "  python $gen_path"
        echo "  git add $manifest_path"
        cp "$snapshot" "$manifest_path"
        return 1
    fi
    cp "$snapshot" "$manifest_path"
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

# CHANGELOG ↔ git tag parity (v0.2.83). Catches the v0.1.67 drift
# class — a tag that was pushed without a per-version CHANGELOG
# entry. Skips silently if not in a git repo (e.g. tarball release).
resolve_gitdir_path() {
    local p="$1"
    p="${p//$'\r'/}"
    p="${p//\\//}"
    if [[ "$p" =~ ^([A-Za-z]):/(.*)$ ]]; then
        local drive="${BASH_REMATCH[1],,}"
        echo "/mnt/$drive/${BASH_REMATCH[2]}"
    elif [[ "$p" = /* ]]; then
        echo "$p"
    else
        echo "$ROOT/$p"
    fi
}

collect_git_tags() {
    if command -v git >/dev/null 2>&1; then
        if git -C "$ROOT" tag -l 'v*' 2>/dev/null; then
            return 0
        fi
    fi

    local git_dir=""
    if [ -d "$ROOT/.git" ]; then
        git_dir="$ROOT/.git"
    elif [ -f "$ROOT/.git" ]; then
        local raw_gitdir
        raw_gitdir=$(sed -n 's/^gitdir: //p' "$ROOT/.git")
        [ -n "$raw_gitdir" ] || return 1
        git_dir=$(resolve_gitdir_path "$raw_gitdir")
    else
        return 1
    fi
    [ -d "$git_dir" ] || return 1

    local common_dir="$git_dir"
    if [ -f "$git_dir/commondir" ]; then
        local common_rel
        common_rel=$(tr -d '\r' < "$git_dir/commondir")
        if [[ "$common_rel" = /* || "$common_rel" =~ ^[A-Za-z]:/ ]]; then
            common_dir=$(resolve_gitdir_path "$common_rel")
        else
            common_dir=$(cd "$git_dir/$common_rel" 2>/dev/null && pwd -P) || return 1
        fi
    fi
    [ -d "$common_dir" ] || return 1

    {
        if [ -d "$common_dir/refs/tags" ]; then
            (cd "$common_dir/refs/tags" && find . -type f | sed 's#^\./##')
        fi
        if [ -f "$common_dir/packed-refs" ]; then
            sed -n 's#^[0-9a-f][0-9a-f]* refs/tags/##p' "$common_dir/packed-refs" | sed 's/\^{}$//'
        fi
    } | grep '^v' | sort -u
}

if tag_list=$(collect_git_tags); then
    tag_set=$(echo "$tag_list" | sed 's/^v//' | sort -u)
    ch_set=$(grep -oE '^## \[[0-9.]+\]' "$ROOT/CHANGELOG.md" | sed 's/^## \[//; s/\]$//' | sort -u)
    missing_in_ch=$(comm -23 <(echo "$tag_set") <(echo "$ch_set"))
    if [ -n "$missing_in_ch" ]; then
        echo "FAIL: git tags exist with no CHANGELOG entry:"
        echo "$missing_in_ch" | sed 's/^/  - v/'
        echo "Add a per-version block to CHANGELOG.md or remove the stray tag."
        exit 1
    fi
    echo "OK: CHANGELOG.md covers every git tag"
fi

exit 0
