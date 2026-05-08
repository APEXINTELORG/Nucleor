# Lane 2 — Memory Safety + Handle Encapsulation

**Branch:** `fix/audit-lane-2-memory-safety-2026-05-08`
**Theme:** Close G-1..G-11 false negatives + encapsulate raw-pointer handles + fix NVec layout divergence. The "unsafe code accepted" cluster.

## In-scope findings

### Critical (14)
- **Layer 4** — all 11 Critical false-negative findings:
  - G-4 `as`-cast UAF (one-function fix)
  - G-11 textbook if-without-else case
  - G-8 textbook one-arm move case
  - G-3 hashmap_free while shared borrow alive
  - G-9/G-10/G-5/G-7 opt-in cliff
  - G-5/G-1/G-4 alias double-free
  - G-2 multi-input lifetime
  - G-5 extern-fn null returns
  - G-6 struct-with-HashMap
  - (and the two not summarized above — read full file)
- **Layer 5 / F-CONC-001** — Forgeable handles via raw `i64` (AtomicI64, channel, mutex, thread, future, barrier all affected)
- **Layer 5 / F-CONC-002** — `thread_future_get` double-free via repeated call
- **Layer 7 / A1** — NVec layout divergence (~200 sister `_rt.c` files redeclare without trailing field → 24-byte allocs hit 32-byte access)
- **Layer 7 / A3** — `vec_push` NULL-deref under `NUCLEOR_OOM_LENIENT=1`

### High
- **Layer 4** — G-2 let-chain trace, G-3 false-positive heuristic, G-10 unknown-effect-name silent acceptance

### Medium
- **Layer 4** — G-5 prescribed remediation `ptr_is_null()` undefined in stdlib; G-8 IDENT-only shape

## Source-of-truth findings docs
- `docs/audit/findings/audit_recon_pass1_memsafe_2026-05-08.md`
- `docs/audit/findings/audit_recon_pass1_concurrency_2026-05-08.md` (F-CONC-001, F-CONC-002 only)
- `docs/audit/findings/audit_recon_pass1_runtime_abi_2026-05-08.md` (A1, A3 only)

## Strategy

**Root cause class: gaps in walks (G-* checks miss code shapes) + exposed internals (handles forgeable, struct layouts not canonical).**

Sketch:
1. **G-4 walk extension.** Per-arg walk in check_expr must traverse `as` casts. One-function fix per finding.
2. **G-11 init-state propagation.** `__init_seen_*` must NOT be cleared by `own_restore` for if-without-else flow; track the "incomplete" path.
3. **G-8 shape coverage.** Beyond bare-IDENT struct reads — also field reads (`b.v`), method calls (`b.f()`), match-arm uses, loop-body uses, nested-if branches.
4. **G-3 hashmap_free.** Add to the checked-op set alongside insert/remove/clear.
5. **Effects opt-in cliff.** When source has zero `#[effect]`/`#[allow_effect]` annotations, gates G-9/G-10/G-5/G-7 must STILL run with implicit defaults — don't silently disable. Document the implicit defaults clearly.
6. **Alias tracking.** `let alias: Vec<i64> = v` and `as i64` cast must propagate the freed-flag to the new binding name.
7. **G-2 multi-input lifetimes.** Promote BR-7 from advisory warning to hard error for multi-input cases.
8. **G-5 extern-fn null returns.** Add `#[may_return_null]` to every extern fn that can return a null pointer (audit the C runtime). Compiler refuses to use the result without `#[allow_effect(may_return_null)]`.
9. **G-6 struct-with-HashMap per-shape diag.** SEND-G6-HASHMAP must fire on custom struct containing HashMap.
10. **Concurrency handle encapsulation.** AtomicI64/Channel/Mutex/Thread/Future/Barrier handles must be opaque — wrap raw `i64` in a private struct so `Atomic { handle: 12345 }` is a type error. Public accessors only.
11. **`thread_future_get` idempotency.** Add a freed flag; second call returns sentinel + diagnostic.
12. **NVec canonical declaration.** Move NVec definition to a single header (`stdlib/runtime/nvec.h` or similar) included by all `_rt.c` files. Audit sister files; remove redeclarations. Add a static_assert that `sizeof(NVec)` is consistent across translation units.
13. **`vec_push` NULL guard.** Under `NUCLEOR_OOM_LENIENT=1`, return error sentinel rather than NULL-deref.

## Test mandate

For every Critical:
- A negative `tests/err/G<N>_<axis>.nr` exit-code 1 (for diagnostic firing)
- A positive `tests/lang/G<N>_<axis>_legit.nr` exit-code 0 (for "doesn't false-fire")
- Concurrency handle encapsulation: `tests/err/conc_forge_handle.nr` (constructor literal rejected) + `tests/lang/conc_handle_round_trip.nr` (legit usage works)
- NVec canonical: `tools/check_nvec_layout.sh` script that greps all `_rt.c` files for redeclarations and asserts they include the canonical header

The 88-cell coverage matrix from Layer 4 audit should be the test target — at least one test per cell.

## Verify policy

Run `bash tools/verify.sh` ONCE at end. Re-bootstrap if compiler signature changed.

## Hard constraints

- Same as Lane 1.
- Coordinate with Lane 6 if effects-framework opt-in fix overlaps (it does — Lane 6 owns the broader effects-wiring + Lane 4 effects opt-in cliff is here in Lane 2 because it's a memory-safety gate).

## Output

- Branch + report committed as `docs/audit/lanes/LANE_2_REPORT.md`.
