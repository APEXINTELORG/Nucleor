---
title: Array surface has three gaps — (1) Rust **repeat-init shape `[VAL; N]`** (e.g. `let zeros: [i64; 5] = [0; 5];`) NR020-rejects at parse; (2) **slice type `&[T]` as fn parameter** (e.g. `fn first(s: &[i64]) -> i64`) NR020-rejects at parse; (3) **array OOB index `arr[99]` panics with `vec_get OOB: index 99, len 3`** — leaks the internal Vec representation in the diagnostic, same family as the Option::unwrap()-on-None leak.
severity: parse-rejection (gaps 1 + 2) + misleading-diag / implementation-leak (gap 3)
probe_file: probes/types/array_shape_gaps.nr (probe-branch)
diagnostic_actual: gap 1 → `error[NR020]: parse error at byte 47: expected ',', got ';'`; gap 2 → `error[NR020]: parse error at byte 17: expected ';', got ']'`; gap 3 → `PANIC: vec_get OOB: index 99, len 3`
diagnostic_expected: gap 1 → accept `[VAL; N]`; gap 2 → accept `&[T]` as fn param type; gap 3 → emit Rust-canonical OOB diag without leaking that arrays are Vec internally
discovered_against: main v0.6.22 (probe rebased)
commit: probe (post-rebase) + main d8d8548e
status: PARTIALLY CLOSED — gap 3 closed in v0.6.29 via Rust-canonical OOB wording. Gaps 1 + 2 deferred (both substantive parse-pass changes — separate ships).
---

## Closure (main agent v0.6.29) — gap 3 only

`stdlib/runtime/nucleor_llvm_rt.c:2247` — single-line wording
change. Pre-fix:

```
PANIC: vec_get OOB: index 99, len 3 (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)
```

Post-fix:

```
PANIC: index out of bounds: the len is 3 but the index is 99 (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)
```

Rust-canonical phrasing matches `vec[i]` and `arr[i]` OOB panics
in stdlib — works for both real `Vec<T>` and arrays (which
desugar to Vec internally) without leaking either way.

## Adopter migration

No source change required — runtime wording shift only.

```nucleor
let arr: [i64; 3] = [10, 20, 30];
let bad: i64 = arr[99];
// pre-v0.6.29: PANIC: vec_get OOB: index 99, len 3 …
// v0.6.29:     PANIC: index out of bounds: the len is 3 but the index is 99 …
```

Opt-out env var (`NUCLEOR_VEC_OOB_LENIENT=1`) is preserved.

## Why this ship doesn't touch gaps 1 + 2

- **Gap 1 (`[VAL; N]` repeat-init)**: real fix needs the array-
  literal parser to recognise `;` between value and count, then
  lower to a length-N Vec filled with the value. Touches parse +
  lower passes. Substantive — separate ship.
- **Gap 2 (`&[T]` slice param)**: real fix needs `&[T]` as a type
  surface — at minimum a parse-pass change to recognise `&[T]`
  in fn parameter positions, plus a semantic substrate that
  treats the slice as Vec-like read-only. Substantive — separate
  ship.

Both queued.

## Promoted

- Fixture: none — single-line runtime wording change. Smoke
  validation via `tests/fixtures/probe_vec_oob.nr` (existing
  fixture, just exercised manually).
- Comment-fidelity sync: `tests/fixtures/t461_vec_oob_panic.nr`,
  `tests/features/option_question_op.nr`,
  `tests/err/err_atomic_006_in_closure.nr` (all three previously
  referenced the old wording in their docstrings).
- Fix shipped: v0.6.29 (gap 3 only).
- Promoted: 2026-05-02 NIGHT by main agent (probe commit on
  `origin/probe/exploration`).
