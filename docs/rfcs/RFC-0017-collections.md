# RFC-0017 — Standard Collections: String, HashMap, BTreeMap, HashSet, BTreeSet, VecDeque

| Field | Value |
|---|---|
| **Number** | 0017 |
| **Title** | Standard Collections — `String`, `HashMap<K, V>`, `BTreeMap<K, V>`, `HashSet<T>`, `BTreeSet<T>`, `VecDeque<T>` |
| **Status** | Implemented v0.1.27–v0.1.47 — see `docs/milestones/v0.2.0.md`; v0.2 DoD met |
| **Author** | Joseph Wescott + Claude |
| **Created** | 2026-04-22 |
| **Target release** | v0.2.0 |
| **Depends on** | RFC-0015 (numerics), RFC-0002 (allocators) |

---

## 1. Summary

Ship the standard collections every modern language has on day one.

```nucleor
let mut m: HashMap<String, i32> = HashMap::new();
m.insert("alice".to_string(), 30);
m.insert("bob".to_string(),   42);
for (name, age) in &m { println!("{} = {}", name, age); }

let s: String = "hello".to_string() + ", world";
let bytes: &[u8] = s.as_bytes();
let chars: Chars = s.chars();

let q: VecDeque<i32> = VecDeque::with_capacity(64);
q.push_back(1); q.push_back(2); q.pop_front();
```

Today only `Vec<i32>` exists with `i32`-element-only restriction.
Every real program needs the rest.

---

## 2. Motivation

`HashMap` and `String` are the two collections every CLI / web /
data-processing tool hits on day one. Without them Nucleor cannot be
used for those tasks. `BTreeMap` for ordered iteration (replay
debugging, deterministic output). `VecDeque` for queue patterns.

Prior art: every modern language. Rust's std::collections is the
target — same API surface, same performance contracts.

---

## 3. Design

### 3.1 String

UTF-8-encoded growable string.

```nucleor
struct String<A: Allocator = Global> {
    buf: Vec<u8, A>,
}

impl String {
    pub fn new() -> Self;
    pub fn with_capacity(n: usize) -> Self;
    pub fn from_str(s: &str) -> Self;
    pub fn push(&mut self, c: char);
    pub fn push_str(&mut self, s: &str);
    pub fn pop(&mut self) -> Option<char>;
    pub fn len(&self) -> usize;
    pub fn is_empty(&self) -> bool;
    pub fn capacity(&self) -> usize;
    pub fn clear(&mut self);
    pub fn as_bytes(&self) -> &[u8];
    pub fn as_str(&self) -> &str;
    pub fn chars(&self) -> Chars;
    pub fn split(&self, sep: &str) -> Split;
    pub fn replace(&self, from: &str, to: &str) -> String;
    pub fn to_lowercase(&self) -> String;
    pub fn to_uppercase(&self) -> String;
    pub fn trim(&self) -> &str;
    pub fn starts_with(&self, prefix: &str) -> bool;
    pub fn ends_with(&self, suffix: &str) -> bool;
    pub fn contains(&self, needle: &str) -> bool;
    pub fn find(&self, needle: &str) -> Option<usize>;
}
```

`&str` is the borrowed slice form. UTF-8 invariant maintained at all
boundaries; invalid UTF-8 input returns `Err(Utf8Error)`.

### 3.2 HashMap

```nucleor
struct HashMap<K: Hash + Eq, V, A: Allocator = Global> { ... }

impl<K, V> HashMap<K, V> {
    pub fn new() -> Self;
    pub fn with_capacity(n: usize) -> Self;
    pub fn insert(&mut self, k: K, v: V) -> Option<V>;     // returns old value
    pub fn get(&self, k: &K) -> Option<&V>;
    pub fn get_mut(&mut self, k: &K) -> Option<&mut V>;
    pub fn remove(&mut self, k: &K) -> Option<V>;
    pub fn contains_key(&self, k: &K) -> bool;
    pub fn len(&self) -> usize;
    pub fn iter(&self) -> Iter;
    pub fn iter_mut(&mut self) -> IterMut;
    pub fn keys(&self) -> Keys;
    pub fn values(&self) -> Values;
    pub fn entry(&mut self, k: K) -> Entry;     // entry API
    pub fn drain(&mut self) -> Drain;
}
```

Implementation: **hashbrown-style** Robin Hood / SwissTable open
addressing. SipHash-1-3 default hasher (DOS-resistant). User can
override hasher via `HashMap::with_hasher`.

**Determinism:** default hasher uses a per-process random seed
(security default). For deterministic builds: pass `FxHash` or
`AHash` with fixed seed. `--profile=deterministic` (Decisions §B10)
auto-overrides to fixed-seed.

### 3.3 BTreeMap

```nucleor
struct BTreeMap<K: Ord, V, A: Allocator = Global> { ... }
```

Same API as HashMap. Backed by B-tree. Ordered iteration. O(log n)
operations. Use when:
- Iteration order matters
- Determinism required
- Range queries needed (`range(low..high)`)

### 3.4 HashSet / BTreeSet

```nucleor
struct HashSet<T: Hash + Eq, A: Allocator = Global> { inner: HashMap<T, ()> }
struct BTreeSet<T: Ord, A: Allocator = Global> { inner: BTreeMap<T, ()> }
```

Standard set ops: `insert`, `remove`, `contains`, `union`,
`intersection`, `difference`, `symmetric_difference`.

### 3.5 VecDeque

```nucleor
struct VecDeque<T, A: Allocator = Global> { ... }
```

Ring-buffer based deque. O(1) `push_front`, `push_back`, `pop_front`,
`pop_back`. Indexed access O(1). Good for FIFO message queues.

### 3.6 Iteration

All collections implement `IntoIterator` for `&self`, `&mut self`,
`self`. `for k in &map`, `for (k, v) in &map`, `for x in vec`. The
iterator trait spec lives in RFC-0024.

### 3.7 Composition with allocator types (RFC-0002)

Every collection takes an `A: Allocator = Global`. RT users:

```nucleor
let arena = Arena::with_capacity(1 << 16);
let mut m: HashMap<i32, i32, &Arena> = HashMap::new_in(&arena);
m.insert(1, 100);   // allocates from arena, not global heap
```

### 3.8 Composition with `#[no_alloc]`

Pre-sized collections (`with_capacity_in`) + capacity-checked ops
(`try_insert`) work in `#[no_alloc]` functions. Growing ops do not.

### 3.9 Composition with `#[no_panic]`

Collections panic on:
- Out-of-bounds index → use `get`/`get_mut` returning `Option`
- Integer overflow in capacity calc → use `try_with_capacity`
- Allocator failure → handled per allocator's `MAY_PANIC` constant

`#[no_panic]` users use the panic-free API only.

### 3.10 Diagnostics

| Code | Meaning |
|---|---|
| COLL-001 | `K: Hash + Eq` requirement violated |
| COLL-002 | `K: Ord` requirement violated for BTree |
| COLL-003 | Collection method that may grow used in `#[no_alloc]` |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| `runtime/string_rt.c` | UTF-8 string buffer | ~400 |
| `runtime/hashmap_rt.c` | SwissTable hash map | ~700 |
| `runtime/btreemap_rt.c` | B-tree map | ~600 |
| `runtime/vecdeque_rt.c` | Ring-buffer deque | ~250 |
| `stdlib/rods/string.nr` | Wrapper rod | ~400 |
| `stdlib/rods/hashmap.nr` | Wrapper rod | ~300 |
| `stdlib/rods/btreemap.nr` | Wrapper rod | ~300 |
| `stdlib/rods/hashset.nr` | Wrapper over HashMap | ~150 |
| `stdlib/rods/btreeset.nr` | Wrapper over BTreeMap | ~150 |
| `stdlib/rods/vecdeque.nr` | Wrapper rod | ~200 |
| Diagnostics | COLL-001…003 | ~150 |
| **Total** | | **~3600** |

---

## 5. Alternatives considered

- **Skip BTreeMap, ship HashMap only** — loses determinism story.
- **Use C++ std::unordered_map via FFI** — slow, fragmentation-prone.
- **Persistent (immutable) collections by default** — too opinionated;
  community rod for `Im<T>`.

## 6. Open questions

1. Default hasher — SipHash-1-3 (Rust default) vs AHash (faster, no
   DOS resistance). Recommend SipHash-1-3 default; AHash opt-in.
2. SmallVec/SmallString optimization (inline storage for short)?
   Defer to v0.4.
3. String growth strategy — golden ratio vs doubling. Doubling
   default; configurable.
4. UTF-8 vs UTF-16 for String — UTF-8 only.

## 7. Definition of done

- [ ] All six collections ship and pass standard tests
- [ ] Allocator-parameterized via RFC-0002
- [ ] Iterator integration via RFC-0024 (or stub for v0.2)
- [ ] Verify gate green
- [ ] CHANGELOG documents

## 8. Future extensions

- IndexMap (insertion-ordered HashMap) — community rod first
- Persistent / immutable collections — community rod
- Concurrent collections (DashMap-style) — RFC-0033 with atomic
- TinyMap / SmallMap (inline storage) — v0.4

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] Compatible with v0.2 schedule
- [ ] LOC budget ~3600 fits
- [ ] Pitch survives ("the collections every program needs on day one")
