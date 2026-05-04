# Unsafe-Block Audit (RFC-0062 G-7 Phase 1)

**Status:** Phase 1 complete (v0.8.17, 2026-05-04)
**Scope:** Compiler source (`compiler/nucleor_s1_compiler.nr`,
`compiler/nucleor_tools_suite.nr`) + all stdlib rod sources
(`stdlib/rods/*.nr`).
**Out of scope:** User-written adopter programs, example trees
outside this repo, third-party rods.

## 1. Audit result

**Zero `unsafe { ... }` blocks. Zero `unsafe fn` / `unsafe trait`
/ `unsafe impl` declarations. Zero unsafe-bypass code in the OSS
tree.**

The grep:

```
$ grep -rnE "^\s*unsafe\s*\{" compiler/ stdlib/ --include="*.nr"
(no output)
$ grep -rnE "^\s*unsafe\s+(fn|trait|impl)" compiler/ stdlib/ --include="*.nr"
(no output)
```

The only hits for the literal token `unsafe` in the OSS tree are:

- Diagnostic message text (the v0.6.53 / v0.7.61 wrong-class halts
  for `unsafe fn` / `unsafe trait` / `unsafe impl` decls).
- Comment text describing the lex-time skip of contextual `unsafe`
  blocks.
- The substring scan in `compiler/nucleor_tools_suite.nr:8612`
  used by GOV-002 (`@policy(no_unsafe)`) to detect adopter code
  that contains `unsafe {`.
- Sister context comments referencing `unsafe { ... }`.

None of these are actual unsafe-region code; all are textual
references to the keyword for diagnostic / governance purposes.

## 2. Why this matters

Per RFC-0062 G-7 Phase 1: "until the unsafe surface is inventoried
and each block has a documented soundness argument, the
memory-safety claim of the language as a whole rests on
assumptions nobody has stated."

The audit result is:

- The OSS compiler is written **entirely in safe Nucleor**. The
  i64-everywhere ABI doesn't require an `unsafe` escape hatch
  inside `.nr` source; every operation that would be `unsafe` in
  Rust is performed via an `extern fn` declaration (FFI to the
  C runtime) where the unsafe code lives on the C side.
- The C runtime (`stdlib/runtime/*_rt.c`) is conventional C and
  inherits C's lack of memory-safety guarantees. That's the
  actual unsafe surface area, audited separately under the
  C-side review.

So the `unsafe`-block audit at the Nucleor language level is
clean. The unsafe surface lives entirely in the C runtime, which
is the documented FFI boundary.

## 3. C-runtime adjacent surface

The compiler / stdlib stack relies on these C-runtime files:

- `stdlib/runtime/nucleor_llvm_rt.c` — core runtime (Vec, String,
  HashMap, allocation, etc.). Largest unsafe surface.
- `stdlib/runtime/governance_rt.c` — RFC-0060 Phase 2a/b registry.
- `stdlib/runtime/energy_budget_rt.c` — RFC-0050 Phase A registry.
- `stdlib/runtime/model_provenance_rt.c` — RFC-0051 Phase A.
- `stdlib/runtime/photonic_rt.c` — RFC-0052 Phase A stubs.
- `stdlib/runtime/neuromorphic_rt.c` — RFC-0053 Phase A LIF.
- `stdlib/runtime/logical_qubit_rt.c` — RFC-0054 Phase A.
- `stdlib/runtime/distributed_rt.c` — RFC-0055 Phase A.
- `stdlib/runtime/replay_rt.c` — RFC-0056 Phase A.
- `stdlib/runtime/enclave_rt.c` — RFC-0057 Phase A.
- `stdlib/runtime/pq_crypto_rt.c` — RFC-0058 Phase A stubs.
- `stdlib/runtime/differentiable_rt.c` — RFC-0045 Phase A.
- `stdlib/runtime/qsim_graph_rt.c` — RFC-0061 Tier 3 Phase A.
- `stdlib/runtime/graph_rt.c` — graph algorithm helpers.
- `stdlib/runtime/gnn_rt.c` — GNN runtime.
- ... plus the rod-specific `*_rt.c` files (audio, bayesian,
  bigint, csv_table, etc. — full list from `stdlib/runtime/`).

Each of these is conventional C with the standard C-side audit
disciplines: bounds checks on array access, NULL checks on
pointers crossing the FFI boundary, no double-free in
process-local registries.

The Phase 2 closure for G-7 (per RFC-0062 §3.3) is a property
test per C-runtime function that exercises the invariant the
function depends on. That work is out of scope for Phase 1
(this audit), but the inventory above is the input list for
that follow-up.

## 4. Adopter-side guidance

Adopters writing Nucleor code who **do** use `unsafe` blocks
hit the v0.7.61 `unsafe trait` / v0.6.53 `unsafe fn` halts at
parse time. The compiler does not yet accept `unsafe { ... }`
blocks at expression position with semantic meaning — the lex
treats `unsafe { ... }` as a passthrough block (per the v0.3.149
shipping decision). Adopter intent that the block carry Rust-
equivalent unsafe semantics is silently lost; this is a known
v0.x limitation per RFC-0062 G-7.

When the v1.x ships any checked-arith opt-out semantics, the
`unsafe` qualifier will gain meaning. Until then, code that needs
to bypass safety guarantees must do it via the FFI extern path
(C runtime).

## 5. Phase 2 + Phase 3 work

Per RFC-0062 §3.3 G-7:

- **Phase 2:** property test per C-runtime function exercising
  the invariant. ~500-800 LOC across all `*_rt.c` files,
  written as Nucleor fixtures that fuzz the FFI boundary.
- **Phase 3 (v1.0 gate):** `@policy(no_unsafe)` becomes default
  for new rod modules. Existing rods grandfathered with explicit
  audit comments.

The Phase 1 audit (this doc) is the input artifact for Phase 2
work scheduling.
