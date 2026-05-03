---
title: `HashMap<i64, V>` (any non-str key type) crashes at runtime with **STATUS_ACCESS_VIOLATION** (rc=-1073741819 / 0xC0000005) on the first `hashmap_insert`. The hashmap runtime helper dereferences the key as a str pointer; passing an i64 like `1` makes it deref address `0x1`. Confirmed crashing for i64, i32, u32, u64, f64, bool keys across HashMap/BTreeMap/HashSet/BTreeSet.
severity: CRITICAL crash-class (memory-safety — accept-then-OS-segfault)
probe_file: probes/hashmap/hashmap_i64_key_crashes.nr (probe-branch)
diagnostic_actual: pre-fix — `nuc run: child exited rc=-1073741819` Windows STATUS_ACCESS_VIOLATION
diagnostic_expected: compile-time error or proper key-type-aware hashing
discovered_against: main v0.5.31 (probe rebased)
commit: probe (post-rebase) + main f78d922
status: CLOSED in v0.6.51 — clean compile-time halt at the let-binding type-check site (TYP-026) when a `HashMap`/`HashSet`/`BTreeMap`/`BTreeSet` with non-str key type is declared.
---

## Closure (main agent v0.6.51)

`compiler/nucleor_s1_compiler.nr` let-stmt type-check (~line
17582) now detects `HashMap<KeyT, ...>`, `HashSet<KeyT>`,
`BTreeMap<KeyT, ...>`, `BTreeSet<KeyT>` declarations and halts
when `KeyT != str` (and != `_`). The diagnostic names the
workaround:

- For integer keys: `str_from_int(k)`.
- For bool: `if b { "true" } else { "false" }`.
- For f64: `f64_to_str(k)`.
- For ordered insertion semantics with non-str keys: use
  `Vec<(KeyT, ValT)>`.

The compiler's own internal HashMaps use str keys (the i64-
everywhere ABI stores str pointers cast to i64), so the
workaround mirrors the existing internal pattern.

## Why halt instead of fix

A proper fix needs key-type-aware hash/eq helper family — one
helper per key-type-class (str, i64, bool, f64). That's a
runtime ABI extension. The runtime helper signature change
would need a dedicated cycle (same bootstrap-cycle hole class
as the v0.6.48-attempt-1 negative-zero ship). Forward-roadmap.

Until then, the halt prevents the crash class entirely. Adopters
porting Rust code that uses non-str-keyed HashMaps see a clean
diagnostic at compile time pointing at the workaround, not a
Windows STATUS_ACCESS_VIOLATION at runtime.

## Adopter migration

```nucleor
// Pre-fix (CRASH):
let mut m: HashMap<i64, str> = HashMap::new();
hashmap_insert(&mut m, 1, "one");        // ← STATUS_ACCESS_VIOLATION

// v0.6.51 workaround (str-keyed):
let mut m: HashMap<str, str> = HashMap::new();
hashmap_insert(&mut m, str_from_int(1), "one");
hashmap_insert(&mut m, str_from_int(2), "two");
print(hashmap_get(&m, str_from_int(1)));    // "one"

// Or for non-string-coercible keys, use Vec<(K, V)>:
let mut entries: Vec<(i64, str)> = Vec::new();
entries.push((1, "one"));
entries.push((2, "two"));
// ... linear scan or sort + binary search
```

## Verify

- Regression-lock: `tests/err/err_typ026_hashmap_i64_key.nr`
  (auto-picked-up by tests/err walker).
- TYP-026 already registered as a known diag code; v0.6.51 adds
  one new emit site for the keyed-collection key-type check.

## Promoted

- Fix shipped: v0.6.51.
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
