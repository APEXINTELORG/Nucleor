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

## Phase 2b-3 unblock criteria — UPDATED 2026-05-04

The unconditional default-flip ship can land when:

1. ✓ Cache-key fix (v0.8.64)
2. ✓ Vec + HashMap reliable double-free guards (v0.8.68/0.8.69)
3. **Static handoff detection** OR **dangling-pointer guard**

### Empirical finding (v0.8.70 testing)

The double-free guard catches `vec_free(v); vec_free(v);` —
two explicit frees on the same handle. **It does NOT catch
silent dangling pointers** in handoff patterns:

```nucleor
fn build_into(reg: Vec<i32>) -> i64 {
    let mut local: Vec<i32> = Vec::new();
    local.push(1);
    vec_push(reg, local);  // ← registry now owns local's bits
    return 0;
    // Under unconditional flip, auto_drop fires on `local`
    // here, freeing it. Registry still holds the i64 pointer
    // to the now-freed Vec. NO double-free occurs (only one
    // free), so the guard doesn't fire.
}
```

The result: registry contains a dangling pointer to a freed
NVec. Subsequent access (vec_get, vec_len) reads invalid
memory. Under guard ON the freed NVec has cap = sentinel
(0xDEADBEEF), so `vec_len` returns the sentinel value cast
to i64 — wrong but doesn't crash.

**The guard is necessary but not sufficient for unconditional
flip safety.** Need ADDITIONAL coverage:

### Path A — static handoff detection

Detect at compile time when a local Vec is `vec_push`ed (or
`vec_set`ed) into a parameter. Flag the fn as
HANDOFF-SUSPECT and require explicit `#[manual_drop]`.

The audit heuristic from v0.8.41 catches the most common
patterns. Extending to cover indirect cases (storing into a
struct field that has parameter-lifetime, FFI escape, etc.)
needs proper data-flow analysis.

### Path B — runtime dangling-pointer guard

When auto-drop runs at fn exit, scan the function's local
scope for any `vec_push(<param>, <local>)` calls — if any
exist, SKIP the auto-drop on `local` (since it's been
handed off).

This is conservative (might miss some leaks) but safe
(never produces dangling pointers).

### Recommended path

**Path A is the right semantic answer.** Path B is a runtime
hack that papers over the issue. The proper fix is a
dataflow analysis in lower_fn that tracks "this local was
vec_push'd into a non-local container" and conservatively
disables auto-drop for that local.

This is RFC-0062 G-3 Phase 2b territory (heap aliasing
through Vec<&T>). The work is substantial — a real per-fn
data-flow pass. Tracked as the load-bearing item to
unblock the unconditional default-flip.

## Memory safety state — honest summary

```
Static visibility (audits)               COMPLETE
#[manual_drop] suppress mechanism        COMPLETE
Per-fn safety audit (textual heuristic)  COMPLETE (catches obvious cases)
Cache-key correctness                    COMPLETE
Vec + HashMap double-free guard          COMPLETE (but only catches
                                                    double-free, not
                                                    dangling-after-handoff)
String/Box/BTree double-free guard       QUEUED
PROPER dataflow handoff analysis         BLOCKING — needs work
Unconditional default-flip               BLOCKED on handoff dataflow
Phase 3 / Phase 4                        v0.9 / v1.0
```

**The honest assessment:** memory safety has progressed from
"shape-only" to "extensive visibility + opt-in runtime safety
net + opt-in default-flip." The remaining work is the proper
dataflow handoff analysis — substantial multi-ship work, but
well-scoped.

Until that lands, adopters use:
- Default mode (zero overhead, leak risk on unfreed locals)
- Or `NUC_AUTO_DROP_DEFAULT=1` opt-in (heals leaks but may
  produce dangling-pointer bugs in handoff patterns)
- `NUC_VEC_FREE_GUARD=1` opt-in (catches explicit double-free,
  not dangling)

## Updates log

- **2026-05-04** v0.8.68: Vec sentinel guard landed
- **2026-05-04** v0.8.69: HashMap sentinel guard landed
- **2026-05-04** v0.8.70: Smoke fixtures + this readiness doc
