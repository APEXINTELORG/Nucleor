# G-4 Double-Free Guard — Production-Readiness Status

**Status:** Active spec (started 2026-05-04)
**Companion to:** `docs/rfcs/RFC-0062-IMPLEMENTATION-PLAN.md`
**Mandate:** Reliable runtime double-free detection unblocks the unconditional default-flip ship.

This document tracks the production-readiness of the G-4
runtime double-free guard introduced in v0.8.68 (Vec) and
v0.8.69 (HashMap). The guard is the safety net that makes
the unconditional default-flip rollout practical.

## Mechanism

When `NUC_VEC_FREE_GUARD=1` is set:

1. The free helper checks if the struct's `cap` field equals
   the magic sentinel `0xDEADBEEF`. If so → PANIC.
2. Otherwise frees the data buffer, sets `cap = 0xDEADBEEF`,
   and **intentionally leaks the wrapping struct (~32 bytes
   for NVec, ~24 bytes for NHashMap)**.

Default OFF: identical pre-v0.8.68 semantics (full free).

## Coverage matrix

| Heap type | Free helper | Sentinel guard | Notes |
|---|---|---|---|
| `Vec<T>` | `__nucleor_vec_free` | ✓ v0.8.68 | NVec.cap = sentinel |
| `HashMap<K, V>` | `__nucleor_hashmap_free` | ✓ v0.8.69 | NHashMap.cap = sentinel |
| `String` | `__nucleor_str_free` | NOT YET | pure `free(s)` of `char *`; no wrapping struct |
| `Box<T>` | (no separate helper) | NOT YET | raw pointer in i64-ABI |
| `VecDeque<T>` | shared with Vec | shares Vec guard | |
| `BTreeMap<K, V>` | dedicated helper | NOT YET | similar struct shape; queued |
| `BTreeSet<T>` | dedicated helper | NOT YET | similar struct shape; queued |

## Why String / Box are harder

`__nucleor_str_free(const char *s)` is just `if (s) free(s)`.
There's no wrapping NString struct holding a sentinel field.
Reliable double-free detection for raw `char *` requires either:

1. **Header-prefixed allocations:** wrap every `str_concat` /
   `str_substring` / etc. allocation with a header containing
   a sentinel + magic. Adds 16 bytes per string. Risky for
   fixed-point + adopter ABI compat.

2. **Side-table allocator:** maintain a hash set of currently-
   allocated string pointers. `str_free` removes; subsequent
   call detects absence and panics. Adds ~16 bytes/string in
   side-table memory; O(1) lookups.

3. **Instrumented malloc:** wrap malloc/free with metadata
   tracking. Most invasive.

Option 2 (side-table) is the most pragmatic. Queued for
v0.8.71 or later.

## Production-readiness checklist

For the unconditional default-flip to ship safely:

- [x] **Vec double-free guard** — v0.8.68
- [x] **HashMap double-free guard** — v0.8.69
- [ ] **String double-free guard** — queued
- [ ] **Box double-free guard** — queued (or N/A if always wrapped)
- [ ] **BTreeMap / BTreeSet guards** — queued
- [x] **Smoke fixtures locking guard behavior** — v0.8.70 (this ship)
- [ ] **Per-rod handoff audit under guard** — pending
- [ ] **CI integration of guard mode** — pending

## Recommended adopter workflow

```bash
# Stage 1: validate against future default-flip with guard ON
NUC_VEC_FREE_GUARD=1 NUC_AUTO_DROP_DEFAULT=1 nucleor build my_code.nr

# Run the resulting binary — any double-free becomes a clean panic
NUC_VEC_FREE_GUARD=1 ./my_code

# Stage 2: production builds (default OFF)
nucleor build my_code.nr   # zero-overhead
./my_code
```

## Phase 2b-3 unblock criteria

The unconditional default-flip ship can land when:

1. ✓ Cache-key fix (v0.8.64)
2. ✓ Vec + HashMap reliable guards (v0.8.68/0.8.69)
3. Either:
    - String + Box + BTree guards (queued)
    - OR per-rod handoff audit clean under
      NUC_VEC_FREE_GUARD=1 + NUC_AUTO_DROP_DEFAULT=1

The latter is faster path. The former is more complete. Both
are valid paths to v1.0 launch.

## Updates log

- **2026-05-04** v0.8.68: Vec sentinel guard landed
- **2026-05-04** v0.8.69: HashMap sentinel guard landed
- **2026-05-04** v0.8.70: Smoke fixtures + this readiness doc
