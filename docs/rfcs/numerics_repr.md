# RFC: Numerics — Memory Layout + sizeof Builtins

## Summary

Compile-time byte-size queries for primitives and user structs.
`sizeof_<T>()` for primitives (i8 → 1, i32 → 4, f64 → 8,
usize → 8, etc.). `sizeof_struct(<Name>)` for user-defined
structs (default Nucleor representation = field count × 8 bytes
because backing storage is `Vec<i32>` with one i64 slot per
field).

## sizeof_<T>() primitives

```nucleor
let s: i64 = sizeof_u8();    // 1
let s: i64 = sizeof_i16();   // 2
let s: i64 = sizeof_u16();   // 2
let s: i64 = sizeof_f16();   // 2
let s: i64 = sizeof_bf16();  // 2
let s: i64 = sizeof_i32();   // 4
let s: i64 = sizeof_u32();   // 4
let s: i64 = sizeof_f32();   // 4
let s: i64 = sizeof_char();  // 4
let s: i64 = sizeof_i64();   // 8
let s: i64 = sizeof_u64();   // 8
let s: i64 = sizeof_f64();   // 8
let s: i64 = sizeof_usize(); // 8 (64-bit targets)
let s: i64 = sizeof_isize(); // 8 (64-bit targets)
let s: i64 = sizeof_ptr();   // 8 (64-bit targets)
let s: i64 = sizeof_bool();  // 1
let s: i64 = sizeof_i128();  // 16
let s: i64 = sizeof_u128();  // 16
```

Implemented as zero-arg runtime helpers (`__nucleor_sizeof_<T>`)
that return the C `sizeof()` of the corresponding type. The
compiler maps `sizeof_<T>` → `__nucleor_sizeof_<T>` via
`get_rt_name`.

## sizeof_struct(<Name>) for user types

```nucleor
struct Point { x: i32, y: i32 }
struct Three { a: i32, b: i32, c: i32 }
struct Single { x: i64 }

fn main() -> i32 {
    let s1: i64 = sizeof_struct(Point);   // 16
    let s2: i64 = sizeof_struct(Three);   // 24
    let s3: i64 = sizeof_struct(Single);  // 8
    return 0;
}
```

Implementation: `lower_expr` `kind == 7` (call) intercepts
function name `sizeof_struct`. The single argument must be a
kind-3 (identifier) referring to a known struct. The compiler
looks up the struct in the `structs` table, runs
`struct_byte_size(struct_nid, repr)`, and emits an
`ir_const_int` of the computed size.

## Default Nucleor struct representation

Field count × 8 bytes. Backing storage is `Vec<i32>` (a Nucleor
runtime type that stores i64 values in i64-wide slots). Every
struct field — regardless of its declared type — occupies one
i64 slot in this representation.

This means `struct Foo { x: i8, y: u8 }` has `sizeof_struct(Foo)
== 16` (2 fields × 8), not `2` (the natural C-aligned size).
The trade-off: simpler runtime, no per-struct layout pass needed
for the default case; users who need byte-tight layout opt into
`#[repr(C)]` or `#[repr(packed)]`.

## #[repr(C)] / #[repr(packed)]

Currently parsed and accepted by the lexer (via the generic
attribute parsing at compiler:126), but not yet propagated
through the AST to the `struct_byte_size` helper. The helper
itself ALREADY supports the natural-aligned (`"C"`) and packed
(`"packed"`) repr modes — the only remaining work is teaching
the parser to attach the attribute to the struct AST node.

Example:
```nucleor
#[repr(C)]
struct PointC { x: i32, y: i32 }   // sizeof_struct(PointC) == 8

#[repr(packed)]
struct Header { tag: u8, val: i32 } // sizeof_struct(Header) == 5
```

## Helpers (in compiler/nucleor_s1_compiler.nr)

```nucleor
fn type_byte_size(t: str) -> i64        // primitive size
fn type_align(t: str) -> i64            // = type_byte_size for primitives
fn align_up(offset: i64, align: i64) -> i64
fn struct_byte_size(struct_nid, repr: str) -> i64
```

These are compile-time only; `sizeof_struct` invocations
constant-fold at lowering time and emit a single `add i64
<size>, 0` instruction in the IR.

## Future: alloca-at-width

Currently every local variable allocates an i64 stack slot
regardless of declared type. Switching alloca to honor declared
width (e.g. `let x: u8` → `alloca i8`) requires touching every
load/store in every Nucleor program — gigantic blast radius.

This is intentionally separate from the public `sizeof_struct` surface.
It should land only when per-element-width allocation is load-bearing.
