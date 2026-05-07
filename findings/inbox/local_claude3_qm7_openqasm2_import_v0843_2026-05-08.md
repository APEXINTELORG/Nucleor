# local Claude3 — QM-7 OpenQASM 2.0 minimal parser closes round-trip (v0843)

**Date:** 2026-05-08
**Spike:** self-picked follow-up to the v0842 emit-only ship; closes the
"OpenQASM 2.0 import / parser round-trip" item I left open in the v0842
findings.
**Branch:** `fix/local-claude3-qm7-openqasm2-import-v0843`
**HEAD:** `ee45d0caecfe4ca4d90b7de733a94053f6a33968`
**Base / merge-base:** `49d949d2269b69c1d7aabcb7faf7e6ac2e8242fb`
(origin/main `tests: align env_get fixture with string return`).
Origin/main already integrates `0daec53a qm7: minimal OpenQASM 2.0 emit-only stdlib surface`
and `b398b532 qm6: bounded MPS streaming-range fold helpers`, so this spike
builds directly on top of the v0842 emit surface.

## What shipped

A deterministic, dialect-restricted OpenQASM 2.0 parser in
`stdlib/rods/quantum.nr`. The parser accepts **only** the exact byte
format that `qasm2_render` produces — fixed three-line header plus
per-line H/X/Z/CX gate forms separated by `\n`. There is intentionally
no whitespace tolerance, comment handling, alternative spelling,
parameterized rotation, or classical control. This is not a general
OpenQASM2 importer; it closes the round-trip half of the surface I
shipped emit-only at v0842 and nothing else.

### Public surface

```text
qasm2_parse(src: str)                         -> i64  // 2-slot result handle [status, program]
qasm2_parse_result_status(r: i64)             -> i64
qasm2_parse_result_program(r: i64)            -> i64
qasm2_program_eq(a: i64, b: i64)              -> i64

qasm2_status_parse_empty_source       -> 6
qasm2_status_parse_unexpected_header  -> 7
qasm2_status_parse_malformed_qreg     -> 8
qasm2_status_parse_unsupported_gate   -> 9
qasm2_status_parse_malformed_gate     -> 10
qasm2_status_parse_explain(status)             -> str  // falls through to qasm2_status_explain
```

### Round-trip contract

For any program `p` built with `qasm2_program_new` +
`qasm2_emit_h/x/z/cx`:

```text
let r = qasm2_parse(qasm2_render(p));
qasm2_parse_result_status(r) == qasm2_status_ok();
qasm2_program_eq(p, qasm2_parse_result_program(r)) == 1;
str_eq(qasm2_render(p), qasm2_render(qasm2_parse_result_program(r))) == 1;
```

The fixture verifies all three.

### Status code propagation

The parser deliberately reuses the existing emit-side status codes
when the *content* of the source is invalid even though the syntax
parses cleanly:

- A reference to `q[k]` where `k >= N` returns
  `qasm2_status_qubit_out_of_range` (2) — same code an explicit
  `qasm2_emit_h(p, oob_q)` returns.
- A `cx q[k],q[k];` returns `qasm2_status_same_qubit` (3).
- A `qreg q[N];` with `N > qasm2_max_qubits()` returns
  `qasm2_status_invalid_qubit_count` (5).

This keeps callers from having to learn two parallel code tables for
"emit refused" vs "parser-from-source refused".

### Memory / determinism

- Parser holds no static state; everything lives on the
  caller-provided `src` and the freshly-allocated program handle.
- Memory bound: O(`str_len(src)`) for the line-split intermediate
  Vec plus O(N + body lines) for the program handle. No per-character
  allocation beyond what `strings_split` already does.
- Time bound: O(`str_len(src)`) since each line is touched once with
  prefix/suffix/literal-int parsing only.
- Deterministic: identical input always produces identical
  `(status, program)` output, byte-for-byte.

## Files

| Path | Status |
|---|---|
| `stdlib/rods/quantum.nr` | extended (`+217`) — added `import "strings.nr"`, parser status codes 6–10, parser explain helper, parser internals (`_qasm2_parse_uint`, `_qasm2_parse_1q_arg`, `_qasm2_parse_cx_args`, `_qasm2_parse_gate_into`), public `qasm2_parse` / `qasm2_parse_result_*` / `qasm2_program_eq`, and updated `qasm2_limitations` text |
| `docs/rfcs/v1_PUNCHLIST.md` | updated (`+22/-3`) — new "Phase 2f OpenQASM 2.0 minimal parser" entry; remaining QM-7 open items narrowed to (a) citation-backed external weight-enumerator parity row and (b) general (foreign-source) OpenQASM 2.0 importing |
| `tests/features/qm7_openqasm2_roundtrip_smoke.nr` | NEW (261 lines) — 19 check groups |

Total commit: 3 files changed, +500 / -4.

No edits to `R05`, `ROBO-7`, `RFC-0063`, RT/laws, package/R06, `bin/`,
`bootstrap/`, `compiler/`, or any runtime `.c`. Pure stdlib `.nr` plus
fixture plus punchlist.

## Validation

```text
> .\bin\nucleor.exe build tests\features\qm7_openqasm2_roundtrip_smoke.nr -o _qm7_openqasm2_roundtrip_v0843 --no-cache
  source: tests/features/qm7_openqasm2_roundtrip_smoke.nr (79507 bytes)
  functions: 253
  strings: 102
  optimized: 39 instructions
  DCE: 190 of 253 fns elided as unreachable
  emitted: target/_qm7_openqasm2_roundtrip_v0843.ll (154731 bytes)
  compiled: target\_qm7_openqasm2_roundtrip_v0843.exe

> .\target\_qm7_openqasm2_roundtrip_v0843.exe
  rc=0   (all 19 check groups pass)

> bash tools/check_rod_void_abi.sh
  OK: rod void ABI clean (355 C void nuc_* definitions, 1275 non-void rod externs checked)

> git diff --check
  (no whitespace damage)
```

No compiler / runtime changes, so no compiler-drift / cold-perf gate
required for this slice.

## What the fixture locks

Each numbered group is one `check_*` function:

| # | Group | Locks |
|---|---|---|
| 1 | `status_codes_distinct` | 6, 7, 8, 9, 10 are distinct |
| 2 | `round_trip_canonical` | 5-gate H/CX/X/Z/CX program parse(render(p)) == p, and render bytes are identical |
| 3 | `round_trip_minimal` | 1-qubit, 1-gate program round-trips |
| 4 | `round_trip_empty_body` | header-only program (no gates) round-trips |
| 5 | `empty_source` | `""` -> `parse_empty_source` |
| 6 | `bad_header_first_line` | `"QASM 2.0;"` -> `parse_unexpected_header` |
| 7 | `bad_header_include_line` | wrong include path -> `parse_unexpected_header` |
| 8 | `truncated_header` | header + trailing `\n` only -> `parse_malformed_qreg` |
| 9 | `truncated_header_two_lines_only` | no trailing newline, 2 parts -> `parse_unexpected_header` |
| 10 | `malformed_qreg_missing_brackets` | `"qreg q3];"` -> `parse_malformed_qreg` |
| 11 | `malformed_qreg_non_digit` | `"qreg q[xx];"` -> `parse_malformed_qreg` |
| 12 | `malformed_qreg_zero` | `"qreg q[0];"` -> `parse_malformed_qreg` |
| 13 | `qreg_above_cap` | `"qreg q[1025];"` -> `invalid_qubit_count` (propagated) |
| 14 | `unsupported_gate` | `"y q[0];"` -> `parse_unsupported_gate` |
| 15 | `malformed_gate_line_real` | `"h q[0"` -> `parse_malformed_gate` |
| 16 | `cx_malformed_args` | `"cx q[0];"` (missing comma form) -> `parse_malformed_gate` |
| 17 | `qubit_out_of_range_propagates` | source references out-of-range qubit -> `qubit_out_of_range` (propagated) |
| 18 | `same_qubit_propagates` | `"cx q[0],q[0];"` -> `same_qubit` (propagated) |
| 19 | `status_explain_text` + `limitations_mentions_parser` | every code decodes; limitations now mentions the parser surface |

## Why dialect-restricted (not a general importer)

The dispatch language for v0842 was: "Add a parser/validator only if
it can be kept small and deterministic. Otherwise add emit-only plus
explicit docs that import remains open." The v0842 ship took the
emit-only path with that explicit doc. This v0843 spike picks the
"small and deterministic" path: it parses *only* the bytes my own
emitter produces. That keeps the parser small (~140 lines including
helpers, comments, and status code wiring), makes the round-trip
property easy to assert, and avoids the rabbit hole of full
OpenQASM 2.0 grammar coverage (qelib1 gates with parameters,
measurement, classical control, custom gate definitions, includes,
comments, multiple registers, register subsetting, etc.).

A general foreign-source importer remains future work and is now
the only OpenQASM 2.0 item in the punchlist.

## Branch hygiene

This spike ran cleanly: HEAD was not switched out from under me
during the queue, and the commit landed on the intended branch on
the first try. No reflog gymnastics needed. I think the v0842 races
were caused by parallel agents in this same worktree all running
in tight loops; this spike fired into a quieter window.

## Remaining QM-7 quantum tails

- **Citation-backed external published weight-enumerator parity** —
  internal exhaustive consistency over Surface-17 and [[5,1,3]] is
  already locked, but no published-source parity row has been added
  in-tree. This is the only remaining QM-7 punchlist tail.
- **General OpenQASM 2.0 importer for foreign sources** — out of
  scope for v1.0; deliberately listed as future work, not as a
  punchlist tail.

## Suggested next pickups

If you want a v0844-style follow-on in the same lane:

1. **MPS truncation-error magnitude diagnostic** — fills the
   "truncation-error magnitude is still not quantified" gap in the
   QM-2/QM-3/QM-6 limitations text. Pure runtime + stdlib.
2. **QM-6 Phase 2f real per-state callback streaming** — needs the
   `rod_helpers` callback ABI widened from `call_fn2/3 (i64,i64) ->
   i64` to a callback that can receive a basis index + amplitude.
3. **QM-7 published weight-enumerator parity row** — small, fixture-
   only, citation-backed (Surface-17 from Tomita/Svore Table II
   already cited; just needs a published enumerator value pinned in
   the fixture).
