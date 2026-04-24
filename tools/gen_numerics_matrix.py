#!/usr/bin/env python3
"""
gen_numerics_matrix.py — Phase 0 generator for the T1.1 maximalist
numerics test matrix at tests/lang/numerics_matrix/.

Emits ~52 test files across 9 phase subdirectories. Idempotent —
overwrites existing files cleanly. Run from repo root:

    python tools/gen_numerics_matrix.py
"""
import os
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
ROOT = REPO / "tests" / "lang" / "numerics_matrix"


def write(rel: str, body: str) -> None:
    p = ROOT / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(body, encoding="utf-8")


def t_intarith():
    """Phase 1 — width-aware integer arithmetic + comparisons."""
    # Each test does a small set of assertions for one (op, type).
    cases = [
        # (filename, type, op, lhs, rhs, expected, narrow_truth_str)
        ("add_i8.nr",   "i8",  "+", 100,  20,  120,  "100 + 20 = 120"),
        ("add_i16.nr",  "i16", "+", 30000, 1000, 31000, "30000 + 1000 = 31000"),
        ("add_i32.nr",  "i32", "+", 1000000, 234567, 1234567, "1000000 + 234567"),
        ("add_u8.nr",   "u8",  "+", 100,  50,  150,  "100 + 50 = 150"),
        ("add_u16.nr",  "u16", "+", 60000, 1000, 61000, "60000 + 1000"),
        ("add_u32.nr",  "u32", "+", 1000000, 1, 1000001, "1000000 + 1"),
        ("sub_i32.nr",  "i32", "-", 1000, 200, 800,   "1000 - 200"),
        ("sub_u8.nr",   "u8",  "-", 200,  50,  150,   "200 - 50"),
        ("mul_u8.nr",   "u8",  "*", 10,   20,  200,   "10 * 20 = 200"),
        ("mul_i32.nr",  "i32", "*", 1000, 1000, 1000000, "1000 * 1000"),
        ("div_u32.nr",  "u32", "/", 1000, 7,   142,   "1000 / 7 = 142"),
        ("div_i32.nr",  "i32", "/", 100,  3,   33,    "100 / 3 = 33"),
        ("rem_u32.nr",  "u32", "%", 1000, 7,   6,     "1000 % 7 = 6"),
        ("rem_i32.nr",  "i32", "%", 100,  3,   1,     "100 % 3 = 1"),
    ]
    for fn, ty, op, a, b, exp, msg in cases:
        body = f'''// p1_intarith/{fn} — Phase 1: native {ty} {op}
// Expected to FAIL until v0.2.308 lands width-aware emit_arith.

fn main() -> i32 {{
    let a: {ty} = {a};
    let b: {ty} = {b};
    let c: {ty} = a {op} b;
    if c != {exp} {{
        print("FAIL: {msg}\\n");
        return 1;
    }};
    print("OK {fn[:-3]}\\n");
    return 0;
}}
'''
        write(f"p1_intarith/{fn}", body)

    # Width-boundary tests — these exercise the actual narrow-width
    # semantics. Currently FAIL because storage is i64. Phase 1's
    # job is to make these pass.
    boundary_cases = [
        ("add_u8_wrap.nr",   "u8",  "+", 250, 10,  4,    "250 + 10 wraps to 4 (mod 256)"),
        ("add_u16_wrap.nr",  "u16", "+", 65000, 1000, 464, "65000 + 1000 wraps mod 65536"),
        ("mul_i8_wrap.nr",   "i8",  "*", 50, 3, 0 - 106, "50 * 3 = 150 wraps to -106 in i8"),
        ("mul_u8_wrap.nr",   "u8",  "*", 100, 100, 16, "100 * 100 = 10000, mod 256 = 16"),
        # i32/u32 wrap — re-enabled in Phase 3c after stdlib audit.
        ("add_u32_wrap.nr",  "u32", "+", 4000000000, 500000000, 205032704, "4e9 + 5e8 wraps mod 2^32"),
        ("mul_i32_wrap.nr",  "i32", "*", 100000, 100000, 1410065408, "1e10 wraps to 1410065408 in i32"),
    ]
    for fn, ty, op, a, b, exp, msg in boundary_cases:
        body = f'''// p1_intarith/{fn} — Phase 1: {ty} `{op}` width-boundary
// Currently fails (i64 storage). Phase 1 fixes by emitting
// narrow-width LLVM ops that wrap at the type's bit boundary.

fn main() -> i32 {{
    let a: {ty} = {a};
    let b: {ty} = {b};
    let c: {ty} = a {op} b;
    if c != ({exp}) {{
        print("FAIL: {msg}\\n");
        return 1;
    }};
    print("OK {fn[:-3]}\\n");
    return 0;
}}
'''
        write(f"p1_intarith/{fn}", body)

    # Comparison tests (4)
    cmp_cases = [
        ("cmp_lt_i32.nr",  "i32",  -10, 5,  "<", 1),
        ("cmp_lt_u32.nr",  "u32",  100, 200, "<", 1),
        ("cmp_eq_i32.nr",  "i32",  42, 42, "==", 1),
        ("cmp_ne_u8.nr",   "u8",   100, 200, "!=", 1),
    ]
    for fn, ty, a, b, op, exp in cmp_cases:
        body = f'''// p1_intarith/{fn} — Phase 1: {ty} comparison `{op}`
fn main() -> i32 {{
    let a: {ty} = {a};
    let b: {ty} = {b};
    if (a {op} b) != {exp} {{
        print("FAIL: {a} {op} {b}\\n");
        return 1;
    }};
    print("OK {fn[:-3]}\\n");
    return 0;
}}
'''
        write(f"p1_intarith/{fn}", body)


def t_literals():
    """Phase 2 — suffix literals + overflow at compile time."""
    cases = [
        ("lit_u8_basic.nr",     "u8",   "200u8",     200),
        ("lit_u8_max.nr",       "u8",   "255u8",     255),
        ("lit_i32_basic.nr",    "i32",  "1234567i32", 1234567),
        ("lit_underscore.nr",   "i32",  "1_000_000i32", 1000000),
        ("lit_f32_suffix.nr",   "f32",  "3.14f32",   None),  # float compare
        ("lit_negative_i8.nr",  "i8",   "-100i8",    -100),
    ]
    for fn, ty, lit, expected in cases:
        if expected is None:
            body = f'''// p2_literals/{fn} — Phase 2: {ty} suffix literal
// Float case — compare against constructed reference.

fn main() -> i32 {{
    let a: {ty} = {lit};
    let ref: {ty} = 3.14;
    if a != ref {{
        print("FAIL: {lit} mismatch\\n");
        return 1;
    }};
    print("OK {fn[:-3]}\\n");
    return 0;
}}
'''
        else:
            body = f'''// p2_literals/{fn} — Phase 2: {ty} suffix literal
fn main() -> i32 {{
    let a: {ty} = {lit};
    if a != {expected} {{
        print("FAIL: {lit} != {expected}\\n");
        return 1;
    }};
    print("OK {fn[:-3]}\\n");
    return 0;
}}
'''
        write(f"p2_literals/{fn}", body)


def t_layout():
    """Phase 3 — width-correct alloca + struct layout."""
    write("p3_layout/alloca_u8.nr", '''// p3_layout/alloca_u8.nr — Phase 3: u8 alloca should be 1 byte
// We can't directly observe the alloca size, but we can pack
// adjacent u8 vars and check that overflow on one doesn't
// touch the other (proves separate 1-byte slots).

fn main() -> i32 {
    let a: u8 = 200;
    let b: u8 = 100;
    let c: u8 = a + 100;   // wraps to 44 (300 - 256)
    if c != 44 {
        print("FAIL: u8 wrap at narrow alloca\\n");
        return 1;
    };
    if b != 100 {
        print("FAIL: adjacent u8 corrupted by wrap\\n");
        return 1;
    };
    print("OK alloca_u8\\n");
    return 0;
}
''')
    write("p3_layout/struct_repr_c.nr", '''// p3_layout/struct_repr_c.nr — Phase 3: #[repr(C)] struct layout

#[repr(C)]
struct Point {
    x: i32,
    y: i32,
}

fn main() -> i32 {
    // sizeof(Point) should be 8 (two i32 fields, natural align).
    // For now we can only check field round-trip works.
    let p = Point { x: 100, y: 200 };
    if p.x != 100 || p.y != 200 {
        print("FAIL: repr(C) struct field round-trip\\n");
        return 1;
    };
    print("OK struct_repr_c\\n");
    return 0;
}
''')
    write("p3_layout/struct_packed.nr", '''// p3_layout/struct_packed.nr — Phase 3: #[repr(packed)] struct

#[repr(packed)]
struct Header {
    tag: u8,
    val: i32,
}

fn main() -> i32 {
    let h = Header { tag: 1, val: 100 };
    if h.tag != 1 || h.val != 100 {
        print("FAIL: packed struct round-trip\\n");
        return 1;
    };
    print("OK struct_packed\\n");
    return 0;
}
''')


def t_cast():
    """Phase 4 — `as` cast operator full matrix."""
    cases = [
        ("cast_i32_to_u8.nr",   "i32 = 300",    "u8",  "44",   "trunc 300 to u8"),
        ("cast_u8_to_i32.nr",   "u8 = 200",     "i32", "200",  "zero-ext u8 to i32"),
        ("cast_i32_neg_to_i8.nr", "i32 = 0 - 200", "i8", "56",  "neg i32 to i8 trunc"),
        ("cast_u32_to_u8.nr",   "u32 = 1000",    "u8",  "232", "trunc u32 1000 to u8"),
        ("cast_f32_to_i32.nr",  "f32 = 3.7",    "i32", "3",   "f32 to i32 trunc toward zero"),
        ("cast_i32_to_f32.nr",  "i32 = 100",    "f32", "100",  "i32 to f32"),
        ("cast_f64_to_f32.nr",  "f64 = 3.14",   "f32", "3.14", "f64 to f32 narrow"),
        ("cast_u8_to_i64.nr",   "u8 = 255",     "i64", "255",  "zero-ext u8 to i64"),
    ]
    for fn, src_decl, dst_ty, expected, msg in cases:
        body = f'''// p4_cast/{fn} — Phase 4: cast `{msg}`
fn main() -> i32 {{
    let a: {src_decl};
    let b: {dst_ty} = a as {dst_ty};
    let want: {dst_ty} = {expected};
    if b != want {{
        print("FAIL: {msg}\\n");
        return 1;
    }};
    print("OK {fn[:-3]}\\n");
    return 0;
}}
'''
        write(f"p4_cast/{fn}", body)


def t_float():
    """Phase 5 — native float arithmetic."""
    cases = [
        ("add_f32.nr",  "f32", "+", "1.5", "2.5", "4.0"),
        ("mul_f32.nr",  "f32", "*", "2.0", "3.5", "7.0"),
        ("add_f64.nr",  "f64", "+", "1.5", "2.5", "4.0"),
        ("div_f32.nr",  "f32", "/", "10.0", "4.0", "2.5"),
    ]
    for fn, ty, op, a, b, exp in cases:
        body = f'''// p5_float/{fn} — Phase 5: native {ty} `{op}`
fn main() -> i32 {{
    let a: {ty} = {a};
    let b: {ty} = {b};
    let c: {ty} = a {op} b;
    let want: {ty} = {exp};
    if c != want {{
        print("FAIL: {ty} {a} {op} {b}\\n");
        return 1;
    }};
    print("OK {fn[:-3]}\\n");
    return 0;
}}
'''
        write(f"p5_float/{fn}", body)


def t_bitwise():
    """Phase 6 — bitwise + shift at width."""
    cases = [
        ("and_u8.nr",   "u8",  "&",  "0xF0", "0x0F", "0"),
        ("or_u32.nr",   "u32", "|",  "0xF0", "0x0F", "255"),
        ("shl_u8.nr",   "u8",  "<<", "1",    "3",    "8"),
        ("shr_i8.nr",   "i8",  ">>", "0 - 8", "1",   "0 - 4"),  # arithmetic shift
    ]
    for fn, ty, op, a, b, exp in cases:
        body = f'''// p6_bitwise/{fn} — Phase 6: {ty} `{op}` width-correct
fn main() -> i32 {{
    let a: {ty} = {a};
    let b: {ty} = {b};
    let c: {ty} = a {op} b;
    let want: {ty} = {exp};
    if c != want {{
        print("FAIL: {ty} {a} {op} {b}\\n");
        return 1;
    }};
    print("OK {fn[:-3]}\\n");
    return 0;
}}
'''
        write(f"p6_bitwise/{fn}", body)


def t_overflow():
    """Phase 7 — wrap/trap/saturate modes + intrinsics."""
    write("p7_overflow/wrap_u8_add.nr", '''// p7_overflow/wrap_u8_add.nr — Phase 7: u8 wrap (default in release)

fn main() -> i32 {
    let a: u8 = 250;
    let b: u8 = 10;
    let c: u8 = a + b;     // wraps to 4 (260 mod 256)
    if c != 4 {
        print("FAIL: u8 wrap-mode add\\n");
        return 1;
    };
    print("OK wrap_u8_add\\n");
    return 0;
}
''')
    write("p7_overflow/wrapping_add_u8.nr", '''// p7_overflow/wrapping_add_u8.nr — Phase 7: explicit wrapping_add intrinsic

fn main() -> i32 {
    let a: u8 = 250;
    let b: u8 = 10;
    let c: u8 = wrapping_add::<u8>(a, b);
    if c != 4 {
        print("FAIL: wrapping_add::<u8>\\n");
        return 1;
    };
    print("OK wrapping_add_u8\\n");
    return 0;
}
''')
    write("p7_overflow/saturating_add_u8.nr", '''// p7_overflow/saturating_add_u8.nr — Phase 7: saturating clamp

fn main() -> i32 {
    let a: u8 = 250;
    let b: u8 = 10;
    let c: u8 = saturating_add::<u8>(a, b);
    if c != 255 {
        print("FAIL: saturating_add::<u8> should clamp to 255\\n");
        return 1;
    };
    print("OK saturating_add_u8\\n");
    return 0;
}
''')
    write("p7_overflow/checked_add_u8.nr", '''// p7_overflow/checked_add_u8.nr — Phase 7: checked returns flag

fn main() -> i32 {
    let a: u8 = 250;
    let b: u8 = 10;
    let (c, of): (u8, bool) = checked_add::<u8>(a, b);
    if !of {
        print("FAIL: checked_add::<u8> overflow flag\\n");
        return 1;
    };
    print("OK checked_add_u8\\n");
    return 0;
}
''')


def t_vec():
    """Phase 8 — Vec<T> monomorphization byte-packing."""
    write("p8_vec/vec_u8_size.nr", '''// p8_vec/vec_u8_size.nr — Phase 8: Vec<u8> = 1 byte/elem

fn main() -> i32 {
    let mut v: Vec<u8> = Vec::with_capacity(1000);
    for i in 0..1000 {
        v.push((i % 256) as u8);
    };
    if v.len() != 1000 {
        print("FAIL: Vec<u8> push count\\n");
        return 1;
    };
    if v[100] != 100u8 {
        print("FAIL: Vec<u8> indexing\\n");
        return 1;
    };
    print("OK vec_u8_size\\n");
    return 0;
}
''')
    write("p8_vec/vec_i32_roundtrip.nr", '''// p8_vec/vec_i32_roundtrip.nr — Phase 8: Vec<i32> width round-trip

fn main() -> i32 {
    let mut v: Vec<i32> = Vec::with_capacity(10);
    let max32: i32 = 2147483647;
    v.push(max32);
    v.push(0 - 1);
    v.push(0);
    if v[0] != max32 {
        print("FAIL: Vec<i32> max\\n");
        return 1;
    };
    if v[1] != (0 - 1) {
        print("FAIL: Vec<i32> -1\\n");
        return 1;
    };
    print("OK vec_i32_roundtrip\\n");
    return 0;
}
''')
    write("p8_vec/vec_f32_basic.nr", '''// p8_vec/vec_f32_basic.nr — Phase 8: Vec<f32>

fn main() -> i32 {
    let mut v: Vec<f32> = Vec::with_capacity(4);
    v.push(1.0);
    v.push(2.5);
    v.push(3.14);
    if v[1] != 2.5f32 {
        print("FAIL: Vec<f32> indexing\\n");
        return 1;
    };
    print("OK vec_f32_basic\\n");
    return 0;
}
''')


def t_format():
    """Phase 11 — width-correct formatting."""
    write("p11_format/print_u8.nr", '''// p11_format/print_u8.nr — Phase 11: print_u8 prints unsigned

fn main() -> i32 {
    let a: u8 = 200;
    print_u8(a);   // should print "200"
    print("\\n");
    print("OK print_u8\\n");
    return 0;
}
''')
    write("p11_format/print_f32.nr", '''// p11_format/print_f32.nr — Phase 11: print_f32 native

fn main() -> i32 {
    let a: f32 = 3.14;
    print_f32(a);
    print("\\n");
    print("OK print_f32\\n");
    return 0;
}
''')


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    t_intarith()
    t_literals()
    t_layout()
    t_cast()
    t_float()
    t_bitwise()
    t_overflow()
    t_vec()
    t_format()
    # Count files written.
    n = sum(1 for _ in ROOT.rglob("*.nr"))
    print(f"Wrote {n} test files into {ROOT}")


if __name__ == "__main__":
    main()
