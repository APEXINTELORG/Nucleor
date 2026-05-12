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
| NR035 | Explicit enum discriminants not yet supported (parse-time halt — v0.6.35) | parse |
| NR036 | Self-recursive struct without Box / & indirection (Rust E0072 — v0.6.36) | parse |
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
| OWN-013 | Spawn block captures non-`Send` `DeviceBuffer` value | spawn-capture checker | error |

Gate-tested via `tests/err/err_*` (use-after-move, borrow-
after-move, two-mut-borrows, shared-mut-conflict,
assign-shared-ref, field-assign-while-borrowed,
immutable-assign, dangling-return, lifetime-scope-escape,
mut-borrow-immutable, arena-destroy-live-ref). **OWN-013**
is fired from `compiler/nucleor_tools_suite.nr`'s spawn-
capture pass when a `spawn { ... }` block captures a
non-`Send` `DeviceBuffer` (GPU memory handles are pinned to
their launching thread); documented v0.2.131 after the audit
sweep found it fired without spec + explain-registry entries.

## RACE series — RFC-0035 Sendable + actor isolation

| Code | Title | RFC section |
|---|---|---|
| RACE-001 | Non-Sendable value captured by spawned closure or spawn-style call | [RFC-0035 §3.5](../rfcs/RFC-0035-sendable-actors.md) |
| RACE-002 | Actor method called without await | [RFC-0035 §3.3](../rfcs/RFC-0035-sendable-actors.md) |
| RACE-003 | Actor internal state escapes isolation | [RFC-0035 §3.3](../rfcs/RFC-0035-sendable-actors.md) |
| RACE-004 | Shared mutable state without Mutex or actor | [RFC-0035 §3.1](../rfcs/RFC-0035-sendable-actors.md) |
| RACE-005 | `&mut T` crosses a thread boundary | [RFC-0035 §3.7](../rfcs/RFC-0035-sendable-actors.md) |
| RACE-006 | Reentrant actor lock violation | [RFC-0035 §3.4](../rfcs/RFC-0035-sendable-actors.md) |
| RACE-007 | Deadline composition under actor await is invalid | [RFC-0035 §3.6](../rfcs/RFC-0035-sendable-actors.md) |
| RACE-008 | `#[not_sendable]` type used where Sendable is required | [RFC-0035 §3.2](../rfcs/RFC-0035-sendable-actors.md) |
| RACE-009 | Reserved | [RFC-0035 §4](../rfcs/RFC-0035-sendable-actors.md) |
| RACE-010 | Reserved | [RFC-0035 §4](../rfcs/RFC-0035-sendable-actors.md) |

The v0.6 first-pass checker is source-level and intentionally
conservative: explicit `impl Sendable for T {}` unlocks spawned
value transfer, `#[not_sendable]` wins over structural shape, and
field-only `actor` declarations reject direct external field access.

## TNT series — taint analysis (expansion of NR033)

The taint analyzer fires concrete `TNT-NNN` codes; `NR033`
remains the umbrella stage code. **One TNT code shipped today
(documented v0.2.120)**, fired from
`compiler/nucleor_tools_suite.nr`'s strict-checker pass when
tainted data flows into a function annotated as a sensitive
sink. The suggestion machinery proposes wrapping the value in
`sanitize(value)` before the call.

| Code | Title | Source | Severity |
|---|---|---|---|
| TNT-001 | Tainted data passed to sensitive sink | strict-mode taint pass | warning |

Gate-tested via `tests/err/err_taint_*` (taint_arg, taint_leak,
taint_propagation, taint_to_clean — though those fire TYP-006
or TYP-008 from the type checker rather than TNT-001 from the
strict pass; TNT-001 is the warning-level companion).

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
| TYP-011 | `str + str` not supported (would silently segfault) | binop type-check, v0.4.51 | error |
| TYP-012 | Missing field(s) in struct initialization (would silently default to 0/empty) | struct-init type-check, v0.4.62 | error |
| TYP-013 | Unknown field in struct initialization (would silently drop the extra field) | struct-init type-check, v0.4.63 | error |
| TYP-026 | Invalid or unproven `as char`, or a non-void function reaches the end with no tail expression | type-check, v0.4.219/v0.8.45 | error |
| TYP-027 | Type inference failed; explicit annotation required | strict inference type-check, v0.8 E3 | error |
| TYP-044 | Implicit integer width conversion in binding | let stmt type-check, v1.1.0 audit | error |

`TYP-027` is suppressed only when strict inference can prove the
initializer's concrete type. The current positive helper-return table
covers core string helpers, direct IO/env/path helpers, format/string
conversion helpers, and direct numeric/f64 runtime helpers. Unknown
helpers still require an explicit user function signature or a concrete
type annotation at the call boundary.

`TYP-044` rejects implicit integer width conversion at bindings.
Use an explicit `as` cast when the conversion is intentional.

### FMT series — format macro expansion

| Code | Title | Source | Notes |
|---|---|---|---|
| FMT-002 | Type does not implement Display for bare `{}` formatting | format macro expansion, v0.4.91 | error |
| FMT-003 | Format string has more arguments than `{}` placeholders (extras would be silently dropped) | format macro expansion, v0.5.11 | error |

### TRAIT series — trait dispatch and conversions

| Code | Title | Source | Notes |
|---|---|---|---|
| TRAIT-001 | Missing From conversion for `?` error propagation | `?` lowering, RFC-0016 §3.7 | error |

Gate-tested via `tests/err/err_bool_arith`, `err_args`,
`err_deref_nonref`, `err_taint_arg/leak/propagation`,
`err_taint_to_clean`.

## RT series — RFC-0001 real-time function attributes

| Code | Title | RFC section |
|---|---|---|
| RT-001 | Allocation in #[no_alloc] function | [RFC-0001 §3.2.1](../rfcs/RFC-0001-rt-attributes.md) |
| RT-002 | Possibly-panicking expression in #[no_panic] function | [RFC-0001 §3.2.2](../rfcs/RFC-0001-rt-attributes.md) |
| RT-003 | Dynamic dispatch in #[no_dyn] function | [RFC-0001 §3.2.3](../rfcs/RFC-0001-rt-attributes.md) |
| RT-004 | Heuristic deadline estimate exceeds declared #[deadline] (not certified WCET) | [RFC-0001 §3.2.4](../rfcs/RFC-0001-rt-attributes.md), [RFC-0009](../rfcs/RFC-0009-heptane-wcet.md) |
| RT-005 | FFI call in RT function without #[ffi_no_*] annotation | [RFC-0001 §3.5](../rfcs/RFC-0001-rt-attributes.md) |
| RT-006 | RT attribute on async fn | [RFC-0001](../rfcs/RFC-0001-rt-attributes.md), [RFC-0030](../rfcs/RFC-0030-async-decision.md) |
| RT-007 | Deadline annotation without no_alloc or no_panic | [RFC-0001](../rfcs/RFC-0001-rt-attributes.md) |
| RT-008 | Recursive call in #[deadline] function | [RFC-0014](../rfcs/RFC-0014-max-depth.md) |
| RT-009 | Integer division or modulo in #[no_panic] function | [RFC-0001 §3.2.2](../rfcs/RFC-0001-rt-attributes.md) |

## ASYNC series — async fn handling

| Code | Title | Source | Notes |
|---|---|---|---|
| ASYNC-001 | `async` keyword on fn is silently stripped (use `async_spawn` + `async_await` for threading) | resolver async-strip pass, v0.5.19 | warning |

## PERF series — router and hot-path diagnostics

| Code | Title | Source |
|---|---|---|
| PERF-1 | Invalid router `--tier` value | router / performance tier validation |
| PERF-2 | `@hot` function contains heap allocation or I/O | hot-path audit |
| PERF-3 | Heap allocation inside a while/loop block | heap-in-loop audit |

## ALLOC series — RFC-0002 allocator types

| Code | Title | RFC section |
|---|---|---|
| ALLOC-001 | Allocated value escapes its allocator | [RFC-0002 §3.2](../rfcs/RFC-0002-allocator-types.md) |
| ALLOC-002 | Allocator type mismatch | [RFC-0002 §3.9](../rfcs/RFC-0002-allocator-types.md) |
| ALLOC-003 | Allocation forbidden by #[no_alloc] | [RFC-0002 §3.7](../rfcs/RFC-0002-allocator-types.md) |

## FRAME series — RFC-0003 typed coordinate frames

| Code | Title | RFC section | Status |
|---|---|---|---|
| FRAME-001 | Cannot combine values in different coordinate frames | [RFC-0003 §3.3](../rfcs/RFC-0003-typed-frames.md), [RFC-0046](../rfcs/RFC-0046-coordinate-frame-types.md) | LIVE — fires at let-binding, call-argument, struct/tuple init, assignment, return, and binop sites for `Pose<Frame_X>`-style phantom-tag mismatches |
| FRAME-002 | Transform composition mismatch | [RFC-0003 §3.3](../rfcs/RFC-0003-typed-frames.md) | RESERVED — fires once `Transform<From, To>` parses/type-checks |
| FRAME-003 | Cannot apply transform to value in incompatible frame | [RFC-0003 §3.3](../rfcs/RFC-0003-typed-frames.md) | RESERVED — fires once `transform()` call sites are wired |

**FRAME-001 firing surface:**
The type-check pass detects two types whose first generic arguments
carry distinct `Frame_*` phantom tags on matching base names (e.g.
`Pose<Frame_Camera>` vs `Pose<Frame_Base>`) and emits
`error[FRAME-001]` with the canonical Mars-Climate-Orbiter framing
and a `kinematics_transform` fix pointer. `Frame_Unknown` is the
documented migration sentinel (RFC-0046 §migration) and matches any
frame; untagged types (no `<...>` parameter) are unaffected.

Covered diagnostic sites: let bindings, function-call arguments,
named struct initialization fields, tuple-struct positional fields,
plain assignments, indexed assignments, struct-field assignments,
explicit returns, tail-expression returns, and binary/operator
operands. Positive coverage:
`tests/features/robo7_frame_positive_smoke.nr` (5 invariants).
Negative coverage: `tests/err/err_robo7_frame_mismatch.nr` plus
the `tests/err/err_robo7_frame_*_mismatch.nr` site-specific
fixtures.

Stdlib migration coverage: `stdlib/rods/kinematics.nr` exposes
an adopter-facing `Pose<Frame_*>` facade and explicit
`kinematics_transform*` helpers over the existing pose math handles.
Positive coverage:
`tests/features/robo7_kinematics_typed_pose_smoke.nr`. Negative
coverage:
`tests/err/err_robo7_kinematics_transform_call_mismatch.nr`.

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

Current implementation note: the `UNIT-*` series remains the
reserved semantic-diagnostic namespace for the future compiler-level
`unit<T, dim>` algebra. The active fail-closed archive guards currently
surface through `TYP-003`, `TYP-007`, and `TYP-008`, while
`stdlib/rods/units.nr` provides a positive nominal `UnitDistance` /
`UnitVelocity` API over f64 values plus stable unit IDs.

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
| CONTRACT-008 | `result` referenced in `#[ensure]` on a void fn | [RFC-0006 §3.3](../rfcs/RFC-0006-design-by-contract.md) |
| CONTRACT-009 | Unrecognized `NUCLEOR_DBC_MODE` env value | [RFC-0006 §4.2](../rfcs/RFC-0006-design-by-contract.md) |
| CONTRACT-010 | `old(...)` used inside `#[require]` (preconditions have no prior state) | [RFC-0006 §3.2](../rfcs/RFC-0006-design-by-contract.md) |
| CONTRACT-011 | Undefined identifier in `#[require]` / `#[ensure]` predicate | [RFC-0006 §3.2](../rfcs/RFC-0006-design-by-contract.md) |

## ATOMIC series — RFC-0007 atomic + lock-free

| Code | Title | RFC section |
|---|---|---|
| ATOMIC-001 | Blocking call inside #[atomic] function | [RFC-0007 §3.3](../rfcs/RFC-0007-atomic.md) |
| ATOMIC-002 | Allocating call inside #[atomic] function | [RFC-0007 §3.3](../rfcs/RFC-0007-atomic.md) |
| ATOMIC-003 | Use of Cell/RefCell in #[atomic] | [RFC-0007](../rfcs/RFC-0007-atomic.md) |
| ATOMIC-004 | Mismatched orderings in compare_exchange | [RFC-0007 §3.2](../rfcs/RFC-0007-atomic.md) |
| ATOMIC-005 | Invalid memory ordering for atomic load/store | [RFC-0007 §3.2](../rfcs/RFC-0007-atomic.md) |
| ATOMIC-006 | Atomic helper called inside closure body (closure-lowering enum-scope gap) | [RFC-0007 §3.4](../rfcs/RFC-0007-atomic.md) |

## ISR series — RFC-0008 interrupt service routines

| Code | Title | RFC section |
|---|---|---|
| ISR-001 | #[isr] function must be `fn() -> void` | [RFC-0008 §3.2](../rfcs/RFC-0008-isr.md) |
| ISR-002 | #[isr] cannot be combined with #[deadline] | [RFC-0008 §3.2](../rfcs/RFC-0008-isr.md) |
| ISR-003 | Target does not support #[isr] yet | [RFC-0008 §3.5](../rfcs/RFC-0008-isr.md) |
| ISR-004 | Vector name not recognized for target architecture | [RFC-0008 §3.1](../rfcs/RFC-0008-isr.md) |
| ISR-005 | Two ISRs assigned to the same vector | [RFC-0008 §3.3](../rfcs/RFC-0008-isr.md) |
| ISR-006 | Priority out of range for target NVIC | [RFC-0008 §3.1](../rfcs/RFC-0008-isr.md) |
| ISR-007 | Malformed `prio` attribute (negative / string / missing value) — v0.6.32 | [RFC-0008 §3.1](../rfcs/RFC-0008-isr.md) |
| ISR-008 | `#[isr]` applied to a non-fn item — v0.6.31 (orig. ISR-004; renamed in v0.6.32 because ISR-004 is reserved for "Vector name not recognized") | [RFC-0008 §3.1](../rfcs/RFC-0008-isr.md) |

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
| DEPTH-001 | Max-depth analysis cannot bound recursive path | [RFC-0014 §3.3](../rfcs/RFC-0014-max-depth.md) |
| DEPTH-002 | Bounded recursion exceeds #[max_depth = N] | [RFC-0014 §3.3](../rfcs/RFC-0014-max-depth.md) |
| DEPTH-003 | Mutually-recursive max_depth cycle violates bounds | [RFC-0014 §3.4](../rfcs/RFC-0014-max-depth.md) |
| DEPTH-004 | Invalid #[max_depth] attribute placement or value | [RFC-0014 §3.1](../rfcs/RFC-0014-max-depth.md) |
| DEPTH-005 | Total stack budget exceeded | [RFC-0014 §3.5](../rfcs/RFC-0014-max-depth.md) |

## NUM series — RFC-0015 numeric types

| Code | Title | RFC section |
|---|---|---|
| NUM-001 | Mixed-width arithmetic without cast | [RFC-0015 §3.2](../rfcs/RFC-0015-numeric-types.md) |
| NUM-002 | Numeric literal out of range for declared type | [RFC-0015 §3.6](../rfcs/RFC-0015-numeric-types.md) |
| NUM-003 | `as` cast loses precision (warning) | [RFC-0015 §3.5](../rfcs/RFC-0015-numeric-types.md) |
| NUM-004 | f8/f16/bf16 op without hardware support | [RFC-0015 §3.4](../rfcs/RFC-0015-numeric-types.md) |
| NUM-005 | usize/isize mixed with explicit-width type | [RFC-0015 §3.1](../rfcs/RFC-0015-numeric-types.md) |
| NUM-006 | Signed/unsigned arithmetic without explicit cast | RFC-0015 / v0.2.319 expansion |
| NUM-007 | Float→int cast saturates to type bounds | RFC-0015 / v0.2.319 expansion |
| NUM-008 | Shift amount equals or exceeds operand width (UB-prone) | RFC-0015 / v0.2.319 expansion |
| NUM-009 | Division or remainder by literal zero | RFC-0015 / v0.2.319 expansion |
| NUM-010 | Implicit narrowing of f64 literal to f32 may lose precision | RFC-0015 / v0.2.319 expansion |
| NUM-011 | Overflow attribute conflicts with operation kind | RFC-0015 / v0.2.319 expansion |
| NUM-012 | Cast from pointer to non-pointer-width integer | RFC-0015 / v0.2.319 expansion |
| NUM-013 | Vec\<T\> requires sized element type | RFC-0015 / v0.2.319 expansion |
| NUM-014 | sizeof_struct on unknown / generic struct | RFC-0015 / v0.2.319 expansion |
| NUM-015 | extern fn signature uses non-ABI-stable type | RFC-0015 / v0.2.319 expansion |
| NUM-016 | Comparison between signed and unsigned of equal width | RFC-0015 / v0.2.319 expansion |
| NUM-017 | Bitwise op on signed type may have surprising sign-extension | RFC-0015 / v0.2.319 expansion |
| NUM-018 | Float literal in integer context | RFC-0015 / v0.2.319 expansion |
| NUM-019 | Negative literal assigned to unsigned type | RFC-0015 / v0.2.319 expansion |
| NUM-020 | Mixed-width comparison without explicit cast | RFC-0015 / v0.2.319 expansion |
| NUM-021 | Integer literal or module-level const expression overflows at compile time | RFC-0015 / v0.4.119 / v0.6 E3 |
| NUM-022 | Integer vs float in arithmetic/comparison binop | RFC-0015 / v0.4.137 |
| NUM-023 | Float / bool `as`-cast to `str` rejected | RFC-0015 / v0.4.140 |
| NUM-024 | Cross-width call-site narrowing audit (opt-in: `NUCLEOR_AUDIT_NUM024=1`) | RFC-0015 phase 3c.1 / v0.4.228 |

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
| MATCH-011 | Heterogeneous match literal or arm type mismatch | [RFC-0023 §3.5](../rfcs/RFC-0023-pattern-matching.md) |
| MATCH-012 | Struct-pattern field after `:` is not an identifier | [RFC-0023 §3.6](../rfcs/RFC-0023-pattern-matching.md) |
| MATCH-013 | Float scrutinee or float-literal pattern in `match` is unsupported | [RFC-0023 §3.7](../rfcs/RFC-0023-pattern-matching.md) |
| MATCH-014 | Negative literal range-pattern bounds are unsupported; use a guard | [RFC-0023 §3.1](../rfcs/RFC-0023-pattern-matching.md) |
| MATCH-015 | Negative literal pattern in match arm is unsupported; use a guard | [RFC-0023 §3.1](../rfcs/RFC-0023-pattern-matching.md) |
| MATCH-016 | Cross-enum pattern: scrutinee enum type does not match constructor's enum type | RFC-0062 G-1 memory-safety gate |

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

| Code | Title | Shipped |
|---|---|---|
| DIAG-001 | Unknown diagnostic code in `#[allow]` / `#[deny]` attribute | v0.3.36 |

**v0.3.36 (T3.20) minted the first DIAG-NNN code; v0.3.38 (T3.22)
tightened the check from prefix-only to enumerated.** Prior to
v0.3.36 the namespace was reserved (RFC-0020 phase 1 + 2 shipped
only the LineMap infrastructure and the error-vs-warning split —
no user-facing DIAG codes). DIAG-001 fires when an `#[allow(CODE)]`,
`#[allow_fn(CODE)]`, `#[deny(CODE)]`, or `#[deny_fn(CODE)]`
attribute references a CODE that is not in the canonical
enumerated diagnostic code set (the same ~150 codes audited
by `cli_explain_full_smoke`). The suppression / promotion has
no effect at compile time — the diagnostic the author meant to
control still fires unsuppressed. Suppress DIAG-001 itself
during a noisy refactor with `#[allow(DIAG-001)]`.

The enumerated check (v0.3.38) catches both unknown-prefix
codes (e.g. `WAT-001`) and within-series typos (e.g. `RT-099`
vs `RT-009`) uniformly. The v0.3.36 prefix-only check let the
within-series class slip through; v0.3.38 closes that gap by
maintaining a hardcoded set in `is_known_diag_code` parallel
to the `cli_explain_full_smoke` audit list. When minting a new
code, add to BOTH locations.

The `nuc explain CODE` command is part of the RFC-0020 surface;
its error path (unknown code) is reported as a plain
"unknown error code" message — that path is unchanged by v0.3.36.
RFC-0020 phase 3 (planned for v0.4) is the existing-error span
migration plus the within-series enumerated DIAG-001 check.

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
| LAW-001 | Generated law check failed, declared law has incompatible arity, or canonical form lacks a shipped bounded checker | [RFC-0031 §3.2](../rfcs/RFC-0031-algebraic-laws.md) |
| LAW-002 | SMT disproves law (cert profile) | [RFC-0031 §3.4](../rfcs/RFC-0031-algebraic-laws.md) |
| LAW-003 | Law cited but optimizer cannot use it | [RFC-0031](../rfcs/RFC-0031-algebraic-laws.md) |
| LAW-004 | Float or approximate law form lacks shipped tolerance semantics | [RFC-0031 §3.3](../rfcs/RFC-0031-algebraic-laws.md) |
| LAW-006 | `--check-laws` rejected deprecated alias `zero = Z`; use `absorbing = Z` | [Algebraic law schema](Nucleor_Algebraic_Laws_Schema.md) |
| LAW-007 | `--check-laws` rejected deprecated bare `distributive`; use `distributive_over = g` | [Algebraic law schema](Nucleor_Algebraic_Laws_Schema.md) |
| LAW-008 | `--check-laws` rejected an unrecognized law name | [Algebraic law schema](Nucleor_Algebraic_Laws_Schema.md) |

## GOV series — governance policies

The governance pass in `compiler/nucleor_tools_suite.nr` enforces
opt-in `@policy(...)` attributes that constrain what authored
functions and unsafe blocks may appear in the source. Documented
v0.2.131 after the audit sweep found the codes fired without
spec + explain-registry entries.

| Code | Title | Source | Severity |
|---|---|---|---|
| GOV-001 | `policy(require_authored)` requires `@authored` annotations | governance pass | warning |
| GOV-002 | `policy(no_unsafe)` forbids `unsafe` blocks | governance pass | warning |

Test corpus: `tests/err/_unimplemented/err_policy_missing_authored.nr`
+ `err_policy_no_unsafe.nr` — currently quarantined under
`_unimplemented/` because the s1 compiler accepts the source
unconditionally; the tools-suite governance pass does fire the
codes via `nuc check` / `nuc audit`. Once the s1 strict-mode
flip lands (v0.4 follow-on), the tests will move out of
`_unimplemented/` and the verify gate will enforce them.

---

## Adding a new error code

When a new error code is introduced (via an RFC or by audit
finding a fired-but-undocumented code), all six steps below
must be done in the same commit so the verify gate locks the
addition in:

1. **Spec doc (this file)** — add a row in the appropriate
   series table (create a new series table if needed).
2. **Explain registry in `compiler/nucleor_tools_suite.nr`** —
   add three entries (one per function) for the code:
   - `explain_error_title()` — one-line summary
   - `explain_error_summary()` — single-sentence description
   - `explain_error_explanation()` — paragraph of context
3. **Gate scripts in BOTH `tools/verify.sh` AND
   `tools/verify.ps1`** — append the code to the
   `cli_explain_full_smoke` codes array (the bash array literal
   and the PowerShell array; keep the two scripts in step-for-
   step parity). This step is what makes `nuc explain CODE`
   gate-tested.
4. **Test in `tests/err/`** — add a one-file negative test
   that triggers the code. The first line must be a
   `// EXPECT: CODE [text]` header (the v0.2.118
   `err_tests_have_expect_smoke` gate step rejects test files
   without one).
5. **Verify the gate stays green** — run `bash tools/verify.sh`
   (or `powershell -File tools/verify.ps1` on Windows). The
   `cli_explain_full_smoke` step exercises every code in its
   array; a missing explain-registry entry surfaces as an
   immediate gate failure.
6. **Update consumer docs** — keep this spec, `docs/language-reference.md`,
   and the `nuc explain` help coverage in sync when the catalog changes.
   `tools/check_compiler_drift.sh` does not enforce the prose count, so
   this remains a reviewer responsibility.

Codes that fire from the s1 compiler proper (`nucleor_s1_compiler.nr`)
follow the same recipe — the compiler ABI tables don't track
diagnostic codes (only `__nucleor_*` symbols), so a new code
added there only changes step 2's source file (the explain
registry still lives in the tools-suite, since that's what
backs `nuc explain`). The 2-iteration LLVM IR fixed-point
check from `bootstrap/README.md` applies whenever the s1 source is touched.

## Suppression

> **Status (v0.2.152):** `#[allow(CODE)]` and `#[deny(CODE)]`
> both ship. Scope is file-wide for the v0.2 cut — anywhere
> the attribute appears in the source, the named code is
> respectively silenced or promoted-to-error for the whole
> compile unit. Per-fn / per-block scoping ships with v0.4
> alongside the general attribute-with-argument parsing
> infrastructure that powers RFC-0004 `#[assume]` and
> RFC-0014 `#[max_depth]`.

Users suppress warning-severity diagnostics per-file via
`#[allow(CODE)]`, and promote warning-severity diagnostics to
errors via `#[deny(CODE)]`. Both checks happen after every
compiler pass fires its diagnostics — `filter_allow_suppressed`
walks the collected `diags` vec and drops any whose severity
is `"warning"` and whose code matches an entry in the source's
collected allow-list, then `promote_denied_to_errors` walks
the surviving diags and flips severity from `"warning"` to
`"error"` where the code matches an entry in the deny-list.
Errors are never suppressible; allow runs first so a deny on
a previously-allowed code is a no-op (the diag is gone).
Gate-tested via `tests/lang/allow_suppress_warning.nr` (allow)
and `tests/err/err_deny_promotes_warning.nr` (deny).

The mechanism preserves `#[allow]` and `#[deny]` lines through
`resolve_source_with_records` (the import / `#cfile` / `#link`
preprocessor) by checking for `#[` after the leading `#`
before stripping the line — Rust-style attributes are kept
intact for the diag-filter to scan.

**Planned v0.4 design:** per-fn / per-block scoping for
`#[allow]` / `#[deny]`; build-profile suppression. Safety-cert
diagnostics are not suppressible in `--profile=cert` mode.
