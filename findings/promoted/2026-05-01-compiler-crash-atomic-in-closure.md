---
title: Compiler PANICs (`vec_get OOB: index <large>, len 919`) when compiling a closure that calls `atomic_fetch_add`
severity: compiler-meltdown (TOP PRIORITY — hazard tier above silent-miscompute)
probe_file: probes/dbc/atomic_in_closure.nr (will be filed; not actually DbC, naming TBD)
diagnostic_actual: PANIC inside the compiler during type-check or lower of the closure body. Build aborts with `PANIC: vec_get OOB: index <huge_number>, len 919 (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)`. Different OOB index every run (looks like raw memory addresses being misinterpreted as Vec indices).
diagnostic_expected: clean compile or, if the pattern isn't supported, clean parse-time TYP/ATOMIC diagnostic naming the limitation
discovered_against: main v0.4.273 (Track G RFC-0007 atomics LIVE)
commit: probe e101dc0 + main ac65419
---

## Repro

```nr
import "stdlib/rods/atomic.nr"

fn main() -> i32 {
    let a: AtomicI64 = atomic_i64(0);
    let inc = || atomic_fetch_add(&a, 1, MemOrder::SeqCst);
    let _: i64 = inc();
    let _: i64 = inc();
    let _: i64 = inc();
    print_int(atomic_load(&a, MemOrder::SeqCst) as i32);
    0
}
```

## Actual

```
warning[NUM-003]: `as` cast loses precision: i64 (64-bit) -> i32 (32-bit)
  --> fn main@line 193:49
    |
193 |     print_int(atomic_load(&a, MemOrder::SeqCst) as i32);
    |                                                 ^
PANIC: vec_get OOB: index 2851263924464, len 919 (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)
```

The OOB index is enormous (2.85 trillion) and varies per run (different value: 2245255805472 on one run, 2851263924464 on another). That's a strong indicator that some pointer is being passed where an index was expected — undefined-behavior-class compiler bug.

## Hazard tier

**Compiler meltdown** — a probe input crashes the compiler with no useful diagnostic. The `vec_get OOB` PANIC text is the runtime safety guard that caught the compiler from segfaulting; the underlying bug is the compiler's own internal pool/list dereferencing a non-existent slot via a poison pointer.

## Suspected interaction

The closure body `atomic_fetch_add(&a, 1, MemOrder::SeqCst)` references:
1. `&a` — borrow of an outer-scope `AtomicI64` (a struct with `handle: i64`)
2. `1` — int literal
3. `MemOrder::SeqCst` — enum variant constant

The closure capture machinery (kind-42 lower path; ship 37 era code) walks the body collecting captures. For an `&<ident>` it should capture `a`. For `MemOrder::SeqCst` (kind-12 enum constructor) it shouldn't capture anything — but maybe the capture-collector is treating the kind-12 args list incorrectly, dereferencing the args list-id as a pool index.

The "len 919" matches roughly the number of pool entries for a small main fn — consistent with a corrupt list-id from kind-12 enum-variant being walked as if it were a kind-7 args list.

## Workarounds

Inlining the call directly in main works fine — the crash is specific to the closure-body path:

```nr
fn main() -> i32 {
    let a: AtomicI64 = atomic_i64(0);
    let _: i64 = atomic_fetch_add(&a, 1, MemOrder::SeqCst);
    let _: i64 = atomic_fetch_add(&a, 1, MemOrder::SeqCst);
    print_int(atomic_load(&a, MemOrder::SeqCst) as i32);
    0
}
```

(Verified — this version compiles and prints `2`.)

## Suspected fix area

`compiler/nucleor_s1_compiler.nr` — closure capture-collect path for kind-12 (enum variant constructor) inside the closure body. Likely:

- `closure_collect_capture_expr` at kind-12 walks `args` field but uses wrong field index
- OR: the `MemOrder` enum's variant-constructor is being treated as a regular fn call (kind-7) and its arg-list pool index is being used as if it were the AST nid

Reproducer should let the compiler dev pinpoint the exact dereferencing bug.

## Memory-blow-up note

Not memory-leak class. Compiler-internal OOB read.

## Cross-ref

- v0.4.273 — RFC-0007 atomics LIVE; this probe exposes a closure-capture-vs-enum-variant interaction.
- Ship 37 (closure-sibling-call halt) — closure-machinery sister surface; my Ship 37 work intersected with the closure capture path.
- The `MemOrder` enum is defined in `stdlib/rods/atomic.nr`; probably a regular kind-36 enum with regular kind-12 variant ctors. Nothing exotic.

## Probe

`probes/atomic/atomic_in_closure.nr` — minimal repro.


## Promoted

- Fixture: `tests/err/err_atomic_006_in_closure.nr` — exact probe repro.
- Verify gate step: `t_atomic_006_in_closure` — asserts exit 1 + ATOMIC-006 + (negative-grep) absence of `vec_get OOB`.
- Fix shipped: v0.4.280 — temporary halt at parse-time. New `enforce_no_atomic_in_closure(source)` text-level scanner detects `||` followed within ~200 chars by `atomic_` (without crossing `;`), halts with ATOMIC-006 naming the closure-lowering enum-scope gap and the workaround (call atomic helpers directly from a regular fn body).
- Real fix is closure sym-table inheritance for `__etag_<TypeName>_<Variant>` entries — the closure-lowering path uses a fresh sym that doesnt carry the parent fns enum etags, so `MemOrder::SeqCst` falls through to the unsupported-associated-fn-call branch and panics. Multi-cycle ship.
- ATOMIC-006 reserved in is_known_diag_code + spec doc + verify scripts.
- Promoted: 2026-05-01 by main agent (from probe-agent prep on origin/probe/exploration commit e27ee0a)
