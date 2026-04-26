# ML_Suite Feedback Queue (inbound from Nucleor_ML_Suite)

This doc mirrors `Nucleor_ML_Suite/docs/NUCLEOR_LANGUAGE_FEEDBACK.md`
into a cron-driven punchlist queue so the compiler-side fixes can land
in priority order.

The full upstream-side response with diagnosis, agree/disagree, and
fix-plan is at:
`C:\Users\JoeWe\Desktop\Nucleor_ML_Suite\docs\NUCLEOR_LANGUAGE_FEEDBACK_RESPONSE.md`

## Active queue

### NUC-FEEDBACK-002 — `Vec<f32>` round-trip silent miscompute
**Status: PARTIAL CLOSED in v0.3.119 (diag landed; real type-prop fix queued). Fixture t396.**
**Priority: HIGH (silent miscompute, ML-launch blocker)**

Reproducer pinned upstream:
```rust
fn main() -> i64 {
    let mut v: Vec<f32> = Vec::new();
    v.push(1.0f32);
    v.push(2.0f32);
    let s: f32 = f32_add(v[0], v[1]);
    print_f32(s);   // prints "0", expected "3"
    return 0;
}
```

Standalone f32 ops work; the bug is the `Vec<f32>` storage path losing
the f32 type tag through the `vec_get` chain so `f32_add` ends up
operating on raw i64 storage values (which decode as 0).

Fix options (pick one for first ship):
1. Make `expr_struct_type` propagate the element type when the receiver
   is a `Vec<T>` and the operation is indexing — so subsequent uses
   dispatch through the typed binop helper.
2. Add a hard diagnostic that rejects `Vec<f32>` / `Vec<f64>` /
   `Vec<bf16>` / `Vec<f16>` until proper element-type wiring lands.
   Suggest the workaround: `Vec<i64>` of bit patterns + manual
   `f*_*` helpers (the workaround the ML_Suite agent already adopted),
   or `Tensor::*` for ML work.

Either way, must ship before v1 OSS public release.

### NUC-FEEDBACK-003 — `clang` toolchain detection on Windows
**Status: CLOSED in v0.3.119. Windows install paths probed + clang path now quoted in shell command. NUCLEOR_CLANG env override honored.**
**Priority: LOW (UX, easy)**

The compiler emits LLVM IR successfully then dies at link with
`'clang' is not recognized as an internal or external command` if LLVM
isn't on `PATH` — even when `C:\Program Files\LLVM\bin\clang.exe`
exists. Adopters get no signal what to install or where.

Fix:
1. After PATH lookup fails, probe `C:\Program Files\LLVM\bin\clang.exe`
   (Windows), `C:\msys64\mingw64\bin\clang.exe`,
   `/opt/homebrew/opt/llvm/bin/clang` (macOS), `/usr/lib/llvm-*/bin/clang`
   (Linux).
2. If none found, emit a clear diagnostic naming what was tried and
   suggesting the LLVM download URL.
3. Add `NUCLEOR_CLANG` env override and `[toolchain] clang = "<path>"`
   in `Nucleor.toml`.

### NUC-FEEDBACK-001 — `nuc test` parse error + harness divergence
**Status: CLOSED in v0.3.121 (panic/assert strip mirrored into nucleor_tools_suite expand_format_macros). Fixture t398.**
**Priority: MEDIUM (test-surface trust)**

### NUC-FEEDBACK-004 — `stdlib/rods/jsonl.nr` undefined-symbol cascade from external repos
**Status: CLOSED in v0.3.122. resolve_import_path now probes NUCLEOR_STDLIB env, exe_dir, exe_dir/.. — same pattern as resolve_toolchain_path. Fixture t399.**
**Priority: HIGH (any external import was broken — adoption blocker for the entire OSS distribution)**

### NUC-IMPROVE-004 — Typed f64 text parser / f64_from_bits reinterpret helper
**Status: CLOSED in v0.3.125. Four runtime helpers added: f64_from_bits / f64_to_bits / f32_from_bits / f32_to_bits. Fixture t401.**
**Priority: MEDIUM (was silent miscompute on `str_to_f64(s) as f64` decimal-text ingest; ML adopter pattern)**

### NUC-IMPROVE-005 — Typed f64 elementary math wrappers
**Status: CLOSED in v0.3.127. New stdlib/rods/math_typed.nr with 7 wrappers (sqrt/exp/log/tanh/sin/cos/pow as f64 -> f64). Fixture t403.**
**Priority: HIGH for NN/ML kernels (cross entropy, softmax, sigmoid, Adam, GELU, LayerNorm)**
**Follow-on:** erf_f64 deferred (no `__nucleor_erf` in runtime today; one-liner add when ML_Suite needs it).

### NUC-FEEDBACK-005 — Long-precision f64 literal silently collapses to 0
**Status: CLOSED in v0.3.130. f64-literal lexer truncates fractional digits to 6-decimal precision before computing frac_div (was integer-division underflow when frac_len > 6, zeroing the entire fractional part). Fixture t406.**
**Priority: HIGH (silent miscompute on canonical ML constants — sqrt(2/π), log(2), etc.)**

### NUC-FEEDBACK-006 — Sub-micro f64 literals silently zero (NaN cascade in AdamW eps=1e-8)
**Status: CLOSED in v0.3.133. Lexer detects sub-micro literals and falls back to runtime str_to_f64 for full IEEE-754 precision. New token kind 124 / AST kind 72 path; existing scaled-int fast-path preserved for ≥1e-6. Fixture t409.**
**Priority: HIGH (NaN cascade in canonical ML optimizers using PyTorch defaults)**

### NUC-FEEDBACK-007 — Stale cache hit after compiler version bump
**Status: CLOSED in v0.3.135. Both build_cache_key and module_graph_cache_id now include compiler_version_label. Schemes bumped to native-cache-v5 / module-graph-v2.**
**Priority: MEDIUM (blocks adopters from validating fixes after compiler upgrades; --no-cache was the workaround)**

### NUC-FEEDBACK-008 — Print after dynamically assembled string/tokenizer output terminates with exit 1
**Status: CLOSED in v0.3.143. Fixture t418.**
**Priority: HIGH (silent runtime termination — adopters lose remaining program output without diagnostic)**

Root cause was simpler than the three hypotheses: get_rt_name mapped EVERY
print call to __nucleor_print_str regardless of arg type. When arg was an
int (token count, counter, literal), the string helper dereferenced the
i64 as const char *. For small ints like 42, that's deref of 0x2A —
guaranteed SIGSEGV. Fix: at the call site for print(arg) with argc == 1,
infer arg static type and dispatch to typed runtime helper
(__nucleor_print_i64 / __nucleor_print_f64 / __nucleor_print_bool /
__nucleor_print_str default).

### NUC-IMPROVE-006 — Tokenizer rod returns opaque handles without readable accessors
**Status: CLOSED in v0.3.144. Fixture t419.**
**Priority: LOW (workaround: build a char-level facade in user code)**

Shipped exactly as spec'd. nuc_tok_decode already existed in
tokenizer_rt.c — was just never exposed in .nr surface. v0.3.144 added
tok_vec_len/at/free runtime helpers and exposed all four (plus decode)
via stdlib/rods/tokenizer.nr. Canonical round-trip now works:
encode → vec_len → vec_at → decode → vec_free.

### Compiler-internal hazard: `&&` and `||` do NOT short-circuit
**Status: CLOSED in v0.3.148. Fixture t423.**
**Priority: HIGH (silent miscompute for adopter null-check idioms)**

Earlier attempt v0.3.145 used mid-function alloca placement
(`ir_block_add`) and broke stage C self-host. v0.3.148 hoists the
result alloca to the entry block via `ir_fn_add_entry_alloca` --
the same pattern the while/loop lowering already uses. Stages
B->C->D->E all converge with the new short-circuit lowering.

Branch IR shape for A && B:
  1. eval A
  2. cmp != 0 -> cond
  3. result alloca (entry block)
  4. br cond, eval_B, false_lbl
  5. eval_B path stores (B != 0) to result
  6. false_lbl path stores 0 to result
  7. merge label loads result
A || B inverts: true branch stores 1, false branch evals B and
stores its truthy projection.

Fixture t423 exercises four cases with a side-effecting touch()
helper to assert the actual short-circuit semantic (RHS not called
when LHS determines result). Verify gate green (448/450 -- only
env-dep memory budgets remain).

### Compiler-internal hazard: runtime helpers skip arg type-check
**Status: OPEN -- non-trivial; needs per-helper sig wiring.**
**Priority: MEDIUM (silent SIGSEGV when wrong type passed)**

Pre-fix behaviour: type_expr's call-handling at line 9669 looks up
sigs for the callee. Runtime helpers (str_len, vec_get, str_concat,
str_eq, str_substring, str_char_at, etc.) have NO sig entries, so
the type checker falls through to builtin_rtype(callee) and skips
arg type-check entirely. Adopter writes str_len(42) and gets SIGSEGV
when the helper dereferences 42 as a const char *.

Fix path: add sig entries for the common runtime helpers (~30-50
of them). For each, register expected arg types and return type.
type_expr's existing arg-mismatch logic then fires TYP-006 cleanly.
Tedious but mechanical -- one entry per helper.

Workaround in user code: explicit type annotations on call sites
help adopters notice mistakes before runtime. Documentation should
flag this as "runtime helpers don't validate argument types --
crashes are easy to debug via the helper name in the traceback".

The generated test harness emits a parse error
(`Parse error at token position 8927: expected token 51 got 1`) on the
ML_Suite tensor smoke test, even though the same code compiles via
`nuc run`. Suspect interaction with the `Vec<f32>` issue; try after 002.

Fix targets:
1. Reproduce minimal harness shape that triggers the parse error.
2. Make harness path compile iff `nuc run` does.
3. Pin a verify-gate fixture against the harness shape.

## Backlog (not actively queued)

### NUC-IMPROVE-001 / NUC-IMPROVE-003 — JSON-line metric output for parity testing
**Status: CLOSED in v0.3.120 (`stdlib/rods/jsonl.nr` shipped). Fixture t397.**
Schema delivered exactly as agent specified in NUC-IMPROVE-003.
Deferred: SHA-256 in array entries (needs runtime helper for hashing — schema is forward-compatible).

### NUC-IMPROVE-002 — First-class `Tensor<T, Shape, Device>`
RFC-scale. Post-v1.

## Sync protocol

When a fix ships:
1. Update CHANGELOG with the `NUC-FEEDBACK-NNN` reference in the body.
2. Update `Nucleor_ML_Suite/docs/NUCLEOR_LANGUAGE_FEEDBACK_RESPONSE.md`
   with the closing version and the fixture id.
3. Mark the entry in this queue as `[CLOSED in vX.Y.Z, fixture tNNN]`.
