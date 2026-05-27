# Nucleor Error Codes

Nucleor diagnostics use stable code families so humans, editors, CI systems,
and documentation can refer to compiler errors consistently.

## Format

Diagnostics are printed as:

```text
error[CODE-NNN]: message
```

Warnings and informational diagnostics use the same code format.

## Code Families

| Family | Area |
|---|---|
| `NR` | Lexer, parser, and source-shape errors |
| `TYP` | Type checking and type inference |
| `NUM` | Numeric literals, casts, overflow, and arithmetic hazards |
| `MATCH` | Pattern matching, exhaustiveness, and `?` lowering |
| `OWN` | Ownership, moves, drops, and use-after-move checks |
| `RACE` | Sendable, thread, actor, and isolation checks |
| `RT` | Real-time attributes: allocation, panic, dynamic dispatch, deadlines |
| `FFI` | ABI, nullability, extern, and host-call boundaries |
| `ALLOC` | Allocator and region rules |
| `FRAME` | Typed coordinate frames |
| `UNIT` | Dimensional units |
| `CONTRACT` | `#[require]`, `#[ensure]`, and invariants |
| `ATOMIC` | Atomic and lock-free constraints |
| `ITER`, `CLO`, `DYN`, `LIFE` | Iterators, closures, trait objects, and lifetimes |
| `FMT` | Formatting and display/debug rules |
| `MOD` | Modules and imports |
| `PKG` | Manifests, package resolution, and publishing |
| `TST` | Test runner diagnostics |
| `DIAG` | Diagnostic attributes and explain registry |
| `EFF` | Effects and capability rows |
| `LAW` | Algebraic law metadata and generated checks |
| `PERF` | Hot-path and performance-envelope checks |

## Active Diagnostic Codes

Each code below is in the canonical set tracked by
`tools/verify.sh`'s drift gate. The meaning column is
auto-generated from the explain registry
(`compiler/nucleor_tools_suite.nr` fn `explain_error_title`).

| Code | Meaning |
|---|---|
| ALLOC-001 | Allocated value escapes its allocator |
| ALLOC-002 | Allocator type mismatch |
| ALLOC-003 | Allocation forbidden by #[no_alloc] |
| ASSUME-001 | predicate not in analyzer's vocabulary |
| ASSUME-002 | assume_unchecked! used without justification |
| ASSUME-003 | assume! predicate is a tautology |
| ASSUME-004 | assume! contradicts type-system fact |
| ASSUME-005 | cert-profile: assume! not proven |
| ASYNC-001 | `async` keyword on fn is silently stripped (v0.5 has no Future/.await; use async_spawn + async_await for threading) |
| ATOMIC-001 | Blocking call inside #[atomic] function |
| ATOMIC-002 | Allocating call inside #[atomic] function |
| ATOMIC-003 | Use of Cell/RefCell in #[atomic] |
| ATOMIC-004 | Mismatched orderings in compare_exchange |
| ATOMIC-005 | Invalid memory ordering for atomic load/store |
| ATOMIC-006 | Atomic helper inside closure is temporarily unsupported |
| BINDGEN-001 | Header file not found |
| BINDGEN-002 | libclang parse error |
| BINDGEN-003 | Type conversion not supported |
| BINDGEN-004 | Forward-declared type with no definition |
| BINDGEN-005 | Duplicate symbol |
| COLL-001 | K: Hash + Eq requirement violated |
| COLL-002 | K: Ord requirement violated for BTree |
| COLL-003 | Collection method that may grow used in #[no_alloc] |
| COLL-004 | Iterator invalidated by mutation during walk |
| COLL-005 | Index out of bounds on fixed-length collection |
| CONTRACT-001 | Require violation |
| CONTRACT-002 | Ensure violation |
| CONTRACT-003 | Invariant violation |
| CONTRACT-004 | Trait impl weakens precondition (Liskov) |
| CONTRACT-005 | Trait impl strengthens postcondition (Liskov) |
| CONTRACT-006 | old(expr) references mutable state without snapshot |
| CONTRACT-007 | In cert profile, contract not statically provable |
| CONTRACT-008 | result referenced in void-fn ensure |
| CONTRACT-009 | Invalid NUCLEOR_DBC_MODE value |
| CONTRACT-010 | old(expr) used in require precondition |
| CONTRACT-011 | Undefined identifier in contract predicate |
| CXX-001 | C++ header not found |
| CXX-002 | Type mismatch between Nucleor decl and C++ source |
| CXX-003 | Use of std::function without #[no_dyn] opt-out |
| CXX-004 | extern \ |
| CXX-005 | C++ exception escapes through bridge |
| DEPTH-001 | Max-depth analysis cannot bound recursive path |
| DEPTH-002 | Bounded recursion exceeds #[max_depth = N] |
| DEPTH-003 | Mutually-recursive max_depth cycle violates bounds |
| DEPTH-004 | Invalid #[max_depth] attribute placement or value |
| DEPTH-005 | Total stack budget exceeded |
| DIAG-001 | Unknown diagnostic code in #[allow]/#[deny] attribute |
| DLPACK-001 | Unsupported device |
| DLPACK-002 | Unsupported dtype |
| DLPACK-003 | Shape mismatch |
| DLPACK-004 | Non-contiguous tensor and no copy requested |
| DLPACK-005 | DLPack version too old |
| EFF-001 | Function uses effect not in declared row |
| EFF-002 | pure fn calls effectful fn |
| EFF-003 | restricts [...] violated |
| EFF-004 | Effect declared but not used (warning) |
| EFF-005 | Custom effect handler missing |
| FMT-002 | Type does not implement Display for bare `{}` formatting |
| FMT-003 | Format string has more arguments than `{}` placeholders (extras would be silently dropped) |
| FRAME-001 | Cannot add values in different coordinate frames |
| FRAME-002 | Transform composition mismatch |
| FRAME-003 | Cannot apply transform to value in incompatible frame |
| GOV-001 | policy(require_authored) requires authored annotations |
| GOV-002 | policy(no_unsafe) forbids unsafe blocks |
| ISR-001 | #[isr] function must be fn() -> void |
| ISR-002 | #[isr] cannot be combined with #[deadline] |
| ISR-003 | Target does not support #[isr] yet |
| ISR-004 | Vector name not recognized for target |
| ISR-005 | Two ISRs assigned to the same vector |
| ISR-006 | Priority out of range for target NVIC |
| ISR-007 | Malformed prio attribute (negative / string / missing value) |
| ISR-008 | #[isr] applied to a non-fn item |
| LAW-001 | Generated law check failed, declared law has unsupported arity, or canonical form lacks a shipped bounded checker |
| LAW-002 | SMT disproves law (RESERVED — Phase 3 not shipped) |
| LAW-003 | Law cited but optimizer cannot use it (RESERVED — Phase 2 not shipped) |
| LAW-004 | Float or approximate law form lacks shipped tolerance semantics |
| LAW-006 | Deprecated alias `zero = Z`; use `absorbing = Z` |
| LAW-007 | Deprecated alias bare `distributive`; use `distributive_over = g` |
| LAW-008 | Unrecognized law name |
| MATCH-001 | Non-exhaustive match |
| MATCH-002 | Unreachable match arm |
| MATCH-003 | Type mismatch between match arms |
| MATCH-004 | ? in a function not returning Result/Option |
| MATCH-005 | ? error type doesn't Into the function's error type |
| MATCH-006 | unwrap() in #[no_panic] function |
| MATCH-007 | Range pattern bounds in wrong order |
| MATCH-008 | Or-pattern arms have different bindings |
| MATCH-009 | Slice pattern overlaps |
| MATCH-010 | @-binding name collides with outer scope |
| MATCH-011 | Match arms produce values of incompatible types |
| MATCH-012 | Struct pattern field after `:` must be an identifier (literal field-equality patterns deferred) |
| MATCH-013 | Float scrutinee or float-literal pattern in `match` is not supported |
| MATCH-014 | Negative literal bounds in range patterns are not yet supported |
| MATCH-015 | Negative literal pattern in match arm not yet supported |
| MATCH-016 | Cross-enum pattern: scrutinee enum type does not match constructor's enum type |
| MOD-001 | Module file not found at expected path |
| MOD-002 | Path references non-existent module/item |
| MOD-003 | Visibility violation |
| MOD-004 | Glob `use *` from a module without an explicit prelude (warning) |
| MOD-005 | Circular module dependency |
| MOD-006 | Two `use` declarations bind the same name |
| NR001 | Source Input Failure |
| NR005 | Module Resolution Failure |
| NR010 | Lexical Syntax Failure |
| NR020 | Parser Failure |
| NR030 | Semantic Type Failure |
| NR031 | Borrow Safety Failure (legacy — superseded by RFC-0062 G-series at v1.0) |
| NR032 | Effect or Policy Failure |
| NR033 | Taint Safety Failure |
| NR034 | Send/Sync Safety Failure |
| NR035 | Explicit enum discriminants not yet supported |
| NR036 | Self-recursive struct without Box / & indirection (Rust E0072) |
| NR040 | IR Lowering Failure |
| NR050 | Backend Code Generation Failure |
| NR051 | WASM Backend Unavailable |
| NR070 | Manifest or Lockfile Failure |
| NR090 | Compiler Pipeline Invariant Failure |
| NUM-001 | Mixed-width arithmetic without cast |
| NUM-002 | Numeric literal out of range for declared type |
| NUM-003 | Cast loses precision (warning) |
| NUM-004 | f8/f16/bf16 op without hardware support |
| NUM-005 | usize/isize mixed with explicit-width type |
| NUM-006 | Signed/unsigned arithmetic without explicit cast |
| NUM-007 | Float→int cast saturates to type bounds |
| NUM-008 | Shift amount equals or exceeds operand width (UB-prone) |
| NUM-009 | @const_fn body contains an effectful operation |
| NUM-010 | Implicit narrowing of f64 literal to f32 may lose precision |
| NUM-011 | Overflow attribute conflicts with operation kind |
| NUM-012 | Cast from pointer to non-pointer-width integer |
| NUM-013 | Vec<T> requires sized element type |
| NUM-014 | sizeof_struct on unknown / generic struct |
| NUM-015 | extern fn signature uses non-ABI-stable type |
| NUM-016 | Comparison between signed and unsigned of equal width |
| NUM-017 | Bitwise op on signed type may have surprising sign-extension |
| NUM-018 | Float literal in integer context |
| NUM-019 | Negative literal assigned to unsigned type |
| NUM-020 | Mixed-width comparison without explicit cast |
| NUM-021 | Integer literal or constant expression overflows at compile time |
| NUM-022 | Integer vs float in arithmetic/comparison binop |
| NUM-023 | Float / bool `as`-cast to `str` rejected |
| NUM-024 | Cross-width call-site narrowing audit (opt-in via NUCLEOR_AUDIT_NUM024=1) |
| OWN-001 | Use of moved variable |
| OWN-002 | Cannot borrow moved value |
| OWN-003 | Cannot move value that is borrowed |
| OWN-004 | Cannot mutably borrow value already borrowed |
| OWN-005 | Cannot shared-borrow mutably-borrowed value |
| OWN-006 | Cannot assign through shared reference |
| OWN-007 | Cannot assign to borrowed location |
| OWN-008 | Cannot assign to immutable binding |
| OWN-009 | Cannot return reference to local value |
| OWN-010 | Cannot bind a reference that escapes an inner block |
| OWN-011 | Cannot mutably borrow immutable value |
| OWN-012 | Cannot destroy arena with live references |
| OWN-013 | Spawn block captures non-Send DeviceBuffer value |
| PERF-1 | Invalid --tier value (router-level) |
| PERF-2 | @hot function contains a perf-violation (alloc / I/O) |
| PERF-3 | Heap allocation inside a while/loop block (HeapInLoop) |
| PKG-001 | Manifest schema error |
| PKG-002 | Version conflict — no resolution found |
| PKG-003 | Checksum mismatch |
| PKG-004 | Network error fetching package |
| PKG-005 | Unknown package / version |
| PKG-006 | Yanked version explicitly required |
| RACE-001 | Non-Sendable value crosses a spawned boundary |
| RACE-002 | Actor method called without await |
| RACE-003 | Actor internal state escapes isolation |
| RACE-004 | Shared mutable state without Mutex or actor |
| RACE-005 | &mut value crosses a thread boundary |
| RACE-006 | Reentrant actor lock violation |
| RACE-007 | Deadline composition under actor await is invalid |
| RACE-008 | #[not_sendable] type used where Sendable is required |
| RACE-009 | Reserved Sendable/actor diagnostic |
| RACE-010 | Reserved Sendable/actor diagnostic |
| RT-001 | Allocation in #[no_alloc] function |
| RT-002 | Possibly-panicking expression in #[no_panic] function |
| RT-003 | Dynamic dispatch in #[no_dyn] function |
| RT-004 | Heuristic deadline estimate exceeds declared #[deadline] (NOT certified WCET) |
| RT-005 | FFI call in RT function without #[ffi_no_*] annotation |
| RT-006 | RT attribute on async fn |
| RT-007 | Deadline annotation without no_alloc or no_panic |
| RT-008 | Recursive call in #[deadline] function without #[max_depth] |
| RT-009 | Implicit panic-capable expression in #[no_panic] function |
| TGT-001 | Unknown target triple |
| TGT-002 | Sysroot not installed for target |
| TGT-003 | Feature unsupported on target |
| TGT-004 | Cross-link error |
| TNT-001 | Tainted data passed to sensitive sink |
| TRAIT-001 | Missing From conversion for `?` error propagation |
| TST-001 | Test discovery: no #[test] functions found |
| TST-002 | Test isolation: process child crashed before reporting |
| TST-003 | Test fixture: setup fn returned non-zero |
| TYP-001 | Non-exhaustive match (LEGACY — unified under MATCH-001 in v0.5.18; no longer emitted) |
| TYP-002 | Boolean values cannot be used in arithmetic |
| TYP-003 | Unit operands for addition/subtraction must match |
| TYP-004 | Cannot dereference a non-reference value |
| TYP-005 | Wrong number of arguments |
| TYP-006 | Argument type mismatch in call |
| TYP-007 | Bare numeric literal cannot initialize a unit value |
| TYP-008 | Type mismatch for binding |
| TYP-009 | Assignment type mismatch |
| TYP-010 | Return type mismatch |
| TYP-011 | `str + str` not supported (would silently segfault) |
| TYP-012 | Missing field(s) in struct initialization (would silently default to 0/empty) |
| TYP-013 | Unknown field in struct initialization (would silently drop the extra field) |
| TYP-026 | Invalid or unproven `as char`, or non-void function reaches the end without returning a value |
| TYP-027 | Type inference failed |
| TYP-044 | Implicit integer width conversion in binding |
| UNIT-001 | Add/sub mismatched dimensions |
| UNIT-002 | Implicit unit conversion attempted |
| UNIT-003 | Power expression is non-integer at compile time |
| UNIT-004 | Unknown unit alias |
| UNIT-005 | Dimensional inconsistency in @law annotation |
| URDF-001 | No path from A to B in any imported URDF |
| URDF-002 | A and B in different URDFs without #[urdf_attach] |
| URDF-003 | Cycle in URDF tree |
| URDF-004 | URDF file not found |
| URDF-005 | URDF parse error |
| URDF-006 | Joint limit violated |
| WCET-001 | #[deadline] function uses dynamic dispatch |
| WCET-002 | Loop bound unknown |
| WCET-003 | WCET exceeds declared deadline |
| WCET-004 | Indirect-call bound unknown |
| WCET-005 | Recursive call exceeds #[max_depth] |
| WCET-006 | Heptane analysis failed (internal tool error) |


## Explain Command

Use:

```bash
nuc explain OWN-001
```

The explain surface should include the code, severity, triggering condition,
and a short repair path. Unknown codes should fail clearly instead of silently
falling back to a generic message.
