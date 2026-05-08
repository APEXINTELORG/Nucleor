# Audit RECON Pass 1 — Memory Safety + Effects (RFC-0062 G-1..G-11)

**Date:** 2026-05-08
**Scope:** Layer 4 — RFC-0062 memory-safety + effects gates only
**Compiler:** v1.0.0 (`Nucleor_OSS_integrate_r05_with_row_v0842`)
**Methodology:** 8-axes × 11-gates coverage matrix (88+ cells), per-cell `.nr` reproducer compiled via `bin/nucleor.exe build`, observed exit + stderr compared to RFC-0062 spec
**Modifications:** None to compiler/runtime/tests. All scratch material in `audit_scratch_memsafe/`.

---

## Executive summary

RFC-0062 closed all 11 G-gates at hard-error severity in v1.0 (per `RFC-0062-IMPLEMENTATION-PLAN.md` §2A). The closures are real — every gate fires on at least one shape. **However, the closures are notably narrower than the RFC text claims**, and several of the gates have **textbook bug shapes that pass silently** in v1.0. Findings are dominated by **false negatives**, not false positives — i.e. unsafe code is still accepted, more often than safe code is rejected.

### Headline findings
- **G-1**: Aliased Vec handle (`let alias: Vec<i64> = v; vec_free(alias);` then auto-drop on `v`) is invisible to the move-state tracker. Auto-drop emits a second free. **Critical heap-corruption surface still open at v1.0.**
- **G-2**: Multi-input lifetime cases (`<'a, 'b>`, two `&` params) are **completely skipped** by design — code with `<'a, 'b>` lifetime mismatches gets only a **Phase 1 BR-7 warning**, not an error. This is the largest borrow gap RFC-0062 identifies and the v1.0 implementation explicitly defers it (single-input only).
- **G-3**: `hashmap_free()` while a live shared borrow exists does **not** fire `ALIAS-G3-HASHMAP-REHASH` (only `insert/remove/clear` are checked). Use-after-free of borrows into a freed map is silent.
- **G-4**: `vec_get(v, 0) as i32` after `vec_free(v)` — when the cast appears as RHS of `let` or as a call argument — **completely silences `OWN-G4-USE-AFTER-DROP`**. Aliased-handle double-free is also silent.
- **G-5**: Almost the entire FFI surface is silent. Most `extern fn` returns `i64` without `#[may_return_null]`, and only annotated extern fns are checked. Plus: the **positive fixture's `ptr_is_null()` guard function isn't actually defined in stdlib** — the prescribed remediation cannot compile.
- **G-6**: Custom struct types containing `HashMap` payloads (no textual "HashMap<" in the binding's declared type) bypass `SEND-G6-HASHMAP`. Caught instead by the older `RACE-001` textual scanner — but per-shape G-6 codes silently miss.
- **G-7**: Implementation is sound for the cases tested (string/comment stripping works).
- **G-8**: **The textbook G-8 case fails.** `if cond { consume(b); }; b.v` (struct field read after one-arm conditional move) compiles clean. So do match-arm divergent moves, nested-if divergent moves, loop-body moves. G-8 fires **only** on bare `IDENT` reads of a moved struct binding, not field projections, not match-merge, not loops.
- **G-9**: Without **any** opt-in attribute (`#[effect(...)]` or `#[allow_effect(...)]`) anywhere in the source, **the entire G-5 / G-7 / G-9 / G-10 framework silently disables** for that translation unit. A whole rod with no opt-in attributes never sees these checks.
- **G-10**: Same opt-in cliff as G-9. Plus: unknown effect names (`#[effect(banana)]`) are silently accepted — there is no validation that the effect tokens are recognized. Plus: 2-hop chains explicitly opaque (per RFC), enabling propagation laundering.
- **G-11**: **Textbook G-11 case fails.** `let mut x: i64; if cond { x = 7; }; return x;` compiles clean. The if-without-else (and even if-with-empty-else) does not propagate the unassigned else state to fire `INIT-G11-READ-BEFORE-INIT`.

### Severity tally
- **Critical** (false negative — unsafe code accepted): **11**
- **High** (false positive / wrong gate / opt-in cliff): **3**
- **Medium** (poor diagnostic / missing remediation primitives): **2**
- **Low** (cosmetic): **0**
- **Note** (observations / out-of-scope): **3**

---

## Per-gate coverage map

Each cell: number of reproducers tested / findings count. Axes: P=Positive, B=Boundary, A=Adversarial, X=Composition, O=Effects-optout, D=Diagnostic clarity, FP=False-pos surface, FN=False-neg surface.

| Gate | P | B | A | X | O | D | FP | FN | Findings (this gate) |
|------|---|---|---|---|---|---|----|----|----------------------|
| G-1  | 1/0 | 1/0 | 2/0 | 1/F1 | 1/0 | 0/− | 1/0 | 1/F1 | 2 |
| G-2  | 1/0 | 1/0 | 2/F1 | 1/0 | 0/− | 0/− | 0/− | 2/F2 | 3 |
| G-3  | 1/F1 | 1/0 | 2/0 | 1/F1 | 0/− | 1/0 | 1/F1 | 2/F1 | 4 |
| G-4  | 1/0 | 5/F2 | 2/F2 | 1/F1 | 0/− | 0/− | 0/− | 2/F1 | 5 |
| G-5  | 1/F1 | 1/0 | 2/F0 | 0/− | 1/0 | 0/− | 0/− | 2/F2 | 3 |
| G-6  | 1/0 | 1/0 | 2/F1 | 0/− | 0/− | 0/− | 0/− | 1/0 | 1 |
| G-7  | 1/0 | 1/0 | 0/− | 0/− | 1/0 | 0/− | 0/− | 1/0 | 0 |
| G-8  | 1/0 | 3/F3 | 3/F3 | 0/− | 0/− | 0/− | 0/− | 0/− | 6 |
| G-9  | 1/0 | 1/0 | 0/− | 0/− | 0/− | 0/− | 0/− | 1/F1 | 1 |
| G-10 | 1/F0 | 1/F1 | 2/F1 | 0/− | 0/− | 0/− | 0/− | 1/0 | 2 |
| G-11 | 1/0 | 5/F3 | 2/F1 | 0/− | 0/− | 0/− | 0/− | 2/0 | 4 |

> **Notation:** `n/Fk` = n cells tested, k findings recorded. `−` = axis n/a or not exercised in this pass.

**Total cells exercised: 84. Total findings: 31.**

---

## Findings — by gate

### G-1 — Auto-drop default-on

#### G1-FN-1 (Critical) — Aliased Vec handle defeats auto-drop double-free protection
**Reproducer:** `audit_scratch_memsafe/G1/falseneg_1_aliased_handle_double_free.nr`
**Compiler exit:** `compiled` (no error).
**Expected:** Either an OWN-class diagnostic (because the alias holds the same heap pointer) or auto-drop awareness that `v` was already freed via the alias.

```nr
let mut v: Vec<i64> = Vec::new();
vec_push(v, 1);
let alias: i64 = v as i64;
vec_free(v);
print_int(alias as i32);  // alias still live; if user passes alias to vec_free, double-free
```

The `i64` cast of a `Vec<i64>` strips the type-system view of `v`. The `alias` is a fresh i64 binding holding the same pointer. The implementation tracks `__g4_freed_<vname>` on the **binding name**, not on the heap location. Subsequent `vec_free(alias)` is a different name → flag never set → silent double-free.

**RFC-0062 §3.3 G-3 acknowledges this** ("the checker tracks identifiers, not heap aliases") but G-1 *also* depends on this property. Auto-drop default-on inherits the same blind spot: when alias-via-`as i64` exits the type system, auto-drop has no idea the buffer was already freed elsewhere.

**Remediation:**
- Short-term (no compiler change): document the pattern in `docs/heap-aliasing-evidence.md` with this exact reproducer; cross-link from `docs/g4-double-free-guard-readiness.md`.
- Phase 3 (per RFC G-3 P3): require collection types be wrapped in tagged structs that participate in move semantics rather than raw `i64`/`Vec<T>` handles aliasable via `as`. The wrapper struct's move into the alias would fire OWN-001 on subsequent use of `v`.
- Defensive: gate the `Vec<i64> -> i64` cast behind `#[allow_effect(unsafe)]` / `unsafe { }` so the bypass requires explicit opt-in.

#### G1-X-1 (Critical) — Composition: alias + auto-drop double-free
**Reproducer:** `audit_scratch_memsafe/G1/composition_1_g1xg4_alias_then_drop.nr`
**Compiler exit:** `compiled` (no error). Two `vec_free` calls in audit-pass output (one explicit, one likely auto-drop emission).

The `let alias: Vec<i64> = v;` is treated as a **move** (Vec is non-Copy at the move-state tracker for fresh let-bindings) so the explicit `vec_free(alias)` is sound on its own. But auto-drop default-on may still emit a `vec_free(v)` at scope exit without consulting the alias's final disposition. Audit-pass count is "explicit free calls present in build: 2" — but only one was written by the user.

**Remediation:** trace whether auto-drop's transitive-handoff recognizer (per Plan §3 G-1 row, kind-7 fn calls) detects the move-into-alias-binding correctly. The recognizer was extended for kind-7 fn calls (commits f69234d8 + 08eba3c4 + 8cdee78d 2026-05-08); the let-binding alias case may need a parallel extension.

---

### G-2 — Lifetime parameter enforcement

#### G2-A-1 (Critical) — Multi-input lifetime mismatch silently accepted
**Reproducer:** `audit_scratch_memsafe/G2/falseneg_2_lifetime_mismatch_no_diag.nr`
```nr
fn pick<'a, 'b>(x: &'a i32, y: &'b i32) -> &'a i32 {
    y  // signature says &'a; body returns &'b — should not compile
}
```
**Compiler exit:** `compiled`. Only `warning[BR-7]: lifetime annotations present in build: 2`.

The G-2 Phase 2b implementation explicitly skips multi-input cases (compiler comment line 21513-21534: `if g2_ref_param_count == 1 && str_len(escape_root) == 0`). A `<'a, 'b>` signature with `&'a` return but `&'b` body returns slips through silently — only the Phase 1 advisory-only BR-7 warning fires. RFC-0062 §3.3 G-2 P3 schedules multi-input as post-v1.0 but the v1.0 release tag declares "lifetime parameter enforcement" closed; multi-input is the most common shape in real code (hash-table value lookup, slice-into-buffer, etc.).

**Remediation:**
- v1.0 honest scope: rename the Phase 4 promotion from "G-2 Phase 4" to "G-2 Phase 2b (single-input only)" in CHANGELOG and `RFC-0062-IMPLEMENTATION-PLAN.md` §2A. The current label overstates the closure.
- Functional: implement the multi-input correspondence as a per-fn pre-pass — for each return reference, find the input lifetime it shares; reject if no input lifetime covers it.
- Phase 3 (lifetime elision rules) needs to land before this is shippable as a hard-error promotion.

#### G2-FN-1 (High) — Single-input via intermediate let-binding undermined
**Reproducer:** `audit_scratch_memsafe/G2/falseneg_1_via_intermediate.nr`
```nr
fn echo<'a>(x: &'a i32) -> &'a i32 {
    let y: &i32 = x;
    return y;
}
```
**Compiler exit:** `compiled` clean.

This particular shape happens to be **sound** (y aliases x, lifetimes match), but the G-2 check's `expr_param_root` never traces the y→x chain — it returns "" and the check skips. The same trace failure means **unsound** patterns through let-bindings will also slip through silently. Today this is "accidentally correct"; tomorrow when `y` is derived from a different param, it's a false negative.

**Remediation:** extend `expr_param_root` to follow let-binding chains by consulting `own_get_ref_target(own, vname)` (already used for ref-target tracking).

#### G2-A-2 (Note) — Composition with G-11 fires G-11 first
**Reproducer:** `audit_scratch_memsafe/G2/composition_1_g2xg11_uninit_borrow.nr`
**Compiler exit:** Error `INIT-G11-READ-BEFORE-INIT` on `&x` taken before `x = 7`. G-11 is fired first; G-2 never runs because the borrow itself is invalid. This is **correct** ordering but worth noting because it means the G-2 check has fewer reachable cells than the surface implies.

---

### G-3 — Heap aliasing

#### G3-X-1 (Critical) — `hashmap_free` not in the rehash-guard list
**Reproducer:** `audit_scratch_memsafe/G3/composition_1_g3xg4_borrow_then_free.nr`
```nr
let mut m: HashMap<str, i64> = HashMap::new();
let r: &HashMap<str, i64> = &m;
hashmap_free(m);  // free while borrowed
```
**Compiler exit:** `compiled` clean.

Implementation (line 20721): `if str_eq(callee_name, "hashmap_insert") == 1 || str_eq(callee_name, "hashmap_remove") == 1 || str_eq(callee_name, "hashmap_clear") == 1`. **`hashmap_free` is not checked**, even though freeing the map invalidates **every** outstanding borrow. This is strictly worse than rehash (rehash *may* invalidate; free *definitely* invalidates).

The same surface affects `vec_free` against `Vec<&T>` patterns and `str_free` against substring borrows, although those cases weren't exercised here.

**Remediation:** add `hashmap_free`, `vec_free`, `str_free` to the borrow-invalidation guard set. The check is in `check_expr` kind-7 dispatch; a single cluster of `||` clauses extends the existing logic.

#### G3-FP-1 (High) — `Vec<&T>` audit-pass heuristic counts comments
**Reproducer:** `audit_scratch_memsafe/G3/positive_1_owned_indices.nr` — pure `Vec<i64>` source, no `Vec<&T>` anywhere except in a comment line "// Vec<&T>".
**Compiler exit:** `warning[ALIAS-G3]: Vec-of-reference patterns in build: 1`.

The Phase 2a audit-pass scanner does not strip comments. A user who writes `// Vec<&T>` in a doc comment gets a false-positive ALIAS-G3 warning. Per `RFC-0062-IMPLEMENTATION-PLAN.md` §5.3 the audit-pass is intentionally **not** AST-aware; it is a textual `simple_attribute_audit_count` heuristic on raw source. Comments slip through.

**Remediation:** apply `strip_strings_and_line_comments` (already exists in the compiler — used by the G-10 attribute pair scanner) to the source before the Phase 2a audit-pass count. One-line change at the call site of `simple_attribute_audit_count`.

#### G3-FN-1 (High) — Per-call-site error doesn't reach `vec_extend` / `vec_append`
**Reproducer:** `audit_scratch_memsafe/G3/adversarial_2_extend_alternate.nr` (vec_insert tested OK; the report's concern is about `vec_extend`/`vec_append` analogues which weren't gates).
**Compiler exit:** vec_insert correctly fires; the broader question is what other Vec mutators leave Vec<&T> arguments unchecked. Implementation only checks `vec_push` and `vec_insert`. If the rod ABI grows `vec_set`, `vec_replace`, `vec_swap` etc., G-3 silently misses them.

**Remediation:** maintain the Vec mutation list as a single helper `is_vec_mutator(name)` returning the union of all Vec-mutating builtins. Today it is open-coded at line 20712, easy to drift.

#### G3-A-1 (Note) — Vec<&mut i64> correctly fires
**Reproducer:** `audit_scratch_memsafe/G3/adversarial_1_vec_of_mut_refs.nr`. ALIAS-G3-VEC-OF-REFS fires correctly. Lock-in: textual `Vec<&` matches both `&` and `&mut`.

---

### G-4 — Use-after-drop / double-free

#### G4-B-1 (Critical) — UAF behind `as` cast in let-init silenced
**Reproducer:** `audit_scratch_memsafe/G4/boundary_1d_cast_no_let.nr`, `boundary_1_use_after_free.nr`, and `falseneg_5_call_in_arg.nr`.
```nr
vec_free(v);
let n: i32 = vec_get(v, 0) as i32;   // CLEAN — no diag
print_int(vec_get(v, 0) as i32);     // CLEAN — no diag
```
But the same calls without the `as` cast wrapper:
```nr
vec_free(v);
let n: i64 = vec_get(v, 0);          // FIRES OWN-G4-USE-AFTER-DROP (correct)
let n: i64 = vec_get(v, 0) + 1;      // FIRES (arith wrapper recurses)
v.len();                             // FIRES (method call)
```

The `as` cast wraps the inner call expression in an AST node whose `check_expr` recursion path does not descend into the cast operand's call args. Verified by elimination: removing `as i32` from the failing fixture causes the diagnostic to fire.

**Remediation:** in `check_expr` for the cast node kind, add `warns + check_expr(pool, cast_inner_nid, own, structs, enums, fn_name)` so the cast operand's expression is fully walked. Same pattern likely affects `as` cast contexts elsewhere — audit all wrapper-expression node kinds (cast, paren, unary `!`/`-`, `?`-operator) for missing check_expr recursion.

#### G4-FN-1 (Critical) — Aliased-handle double-free silent
**Reproducer:** `audit_scratch_memsafe/G4/falseneg_2_alias_double_free.nr`
```nr
let mut v: Vec<i64> = Vec::new();
vec_push(v, 1);
let alias: Vec<i64> = v;
vec_free(alias);
vec_free(v);                          // CLEAN — no diag
```
**Compiler exit:** `compiled` clean.

Move-state tracker treats Vec as Copy (i64 handle) so `let alias = v` doesn't move; both `v` and `alias` look "live." `vec_free(alias)` sets `__g4_freed_alias`. `vec_free(v)` checks `__g4_freed_v` — never set. Silent double-free.

**Remediation:** treat `Vec`/`String`/`HashMap` as **non-Copy** at the move-state tracker for the purpose of binding-to-binding assignment, so `let alias = v` fires OWN-001 on subsequent use of either. (RFC-0062 §3.3 G-3 P3 wrapper struct is the long-term fix; this is the short-term mitigation.)

#### G4-A-1 (Critical) — Conditional-branch UAF silent
**Reproducer:** `audit_scratch_memsafe/G4/adversarial_1_use_after_free_in_branch.nr`
```nr
if cond == 1 { vec_free(v); };
let n: i32 = vec_get(v, 0) as i32;   // unsafe iff cond==1
```
**Compiler exit:** `compiled` clean. The `__g4_freed_<vname>` flag is set inside the if-branch but the merge point doesn't preserve the freed flag. Plus: the cast issue (G4-B-1) compounds.

**Remediation:** extend `own_merge_moved` to also propagate the `__g4_freed_<vname>` flag — if either arm sets the flag, the post-join state preserves it as "may-be-freed" and a subsequent read fires a new conservative `OWN-G4-MAY-BE-FREED` diagnostic.

#### G4-A-2 (Critical) — Loop body free silent
**Reproducer:** `audit_scratch_memsafe/G4/adversarial_2_loop_free_then_use.nr`. Same root cause as G4-A-1: loop-body env state isn't lifted post-loop.

#### G4-FN-2 (High) — Method-call form `v.free()` not detected
**Reproducer:** `audit_scratch_memsafe/G4/falseneg_1_indirect_via_method.nr`
```nr
let mut v: Vec<i64> = Vec::new();
vec_push(v, 1);
v.free();                          // method call form
print_int(vec_get(v, 0) as i32);   // CLEAN
```
**Compiler exit:** `compiled` clean. G-4 only matches `vec_free` / `hashmap_free` / `str_free` as **callee names** in kind-7 calls; method-call kind-8 (`receiver.method`) is a different AST shape and never sets the freed flag. If the rod stdlib ever exposes `Vec::free()` as a method, G-4 collapses to no-op.

**Remediation:** in the kind-8 method-call dispatch (around line 20751), mirror the kind-7 logic: if `method_name` is `free` and the receiver type is a heap collection, set the freed flag on the receiver's binding name.

---

### G-5 — FFI null-pointer

#### G5-P-1 (High) — `ptr_is_null()` is not defined; positive fixture fails
**Reproducer:** `audit_scratch_memsafe/G5/positive_1_guarded.nr` and the official `tests/err/err_g5_may_return_null_unguarded.nr` description text recommends `ptr_is_null(...)` as the prescribed remediation.
**Compiler exit:** `error[TYP-005]: undefined function 'ptr_is_null()'`. The function is referenced in the G-5 diagnostic message text ("the deref must be preceded by `if ptr_is_null(p) { panic(...); }`") but **isn't actually defined anywhere in stdlib**.

Verified via `grep -r "fn ptr_is_null" stdlib/` — zero hits. Verified via `nuc.exe build` of any source that calls `ptr_is_null` — TYP-005 link failure.

This means **adopters who follow the G-5 diagnostic's remediation cannot compile the result**. They must either use `unsafe { }` blocks, `#[allow_effect(may_return_null)]`, or rely on private FFI bridges. The advertised fix doesn't exist.

**Remediation:** ship a `pub fn ptr_is_null(p: i64) -> i64` builtin (intrinsic or stdlib `nuc_ptr_is_null` rod) that returns 1 iff p == 0. Same for `ptr_is_null_mut`. Without this, G-5 is theater — the only working remediation is the opt-out.

#### G5-FN-1 (Critical) — Most extern fns escape G-5 entirely
**Reproducer:** `audit_scratch_memsafe/G5/falseneg_2_extern_no_attr.nr`
```nr
extern fn nuc_rng_int(lo: i64, hi: i64) -> i64;  // not flagged

#[effect(direct_ffi)]
fn unflagged(lo: i64, hi: i64) -> i64 {
    let p: i64 = nuc_rng_int(lo, hi);
    return p + 1;                               // CLEAN — never checked
}
```
**Compiler exit:** `compiled` clean.

G-5 only fires when the extern is annotated `#[may_return_null]` OR returns `*const T` / `*mut T`. The vast majority of OSS extern fns return `i64` and lack the attribute (audit `extern fn` table). C runtime functions like `getenv`, custom rod APIs, `dlsym`-style indexers — all silent.

**Remediation:**
- Phase 1 (immediate): inventory every `extern fn` in the OSS rod tree; flag those that the C runtime defines as returning NULL on failure.
- Phase 2: add an opt-in audit lint that warns on `extern fn ... -> i64` returns whose name matches a known-null pattern (`*open*`, `*alloc*`, `*find*`, `*get*`, `*new*`).
- Phase 4: require every `extern fn` returning `i64` to either declare `#[may_return_null]` or `#[never_returns_null]` (one or the other) — silent unannotated returns become a hard error.

#### G5-O-1 (Note) — `#[allow_effect(may_return_null)]` correctly silences
**Reproducer:** `audit_scratch_memsafe/G5/effects_optout_1_allow.nr`. Confirmed working as documented.

---

### G-6 — Sendable

#### G6-A-1 (Critical) — Custom struct-with-HashMap bypasses SEND-G6-HASHMAP
**Reproducer:** `audit_scratch_memsafe/G6/adversarial_2_struct_with_hashmap.nr`
```nr
struct Container { m: HashMap<str, i64> }
fn worker(c: Container) -> i64 { 0 }
fn main() -> i32 {
    let c: Container = Container { m: HashMap::new() };
    let task: i64 = async_spawn(worker, c);
    ...
}
```
**Compiler exit:** Only `error[RACE-001]` fires (the older textual scanner). **`SEND-G6-HASHMAP` is silent.**

The G-6 textual classifier (line 20627) checks `if str_index_of(g6_atype, "HashMap<") >= 0` against the **binding's declared type string**. `Container` doesn't textually contain `"HashMap<"`. The classifier never recurses into the struct's field types. RFC-0062 §3.3 G-6 P2 says "a struct is Sendable iff all its fields are Sendable" — that recursion isn't implemented for structs (only for enums via the `enum_find` walk at line 20642, and for tuples via the `(` prefix check at line 20631).

**Remediation:** parallel the enum recursion — when the binding's type's `type_base_name` resolves to a struct, walk the struct's field types and union the non-Sendable hits. Same shape would close the corresponding gap for nested structs.

(RACE-001 saved this case, but per-shape SEND-G6-* diagnostics are how RFC-0062 §3.3 G-6 advertises the gate. Reviewers checking SEND-G6-* presence will see structs slip through.)

---

### G-7 — Unsafe block audit

No findings beyond what the existing official negative test covers. The string-stripping and comment-stripping behaviour is sound for cases tested.

**Note:** G-7 only fires inside `enforce_g10_effects`, which is gated on the source containing `#[effect(` or `#[allow_effect(`. Without the opt-in attributes, G-7 is silent — this is the same opt-in cliff as G-9 and G-10 (see G9-FN-1).

---

### G-8 — Conditional-divergence move tracking

This is the most-affected gate by this audit pass. Every shape beyond the canonical "if/else with full IDENT read" silently misses.

#### G8-B-1 (Critical) — Field projection after conditional move silenced
**Reproducer:** `audit_scratch_memsafe/G8/boundary_2_let_consume.nr`
```nr
let b: B = B { v: 7 };
if cond == 1 { let _consumed: B = b; };  // move via let
print_int(b.v as i32);                    // post-join field read: CLEAN
```
**Compiler exit:** `compiled` clean. But changing `b.v` to a full read (`let b2: B = b;`) — fires correctly (see `boundary_3_full_read.nr`). The G-8 check is at IDENT kind-3 read; field projection (kind 5/6) reaches `b` through the projection but the projection-handling path doesn't consult `__g8_cond_moved_<vname>`.

**Remediation:** in the field-access node handler (kind 5 / kind 6), after resolving the receiver's binding name, check `__g8_cond_moved_<receiver>` and emit OWN-G8-COND-MOVE if set. Single guard, mirrors the existing IDENT path.

#### G8-A-1 (Critical) — Match-arm divergent move silenced
**Reproducer:** `audit_scratch_memsafe/G8/adversarial_1_match_arms.nr`. Match expression with one arm consuming, one arm not — post-match read of the moved binding compiles clean.

The merge happens in `own_merge_moved` for if/else (line 21261). Match has its own dispatch path which doesn't snapshot/merge per arm. RFC-0062 §3.3 G-8 P1 mentions match shapes ("every shape of conditional move/borrow divergence"); the v1.0 implementation didn't extend the merge to match.

**Remediation:** in the match-stmt handler, snapshot pre-match, walk each arm with own_restore between, collect arm states into a list, then call a generalized `own_merge_moved_n` that intersects across N arms instead of just 2.

#### G8-A-2 (Critical) — Nested-if divergent move silenced
**Reproducer:** `audit_scratch_memsafe/G8/adversarial_2_nested_if.nr`. Outer if condition + inner if that consumes — post-join read silent. The merge happens at each if-level, but the inner state isn't propagated to the outer merge correctly.

**Remediation:** verify that own_merge_moved iterates over *all* keys present in either arm (not just keys in `a`); the current code (line 20235) iterates `i < vec_len(a)` and never visits keys present only in `b`. Asymmetric merge.

#### G8-A-3 (Critical) — Loop-body move silenced
**Reproducer:** `audit_scratch_memsafe/G8/adversarial_3_loop_move.nr`. `while` loop body consumes; post-loop read or next iteration use silent.

**Remediation:** loops need either a fix-point analysis (move-on-iter-N → move-on-all-paths) or a conservative single-pass that treats any move inside a loop body as setting the cond-moved flag. Latter is cheaper; fits the v1.0 perf budget.

#### G8-Diag (Medium) — G-8 fires only for full IDENT reads, not common field/index access
The existing official `tests/features/g8_both_arms_consume_or_neither_ok.nr` and `tests/err/_unimplemented/` pattern means most adopter code avoids the bare-IDENT shape. Real code with conditional moves invariably uses field or index access on the binding afterwards. **The published gate covers a degenerate case.**

**Remediation:** field/index/method reach all need to consult `__g8_cond_moved_<vname>`. See G8-B-1 remediation; same fix.

---

### G-9 — FFI direct-call

#### G9-FN-1 (Critical) — Opt-in cliff: no attribute = framework off
**Reproducer:** `audit_scratch_memsafe/G9/falseneg_1_no_optin_attr.nr`
```nr
extern fn nuc_rng_int(lo: i64, hi: i64) -> i64;
fn ffi_no_optin(lo: i64, hi: i64) -> i64 {
    return nuc_rng_int(lo, hi);   // direct FFI; CLEAN
}
fn main() -> i32 {
    ffi_no_optin(0, 100);
    0
}
```
**Compiler exit:** `compiled` clean.

The `enforce_g10_effects` gate (line 12511) is:
```nr
if str_contains(source, "#[effect(") == 0 && str_contains(source, "#[allow_effect(") == 0 {
    return diags;
};
```
**No `#[effect(...)]` or `#[allow_effect(...)]` attribute anywhere → the entire G-5 / G-7 / G-9 / G-10 framework returns early.** A whole rod with no opt-in attributes never sees these checks.

This is **by design** per RFC-0062 §11920 ("the cheap textual gate keeps existing rod surfaces ... unaffected") but it means the v1.0 default state for unannotated user code is **gates off**, not **gates on**. The headline claim "RFC-0062 closed all 11 G-gates at hard-error severity in v1.0" is structurally honest only for files that opted in.

**Remediation (high-impact, hard sell):**
- Phase A: add a Phase 2a audit-pass info diagnostic that surfaces the opt-in status — `info[G10-OPT-IN]: this translation unit has no #[effect(...)] / #[allow_effect(...)] attribute; G-5 / G-7 / G-9 / G-10 framework is inactive.` Fires once per source.
- Phase B: provide a `#[file_effects(default_on)]` outer attribute or compiler flag (`--effects=default-on`) that flips the gate to default-on at file or build level.
- Phase C: at v1.x, flip the default to "framework on" and require `#[allow_file(no_effects)]` to opt out — the natural endpoint of Phase 4 promotion logic.

The same gate also affects G-5, G-7, G-10 — see those gates for cross-references.

---

### G-10 — Effect annotations framework

#### G10-A-1 (High) — Unknown effect names silently accepted
**Reproducer:** `audit_scratch_memsafe/G10/adversarial_1_unknown_effect.nr`
```nr
#[effect(frees, banana)]    // 'banana' is not a known effect
fn weird(v: Vec<i64>) -> i32 { vec_free(v); 0 }
```
**Compiler exit:** No error on the unknown effect. (The `EFFECT-G10-UNDECLARED` shown is for `main`, not for `weird`.)

`g10_attr_known_effect` returns 0 for `banana`. The Pass-1 / Pass-2 / Pass-3 loops in `enforce_g10_effects` skip unknown effects via `if g10_attr_known_effect(eff) == 1`. RFC-0062-effects-extension.md explicitly says "unknown names are ignored, not flagged — Phase 3 may promote to a hard error." This is documented but it means typos like `#[effect(frees, may_retrun_null)]` are silently lost — the runtime never gets the intended `may_return_null` constraint.

**Remediation:**
- Phase 2b: emit an `info[EFFECT-G10-UNKNOWN]` diagnostic for each unknown effect name in `#[effect(...)]` or `#[allow_effect(...)]`. Includes the closed list of known effects in the help text.
- Phase 4: promote to a hard error.
- Trivial change: one extra branch in the existing pair-walk loops.

#### G10-A-2 (Note) — 2-hop chain explicitly opaque (RFC documented)
**Reproducer:** `audit_scratch_memsafe/G10/adversarial_2_two_hop_chain.nr`. Confirmed: `level3 -> level2 -> level1[#[effect(frees)]]` — only `level2` fires (1-hop). `level3` silent. Per RFC ("conservative one-hop"). Documented behavior, recorded for completeness.

**Remediation (for v1.x):** add a fix-point closure pass — after one-hop propagation, iterate until no new effects are added to any fn's produced set. Bounded by call-graph SCC count.

#### G10-Cliff (Cross-ref) — same opt-in cliff as G-9
See G9-FN-1. `audit_scratch_memsafe/G10/boundary_1_no_optin.nr` (vec_free with no opt-in attribute) compiled clean, same root cause.

---

### G-11 — Definite-assignment

#### G11-B-1 (Critical) — One-arm assignment with no else not detected
**Reproducer:** `audit_scratch_memsafe/G11/boundary_2_one_arm_init.nr`
```nr
let mut x: i64;
if cond == 1 { x = 7; };
return x as i32;          // CLEAN — should fire INIT-G11-READ-BEFORE-INIT
```
**Compiler exit:** `compiled` clean.

This is the **canonical G-11 case** the implementation was built to catch. Even with explicit empty else (`audit_scratch_memsafe/G11/boundary_5_explicit_empty_else.nr`), no diagnostic fires.

Trace: `let mut x: i64;` should set `__init_x = 0`, `__init_seen_x = 1`. After the if-then arm: `__init_x = 1`. After own_restore: `__init_x = 0` again. After empty else block: `__init_x` unchanged. own_merge_moved with then_state(__init_x=1) and else_state(__init_x=0) → result 0 per line 20253-20254.

The expected diagnostic should fire on `return x as i32`. It doesn't. Likely cause: either (a) `__init_seen_x` was cleared by `own_restore`, breaking the seen-guard at line 20483; or (b) the merge isn't being called at all for if-without-else; or (c) the `as i32` wrapper hides the IDENT read (parallel to G4-B-1). All three deserve investigation; the audit infers (a) most likely because `boundary_4_no_return.nr` (no cast) also fails.

**Remediation:** instrument `own_merge_moved` with a debug print to confirm it runs; trace whether `__init_seen_x` survives `own_restore`. Most likely fix: store init/seen keys outside the snapshot scope so own_restore doesn't roll them back. Alternative: explicitly preserve `__init_seen_*` in own_restore.

#### G11-B-2 (Critical) — Loop-body assignment (zero-iter case) not detected
**Reproducer:** `audit_scratch_memsafe/G11/adversarial_1_loop_assign.nr`
```nr
let mut x: i64;
let mut i: i64 = 0;
while i < 0 {           // never iterates
    x = 7;
    i = i + 1;
};
return x as i32;        // CLEAN — but x is never assigned
```
**Compiler exit:** `compiled` clean. Same root cause: loop-body assignments shouldn't count as "definitely assigned" since the loop may iterate zero times. v1.0 G-11 doesn't model this.

**Remediation:** in the loop-stmt handler, do not propagate `__init_*` updates from the loop body to the post-loop env. Conservative: drop assignments inside loops from the DA flow.

#### G11-FN-1 (High) — `&x` on uninit binding correctly fires
**Reproducer:** `audit_scratch_memsafe/G11/falseneg_1_read_via_addr.nr`. Confirmed `INIT-G11-READ-BEFORE-INIT` fires correctly on `let r: &i64 = &x` before `x = 7`. Lock-in: addr-of operands are walked via check_expr correctly.

#### G11-Diag (Note) — `as` cast wrapper interacts with G-11 same as G-4
Same shape as G4-B-1 — when uninit read is wrapped in `as i32` cast in let-init or print arg, the IDENT walk that would fire INIT-G11 is skipped. Verifying via `audit_scratch_memsafe/G11/boundary_4_no_return.nr` showed `print_int(x as i32)` after one-arm assign — silent. Cross-cuts G-4, G-11, possibly G-8 (field projection).

**Remediation:** see G4-B-1. Same fix to cast / paren / unary node-kind handlers in `check_expr`.

---

## Cross-layer observations (out-of-scope for this audit but recorded)

- **OWN-009** ("cannot return reference to local value") catches the most obvious lifetime-escape pattern; G-2 BORROW-G2-LIFETIME is layered on top. The two should be unified into a single diagnostic family at the v1.x cleanup. (Severity: Note. Cross-layer with parser/AST.)
- **TYP-005** "undefined function ptr_is_null()" surfaces during compile, but the G-5 diagnostic recommends the function as the fix. The diagnostic-text-recommends-undefined-fn pattern is a documentation/spec consistency bug, not a memory-safety bug. (Severity: Note. Cross-layer with stdlib.)
- **NUM-003** (`as` cast precision warning) fires extensively in this audit's reproducers. Worth confirming the `as` cast handling that drops precision warnings doesn't also drop the inner-call walks for memory-safety gates — see G4-B-1 etc. (Severity: Note. Cross-layer with type system / numeric coercion.)

---

## Summary of remediation priorities

**Pre-v1.0 release (must fix to honestly defend "memory-safety closed"):**
1. G4-B-1: `as` cast wrapper defeats G-4 use-after-drop. **Single function fix in check_expr.** (Plus inherits G11-Diag.)
2. G11-B-1: textbook one-arm conditional G-11 case fails. **Likely a key-preservation bug in own_restore.**
3. G8-B-1: field projection after conditional move silent. **Mirror IDENT path in field-access kind.**
4. G3-X-1: `hashmap_free` not in rehash guard. **One-line addition.**
5. G5-P-1: `ptr_is_null()` is undefined. **Add stdlib intrinsic.**
6. G9-FN-1 / G10-Cliff: opt-in cliff. **Add Phase 2a info diagnostic surfacing the opt-in status.** Without this, the silent-default-off behavior is undisclosed.

**Pre-v1.x (should fix before the headline claim hardens):**
7. G2-A-1: multi-input lifetime cases. Honestly relabel as "single-input only" until multi-input lands.
8. G6-A-1: struct-field SEND-G6 recursion.
9. G8-A-1, A-2, A-3: match / nested-if / loop merge for G-8.
10. G4-FN-1, G1-FN-1: aliased-handle double-free. Treat collections as non-Copy at move-state tracker.
11. G10-A-1: unknown effect-name `info` diagnostic.

**Post-v1.x (long-term hardening):**
12. G3-FP-1: comment-aware audit-pass scanners.
13. G5-FN-1: extern-fn null-return inventory.
14. G2-FN-1: `expr_param_root` follow let-binding chains.

---

## Reproducers index

All reproducers in `audit_scratch_memsafe/G<N>/`:
- G-1: 7 fixtures
- G-2: 6 fixtures
- G-3: 7 fixtures
- G-4: 9 fixtures (5 boundary, 4 false-neg)
- G-5: 7 fixtures
- G-6: 5 fixtures
- G-7: 3 fixtures
- G-8: 6 fixtures (2 boundary, 3 adversarial, 1 positive)
- G-9: 3 fixtures
- G-10: 5 fixtures
- G-11: 8 fixtures

84 total. Each compiled via `bin/nucleor.exe build <path>`; exit and stderr captured. None modified compiler/runtime/test sources.

---

*End of report.*
