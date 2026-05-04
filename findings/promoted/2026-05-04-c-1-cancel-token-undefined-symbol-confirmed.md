---
title: C-1 — cancel_token_new/cancel/is_cancelled are undefined symbols at link; cooperative cancellation cannot ship today
severity: crash
probe_file: probes/concurrency/c_1_cancel_token_linker_bomb.nr
diagnostic_actual: clang/lld-link error "undefined symbol: __nucleor_cancel_token_new" (and _cancel, _is_cancelled). nucleor.exe rc=1.
diagnostic_expected: working cancel-token primitive on both Win32 and POSIX
discovered_against: v0.4.180
commit: 53af3b53
status: NEW
---

## Repro

```nr
fn main() -> i32 {
    let tok: i64 = cancel_token_new(0);
    if cancel_token_is_cancelled(tok) == 1 {
        print("cancelled");
    } else {
        print("not cancelled");
    }
    cancel_token_cancel(tok);
    if cancel_token_is_cancelled(tok) == 1 {
        print("now cancelled");
    } else {
        print("still not cancelled");
    }
    return 0;
}
```

## Actual

```
$ bin/nucleor.exe build probes/concurrency/c_1_cancel_token_linker_bomb.nr
  source: probes/concurrency/c_1_cancel_token_linker_bomb.nr (555 bytes)
  ...
  emitted: target/c_1_cancel_token_linker_bomb.ll (40766 bytes)
lld-link: error: undefined symbol: __nucleor_cancel_token_new
>>> referenced by C:\...\c_1_cancel_token_linker_bomb-881a2c.o:(main)

lld-link: error: undefined symbol: __nucleor_cancel_token_is_cancelled
>>> referenced by C:\...\c_1_cancel_token_linker_bomb-881a2c.o:(main)
>>> referenced by C:\...\c_1_cancel_token_linker_bomb-881a2c.o:(main)

lld-link: error: undefined symbol: __nucleor_cancel_token_cancel
>>> referenced by C:\...\c_1_cancel_token_linker_bomb-881a2c.o:(main)
clang: error: linker command failed with exit code 1
  COMPILE FAILED (clang exit 1)
nucleor rc=1
```

## Expected

`cancel_token_new(0)` returns a valid handle; `cancel_token_is_cancelled` returns 0 then 1 after `cancel_token_cancel`. Cooperative-cancellation patterns (long-running RPC, cancellable parallel work) need this primitive.

## Source-side audit

The compiler emits the LLVM declarations and the runtime name registry knows them, but no `.c` file defines the symbols.

`compiler/nucleor_s1_compiler.nr:7376-7378`:

```nr
sb_append(sb, "declare i64 @__nucleor_cancel_token_new(i64)\n");
sb_append(sb, "declare void @__nucleor_cancel_token_cancel(i64)\n");
sb_append(sb, "declare i64 @__nucleor_cancel_token_is_cancelled(i64)\n");
```

`compiler/nucleor_s1_compiler.nr:5580-5582`:

```nr
if str_eq(name, "cancel_token_new") { return "__nucleor_cancel_token_new"; };
if str_eq(name, "cancel_token_cancel") { return "__nucleor_cancel_token_cancel"; };
if str_eq(name, "cancel_token_is_cancelled") { return "__nucleor_cancel_token_is_cancelled"; };
```

`stdlib/runtime/nucleor_llvm_rt.c`: `grep` finds **zero** definitions for any of the three. Tools-suite has the same declares (twin source); same gap.

## Severity

**crash** at link time, on every host. Loud failure mode (rc=1, undefined-symbol error) — adopter cannot ship a binary calling these names. RFC's classification of "Linux-launch-blocker" understates: it's a build failure on **both** Win32 and POSIX, since the LLVM IR `declare`s flow through `lld-link` / `ld` regardless of platform.

The reason this hasn't surfaced before is that no `.nr` rod or test today calls these names — the compiler's name-registry knows about them but no source path actually emits a call site, so the linker never sees the references.

## Suggested fix

Per RFC C-1 Phase 1: implement `__nucleor_cancel_token_new`, `_cancel`, `_is_cancelled` in `nucleor_llvm_rt.c`. Trivial atomic-flag implementation:

```c
// At top of file, near the channel/atomic block:
typedef struct { volatile long flag; } NCancelToken;

long long __nucleor_cancel_token_new(long long reserved) {
    (void)reserved;
    NCancelToken *t = (NCancelToken*)calloc(1, sizeof(NCancelToken));
    return (long long)t;
}
void __nucleor_cancel_token_cancel(long long handle) {
    NCancelToken *t = (NCancelToken*)(void*)handle;
    if (!t) return;
#if defined(_WIN32)
    InterlockedExchange((volatile LONG*)&t->flag, 1);
#else
    __sync_lock_test_and_set(&t->flag, 1);
#endif
}
long long __nucleor_cancel_token_is_cancelled(long long handle) {
    NCancelToken *t = (NCancelToken*)(void*)handle;
    if (!t) return 0;
#if defined(_WIN32)
    return InterlockedCompareExchange((volatile LONG*)&t->flag, 0, 0) ? 1 : 0;
#else
    return __sync_val_compare_and_swap(&t->flag, 0, 0) ? 1 : 0;
#endif
}
```

Plus a `__nucleor_cancel_token_free` for memory hygiene (RFC C-11 cross-cut).

Add a smoke fixture that exercises new → !cancelled → cancel → cancelled → free.

## Cross-ref

- C-2 sister: POSIX channel stub (separate finding)
- C-11 sister: mutex resource leak (no destroy path) — same systematic gap (extern declared without owner-side cleanup)
- RFC C-1 in concurrency gap analysis
- `compiler/nucleor_s1_compiler.nr:5580-5582, 7376-7378` (registry and IR declarations)
- `stdlib/runtime/nucleor_llvm_rt.c` (no implementation present)

## Notes for main agent

Recommend doing C-1 fix together with C-2 (POSIX channel) and C-3 (ordered atomics no C backing) as a single Phase 1 concurrency-correctness ship — they share file (`nucleor_llvm_rt.c`), share platform-conditional pattern, and three small implementations land cleanly together. Adding a CI step that builds `tests/concurrency/c1_smoke.nr` + `c2_smoke.nr` + `c3_smoke.nr` on both Linux and Windows closes the regression gap that lets these hide indefinitely.
