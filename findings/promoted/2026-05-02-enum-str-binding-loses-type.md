---
title: `let x: MyEnum = MyEnum::Variant("hello");` — accessing the str payload via match-binding `MyEnum::Variant(s)` loses the str type and treats `s` as i64
severity: silent-miscompute (enum payload type erasure for str variants)
probe_file: probes/enum/enum_str_binding.nr (probe-branch)
diagnostic_actual: pre-fix — match-binding `s` is i64 (the bit pattern of the str pointer), not str
diagnostic_expected: match-binding receives str type; `print(s)` works
discovered_against: probe/exploration tip
commit: probe + main
status: DOC-ONLY — sister to the v0.6.x enum-payload-typing work. The match-arm pattern parser at line ~1387 uses a single `binding` slot and doesn't carry the variant's payload type. Forward-roadmap: extend the match-arm env-set to look up the variant's declared payload type and tenv-set the binding accordingly.
---

## Closure (analysis-only — no compiler change)

The match-arm-binding env-set at line ~15538
(`tenv_set_pattern_item`) currently defaults the binding's type
to "i64" if the pattern doesn't carry an explicit type
annotation. For str-payload enum variants, this means the
binding loses the str type — downstream `print(s)`, `str_len(s)`,
etc. either reject (TYP-006) or silently miscompute.

A v0.6.49 attempt (referenced in the project memory's enum-str-
binding revert note) tried to add per-enum payload-type lookup
but hit a segfault when the type-checker walked patterns with
internal `__range` / `__int` enames. Reverted.

The clean fix needs:

1. struct_find_type-style lookup for enum_find_type.
2. enum_field_type(pool, e_nid, variant_name) helper.
3. Wire into tenv_set_pattern_item to resolve "i64" default to
   the actual payload type when the enclosing pattern is enum-
   variant-shaped.

## Adopter migration

```nucleor
// Pre-fix (binding loses type):
enum MyEnum { S(str), I(i64) }
fn main() -> i32 {
    let v: MyEnum = MyEnum::S("hello");
    match v {
        MyEnum::S(s) => print(s),    // ← s typed as i64, print(s) TYP-006
        MyEnum::I(n) => print_int(n as i32),
    };
    return 0;
}

// Workaround (explicit cast at use site):
match v {
    MyEnum::S(s) => print_raw(s as str),    // explicit i64-to-str cast
    MyEnum::I(n) => print_int(n as i32),
};
```

The `as str` cast is a no-op at the i64-everywhere ABI level
(both the str pointer AND the i64 binding are 64-bit values
stored as i64), so the cast is purely a type-check accommodation.

## Promoted

- No code change.
- Promoted: 2026-05-03 by main agent.
