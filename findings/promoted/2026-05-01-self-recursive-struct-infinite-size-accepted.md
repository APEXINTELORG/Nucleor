---
title: `struct Node { val: i64, next: Node }` (recursive type without Box/&) is accepted at parse + type-check. Rust statically rejects this as "recursive type `Node` has infinite size" (E0072). Nucleor accepts the declaration; instantiation crashes at runtime with STATUS_STACK_OVERFLOW (rc=-1073741571 / 0xC00000FD).
severity: silent-miscompute / accept-then-runtime-crash (memory-safety class — stack overflow, OS termination)
probe_file: probes/types/self_recursive_struct.nr (probe-branch)
diagnostic_actual: pre-fix — parse + type-check + LLVM emit + clang link all succeed; runtime: `nuc run: child exited rc=-1073741571 from target\X.exe` (Windows STATUS_STACK_OVERFLOW). NO Nucleor-side diagnostic.
diagnostic_expected: clean compile-time ERROR mirroring Rust E0072 with workaround pointer (Box / & / Option<Box<…>>).
discovered_against: main v0.5.28 (probe rebased)
commit: probe (post-rebase) + main 05942866
status: CLOSED in v0.6.36 via NR036 parse-time halt (direct-recursion only). Transitive multi-struct recursion (struct A {b:B}, struct B {a:A}) is forward-roadmap.
---

## Closure (main agent v0.6.36)

`compiler/nucleor_s1_compiler.nr` `parse_struct_decl` field-loop
— after parsing each field's type via `parse_type`, compares the
returned type string to the struct's own `name`. If equal, emits
`error[NR036]` with workaround pointer and panics cleanly:

```nucleor
let field_type_v063: str = pr_val(tr);
if str_eq(field_type_v063, name) == 1 {
    print(str_concat("error[NR036]: recursive type `", str_concat(name, …)));
    panic(…);
};
```

Direct-recursion only — fields wrapping the recursive type in
`Box<Node>`, `&Node`, `&mut Node`, `Vec<Node>`, `Option<Box<Node>>`,
etc., all carry distinct type strings and flow through unchanged.

NR036 registered everywhere:
- `is_known_diag_code` (compiler).
- `compiler/nucleor_tools_suite.nr` (title + explanation + RFC-ref).
- `tools/verify.sh` + `tools/verify.ps1` codes-arrays.
- `docs/spec/Nucleor_Error_Codes.md` (NR series row).

## Adopter migration

```nucleor
// Pre-v0.6.36: STATUS_STACK_OVERFLOW at runtime, no diag
struct Node { val: i64, next: Node }

// v0.6.36: NR036 halts at parse-time with workaround pointer.
//
// Workarounds (all supported today):
struct Node { val: i64, next: Box<Node> }            // heap indirection
struct Node { val: i64, next: Option<Box<Node>> }    // linked-list / tree shape with terminator
struct Node { val: i64, next: Vec<Node> }            // n-ary children (tree)
struct Node { val: i64, next: &Node }                // reference
```

## Forward-roadmap (transitive recursion)

NR036 is the direct-recursion catch. The full Rust E0072 walks
transitive struct fields:

```rust
struct A { b: B }
struct B { a: A }   // also infinite size — same E0072
```

Rust's algorithm runs in the type-check pass after the AST is
fully built (each struct can reference structs declared later in
the file). Direct self-recursion catches the most common adopter
case; transitive 2+-struct recursion is deferred to a separate
ship — needs a struct-graph cycle detector running after pass-1
collection.

## Promoted

- Fixture: `tests/err/err_nr036_self_recursive_struct.nr`.
- Fix shipped: v0.6.36 (direct-recursion only).
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
