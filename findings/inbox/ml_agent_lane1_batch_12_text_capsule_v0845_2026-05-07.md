# ML Suite text + capsule_mvp completion — Queue ML-15

Branch: fix/ml-15-batch-12-text-capsule-mvp-v0845
Date: 2026-05-07

## Headline

Lands **1 of 5 candidates** from text_mvp + capsule_mvp parity tests. The 5-candidate set was: 2 text tokenizer rods (both fail compile-time field-access resolution under canonical 0.8.323), 2 capsule_mvp rods that duplicate ML-5's hand-authored fixtures, and 1 jsonl_evidence_smoke (stable).

## Ship-ready (1)

| Rod | Surface |
|---|---|
| `ml_jsonl_evidence_smoke` | Validates `stdlib/rods/jsonl.nr` round-trips run-meta + i64/f64 metrics + i64/f64 arrays + status records. Confirms NUC-FEEDBACK-004 closure. |

## Deferred (2 — compile-fail) and excluded (2 — duplicates)

Compile-fail at canonical 0.8.323:

| Rod | Symptom |
|---|---|
| `python_char_tokenizer_i64` | `PANIC: nucleor: cannot resolve field access .data` |
| `stdlib_tokenizer_i64` | `PANIC: nucleor: cannot resolve field access .token_ids` |

Both reference `TensorI64.data` / `TensorI64.token_ids` field accesses that don't resolve in the canonical typechecker. The TensorI64 struct from the integrated `tensor_facade.nr` has the fields, but the access pattern (likely `&t.data` or `&t.token_ids` on a borrowed parameter) hits a typechecker limitation. Same family as the `&raw`-on-local issue: parser/typechecker contextual-name handling. Worth surfacing for the language team but NOT blocking integration — these are reference parity tests, not core surfaces.

Excluded as ML-5 duplicates:
- `capsule_manifest_smoke` (ML-5 ships hand-authored `ml_capsule_facade_smoke.nr` with the same surface coverage minus the `capsule_seeded_output_f64` UB)
- `ncap_package_manifest_smoke` (ML-5 ships `ml_ncap_facade_smoke.nr` from the same source)

## Build / drift

- 1/3 attempts succeed (1 stable across 30 runs, 2 fail at build).
- Drift gate clean.

End of finding.
