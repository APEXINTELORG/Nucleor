---
title: `for v in <struct value>` is silently accepted and iterates over field values in declaration order
severity: silent-miscompute
probe_file: probes/for/for_on_struct.nr
diagnostic_actual: none (compile clean, runtime walks fields)
diagnostic_expected: TYP-011 (or sibling) — "value of type `Point` is not iterable"
discovered_against: v0.4.162
commit: a99fc717079b8f7774c8ddf7aa03a4cc5e132eae
---

## Repro

```nr
struct Point { x: i32, y: i32 }

fn main() -> i32 {
    let p: Point = Point { x: 1, y: 2 };
    for v in p {
        print_int(v);
    };
    0
}
```

## Actual

```
$ ./bin/nucleor.exe build probes/for/for_on_struct.nr -o for_on_struct
  source: probes/for/for_on_struct.nr (147 bytes)
  ... (no warning, no error)
  compiled: target\for_on_struct.exe

$ ./target/for_on_struct.exe
1
2
```

The loop ran twice, with `v` bound first to `1` (= `p.x`) and then to `2` (= `p.y`). The compiler accepted the struct value `p` as an iterator and walked the fields in declaration order, with no diagnostic.

This is the natural sibling case of v0.4.152's TYP-011 closure for `for c in <str/String/scalar/bool>`. That ship caught the four scalar-shaped non-iterators. This finding is "what about struct values?"

## Expected

A TYP-011 (or new TYP-NNN) diagnostic at the type-check phase:

```
error[TYP-011]: value of type `Point` is not iterable.
              `for v in <expr>` requires `<expr>` to be a Vec<T> or a Range<i32>/<i64>.
```

…with a span on the `p` (the loop iterand).

Iterating fields of a heterogeneous struct ("structural iteration") is a real feature in some languages but it requires opt-in (e.g. an `IntoIter` impl, or a derive). Doing it by default — silently — is a footgun: any user who writes `for x in something` and gets a struct accidentally typed as the iterand has their loop run over field-shaped garbage.

In this probe both fields happen to be `i32` so the body type-checks. With heterogeneous fields (`struct S { x: i32, y: bool, z: f64 }`) the silent fallthrough may produce even worse miscomputes — possibly UB. (I have not probed that variant in this sweep — flagging as a follow-up.)

## Cross-ref

- v0.4.152 (TYP-011 ext, str/String/scalar/bool non-iterators) — same diagnostic family.
- The mandate's "Suggested probe lanes" lists `for x in some_struct_value` explicitly under lane #4. This finding closes that question: yes, silently accepted today.

## Suspected location

The `for ... in <expr>` lowering path, in the iterand-type discriminator. Pre-v0.4.152 the same path silently 0-iterated for non-Vec/non-Range scalars. v0.4.152 added the four scalar/bool/str cases. The struct-value case appears to have a code path that walks the field list. Either:

- a pre-existing structural-iteration helper is unintentionally reachable from regular `for`, OR
- the iterand-type check has a "kind-X (struct) → fall through to field walk" branch that should error instead.

Recommend a single TYP-011 catch-all at the iterand check that whitelists Vec / Range and rejects everything else, with the iterand's actual type printed in the message.

---
## Promoted

- Fixture: `tests/err/err_for_in_struct.nr`
- Fix shipped: v0.4.163
- Promoted: 2026-04-30 by probe agent
