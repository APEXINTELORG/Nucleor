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

## Common Active Codes

| Code | Meaning |
|---|---|
| `OWN-001` | Use after move |
| `OWN-012` | Double free or use after drop |
| `TYP-003` | Unit operands for addition/subtraction must match |
| `TYP-011` | Invalid string arithmetic |
| `TYP-012` | Missing field in struct initialization |
| `TYP-013` | Unknown field in struct initialization |
| `TYP-026` | Invalid cast or missing non-void return |
| `TYP-027` | Type inference failed; annotation required |
| `TYP-044` | Implicit integer-width conversion in binding |
| `NUM-002` | Literal out of range |
| `NUM-008` | Invalid shift amount |
| `NUM-009` | Division or remainder by literal zero |
| `NUM-021` | Compile-time integer expression overflow |
| `MATCH-001` | Non-exhaustive match |
| `MATCH-004` | `?` in a function that does not return `Result` or `Option` |
| `RT-001` | Allocation in `#[no_alloc]` function |
| `RT-002` | Possibly-panicking expression in `#[no_panic]` function |
| `RT-003` | Dynamic dispatch in `#[no_dyn]` function |
| `RT-004` | Deadline estimate exceeds declared budget |
| `RT-005` | FFI call in RT function lacks required safety markers |
| `EFF-001` | Function uses an undeclared effect |
| `LAW-001` | Generated law check failed or law form is unsupported |

## Explain Command

Use:

```bash
nuc explain OWN-001
```

The explain surface should include the code, severity, triggering condition,
and a short repair path. Unknown codes should fail clearly instead of silently
falling back to a generic message.
