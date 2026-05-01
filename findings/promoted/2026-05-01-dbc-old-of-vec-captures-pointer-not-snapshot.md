---
title: `old(v)` where `v: Vec<T>` (or any heap-allocated type) captures the i64 POINTER, not a deep snapshot — adopter writing canonical RFC-0006 ensure with `old()` over Vec gets wrong semantics
severity: silent-miscompute (memory-aliasing class)
probe_file: probes/_sweep/dbc_old_vec_aliases.nr (will be filed)
diagnostic_actual: silent — `old(v).len` after a vec_push returns the POST-mutation length, because `old(v)` and the call's local `v` point to the same Vec storage
diagnostic_expected: either (a) deep-snapshot semantics matching Eiffel/Ada/JML conventions, OR (b) compile-time TYP-NNN reject when `old(<heap-type-expr>)` is used, naming the i64-ABI pointer-aliasing limitation
discovered_against: main v0.4.251 (old() snapshot LIVE)
commit: probe 099767e + main 02752c1
---

## Repro

```nr
#[ensure(vec_len(result) == vec_len(old(v)) + 1)]
fn append(v: Vec<i64>, x: i64) -> Vec<i64> {
    let mut w: Vec<i64> = v;     // w aliases v's storage
    vec_push(w, x);                // mutates v's underlying buffer
    w
}

fn main() -> i32 {
    let v: Vec<i64> = vec![1, 2, 3];
    let v2: Vec<i64> = append(v, 4);
    print_int(vec_len(v2) as i32);
    0
}
```

## Actual

```
CONTRACT-002: ensure postcondition violated
nuc run: child exited rc=1
```

The `#[ensure]` postcondition fires even though the function semantically does append one element correctly. Because:

- `old(v)` snapshots `v` at fn entry — but for `Vec<i64>`, `v` IS an i64 pointer to the heap buffer. Snapshotting the i64 captures the POINTER VALUE, not a copy of the buffer.
- `let mut w: Vec<i64> = v;` aliases (Nucleor i64-ABI is move-by-pointer-copy here).
- `vec_push(w, x)` mutates the buffer that v ALSO points to.
- At ensure time: `vec_len(old(v))` reads the CURRENT length (4) because old(v) is the same pointer as result. `vec_len(result)` is also 4. So `4 == 4 + 1` is FALSE.

## Hazard tier

**Silent-miscompute, memory-aliasing class.** Adopter ports a canonical RFC-0006 / Eiffel / JML pattern:

```
ensures result.length == old(v.length) + 1
```

…and gets a runtime CONTRACT-002 panic on a function that's semantically correct. The fix the adopter is led to is to remove the `old()`, but that breaks the pattern's intent.

This is the i64-everywhere ABI's pointer/value ambiguity surfacing in DbC. Same root as the str-overloading hazard we noted in the str-concat-loop-rebind finding — `str` and `Vec<T>` are pointers under the hood, so "snapshot the value" is ambiguous.

## Suspected fix

Three options:

**A — deep-snapshot semantics**: `old(<expr>)` calls the appropriate clone helper for heap types (`vec_clone`, `string_clone`, `hashmap_clone`, etc.) at fn entry, stores the cloned i64 in a hidden alloca, and reads from that at ensure time. Cost: a Vec clone per call. Matches RFC-0006 / Eiffel intent.

**B — compile-time reject for heap types**: add TYP-NNN (or extend an existing one) to halt at parse time when `old(<expr>)` is invoked on a kind-3 ident whose declared type is heap-aliasable (Vec/HashMap/HashSet/BTreeMap/BTreeSet/VecDeque/Box/String). Adopter forced to choose: hoist a manual snapshot (`let v_initial_len: i64 = vec_len(v); ... ensure(vec_len(result) == v_initial_len + 1)`) or accept the limitation.

**C — document the limitation**: leave the runtime as-is, add a parse-time WARNING (not error) that names the aliasing concern when `old()` wraps a heap-type expression. Lowest-cost path; worst UX.

Recommended: **A** for correctness with **B** as a fallback for performance-sensitive paths. Match the str_substring strict-default vs _unchecked split pattern (Ships 39+40+41).

## Memory-blow-up note

If A is chosen: each `old(<heap-type>)` call clones at fn entry. Tight inner loops with #[ensure] over Vec args could 10× allocation pressure. Performance-conscious adopters should opt out via B's compile-time reject + manual snapshot.

## Cross-ref

- v0.4.251 — old(expr) snapshot in #[ensure] LIVE. The i64-ABI capture works correctly for primitive types (i64/i32/f64/bool) but aliases for heap types.
- str-concat-loop-rebind finding (2026-04-30) — sister hazard from the str/String pointer-vs-value ambiguity

## Probe

Filed alongside this finding.

## 2026-05-01 — confirmed broader scope (post-filing)

The same hazard reproduces with `String` (via `string_from_str` +
`string_push_str`):

```nr
#[ensure(string_len(result) > string_len(old(s)))]
fn append_str(s: String) -> String {
    let mut t: String = s;
    string_push_str(t, "x");
    t
}
```

Runs `CONTRACT-002: ensure postcondition violated` exactly like
the Vec case. Confirmed: ALL heap-aliased types under the
i64-everywhere ABI exhibit this — Vec, String, HashMap, HashSet,
BTreeMap, BTreeSet, VecDeque, Box. The fix should target all 8
families uniformly (recommendation A: generic deep-snapshot via
the per-type clone helper; recommendation B: parse-time reject
with `is_heap_container_type` from Ship 35).


## Promoted

- Fixture: `tests/err/err_contract_old_vec_aliasing.nr`
- Verify gate step: `t_rfc0006_old_vec_aliasing_reject`
- Fix shipped: v0.4.271 — option B (compile-time reject) per the recommended choice. CONTRACT-006 emits at the dbc preamble when `old(EXPR)` wraps a bare ident whose declared type is one of the eight heap-aliased families. Predicates with non-trivial `old(...)` exprs (e.g., `old(self.field)`, `old(get_vec())`) skip the reject (false negatives preferred over false positives — silent miscompute still surfaces at runtime in those edge cases).
- Promoted: 2026-05-01 by main agent (from probe-agent prep on origin/probe/exploration commit ed85843+e101dc0)
