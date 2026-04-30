# RFC-0024 — Iterator Trait + Adapter Chain

| Field | Value |
|---|---|
| **Number** | 0024 |
| **Title** | `Iterator` trait, `for x in iter`, `.map().filter().collect()` |
| **Status** | Implemented (partial) — `Vec<i64>` `.map/.filter/.fold/.each/.sum/.min/.max` via fn-ptrs (v0.2.9); closure-as-arg shipped in v0.4.x; RFC-0024 generic-enum substrate audited shipping in v0.4.182 (generic functions + structs + enums all type-check + lower + run end-to-end). **Still deferred to v0.5+:** user-impl `Iterator for MyType` trait, associated types (`Iterator::Item`), and trait-bound combinations (`T: Foo + Bar`). |
| **Author** | Joseph Wescott + Claude |
| **Created** | 2026-04-22 |
| **Target release** | v0.2 partial (v0.2.9 — `Vec<i64>` fn-ptr adapters) → v0.4.0 (full trait + closures) |
| **Depends on** | RFC-0016 (Option for `next()`), RFC-0017 (collections that iterate) |

---

## 1. Summary

Standard `Iterator` trait + lazy adapter chain.

```nucleor
let sum: i32 = (1..=100).map(|x| x * x).filter(|x| x % 2 == 0).sum();

let names: Vec<String> = users
    .iter()
    .filter(|u| u.age > 18)
    .map(|u| u.name.clone())
    .collect();

for line in file.lines() { process(line)? }

let zipped: Vec<(i32, String)> = (1..).zip(names.iter()).take(10).collect();
```

Unblocks the 5 quarantined `vec_iter*` tests (per the v0.1.5 audit).

---

## 2. Motivation

`for` loops over indices are noisy. Adapter chains (map/filter/etc.)
are the modern way. Required for ergonomic data processing.

Prior art: Rust Iterator (canonical), Java Stream, C# LINQ, Swift
Sequence/IteratorProtocol.

---

## 3. Design

### 3.1 The trait

```nucleor
trait Iterator {
    type Item;
    fn next(&mut self) -> Option<Self::Item>;

    // Provided methods (default implementations)
    fn map<F, U>(self, f: F) -> Map<Self, F> where F: FnMut(Self::Item) -> U;
    fn filter<F>(self, f: F) -> Filter<Self, F> where F: FnMut(&Self::Item) -> bool;
    fn fold<B, F>(self, init: B, f: F) -> B where F: FnMut(B, Self::Item) -> B;
    fn collect<B: FromIterator<Self::Item>>(self) -> B;
    fn count(self) -> usize;
    fn sum<S: Sum<Self::Item>>(self) -> S;
    fn product<P: Product<Self::Item>>(self) -> P;
    fn min(self) -> Option<Self::Item>;
    fn max(self) -> Option<Self::Item>;
    fn any<F>(self, f: F) -> bool where F: FnMut(Self::Item) -> bool;
    fn all<F>(self, f: F) -> bool where F: FnMut(Self::Item) -> bool;
    fn find<F>(self, f: F) -> Option<Self::Item> where F: FnMut(&Self::Item) -> bool;
    fn position<F>(self, f: F) -> Option<usize> where F: FnMut(Self::Item) -> bool;
    fn take(self, n: usize) -> Take<Self>;
    fn skip(self, n: usize) -> Skip<Self>;
    fn step_by(self, step: usize) -> StepBy<Self>;
    fn chain<I: Iterator<Item = Self::Item>>(self, other: I) -> Chain<Self, I>;
    fn zip<I: Iterator>(self, other: I) -> Zip<Self, I>;
    fn enumerate(self) -> Enumerate<Self>;
    fn peekable(self) -> Peekable<Self>;
    fn rev(self) -> Rev<Self> where Self: DoubleEndedIterator;
    fn flatten(self) -> Flatten<Self> where Self::Item: IntoIterator;
    fn flat_map<F, I>(self, f: F) -> FlatMap<Self, F, I>;
    fn cycle(self) -> Cycle<Self> where Self: Clone;
    fn for_each<F>(self, f: F) where F: FnMut(Self::Item);
    fn last(self) -> Option<Self::Item>;
    fn nth(&mut self, n: usize) -> Option<Self::Item>;
    fn size_hint(&self) -> (usize, Option<usize>);
    fn collect_into<B: Extend<Self::Item>>(self, b: &mut B);
    // ... ~30 more standard adapters ...
}
```

### 3.2 `IntoIterator` and `for`

```nucleor
trait IntoIterator {
    type Item;
    type IntoIter: Iterator<Item = Self::Item>;
    fn into_iter(self) -> Self::IntoIter;
}

// `for x in collection` desugars to:
let mut iter = collection.into_iter();
while let Some(x) = iter.next() { ... }
```

### 3.3 Implementations

Stdlib provides `Iterator` for ranges, slices, `Vec`, `String`,
`HashMap`, `BTreeMap`, etc. Three iterator types per collection:
`Iter` (`&T`), `IterMut` (`&mut T`), `IntoIter` (`T` by-move).

### 3.4 Specialization opportunities

For `Vec<T>::iter().sum()`, the optimizer specializes to
`vectorize_sum(vec.as_slice())` instead of generic fold. Driven by
`@hot` annotations on the adapter combinators.

### 3.5 Composition with `#[no_alloc]`

`map`, `filter`, `take`, `skip`, etc. are zero-allocation iterator
adapters. `collect` allocates (output collection). Lazy chains in
RT loops are fine; final `collect` must use a pre-sized container.

### 3.6 Diagnostics

| Code | Meaning |
|---|---|
| ITER-001 | `for` over non-`IntoIterator` |
| ITER-002 | `collect()` without target type annotation |
| ITER-003 | `next()` called after iterator drained |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| `stdlib/rods/iter.nr` | Trait + ~40 adapters | ~1500 |
| Stdlib collection impls | Iter/IterMut/IntoIter for each | ~1000 |
| `for` desugar | Parser/IR | ~150 |
| Optimizer specialization | `@hot` paths for sum/count | ~200 |
| Diagnostics | ITER-001…003 | ~100 |
| **Total** | | **~2950** |

---

## 5. Alternatives considered

- **Stay with index-based loops** — works but loses ergonomics.
- **Stream-based (Java)** — sufficient but Rust's design is cleaner
  for systems lang.

## 6. Open questions

1. `try_fold` / `try_for_each` (short-circuit on Err) — yes; standard.
2. Iterator combinators that may panic — flag in audit manifest.
3. Parallel iterators (Rayon-style) — defer to community rod.
4. Async iterators — defer; aligns with v0.8 async decision.

## 7. Definition of done

- [ ] `Iterator` trait + ~40 adapters implemented
- [ ] `IntoIterator` for stdlib collections
- [ ] `for` desugar works
- [ ] All 5 quarantined `vec_iter*.nr` tests pass; un-quarantined
- [ ] CHANGELOG documents

## 8. Future extensions

- Parallel iterators (community)
- Async iterators (v0.8 with async)
- `Stream` type for async sequences

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] LOC budget ~2950 fits
