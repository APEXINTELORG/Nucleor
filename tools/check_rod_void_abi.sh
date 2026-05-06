#!/usr/bin/env bash
# check_rod_void_abi.sh -- fail when a rod extern claims a value return
# for a C runtime function implemented as void.
#
# This guards the NN/GNN drift class fixed in v0.8.322 without adding
# compiler/runtime hot-path work or requiring Python.
#
# Usage: bash tools/check_rod_void_abi.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cd "$ROOT" || exit 1

find stdlib -type f \( -name '*.c' -o -name '*.h' \) -exec awk '
        {
            line = $0
            sub(/\r$/, "", line)
            sub(/\/\/.*/, "", line)
            if (line ~ /^[ \t]*(static[ \t]+)?void[ \t]+nuc_[A-Za-z0-9_]+[ \t]*\(/) {
                name = line
                sub(/^[ \t]*(static[ \t]+)?void[ \t]+/, "", name)
                sub(/[ \t]*\(.*$/, "", name)
                print name "\t" FILENAME ":" FNR
            }
        }
    ' {} + | sort -u > "$TMP/c_void.tsv"

find stdlib/rods -type f -name '*.nr' -exec awk '
        FNR == 1 {
            in_decl = 0
            decl = ""
            start_line = 0
        }

        function emit_decl(    clean, name, ret, after) {
            clean = decl
            gsub(/\r/, "", clean)
            if (clean !~ /extern[ \t\n]+fn[ \t\n]+nuc_[A-Za-z0-9_]+[ \t\n]*\(/) {
                return
            }

            name = clean
            sub(/^.*extern[ \t\n]+fn[ \t\n]+/, "", name)
            sub(/[ \t\n]*\(.*$/, "", name)

            ret = "void"
            if (clean ~ /\)[ \t\n]*->[ \t\n]*/) {
                after = clean
                sub(/^.*\)[ \t\n]*->[ \t\n]*/, "", after)
                sub(/[ \t\n]*;.*/, "", after)
                gsub(/[ \t\n]+/, " ", after)
                ret = after
            }

            if (ret != "void") {
                print name "\t" ret "\t" FILENAME ":" start_line
            }
        }

        {
            line = $0
            sub(/\r$/, "", line)
            sub(/\/\/.*/, "", line)
            if (!in_decl && line ~ /extern[ \t]+fn[ \t]+nuc_/) {
                in_decl = 1
                decl = line
                start_line = FNR
                if (line ~ /;/) {
                    emit_decl()
                    in_decl = 0
                }
                next
            }

            if (in_decl) {
                decl = decl "\n" line
                if (line ~ /;/) {
                    emit_decl()
                    in_decl = 0
                }
            }
        }
    ' {} + | sort -u > "$TMP/nr_nonvoid.tsv"

awk -F '\t' '
    NR == FNR {
        if ($1 in c_void) {
            c_void[$1] = c_void[$1] ", " $2
        } else {
            c_void[$1] = $2
        }
        next
    }
    $1 in c_void {
        printf("FAIL: %s declares return %s at %s but C implementation is void at %s\n",
               $1, $2, $3, c_void[$1])
        found = 1
    }
    END {
        if (found) {
            exit 1
        }
    }
' "$TMP/c_void.tsv" "$TMP/nr_nonvoid.tsv" > "$TMP/mismatches.txt"

if [ $? -ne 0 ]; then
    cat "$TMP/mismatches.txt"
    exit 1
fi

void_count=$(wc -l < "$TMP/c_void.tsv" | tr -d ' ')
extern_count=$(wc -l < "$TMP/nr_nonvoid.tsv" | tr -d ' ')
echo "OK: rod void ABI clean (${void_count} C void nuc_* definitions, ${extern_count} non-void rod externs checked)"
exit 0
