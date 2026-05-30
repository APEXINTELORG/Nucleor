#!/usr/bin/env bash
# check_explain_error_table.sh — drift gate for the `nuc explain` text table.
#
#   compiler/ts/explain_error.tsv      (canonical; edit this)
#        | tools/gen_explain_error.nr
#        v
#   compiler/ts/explain_error.gen.nr   (auto-generated; checked in,
#                                        imported by nucleor_tools_suite.nr)
#
# Re-runs the generator against the committed TSV and diffs the result
# against the committed .gen.nr; any drift fails the gate. (DUP-7.)
set -euo pipefail
TSV=compiler/ts/explain_error.tsv
GEN=compiler/ts/explain_error.gen.nr
GENERATOR_SRC=tools/gen_explain_error.nr
GENERATOR_BIN=target/gen_explain_error
for f in "$TSV" "$GEN" "$GENERATOR_SRC"; do
  [[ -f $f ]] || { echo "ERROR: $f not found"; exit 1; }
done
if [[ ! -x $GENERATOR_BIN || $GENERATOR_SRC -nt $GENERATOR_BIN ]]; then
  ./bin/nucleor build "$GENERATOR_SRC" -o "$(basename "$GENERATOR_BIN")" >/dev/null 2>&1
fi
TMP_OUT=$(mktemp); trap 'rm -f "$TMP_OUT"' EXIT
cp "$GEN" "$TMP_OUT"
"./$GENERATOR_BIN" >/dev/null
# Line-ending-insensitive compare (see check_rt_name_table.sh): the generator
# writes LF; core.autocrlf=true stores the committed .gen.nr as CRLF, which a
# byte-exact cmp would false-flag on Windows. Strip CR so only real content
# drift fails the gate, on any platform.
if diff -q <(tr -d '\r' < "$GEN") <(tr -d '\r' < "$TMP_OUT") >/dev/null 2>&1; then
  cp "$TMP_OUT" "$GEN"
  entries=$(grep -c "if str_eq" "$GEN")
  echo "OK: explain_error generator output matches committed $GEN ($entries arms)"
  exit 0
else
  echo "FAIL: $GEN is stale vs $TSV. Re-run: ./bin/nucleor build $GENERATOR_SRC -o gen_explain_error && ./target/gen_explain_error; git add $GEN"
  diff "$TMP_OUT" "$GEN" | head -20 || true
  cp "$TMP_OUT" "$GEN"
  exit 1
fi
