# Parser annotations under default-flip: NOT redundant — experiment finding

- **Date:** 2026-05-07
- **Agent:** main (local Claude integrator)
- **Status:** experiment complete, negative result documented
- **Branch tested:** `experiment/parser-revert-test` (deleted; sub-branch from `fix/default-flip-experiment-v0846`)

## Question tested

After the Phase 2b-3 default-flip lands (`fix/default-flip-experiment-v0846 @ e5081625`), are the 8 `#[manual_drop]` annotations on parser fns added during this session also redundant? The hypothesis was that `auto_drop_mark_constructor_handoffs` at `compiler/nucleor_s1_compiler.nr:29045` covers fn-call args (kind 12) including `pr(cp, params)`, so the parsers shouldn't need explicit annotations either.

The 8 parser annotations under test:
- `parse_generic_params` + `parse_fn_decl` (commit `a3203449`, T2.5 root cause)
- `parse_struct_decl` (commit `5a4b790a`)
- `parse_enum_decl` + `parse_trait_decl` + `parse_impl_block` (commit `cd4f01ae`)
- `parse_match_stmt` (commit `cfb77c68`, T2.1 root cause)
- `parse_let` (commit `fae89980`)

## Method

1. Branched `experiment/parser-revert-test` from `fix/default-flip-experiment-v0846 @ e5081625` (default-flip ON).
2. Removed the `#[manual_drop]` line directly preceding each of the 8 fn declarations (single-line removal each).
3. Rebuilt `target/nucleor_tools.exe` from the modified source.
4. Ran T2.5 + T2.1 + a representative ml_* fixture under `--no-cache`.

## Result

**The 8 parser annotations are NOT redundant under default-flip.**

| Test | Result | Symptom |
| --- | --- | --- |
| `bin/nucleor.exe test tests/smoke/t25_lifetime_params.nr --no-cache` | FAIL | Silent exit RC=0 with no test output past "cache: disabled" line. Compile silently bails before "functions: ..." emit. The original T2.5 silent-exit symptom returns. |
| `bin/nucleor.exe test tests/smoke/t21_range_patterns.nr --no-cache` | FAIL | `PANIC: index out of bounds: the len is 1 but the index is 1` — the original T2.1 OOB panic class returns. |
| `bin/nucleor.exe build tests/features/ml_torch_gelu_tanh_f64.nr` | PASS | Real gelu(tanh) values produced; structural fix's handoff machinery handles the wrapper-fn shape correctly. |

So the structural fix closes the **wrapper-fn move-into-struct** class (which is what cloud's PROBE-3L was hitting on ML fixtures) but does NOT close the **parser fn pr-wrapper** class (which is what T2.5 / T2.1 hit).

## Why the parsers are different

The ML wrapper pattern:
```nr
fn nn_gelu_tanh_f64(input: &TensorF64) -> TensorF64 {
    let mut data: Vec<f64> = Vec::new();
    ... data.push(...) ...
    return tensor_f64_from_vec(rows, cols, data);  // identifier in fn-call arg
}
```

`auto_drop_mark_constructor_handoffs` walks the call args (kind 12 — fn call), finds `data` (kind 3 — identifier), and marks it as freed/handed-off. The Vec heap survives.

The parser pattern:
```nr
fn parse_generic_params(tokens: Vec<i32>, pos: i64) -> Vec<i32> {
    let mut params: Vec<i32> = Vec::new();
    while ... { params.push(...); ... };
    return pr(cp, params);  // identifier in fn-call arg, BUT...
}
```

This LOOKS identical to the ML pattern. `pr` is a fn call (kind 12), `params` is an identifier (kind 3). Yet under default-flip, the experiment shows the Vec gets freed somewhere along the way.

**Hypothesis (untested):** the `pr()` helper itself stores `params` into a Vec<i32> as an i64 (raw heap pointer), and that storage path may not be recognized as a transfer of ownership. The wrapper Vec returned by `pr()` carries a pointer to params' heap — but auto-drop's tracking sees `params` consumed by `pr()` AND ALSO sees the wrapper Vec assigned to `gr` get freed at end of caller's scope. Net: the inner heap allocation gets freed twice, OR freed in a way the wrapper Vec doesn't expect, causing the dangling-pointer reads at consumers like `pr_val(gr)`.

This needs deeper investigation in `auto_drop_mark_constructor_handoffs` for the case "fn-call return value contains identifier-args by reference (Vec<i32> wrapping)." Out of scope for this experiment — partner-Compiler queue.

## Action

**No revert.** All 8 parser annotations on `fix/default-flip-experiment-v0846` stay. The structural fix is complete for the wrapper-fn class; the parser-fn class remains a separate residual closed by the explicit annotations.

## Sub-branch cleanup

`experiment/parser-revert-test` deleted locally, never pushed. No remote artifact.

## Production-readiness implication

The "no kludges" framing earlier: the 8 parser annotations are NOT kludges — they're the correct fix for a specific bug class (`pr()` wrapper around heap-allocated Vec) that's distinct from the wrapper-fn class the structural fix solves. They should remain in v1.0.

The 7 reverted ML stdlib annotations (`tensor_facade.nr` × 3 + `data_facade.nr` × 5 — wait that's 8) are kludges that the structural fix obsoletes — those reverts are correct. Don't conflate the two classes.
