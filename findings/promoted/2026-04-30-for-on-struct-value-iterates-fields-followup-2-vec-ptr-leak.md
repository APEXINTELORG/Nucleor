---
title: followup #2 — `for v in <struct with Vec field>` leaks Vec heap pointer as integer
severity: silent-miscompute
probe_file: probes/for/for_on_struct_with_vec.nr
diagnostic_actual: none
diagnostic_expected: TYP-011 — non-iterable receiver
discovered_against: v0.4.162
commit: a99fc717079b8f7774c8ddf7aa03a4cc5e132eae
---

Second followup to `2026-04-30-for-on-struct-value-iterates-fields.md` and
`...-followup.md` (heterogeneous-fields type-pun). Same root cause, but this
manifestation is information-disclosure flavored, so worth a concrete repro
on the inbox.

## Repro

```nr
struct Holder { tag: i32, items: Vec<i32> }

fn main() -> i32 {
    let mut data: Vec<i32> = Vec::new();
    data.push(11);
    data.push(22);
    let h: Holder = Holder { tag: 42, items: data };
    for v in h {
        print_int(v);
    };
    0
}
```

## Actual

```
42
2607884041088
```

Two iterations (= field count of `Holder`). First prints `tag` correctly.
Second prints `items.<slot>` reinterpreted as i32 — the value
`2607884041088` (`0x25F00C26800`) is a heap-region pointer, almost certainly
the Vec's data buffer base address.

The user got:
- A loop that iterates 2× when they may have expected `items.len()` = 2 elements.
- A heap pointer rendered as a "data value" with no indication it's a pointer.
- No diagnostic at compile time, no diagnostic at runtime, exit 0.

## Why this is the worst manifestation

Compared to the parent finding (homogeneous i32 fields print plausible field
values) and the first followup (heterogeneous fields type-pun bit patterns),
this case **leaks heap layout to user-visible output**. In a binary that
prints any user-controlled struct via a for-loop:

- ASLR can be partially defeated (the leaked pointer reveals the heap base).
- Adopters who serialize a struct via `for v in s { write(v) }` (a perfectly
  reasonable thing for them to attempt) ship pointer-bearing output.

This is "SIGSEGV close" territory — the v0.4.143 NUM-023 ship explicitly
listed runtime-SIGSEGV issues as URGENT and shipped a same-day fix.
For-on-struct's pointer leak isn't a SIGSEGV but it IS a security-flavored
silent-miscompute and the same prioritization applies.

## Fix

Same as parent: TYP-011 reject for-on-struct. Block at compile time, not in
the loop body lowering. The mere presence of a Vec/String/&T field in any
struct that reaches the `for` lowering should make the rejection unmissable.

## Cross-ref

- Parent: `2026-04-30-for-on-struct-value-iterates-fields.md`
- Followup #1 (heterogeneous fields type-pun): `...-followup.md`
- Sibling family: v0.4.152 (TYP-011 ext for str/String/scalar/bool non-iterators)

---
## Promoted

- Fixture: `tests/err/err_for_in_struct.nr`
- Fix shipped: v0.4.163
- Promoted: 2026-04-30 by probe agent
