#!/usr/bin/env bash
# check_mojibake.sh — flag cp1252-as-utf8 mojibake byte sequences across
# source/doc files.
#
# Background: when a file written as UTF-8 is read as cp1252 and re-saved
# as UTF-8, the multi-byte UTF-8 of em-dash (—, U+2014, 3 bytes E2 80 94)
# becomes the cp1252 trio "â€"" which re-encodes as 5 UTF-8 bytes
# C3 A2 E2 82 AC. The byte sequence `c3 a2 e2 82 ac` is the universal
# fingerprint of this drift class.
#
# Caught the v0.2.58 rod-manifest mojibake, the v0.2.90 vqe_h2.nr header
# mojibake, and a self-defeating mojibake re-introduced in CHANGELOG entry
# v0.2.90 (fixed in v0.2.91).
#
# Usage: bash tools/check_mojibake.sh
# Exit: 0 if clean, 1 if any matches found.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Files we audit. Skip target/, .git/, node_modules/, and binary blobs.
mapfile -t files < <(find . \
    -path './.git' -prune -o \
    -path './target' -prune -o \
    -path './node_modules' -prune -o \
    -path './bin' -prune -o \
    -type f \( \
        -name '*.md' -o \
        -name '*.nr' -o \
        -name '*.toml' -o \
        -name '*.py' -o \
        -name '*.sh' -o \
        -name '*.ps1' -o \
        -name '*.c' -o \
        -name '*.h' -o \
        -name '*.txt' \
    \) -print)

# v0.4.29: filter the self-reference up front so we can pass the entire
# file list to a SINGLE grep invocation rather than spawning ~3000 greps.
# On Windows this drops the verify step from ~18s to under 2s.
filtered=()
for f in "${files[@]}"; do
    case "$f" in
        ./tools/check_mojibake.sh) continue ;;
    esac
    filtered+=("$f")
done

found=0
# Single batch grep — `LC_ALL=C grep -lP` matches raw bytes via PCRE
# \xNN escapes without locale interference. -l prints only matching paths;
# rc 1 (no matches) is the OK case so we tolerate it via `|| true`.
flagged=$(LC_ALL=C grep -lP '\xc3\xa2\xe2\x82\xac' "${filtered[@]}" 2>/dev/null || true)
if [ -n "$flagged" ]; then
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        echo "FAIL: mojibake bytes (c3 a2 e2 82 ac = cp1252-as-utf8 'â€') in $f"
        found=1
    done <<< "$flagged"
fi

if [ $found -eq 0 ]; then
    echo "OK: no mojibake byte sequences detected"
    exit 0
fi

cat <<'EOF'

The flagged files contain the universal cp1252-rendered-as-UTF-8
mojibake byte sequence. Most often this is an em-dash or en-dash that
was mis-decoded somewhere in the editing pipeline. Fix by replacing
the bad bytes with the correct character:

  em-dash:  — (U+2014, UTF-8: e2 80 94)
  en-dash:  – (U+2013, UTF-8: e2 80 93)
  curly-r:  " (U+201D, UTF-8: e2 80 9d)
  curly-l:  " (U+201C, UTF-8: e2 80 9c)

If you must write about the mojibake itself in a CHANGELOG entry,
describe the bytes in hex rather than embedding the literal sequence
(see v0.2.91 CHANGELOG for the precedent).
EOF
exit 1
