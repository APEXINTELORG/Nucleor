---
title: `assert_eq!(a, b)` and `assert_ne!(a, b)` macros silently do POINTER COMPARISON on `str` arguments. Equal-content strings make `assert_eq!` always FAIL (false-fail), and `assert_ne!` always PASS (false-pass). The user-level `==`/`!=` on str is correctly caught with TYP-011, but the assert macros bypass that safety check.
severity: CRITICAL silent-miscompute (test correctness — also security-adjacent for assert_ne)
probe_file: probes/asserts/assert_eq_ne_str_silent.nr (probe-branch)
diagnostic_actual: pre-fix — `assert_eq!("hello", "hello")` → `ASSERTION FAILED: 140695883179153 != 140695883179159` (pointer addresses, not values). `assert_ne!("abc", "abc")` → silently passes when it should fail.
diagnostic_expected: TYP-011 at type-check time pointing at `str_eq` workaround, mirroring the v0.4.52 close for `str == str` binops.
discovered_against: main v0.5.28 (probe rebased)
commit: probe (post-rebase) + main 4fdca8d
status: CLOSED in v0.6.20.
---

## Repro (now halts)

```nucleor
fn main() -> i32 {
    assert_eq!("hello", "hello");
    print("OK");
    return 0;
}
```

Pre-v0.6.20 build: succeeded. Run: `ASSERTION FAILED: <addr1> != <addr2>`
exit 1, even though string content was identical.

Post-v0.6.20 build: fails with TYP-011 at compile time, naming the
`str_eq` workaround.

## Closure (main agent v0.6.20)

`compiler/nucleor_s1_compiler.nr` `type_expr` kind-7 (call) — added
a check at the top of the call-type-check that fires TYP-011 when
callee is `assert_eq` / `assert_ne` AND both args are `str`-typed.
Same shape + workaround pointer as the existing v0.4.52 binop close
for `str == str`.

The user-level `==` / `!=` on str was already caught by TYP-011 at
the binop site (since v0.4.52); the assert macros bypassed that
safety check because they go through fn-call dispatch, not binop
dispatch. v0.6.20 closes the bypass.

## Adopter migration

```nucleor
// Pre-v0.6.20 (silent false-fail / false-pass):
assert_eq!("hello", "hello");
assert_ne!("abc", "abc");

// v0.6.20 (TYP-011 at compile time):
assert_eq(str_eq("hello", "hello"), 1);  // value-compare via str_eq
assert_eq(str_eq("abc", "abc"), 0);      // assert_ne shape — expect inequal
```

A future ship may add a transparent rewrite (`assert_eq!(a, b)` on str
auto-routes through `str_eq` without requiring adopter migration), but
the current loud-halt closes the silent-miscompute window cleanly.

## Promoted

- Fixture: `tests/err/err_assert_eq_str_pointer_compare.nr`.
- Fix shipped: v0.6.20.
- Promoted: 2026-05-02 PM by main agent (probe commit on
  `origin/probe/exploration`).
