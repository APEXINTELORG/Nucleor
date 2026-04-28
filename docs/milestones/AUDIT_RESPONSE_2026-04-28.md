# v0.4 Audit Response — Status Map + Action Plan

**Audit source:** `C:\Users\JoeWe\Desktop\Nucleor_v0.4_root_cause_corrective_actions_2026-04-28.md`
(read-only audit, 2026-04-28, against gate `488 PASS / 0 FAIL / 338.73s`).

This doc maps each of the 12 audit sections to: (a) what's already
shipped on main, (b) what the next single-cycle ship can add, and
(c) what is multi-day work better suited to a parallel branch.

## Section-by-section status (updated 2026-04-28 after v0.4.69)

### 1. Strict Numerics Default
- **Already shipped:** `type_width` / `type_signedness` / numeric
  predicates exist (F01:6396-6427); NUM-001 / NUM-002 / NUM-005
  classifiers in place; `nuc fix --numeric` lints.
- **This cycle (v0.4.70):** promote NUM-002 (literal-out-of-range)
  from warning to error. Cheap win — already detected, just severity
  flip + add to error-tier list.
- **Multi-day (parallel):** stdlib audit of 121 rods; width-tagged
  IR ops in lower; remove `NUCLEOR_INT_STRICT_ARITH` env-only path.
  This is the v0.5.0 strict-mode flip work.

### 2. Option / Result / Vec Type Propagation
- **Already shipped:** v0.4.44 (type_first_arg helper); v0.4.45/46
  Phase 2 constructor type propagation; v0.4.47/48 NUM-006 indexing
  guard; v0.4.61 Vec<T> arith/eq guard; v0.4.66 mixed str/int.
- **Multi-day (parallel):** RFC-0024 Phases 3-4 — bind match
  payload types from scrutinee (not source scan); make Vec<T>
  element type flow through `v[i]` / `vec_get` / `.first` end-to-end
  WITHOUT just emitting diagnostics.

### 3. From / Into and `?`
- **Already shipped:** v0.4.54 — `?` on non-Option/Result halts
  cleanly; `?` lowering exists for Vec<i32> [tag, payload] stub.
- **Multi-day (parallel):** RFC-0024 Phase 5 — trait impl registry
  for `from_impl_exists(src, dst)`; `?` lowering inserts conversion
  call between types.

### 4. Module Resolver and Mangling
- **Already shipped:** `pub` tokenized + tracked; private-name
  text mangle; MOD-003 lift-from-clang; v0.4.60 undefined-fn
  warning that defers to MOD-003 cleanly.
- **Multi-day (parallel):** RFC-0024 Phase 6 — real ModuleSymbol
  table; symbol-table-driven private check; codegen mangling as
  `crate__module__item`.

### 5. Rich Pattern Matching
- **Already shipped:** range patterns (T2.1); v0.4.49 int-literal/
  wildcard or-patterns; v0.4.56 MATCH-001 statement form; v0.4.59
  MATCH-001 expression form.
- **This cycle (v0.4.70):** TYP-014 for match guard expression
  with non-bool type. Cheap win — guard parse already exists
  (line ~2364).
- **Multi-day (parallel):** real Pattern AST; or-pattern binding
  set checks; slice / `@` / struct / tuple patterns; decision-tree
  lowering.

### 6. Iterators
- **Already shipped:** `.iter()` identity; map/filter/fold via
  vec_*_i64 helpers; existing T2.2 iterator method dispatch.
- **Multi-day (parallel):** real `Iterator` / `IntoIterator`
  traits; `VecIter<T>` object with item type; lower `for` through
  `IntoIterator`. Move `tests/_unimplemented/{vec_iter*,iter_*}`
  fixtures into active gate one at a time.

### 7. Closures
- **Already shipped:** v0.3.96 FnMut diagnostic (T3.72); v0.4.32a
  closure-mutate-capture silent-noop fix.
- **Multi-day (parallel):** env-as-struct lowering; Fn / FnMut /
  FnOnce trait inference; mutable env writeback. Existing
  t372_mut_closure_capture_diagnostic flips from negative to positive.

### 8. Trait Objects
- **Already shipped:** `dyn` parser acceptance (T3.68); 2-cell
  dyn_box wrapper.
- **Multi-day (parallel):** object-safety check; per-impl vtable
  emission; data-pointer + vtable-pointer layout; coercions for
  Box / &T / &mut T to dyn.

### 9. Lifetimes
- **Already shipped:** lifetime-token parser acceptance (T2.5);
  borrow-state ownership tracker.
- **Multi-day (parallel):** preserve lifetime params on AST/type
  strings; region vars + outlives constraints; LIFE-* diagnostics.

### 10. Format Traits
- **Already shipped:** RFC-0028 phase 5 spec semantics COMPLETE
  (v0.4.41); :? Debug for str (v0.4.41).
- **This cycle (v0.4.70):** TYP-015 for arg-count mismatch in
  `println!("{}", )` / `format!("{} {}", x)` etc. Cheap win —
  format expansion already iterates placeholders.
- **Multi-day (parallel):** user `Display` / `Debug` trait
  resolution; recursive Debug for `Vec<T>` / `Option<T>` /
  `Result<T,E>` containers.

### 11. Doc Generator
- **Already shipped:** `nuc doc` skeleton (v0.1.65).
- **Multi-day (parallel):** `///` AST attachment; HTML page
  rendering; code-fence extraction; doc tests; broken-link
  diagnostics.

### 12. Timing / Memory Gate
- **Already shipped this session AND in standing memory protocol:**
  `tools/verify_timings.csv` per-step timing (every cycle), peak-RSS
  budget gates (T1 step 350 MB / T2 step 425 MB / T3 step 425 MB),
  perf regression script. Audit's "wrap with watchdog, log elapsed,
  current RSS, peak RSS, last-output age" — partially done; the
  watchdog wrapper is the last piece.
- **This cycle:** no further action — already healthy at 326-340s
  per-step, 488 PASS, monitored every loop.

## Suggested division of labor

**Main branch (this agent, single-cycle ships, batched 3-5 per cycle):**
- Section 1 NUM-002 promotion
- Section 5 guard-type check (TYP-014)
- Section 10 format arg-count check (TYP-015)
- Probe-found silent miscomputes (still surfacing one per cycle on
  fresh probes)

**Parallel-branch (other agent, on a worktree clone of Nucleor_OSS):**
- Section 2 RFC-0024 Phases 3-4 generic enum/Vec<T> end-to-end type
  propagation (replace source-scan fallbacks with real type flow)
- Section 3 RFC-0024 Phase 5 From/Into trait registry + `?` lowering
- Section 4 RFC-0024 Phase 6 ModuleSymbol table + mangling rewrite
- Section 5 real Pattern AST + decision-tree lowering
- Section 6 Iterator / IntoIterator trait model
- Section 7 closure env-as-struct lowering
- Section 8 trait-object vtables
- Section 9 lifetime regions + LIFE diagnostics
- Section 10 user Display / Debug trait resolution
- Section 11 doc generator AST attachment + doc tests
- Section 1 stdlib audit of 121 rods (mechanical, parallel-friendly)

Each parallel-branch item ships as `feat/v0.5-section-N` with its own
verify gate; main agent reviews + merges sequentially after current
v0.4.x silent-miscompute close runway exhausts.
