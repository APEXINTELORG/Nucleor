#!/usr/bin/env bash
# check_rt_name_table.sh — drift gate for the get_rt_name dispatch.
#
# Source-of-truth chain:
#
#   compiler/s1/get_rt_name.tsv      (canonical; edit this)
#                |
#                v   tools/gen_rt_name_fn.nr
#                |
#   compiler/s1/get_rt_name.gen.nr   (auto-generated; checked in)
#                |
#                v   import directive in compiler/s1/builtins.nr
#                |
#   inlined into the compiler source at build time
#
# This script enforces the .tsv ⇄ .gen.nr leg. It re-runs the generator
# against the current TSV (in-memory) and diffs the result against the
# committed .gen.nr file; any drift fails the gate. The .gen.nr ⇄
# inlined-compiler leg is trivially enforced by the bootstrap fixed
# point — if the .gen.nr changes, the stage-2 IR changes, and the seed
# regen is mandatory.

set -euo pipefail

TSV=compiler/s1/get_rt_name.tsv
GEN=compiler/s1/get_rt_name.gen.nr
GENERATOR_SRC=tools/gen_rt_name_fn.nr
GENERATOR_BIN=target/gen_rt_name_fn

if [[ ! -f $TSV ]]; then
  echo "ERROR: $TSV not found"
  exit 1
fi
if [[ ! -f $GEN ]]; then
  echo "ERROR: $GEN not found"
  exit 1
fi
if [[ ! -f $GENERATOR_SRC ]]; then
  echo "ERROR: $GENERATOR_SRC not found"
  exit 1
fi

# Ensure the generator is built (mirrors how verify.sh re-builds other tools).
if [[ ! -x $GENERATOR_BIN || $GENERATOR_SRC -nt $GENERATOR_BIN ]]; then
  ./bin/nucleor build "$GENERATOR_SRC" -o "$(basename "$GENERATOR_BIN")" >/dev/null 2>&1
fi

# Run the generator into a temp file (it writes to a fixed path; we
# stash and restore the committed file around the invocation).
TMP_OUT=$(mktemp)
trap 'rm -f "$TMP_OUT"' EXIT

cp "$GEN" "$TMP_OUT"
"./$GENERATOR_BIN" >/dev/null
# Now $GEN is the freshly-generated output; $TMP_OUT is the committed version.
# Compare line-ending-insensitively: the generator emits LF, but a checkout
# with core.autocrlf=true (common on Windows) stores the committed file as
# CRLF. A byte-exact cmp would then false-fail on Windows even though the
# content is identical. Strip CR from both sides so the gate enforces
# content drift on every platform, independent of git's EOL handling.
if diff -q <(tr -d '\r' < "$GEN") <(tr -d '\r' < "$TMP_OUT") >/dev/null 2>&1; then
  cp "$TMP_OUT" "$GEN"
  entries=$(grep -c "if str_eq" "$GEN")
  echo "OK: get_rt_name generator output matches committed $GEN ($entries entries)"
  exit 0
fi

# Drift detected. Show a brief diff and restore the committed file
# so this script is non-destructive when run without --regen.
echo "FAIL: $GEN differs from generator output of $TSV"
echo "--- committed ($GEN) vs regenerated:"
diff "$TMP_OUT" "$GEN" | head -20 || true
cp "$TMP_OUT" "$GEN"
echo
echo "Run './$GENERATOR_BIN' (after building it from $GENERATOR_SRC) to"
echo "regenerate $GEN, then commit the result alongside the TSV edit."
exit 1
