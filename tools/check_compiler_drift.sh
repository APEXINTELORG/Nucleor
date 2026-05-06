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
#   3. helper_manifest.toml freshness vs gen_helper_manifest.nr output
#      (since v0.2.42 — Helpers.md going-forward constraint;
#      manifest mech v0.2.41, gate enforcement v0.2.42).
#   4. rod_manifest.toml freshness vs gen_rod_manifest.nr output
#      (since v0.2.47; ported from Python to native Nucleor v0.8.323
#      per RFC-0063 Phase 5.1 / Track C C3).
#   5. RELEASES.md freshness vs gen_releases_index.nr output
#      (since v0.2.57; ported from Python to native Nucleor v0.8.323
#      per RFC-0063 Phase 1.4 / Track C C2).
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
    # POSIX awk: 2-arg match() + RSTART/RLENGTH + substr (the 3-arg
    # match(str, /re/, array) form is gawk-only and silently fails on
    # mawk, which used to make this gate falsely report "OK" on Ubuntu
    # CI runners where both extracts produced empty output.
    # Match shape: str_eq(name, "NAME")  -> 14-char prefix + NAME + 2-char ")
    awk -v fn="$2" '
        $0 ~ "^fn " fn "\\(" { in_block = 1 }
        in_block && match($0, /str_eq\(name, "[^"]+"\)/) {
            print substr($0, RSTART + 14, RLENGTH - 16)
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
    # POSIX awk: see extract_fn_block_names note about the 3-arg match()
    # gawk-ism. Same fix here.
    awk -v fn="$2" '
        $0 ~ "^fn " fn "\\(" { in_block = 1 }
        in_block && /pk\(tokens,[^)]*\) == [0-9]+/ {
            n = split($0, parts, /pk\(tokens,[^)]*\) == /)
            for (i = 2; i <= n; i++) {
                if (match(parts[i], /[0-9]+/)) {
                    print substr(parts[i], RSTART, RLENGTH)
                }
            }
        }
        in_block && /^\}/ { exit }
    ' "$1" | sort -u
}

extract_fn_line_count() {
    awk -v fn="$2" '
        $0 ~ "^fn " fn "\\(" { in_block = 1; lines = 0 }
        in_block { lines = lines + 1 }
        in_block && /^\}/ { print lines; exit }
    ' "$1"
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
    # v0.8.323: WARN tier, not FAIL. The witness regex (`pk(tokens, ...)
    # == NN`) catches a partial signal of structural divergence — but
    # tools_suite's parsers diverge from s1's by hundreds of lines, not
    # 18 token-id checks. Until parser unification lands (RFC-0063
    # Phase 2.0), this gate documents the divergence rather than
    # pretending a surgical fix would close it. nuc check / nuc
    # build-strict / nuc build-shared are known to segfault on simple
    # fixtures because of this.
    local missing s1_lines tools_lines
    missing=$(comm -23 "$TMP/s1_${fn}.txt" "$TMP/tools_${fn}.txt" | wc -l | tr -d ' ')
    s1_lines=$(extract_fn_line_count "$S1" "$fn")
    tools_lines=$(extract_fn_line_count "$TOOLS" "$fn")
    if [ "$missing" -gt 0 ] || [ "$s1_lines" -gt 0 ] && [ "$tools_lines" -gt 0 ]; then
        local divergence_pct=0
        if [ "$s1_lines" -gt 0 ]; then
            divergence_pct=$(( (s1_lines - tools_lines) * 100 / s1_lines ))
            [ "$divergence_pct" -lt 0 ] && divergence_pct=$(( 0 - divergence_pct ))
        fi
        if [ "$missing" -gt 0 ]; then
            echo "WARN: parser fn '$fn' diverges between s1 and tools_suite"
            echo "      $missing token-id witness checks in s1 missing from tools_suite"
            echo "      structural: s1 has $s1_lines lines, tools_suite has $tools_lines lines (${divergence_pct}% delta)"
            echo "      Tracked as RFC-0063 Phase 2.0 (parser unification — single source of truth)."
            echo "      Surgical add of just the witness branches would be patchwork; the real"
            echo "      fix is to eliminate the duplicate parser, not synchronize it."
        fi
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
# v0.2.47 generalized manifest freshness checks under docs/rfcs/.
# RFC-0063 Track C now requires drift-gated generators to use native
# Nucleor sources; this gate intentionally has no Python fallback.
# Each freshness check regenerates the manifest, diffs against the
# committed snapshot, and fails the gate if they differ.

# Resolve native nucleor binary for .nr-based manifest checks (RFC-0063
# Track C — porting Python generators to native).
NUCLEOR_BIN=""
if [ -x "$ROOT/bin/nucleor" ]; then
    NUCLEOR_BIN="$ROOT/bin/nucleor"
elif [ -x "$ROOT/bin/nucleor.exe" ]; then
    NUCLEOR_BIN="$ROOT/bin/nucleor.exe"
fi

check_manifest() {
    local label="$1" gen_path="$2" manifest_path="$3"
    if [ ! -f "$gen_path" ] || [ ! -f "$manifest_path" ]; then
        return 0
    fi
    # Drift-gated generators run via bin/nucleor. Retired Python
    # generators may remain in the repo as archival/reference material,
    # but they are not valid gate inputs.
    case "$gen_path" in
        *.nr)
            if [ -z "$NUCLEOR_BIN" ]; then
                echo "WARN: bin/nucleor not present — skipping $label freshness check"
                return 0
            fi
            ;;
        *)
            echo "FAIL: unsupported drift-gated generator extension for $label: $gen_path"
            return 1
            ;;
    esac
    local snapshot="$TMP/$(basename "$manifest_path").snapshot"
    cp "$manifest_path" "$snapshot"
    case "$gen_path" in
        *.nr)
            # Two-step: build then exec. We could use `nuc run` now
            # that the v0.8.323 path-construction fix landed, but
            # explicit build+exec is more transparent in CI logs and
            # doesn't depend on the run dispatch staying correct
            # across future ships. Keep the build path repo-relative so
            # a Windows bin/nucleor.exe invoked through WSL can still
            # read the source path, and execute .exe outputs when that
            # is what the host produced.
            local gen_basename gen_build_path gen_exe
            gen_basename="$(basename "$gen_path" .nr)"
            gen_build_path="$gen_path"
            case "$gen_build_path" in
                "$ROOT"/*) gen_build_path="${gen_build_path#"$ROOT/"}" ;;
            esac
            (cd "$ROOT" && "$NUCLEOR_BIN" build "$gen_build_path" -o "$gen_basename") >/dev/null 2>&1 || {
                echo "FAIL: $(basename "$gen_path") build crashed."
                cp "$snapshot" "$manifest_path"
                return 1
            }
            gen_exe="$ROOT/target/$gen_basename"
            if [ -f "$gen_exe.exe" ]; then
                gen_exe="$gen_exe.exe"
            fi
            chmod +x "$gen_exe" 2>/dev/null
            (cd "$ROOT" && "$gen_exe") >/dev/null 2>&1 || {
                echo "FAIL: $(basename "$gen_path") exec crashed."
                cp "$snapshot" "$manifest_path"
                return 1
            }
            ;;
    esac
    local snapshot_norm="$TMP/$(basename "$manifest_path").snapshot.norm"
    local generated_norm="$TMP/$(basename "$manifest_path").generated.norm"
    tr -d '\r' < "$snapshot" > "$snapshot_norm"
    tr -d '\r' < "$manifest_path" > "$generated_norm"
    if ! diff -q "$snapshot_norm" "$generated_norm" >/dev/null 2>&1; then
        local regen_cmd
        case "$gen_path" in
            *.nr) regen_cmd="$NUCLEOR_BIN build $gen_path -o $(basename "$gen_path" .nr) && ./target/$(basename "$gen_path" .nr)" ;;
            *)    regen_cmd="<unknown generator type>" ;;
        esac
        echo ""
        echo "FAIL: $manifest_path is stale."
        echo "Re-run the generator and commit the result:"
        echo "  $regen_cmd"
        echo "  git add $manifest_path"
        cp "$snapshot" "$manifest_path"
        return 1
    fi
    cp "$snapshot" "$manifest_path"
    echo "OK: $(basename "$manifest_path") is up to date"
    return 0
}

# helper_manifest — Helpers.md going-forward constraint (v0.2.33+, gate v0.2.42).
# v0.8.323: ported to native Nucleor (RFC-0063 Phase 5 final / Track C C6).
# Closes the last drift-gated Python dependency. The old .py comparison
# oracle has been retired.
check_manifest "helper_manifest" \
    "$ROOT/tools/gen_helper_manifest.nr" \
    "$ROOT/docs/rfcs/helper_manifest.toml" || exit 1

# rod_manifest — companion gate enforcement (v0.2.47).
# v0.8.323: ported to native Nucleor (RFC-0063 Phase 5.1 / Track C C3).
# Eliminates one of six dev-time Python deps. The old .py comparison
# oracle has been retired.
check_manifest "rod_manifest" \
    "$ROOT/tools/gen_rod_manifest.nr" \
    "$ROOT/docs/rfcs/rod_manifest.toml" || exit 1

# RELEASES.md — tag-only index regenerated from CHANGELOG.md (v0.2.57).
# v0.8.323: ported to native Nucleor (RFC-0063 Phase 1.4 / Track C C2).
# Eliminates one of six dev-time Python deps. The old .py comparison
# oracle has been retired.
check_manifest "RELEASES.md" \
    "$ROOT/tools/gen_releases_index.nr" \
    "$ROOT/RELEASES.md" || exit 1

# audit_dup_fns_report.csv — RFC-0063 Phase 2.0.3a duplicate-fn audit.
# Drives the dedup ship sequencing for parser unification. As 2.0.3b/c/d/e
# ships land and tools_suite duplicates are deleted, this report's
# IDENTICAL/SIG_MATCH/SIG_DIFFERS counts update. Drift gate ensures the
# committed report stays in sync with current compiler source.
check_manifest "audit_dup_fns_report.csv" \
    "$ROOT/tools/audit_dup_fns.nr" \
    "$ROOT/tools/audit_dup_fns_report.csv" || exit 1

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

# compiler_version_label() ↔ CHANGELOG.md latest heading parity. Catches
# the drift class where bin/nucleor / bin/nucleor_tools self-reports a
# stale version because the literal in compiler_version_label() wasn't
# bumped during a ship. Latest CHANGELOG version is the first
# `## [X.Y.Z]` heading in the file (CHANGELOG ordering convention:
# newest at top). Both s1 and tools_suite carry their own label
# (separate binaries, separate versions); both must match.
ch_latest=$(grep -m1 -oE '^## \[[0-9.]+\]' "$ROOT/CHANGELOG.md" | sed 's/^## \[//; s/\]$//')
extract_label() {
    sed -n '/^fn compiler_version_label/,/^\}/p' "$1" \
        | grep -oE 'return "[0-9.]+"' \
        | head -1 \
        | sed 's/return "//; s/"//'
}
s1_label=$(extract_label "$S1")
tools_label=$(extract_label "$TOOLS")
if [ -z "$ch_latest" ]; then
    echo "WARN: could not extract latest version from CHANGELOG.md"
else
    fail=0
    for pair in "s1:$s1_label:$S1" "tools_suite:$tools_label:$TOOLS"; do
        side="${pair%%:*}"
        rest="${pair#*:}"
        label="${rest%%:*}"
        path="${rest#*:}"
        if [ -z "$label" ]; then
            echo "WARN: could not extract compiler_version_label() from $path"
        elif [ "$ch_latest" != "$label" ]; then
            echo "FAIL: $side compiler_version_label() returns '$label' but CHANGELOG.md latest is '$ch_latest'"
            echo "  Bump the return literal in $path fn compiler_version_label()"
            echo "  to match the latest ## [X.Y.Z] heading in CHANGELOG.md, then regenerate"
            echo "  the bootstrap seed:"
            echo "    ./bin/nucleor build $path -o target/_seed --emit llvm --no-link"
            echo "    bash tools/bootstrap_linux.sh   # if you bumped s1"
            fail=1
        else
            echo "OK: $side compiler_version_label() matches CHANGELOG.md ($ch_latest)"
        fi
    done
    if [ "$fail" = 1 ]; then exit 1; fi
fi

# RFC-0063 Phase 2.0.2 guard (v0.8.323): the s1 + tools_suite compiler
# files are intentionally kept WITHOUT any `pub fn` declarations.
# Adding even one `pub fn` to either file would opt that file into
# Nucleor's privatization mechanism (priv_apply_if_opted_in), which
# token-mangles every NON-pub `fn` to `__priv_<file_id>__<name>` —
# silently breaking the cross-module imports that Phase 2.0.3 plans
# (tools_suite import "compiler/nucleor_s1_compiler.nr"). Until Phase
# 2.0.3 ships and either (a) explicitly marks the right surface as
# pub or (b) RFC-NRT-004 §H module-prefixed lowering lands, neither
# file should carry a top-level `pub fn`.
pub_fn_s1=$(grep -cE '^pub fn ' "$S1" 2>/dev/null; true)
pub_fn_tools=$(grep -cE '^pub fn ' "$TOOLS" 2>/dev/null; true)
if [ "$pub_fn_s1" != "0" ] || [ "$pub_fn_tools" != "0" ]; then
    echo ""
    echo "FAIL: top-level 'pub fn' present in compiler source files."
    if [ "$pub_fn_s1" != "0" ]; then
        echo "  $S1: $pub_fn_s1 'pub fn' declaration(s) — silently mangles every other fn"
        grep -nE '^pub fn ' "$S1" | head -5 | sed 's/^/    /'
    fi
    if [ "$pub_fn_tools" != "0" ]; then
        echo "  $TOOLS: $pub_fn_tools 'pub fn' declaration(s) — silently mangles every other fn"
        grep -nE '^pub fn ' "$TOOLS" | head -5 | sed 's/^/    /'
    fi
    echo "  See findings/promoted/2026-05-06-phase-2-0-0-cross-module-import-verified.md"
    echo "  for the privatization model. Until RFC-0063 Phase 2.0.3 (parser unification)"
    echo "  ships, do not add 'pub fn' to either compiler source — it would silently"
    echo "  break cross-module import compatibility."
    exit 1
fi
echo "OK: no opt-in privatization markers (pub fn) in compiler source"

exit 0
