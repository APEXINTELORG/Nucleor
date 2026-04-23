# Nucleor Error Code Reference

Canonical list of every compiler error code, its RFC source, and a
link to the relevant RFC section.

Run `nuc explain CODE` for on-command help. Each entry below also
provides reference material and typical fixes.

---

## NR series — compiler pipeline

Pre-existing codes from the compiler front-end. See the existing
`run_explain_command` in `nucleor_tools_suite.nr` for full text.

| Code | Title | Stage |
|---|---|---|
| NR001 | Source Input Failure | driver |
| NR005 | Module Resolution Failure | resolver |
| NR010 | Lexical Syntax Failure | lexer |
| NR020 | Parser Failure | parser |
| NR030 | Semantic Type Failure | type-check |
| NR031 | Borrow Safety Failure | ownership |
| NR032 | Effect or Policy Failure | effects |
| NR033 | Taint Safety Failure | taint |
| NR034 | Send/Sync Safety Failure | concurrency |
| NR040 | IR Lowering Failure | lower |
| NR050 | Backend Code Generation Failure | codegen |
| NR051 | WASM Backend Unavailable | codegen |
| NR070 | Manifest or Lockfile Failure | package |
| NR090 | Compiler Pipeline Invariant Failure | internal |

## OWN series — borrow-checker (expansion of NR031)

The ownership analyzer fires concrete `OWN-NNN` codes; `NR031`
remains the umbrella stage code. **All 12 OWN codes documented
v0.2.119**; previously the codes fired but were missing from
the spec doc and the explain registry. Surfaced by the audit
chain after `tests/err/*.nr` got EXPECT headers in v0.2.117.

| Code | Title | Source | Severity |
|---|---|---|---|
| OWN-001 | Use of moved variable | move/borrow checker | warning |
| OWN-002 | Cannot borrow moved value | move/borrow checker | error |
| OWN-003 | Cannot move value that is borrowed | move/borrow checker | error |
| OWN-004 | Cannot mutably borrow value already borrowed | borrow checker | error |
| OWN-005 | Cannot shared-borrow mutably-borrowed value | borrow checker | error |
| OWN-006 | Cannot assign through shared reference | borrow checker | error |
| OWN-007 | Cannot assign to borrowed location | borrow checker | error |
| OWN-008 | Cannot assign to immutable binding | mutability checker | error |
| OWN-009 | Cannot return reference to local value | lifetime / scope checker | error |
| OWN-010 | Cannot bind a reference that escapes an inner block | lifetime / scope checker | error |
| OWN-011 | Cannot mutably borrow immutable value | mutability checker | error |
| OWN-012 | Cannot destroy arena with live references | arena lifetime checker | error |

Gate-tested via `tests/err/err_*` (use-after-move, borrow-
after-move, two-mut-borrows, shared-mut-conflict,
assign-shared-ref, field-assign-while-borrowed,
immutable-assign, dangling-return, lifetime-scope-escape,
mut-borrow-immutable, arena-destroy-live-ref).

## TYP series — type checker (expansion of NR030)

The type checker fires concrete `TYP-NNN` codes; `NR030`
remains the umbrella stage code. **All 10 TYP codes documented
v0.2.119**; same drift class as the OWN series above.

| Code | Title | Source | Notes |
|---|---|---|---|
| TYP-001 | Non-exhaustive match | match checker | warning. **Legacy** — superseded by MATCH-001 (RFC-0016); both still fire for backwards compat |
| TYP-002 | Boolean values cannot be used in arithmetic | binop type-check | error |
| TYP-003 | Unit operands for addition/subtraction must match | unit / dimensional checker (RFC-0005) | error |
| TYP-004 | Cannot dereference a non-reference value | deref expr type-check | error |
| TYP-005 | Wrong number of arguments | call expr type-check | error |
| TYP-006 | Argument type mismatch in call | call expr type-check | error |
| TYP-007 | Bare numeric literal cannot initialize a unit value | unit type-check (RFC-0005) | error |
| TYP-008 | Type mismatch for binding | let stmt type-check | error |
| TYP-009 | Assignment type mismatch | assign stmt type-check | error |
| TYP-010 | Return type mismatch | return stmt type-check | error |

Gate-tested via `tests/err/err_bool_arith`, `err_args`,
`err_deref_nonref`, `err_taint_arg/leak/propagation`,
`err_taint_to_clean`.

## RT series — RFC-0001 real-time function attributes

| Code | Title | RFC section |
|---|---|---|
| RT-001 | Allocation in #[no_alloc] function | [RFC-0001 §3.2.1](../rfcs/RFC-0001-rt-attributes.md) |
| RT-002 | Possibly-panicking expression in #[no_panic] function | [RFC-0001 §3.2.2](../rfcs/RFC-0001-rt-attributes.md) |
| RT-003 | Dynamic dispatch in #[no_dyn] function | [RFC-0001 §3.2.3](../rfcs/RFC-0001-rt-attributes.md) |
| RT-004 | Static WCET exceeds declared #[deadline] | [RFC-0001 §3.2.4](../rfcs/RFC-0001-rt-attributes.md), [RFC-0009](../rfcs/RFC-0009-heptane-wcet.md) |
| RT-005 | FFI call in RT function without #[ffi_no_*] annotation | [RFC-0001 §3.5](../rfcs/RFC-0001-rt-attributes.md) |
| RT-006 | RT attribute on async fn | [RFC-0001](../rfcs/RFC-0001-rt-attributes.md), [RFC-0030](../rfcs/RFC-0030-async-decision.md) |
| RT-007 | Deadline annotation without no_alloc or no_panic | [RFC-0001](../rfcs/RFC-0001-rt-attributes.md) |
| RT-008 | Recursive call in #[deadline] function | [RFC-0014](../rfcs/RFC-0014-max-depth.md) |

## ALLOC series — RFC-0002 allocator types

| Code | Title | RFC section |
|---|---|---|
| ALLOC-001 | Allocated value escapes its allocator | [RFC-0002 §3.2](../rfcs/RFC-0002-allocator-types.md) |
| ALLOC-002 | Allocator type mismatch | [RFC-0002 §3.9](../rfcs/RFC-0002-allocator-types.md) |
| ALLOC-003 | Allocation forbidden by #[no_alloc] | [RFC-0002 §3.7](../rfcs/RFC-0002-allocator-types.md) |

## FRAME series — RFC-0003 typed coordinate frames

| Code | Title | RFC section |
|---|---|---|
| FRAME-001 | Cannot add values in different coordinate frames | [RFC-0003 §3.3](../rfcs/RFC-0003-typed-frames.md) |
| FRAME-002 | Transform composition mismatch | [RFC-0003 §3.3](../rfcs/RFC-0003-typed-frames.md) |
| FRAME-003 | Cannot apply transform to value in incompatible frame | [RFC-0003 §3.3](../rfcs/RFC-0003-typed-frames.md) |

## ASSUME series — RFC-0004 assume!

| Code | Title | RFC section |
|---|---|---|
| ASSUME-001 | predicate not in analyzer's vocabulary | [RFC-0004 §3.2](../rfcs/RFC-0004-assume.md) |
| ASSUME-002 | assume_unchecked! used without justification | [RFC-0004 §3.6](../rfcs/RFC-0004-assume.md) |
| ASSUME-003 | assume! predicate is a tautology | [RFC-0004 §3.9](../rfcs/RFC-0004-assume.md) |
| ASSUME-004 | assume! contradicts type-system fact | [RFC-0004 §3.9](../rfcs/RFC-0004-assume.md) |
| ASSUME-005 | cert-profile: assume! not proven | [RFC-0004 §3.1](../rfcs/RFC-0004-assume.md) |

## UNIT series — RFC-0005 typed dimensional units

| Code | Title | RFC section |
|---|---|---|
| UNIT-001 | Add/sub mismatched dimensions | [RFC-0005 §3.1](../rfcs/RFC-0005-units.md) |
| UNIT-002 | Implicit conversion attempted | [RFC-0005 §3.4](../rfcs/RFC-0005-units.md) |
| UNIT-003 | Power expression is non-integer at compile time | [RFC-0005 §3.1](../rfcs/RFC-0005-units.md) |
| UNIT-004 | Unknown unit alias | [RFC-0005 §3.3](../rfcs/RFC-0005-units.md) |
| UNIT-005 | Dimensional inconsistency in @law annotation | [RFC-0005](../rfcs/RFC-0005-units.md) |

## CONTRACT series — RFC-0006 design by contract

| Code | Title | RFC section |
|---|---|---|
| CONTRACT-001 | Require violation at runtime | [RFC-0006 §3.2](../rfcs/RFC-0006-design-by-contract.md) |
| CONTRACT-002 | Ensure violation at runtime | [RFC-0006 §3.3](../rfcs/RFC-0006-design-by-contract.md) |
| CONTRACT-003 | Invariant violation | [RFC-0006 §3.4](../rfcs/RFC-0006-design-by-contract.md) |
| CONTRACT-004 | Trait impl weakens precondition (Liskov) | [RFC-0006 §3.5](../rfcs/RFC-0006-design-by-contract.md) |
| CONTRACT-005 | Trait impl strengthens postcondition (Liskov) | [RFC-0006 §3.5](../rfcs/RFC-0006-design-by-contract.md) |
| CONTRACT-006 | old(expr) references mutable state without snapshot | [RFC-0006 §3.3](../rfcs/RFC-0006-design-by-contract.md) |
| CONTRACT-007 | In cert profile, contract not statically provable | [RFC-0006](../rfcs/RFC-0006-design-by-contract.md) |

## ATOMIC series — RFC-0007 atomic + lock-free

| Code | Title | RFC section |
|---|---|---|
| ATOMIC-001 | Blocking call inside #[atomic] function | [RFC-0007 §3.3](../rfcs/RFC-0007-atomic.md) |
| ATOMIC-002 | Allocating call inside #[atomic] function | [RFC-0007 §3.3](../rfcs/RFC-0007-atomic.md) |
| ATOMIC-003 | Use of Cell/RefCell in #[atomic] | [RFC-0007](../rfcs/RFC-0007-atomic.md) |
| ATOMIC-004 | Mismatched orderings in compare_exchange | [RFC-0007 §3.2](../rfcs/RFC-0007-atomic.md) |

## ISR series — RFC-0008 interrupt service routines

| Code | Title | RFC section |
|---|---|---|
| ISR-001 | #[isr] function not pub | [RFC-0008 §3.3](../rfcs/RFC-0008-isr.md) |
| ISR-002 | ISR stack frame exceeds budget | [RFC-0008 §3.6](../rfcs/RFC-0008-isr.md) |
| ISR-003 | Call to non-#[isr_safe] function from ISR | [RFC-0008 §3.2](../rfcs/RFC-0008-isr.md) |
| ISR-004 | Vector name not recognized for target architecture | [RFC-0008 §3.1](../rfcs/RFC-0008-isr.md) |
| ISR-005 | Two ISRs assigned to the same vector | [RFC-0008 §3.3](../rfcs/RFC-0008-isr.md) |
| ISR-006 | Priority out of range for target NVIC | [RFC-0008 §3.1](../rfcs/RFC-0008-isr.md) |

## WCET series — RFC-0009 Heptane WCET

| Code | Title | RFC section |
|---|---|---|
| WCET-001 | #[deadline] function uses dynamic dispatch | [RFC-0009 §3.5](../rfcs/RFC-0009-heptane-wcet.md) |
| WCET-002 | Loop bound unknown | [RFC-0009 §3.2](../rfcs/RFC-0009-heptane-wcet.md) |
| WCET-003 | WCET exceeds declared deadline | [RFC-0009 §3.1](../rfcs/RFC-0009-heptane-wcet.md) |
| WCET-004 | Indirect-call bound unknown | [RFC-0009 §3.5](../rfcs/RFC-0009-heptane-wcet.md) |
| WCET-005 | Recursive call exceeds #[max_depth] | [RFC-0009](../rfcs/RFC-0009-heptane-wcet.md), [RFC-0014](../rfcs/RFC-0014-max-depth.md) |
| WCET-006 | Heptane analysis failed (internal tool error) | [RFC-0009](../rfcs/RFC-0009-heptane-wcet.md) |

## DLPACK series — RFC-0010 tensor interchange

| Code | Title | RFC section |
|---|---|---|
| DLPACK-001 | Unsupported device | [RFC-0010 §3.3](../rfcs/RFC-0010-dlpack.md) |
| DLPACK-002 | Unsupported dtype | [RFC-0010 §3.4](../rfcs/RFC-0010-dlpack.md) |
| DLPACK-003 | Shape mismatch | [RFC-0010 §3.2](../rfcs/RFC-0010-dlpack.md) |
| DLPACK-004 | Non-contiguous tensor and no copy requested | [RFC-0010 §3.5](../rfcs/RFC-0010-dlpack.md) |
| DLPACK-005 | DLPack version too old | [RFC-0010 §3.1](../rfcs/RFC-0010-dlpack.md) |

## CXX / BINDGEN series — RFC-0011 / RFC-0012 C++ FFI

| Code | Title | RFC section |
|---|---|---|
| CXX-001 | C++ header not found | [RFC-0011 §3.1](../rfcs/RFC-0011-nuc-cxx.md) |
| CXX-002 | Type mismatch between Nucleor decl and C++ source | [RFC-0011 §3.3](../rfcs/RFC-0011-nuc-cxx.md) |
| CXX-003 | Use of std::function without #[no_dyn] opt-out | [RFC-0011 §3.2](../rfcs/RFC-0011-nuc-cxx.md) |
| CXX-004 | extern "Nucleor" type with non-#[repr(C)] layout | [RFC-0011 §3.1](../rfcs/RFC-0011-nuc-cxx.md) |
| CXX-005 | C++ exception escapes through bridge | [RFC-0011 §5](../rfcs/RFC-0011-nuc-cxx.md) |
| BINDGEN-001 | Header file not found | [RFC-0012 §3.1](../rfcs/RFC-0012-nuc-bindgen.md) |
| BINDGEN-002 | libclang parse error | [RFC-0012 §4](../rfcs/RFC-0012-nuc-bindgen.md) |
| BINDGEN-003 | Type conversion not supported | [RFC-0012 §3.2](../rfcs/RFC-0012-nuc-bindgen.md) |
| BINDGEN-004 | Forward-declared type with no definition | [RFC-0012 §3.2](../rfcs/RFC-0012-nuc-bindgen.md) |
| BINDGEN-005 | Duplicate symbol | [RFC-0012](../rfcs/RFC-0012-nuc-bindgen.md) |

## URDF series — RFC-0013 compile-time frame chain verification

| Code | Title | RFC section |
|---|---|---|
| URDF-001 | No path from A to B in any imported URDF | [RFC-0013 §3.2](../rfcs/RFC-0013-urdf-static-frames.md) |
| URDF-002 | A and B in different URDFs without #[urdf_attach] | [RFC-0013 §3.3](../rfcs/RFC-0013-urdf-static-frames.md) |
| URDF-003 | Cycle in URDF tree | [RFC-0013](../rfcs/RFC-0013-urdf-static-frames.md) |
| URDF-004 | URDF file not found | [RFC-0013 §3.1](../rfcs/RFC-0013-urdf-static-frames.md) |
| URDF-005 | URDF parse error | [RFC-0013 §3.1](../rfcs/RFC-0013-urdf-static-frames.md) |
| URDF-006 | Joint limit violated | [RFC-0013 §3.4](../rfcs/RFC-0013-urdf-static-frames.md) |

## DEPTH series — RFC-0014 bounded recursion

| Code | Title | RFC section |
|---|---|---|
| DEPTH-001 | Recursive call detected without #[max_depth] | [RFC-0014 §3.4](../rfcs/RFC-0014-max-depth.md) |
| DEPTH-002 | Static analysis cannot prove #[max_depth = N] | [RFC-0014 §3.3](../rfcs/RFC-0014-max-depth.md) |
| DEPTH-003 | Runtime depth-check fires | [RFC-0014 §3.2](../rfcs/RFC-0014-max-depth.md) |
| DEPTH-004 | Total stack budget exceeded | [RFC-0014 §3.5](../rfcs/RFC-0014-max-depth.md) |
| DEPTH-005 | Mutually-recursive functions with incompatible bounds | [RFC-0014 §3.4](../rfcs/RFC-0014-max-depth.md) |

## NUM series — RFC-0015 numeric types

| Code | Title | RFC section |
|---|---|---|
| NUM-001 | Mixed-width arithmetic without cast | [RFC-0015 §3.2](../rfcs/RFC-0015-numeric-types.md) |
| NUM-002 | Numeric literal out of range for declared type | [RFC-0015 §3.6](../rfcs/RFC-0015-numeric-types.md) |
| NUM-003 | `as` cast loses precision (warning) | [RFC-0015 §3.5](../rfcs/RFC-0015-numeric-types.md) |
| NUM-004 | f8/f16/bf16 op without hardware support | [RFC-0015 §3.4](../rfcs/RFC-0015-numeric-types.md) |
| NUM-005 | usize/isize mixed with explicit-width type | [RFC-0015 §3.1](../rfcs/RFC-0015-numeric-types.md) |

## MATCH series — RFC-0016 Result/Option/match

| Code | Title | RFC section |
|---|---|---|
| MATCH-001 | Non-exhaustive match | [RFC-0016 §3.2](../rfcs/RFC-0016-result-option-match.md) |
| MATCH-002 | Unreachable arm | [RFC-0016 §3.2](../rfcs/RFC-0016-result-option-match.md) |
| MATCH-003 | Type mismatch between arms | [RFC-0016 §3.2](../rfcs/RFC-0016-result-option-match.md) |
| MATCH-004 | ? in a function not returning Result/Option | [RFC-0016 §3.3](../rfcs/RFC-0016-result-option-match.md) |
| MATCH-005 | ? error type doesn't Into the function's error type | [RFC-0016 §3.7](../rfcs/RFC-0016-result-option-match.md) |
| MATCH-006 | unwrap() in #[no_panic] function | [RFC-0016 §3.6](../rfcs/RFC-0016-result-option-match.md), [RFC-0001](../rfcs/RFC-0001-rt-attributes.md) |
| MATCH-007 | Range pattern bounds in wrong order | [RFC-0023 §3.1](../rfcs/RFC-0023-pattern-matching.md) |
| MATCH-008 | Or-pattern arms have different bindings | [RFC-0023 §3.2](../rfcs/RFC-0023-pattern-matching.md) |
| MATCH-009 | Slice pattern overlaps | [RFC-0023 §3.4](../rfcs/RFC-0023-pattern-matching.md) |
| MATCH-010 | @-binding name collides with outer scope | [RFC-0023 §3.3](../rfcs/RFC-0023-pattern-matching.md) |

## COLL series — RFC-0017 collections

| Code | Title | RFC section |
|---|---|---|
| COLL-001 | HashMap/HashSet key type lacks `Hash + Eq` | [RFC-0017 §3.2](../rfcs/RFC-0017-collections.md) |
| COLL-002 | BTreeMap/BTreeSet key type lacks `Ord` | [RFC-0017 §3.3](../rfcs/RFC-0017-collections.md) |
| COLL-003 | Collection method that may grow used in `#[no_alloc]` | [RFC-0017 §3.5](../rfcs/RFC-0017-collections.md), [RFC-0001](../rfcs/RFC-0001-rt-attributes.md) |
| COLL-004 | Iter invalidated by mutation during walk | [RFC-0017 §3.4](../rfcs/RFC-0017-collections.md) |
| COLL-005 | Index out of bounds on fixed-length collection | [RFC-0017 §3.1](../rfcs/RFC-0017-collections.md) |

## MOD series — RFC-0018 modules

| Code | Title | RFC section |
|---|---|---|
| MOD-001 | Module file not found at expected path | [RFC-0018 §3.1](../rfcs/RFC-0018-modules.md) |
| MOD-002 | Path references non-existent module/item | [RFC-0018 §3.3](../rfcs/RFC-0018-modules.md) |
| MOD-003 | Visibility violation | [RFC-0018 §3.2](../rfcs/RFC-0018-modules.md) |
| MOD-004 | Glob `use *` from a module without an explicit prelude (warning) | [RFC-0018](../rfcs/RFC-0018-modules.md) |
| MOD-005 | Circular module dependency | [RFC-0018](../rfcs/RFC-0018-modules.md) |
| MOD-006 | Two `use` declarations bind the same name | [RFC-0018 §3.4](../rfcs/RFC-0018-modules.md) |

## PKG series — RFC-0019 packages

| Code | Title | RFC section |
|---|---|---|
| PKG-001 | Manifest schema error | [RFC-0019 §3.1](../rfcs/RFC-0019-package-manager.md) |
| PKG-002 | Version conflict — no resolution found | [RFC-0019 §3.3](../rfcs/RFC-0019-package-manager.md) |
| PKG-003 | Checksum mismatch | [RFC-0019 §3.4](../rfcs/RFC-0019-package-manager.md) |
| PKG-004 | Network error fetching package | [RFC-0019 §3.5](../rfcs/RFC-0019-package-manager.md) |
| PKG-005 | Unknown package / version | [RFC-0019 §3.5](../rfcs/RFC-0019-package-manager.md) |
| PKG-006 | Yanked version explicitly required | [RFC-0019 §3.5](../rfcs/RFC-0019-package-manager.md) |

## TGT series — RFC-0022 cross-platform

| Code | Title | RFC section |
|---|---|---|
| TGT-001 | Unknown target triple | [RFC-0022 §3.1](../rfcs/RFC-0022-cross-platform.md) |
| TGT-002 | Sysroot not installed for target | [RFC-0022 §3.7](../rfcs/RFC-0022-cross-platform.md) |
| TGT-003 | Feature unsupported on target | [RFC-0022 §3.6](../rfcs/RFC-0022-cross-platform.md) |
| TGT-004 | Cross-link error | [RFC-0022 §3.7](../rfcs/RFC-0022-cross-platform.md) |

## ITER / CLO / DYN / LIFE / FMT / DOC — v0.4 Tier 2

Reserved for RFCs 0024-0029. Codes populate as those RFCs land.

## TST series — RFC-0021 test framework

**TST-001..003 wired into the explain registry in v0.2.79.**
RFC-0021 originally shipped the test framework (`nuc test`
discovery, `assert_eq!` / `assert_ne!` macros,
`--isolation=process` mode) without minting test-runner-specific
error codes — runtime test failures surfaced through `assert_*`
panic messages plus the test harness's own exit-status
reporting. The v0.2.79 explain-coverage audit found three TST
codes spec'd here but missing from the registry; all three were
wired into `compiler/nucleor_tools_suite.nr` and the gate now
exercises them via `cli_explain_full_smoke` (added v0.2.79,
extended to the full 130-code spec catalog in v0.2.80).

| Code | Title | RFC section | Status |
|---|---|---|---|
| TST-001 | Test discovery: no `#[test]` functions found | RFC-0021 §3.1 | Wired (v0.2.79); test runner fires when discovery returns 0 |
| TST-002 | Test isolation: process child crashed before reporting | RFC-0021 §3.4 | Wired (v0.2.79); runtime check fires under `--isolation=process` |
| TST-003 | Test fixture: setup fn returned non-zero | RFC-0021 (deferred) | Wired (v0.2.79) but body deferred — fires when v0.4 fixture work lands |

## DIAG series — RFC-0020 diagnostics machinery

**Reserved namespace; no user-facing codes minted as of v0.2.103.**
RFC-0020 phase 1 + 2 shipped the LineMap infrastructure
(`linemap_*` runtime helpers, error-vs-warning split where warnings
no longer halt the build) but no DIAG-NNN codes — the diagnostic
machinery surfaces through the per-RFC code series (NR, NUM,
MATCH, COLL, MOD, PKG, TGT, TST, etc.) rather than its own series.

The `nuc explain CODE` command is part of the RFC-0020 surface;
its error path (unknown code) was previously reported as a plain
"unknown error code" message rather than a structured DIAG-NNN.
RFC-0020 phase 3 (planned for v0.4) is the existing-error span
migration, not new code minting.

## EFF series — RFC-0032 effects

| Code | Title | RFC section |
|---|---|---|
| EFF-001 | Function uses effect not in declared row | [RFC-0032 §3.1](../rfcs/RFC-0032-effects.md) |
| EFF-002 | pure fn calls effectful fn | [RFC-0032 §3.2](../rfcs/RFC-0032-effects.md) |
| EFF-003 | restricts [...] violated | [RFC-0032 §3.4](../rfcs/RFC-0032-effects.md) |
| EFF-004 | Effect declared but not used (warning) | [RFC-0032](../rfcs/RFC-0032-effects.md) |
| EFF-005 | Custom effect handler missing | [RFC-0032 §3.1](../rfcs/RFC-0032-effects.md) |

## LAW series — RFC-0031 algebraic laws

| Code | Title | RFC section |
|---|---|---|
| LAW-001 | Property test fails | [RFC-0031 §3.2](../rfcs/RFC-0031-algebraic-laws.md) |
| LAW-002 | SMT disproves law (cert profile) | [RFC-0031 §3.4](../rfcs/RFC-0031-algebraic-laws.md) |
| LAW-003 | Law cited but optimizer cannot use it | [RFC-0031](../rfcs/RFC-0031-algebraic-laws.md) |
| LAW-004 | Float operation claimed exact associative (warn) | [RFC-0031 §3.3](../rfcs/RFC-0031-algebraic-laws.md) |

---

## Adding a new error code

When a new error code is introduced (via an RFC):

1. Add it to this file under the appropriate series (create a new
   series table if needed).
2. Register it in `nucleor_tools_suite.nr`:
   - `explain_error_title()` — one-line summary
   - `explain_error_summary()` — single-sentence description
   - `explain_error_explanation()` — paragraph of context
3. Verify `nuc explain CODE` renders correctly.
4. Add a test in `tests/err/` that triggers the code (where
   possible).

## Suppression

Users can suppress diagnostics per-scope via `#[allow(CODE)]` or
per-project via the build profile. Warnings can be promoted to
errors with `#[deny(CODE)]`.

Some codes (safety-cert subset — see `docs/process/nucleor-safe-subset.md`)
cannot be suppressed in `--profile=cert` mode.
