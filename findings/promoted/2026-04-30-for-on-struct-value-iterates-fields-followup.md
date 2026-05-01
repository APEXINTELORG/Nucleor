---
title: followup — `for v in <struct value>` is type-punning, not just walking field values
severity: silent-miscompute
probe_file: probes/for/for_on_heterogeneous_struct.nr, probes/for/for_on_struct_bool_miscount.nr
diagnostic_actual: none (compile clean)
diagnostic_expected: TYP-011 — "value of type `Mixed` is not iterable"
discovered_against: v0.4.162
commit: a99fc717079b8f7774c8ddf7aa03a4cc5e132eae
status: CLOSED in v0.4.163 — same TYP-011 ship as the parent finding closes this heterogeneous-struct shape. Status backfilled v0.4.268.
---

This is a followup to `2026-04-30-for-on-struct-value-iterates-fields.md`. The
homogeneous case (struct of two `i32`s) printed plausible-looking field values.
The heterogeneous case shows the loop body is doing **raw bit reinterpretation**.

## Repro 1: heterogeneous fields (`i32`, `bool`, `f64`)

```nr
struct Mixed { a: i32, b: bool, c: f64 }

fn main() -> i32 {
    let m: Mixed = Mixed { a: 1, b: true, c: 3.14 };
    for v in m {
        print_int(v);
    };
    0
}
```

Output:

```
1
1
4614253070214989087
```

- `1` — `m.a: i32` printed as i32. Fine.
- `1` — `m.b: bool` printed as i32 (bool→int promotion). Marginal.
- `4614253070214989087` — `m.c: f64 = 3.14` printed as i32. This is the
  **IEEE-754 double bit pattern of 3.14** (`0x40091EB851EB851F` =
  4614253070214989087) interpreted as a signed integer. Type-pun.

This is full type-punning UB. The compiler is taking each field's storage
slot, reinterpreting the bits under the loop body's binding type (`i32` for
`print_int`'s parameter), and walking on. Adopters who write a `for` loop
over a struct accidentally get a memory walk with no signal whatsoever.

## Repro 2: confirm the loop iterates exactly N times where N = field count

```nr
struct Mix2 { a: i32, b: bool }

fn main() -> i32 {
    let m: Mix2 = Mix2 { a: 100, b: false };
    let mut count: i32 = 0;
    for v in m {
        count = count + 1;
        print_int(v);
    };
    print_int(count);
    0
}
```

Output: `100\n0\n2` — two iterations (matching field count), then count=2.
Confirms the iteration count = struct field count, not anything semantic.

## Why this raises severity

The original finding called this a silent-miscompute under the assumption that
the loop walked field *values*. It's worse than that: the loop is walking
field *bits*. With heterogeneous structs the user gets:

- `i64` fields read as `i32` (truncation)
- `f64` fields read as `i32` (bit-reinterpret = nonsense number)
- `bool` fields padded by alignment, possibly reading garbage from padding bytes
- `String` / `Vec` fields would expose pointer values as integers (information leak)

The last point is a security-flavored concern — I have not probed
`String`/`Vec` fields in this sweep, but the precedent here suggests they'd
leak as raw pointer integers.

## Expected

Same fix as the parent finding: TYP-011 catch-all rejecting non-Vec /
non-Range iterands at the `for` lowering. The heterogeneous case strongly
argues for a hard reject rather than any kind of structural-iteration
shorthand — the latter is impossible to type-check soundly when fields
disagree.

## Cross-ref

- Parent: `findings/inbox/2026-04-30-for-on-struct-value-iterates-fields.md`
- Sibling family: v0.4.152 (TYP-011 ext for str/String/scalar/bool non-iterators)

---
## Promoted

- Fixture: `tests/err/err_for_in_struct.nr`
- Fix shipped: v0.4.163
- Promoted: 2026-04-30 by probe agent
