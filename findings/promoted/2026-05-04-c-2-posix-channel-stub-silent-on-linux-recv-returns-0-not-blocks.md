---
title: C-2 — POSIX channel runtime is no-op stub; recv returns 0 immediately (RFC says "blocks forever" — actual behavior is worse). Silently miscomputes on every Linux/macOS adopter.
severity: silent-miscompute
probe_file: probes/concurrency/c_2_posix_channel_stub.nr
diagnostic_actual: Win32 — round-trip preserved (100/200/300 sent and received). POSIX — channel_new returns 0; send drops messages; recv returns 0 immediately (NOT blocking).
diagnostic_expected: cross-platform parity — POSIX channel matches Win32 bounded-FIFO with blocking send/recv
discovered_against: v0.4.180 (Win32 confirmed live; POSIX confirmed via source audit, host platform = Windows so live POSIX run requires Linux CI)
commit: 53af3b53
status: NEW
---

## Repro

```nr
fn main() -> i32 {
    let ch: i64 = channel_new(4);
    print("ch handle:");
    print_int(ch);

    channel_send(ch, 100);
    channel_send(ch, 200);
    channel_send(ch, 300);

    let a: i64 = channel_recv(ch);
    let b: i64 = channel_recv(ch);
    let c: i64 = channel_recv(ch);
    print_int(a);
    print_int(b);
    print_int(c);

    if a == 100 && b == 200 && c == 300 {
        print("OK: round-trip preserved (Win32)");
    } else {
        print("BUG: messages lost (POSIX stub fired)");
    }
    return 0;
}
```

## Actual — Win32 (host)

```
$ bin/nucleor.exe build probes/concurrency/c_2_posix_channel_stub.nr
  ... (clean build)
$ ./target/c_2_posix_channel_stub.exe
ch handle:
2180507730640        <- valid heap pointer
a:
100
b:
200
c:
300
OK: round-trip preserved (Win32 path)
rc=0
```

Win32 path works correctly. The POSIX path **was not run on this probe** (host is Windows); behavior is inferred from source audit below.

## Actual — POSIX (predicted from source)

`stdlib/runtime/nucleor_llvm_rt.c:3841-3844`:

```c
long long __nucleor_channel_new(long long cap) { return 0; } // TODO: POSIX channel
void __nucleor_channel_send(long long h, long long v) { (void)h; (void)v; }
long long __nucleor_channel_recv(long long h) { (void)h; return 0; }
long long __nucleor_channel_len(long long h) { (void)h; return 0; }
```

Direct prediction:

```
ch handle:
0                    <- NULL handle, all subsequent calls become no-ops
a:
0
b:
0
c:
0
BUG: messages lost (POSIX stub fired)
rc=0
```

The program returns 0 (success) and prints garbage. Adopter sees a clean exit and corrupted data flow with **no signal whatsoever**.

## Expected vs RFC text

RFC text says "Any program using channels on Linux/macOS silently drops all messages and **blocks forever on recv**." The implementation actually **returns 0 immediately** rather than blocking. This is *worse* than the RFC claims:

- "Blocks forever" — eventually a developer notices their program is hung and investigates.
- "Returns 0 immediately" — values flow as if real data arrived. A producer/consumer pattern looks like it's running fast and producing zeros, with no error signal.

Adopter detection requires comparing output against expected, which most concurrent-program tests don't do tightly. RFC severity is right (CRITICAL) but the failure shape is *quieter* than RFC text implies.

## Severity

**silent-miscompute** on POSIX. The Win32 path works correctly, so adopters who develop on Windows and deploy on Linux see "works in dev, broken in prod" — the worst class of cross-platform regression. A team that uses channels for inter-thread fan-out / fan-in (the entire RFC use case) ships a Linux binary that silently produces zeros where messages should be.

## Suggested fix

Per RFC C-2 Phase 1, replace the four POSIX stubs with a real bounded-queue using pthread mutex + two condvars (matching the Win32 `CRITICAL_SECTION` + Event semantics). Sketch:

```c
typedef struct {
    long long *buf; int cap; int head; int tail; int count;
    pthread_mutex_t lock; pthread_cond_t not_empty; pthread_cond_t not_full;
} NChannel;

long long __nucleor_channel_new(long long cap) {
    NChannel *ch = calloc(1, sizeof(NChannel));
    ch->cap = (cap < 1) ? 16 : (int)cap;
    ch->buf = malloc(ch->cap * sizeof(long long));
    pthread_mutex_init(&ch->lock, NULL);
    pthread_cond_init(&ch->not_empty, NULL);
    pthread_cond_init(&ch->not_full, NULL);
    return (long long)ch;
}
void __nucleor_channel_send(long long h, long long v) {
    NChannel *ch = (NChannel*)(void*)h; if (!ch) return;
    pthread_mutex_lock(&ch->lock);
    while (ch->count == ch->cap) pthread_cond_wait(&ch->not_full, &ch->lock);
    ch->buf[ch->tail] = v;
    ch->tail = (ch->tail + 1) % ch->cap;
    ch->count++;
    pthread_cond_signal(&ch->not_empty);
    pthread_mutex_unlock(&ch->lock);
}
long long __nucleor_channel_recv(long long h) {
    NChannel *ch = (NChannel*)(void*)h; if (!ch) return 0;
    pthread_mutex_lock(&ch->lock);
    while (ch->count == 0) pthread_cond_wait(&ch->not_empty, &ch->lock);
    long long v = ch->buf[ch->head];
    ch->head = (ch->head + 1) % ch->cap;
    ch->count--;
    pthread_cond_signal(&ch->not_full);
    pthread_mutex_unlock(&ch->lock);
    return v;
}
long long __nucleor_channel_len(long long h) {
    NChannel *ch = (NChannel*)(void*)h; if (!ch) return 0;
    pthread_mutex_lock(&ch->lock);
    long long n = ch->count;
    pthread_mutex_unlock(&ch->lock);
    return n;
}
```

This mirrors the existing Win32 implementation 1:1 in semantics (bounded FIFO, blocking on full/empty). Build under `#else` of the existing `#ifdef _WIN32`. Add a `__nucleor_channel_free` while you're there (separate ticket-line in C-11 mutex-leak finding).

CI gate: add `tests/concurrency/c2_channel_smoke.nr` that does the round-trip in this fixture and asserts `a==100 && b==200 && c==300`. Build + run on both Windows AND Linux runners. If POSIX runner is missing today, adding it closes the entire C-pillar test gap (also catches C-1 cancel_token and C-3 ordered atomics).

## Cross-ref

- C-1 sister: cancel_token undefined symbols (separate finding)
- C-3 sister: ordered atomics no C backing (RFC notes this; not yet probed by this tick)
- C-9 sister: `scope { spawn { } }` absent — once channels work, structured-concurrency demos can be written
- RFC C-2 in concurrency gap analysis
- `stdlib/runtime/nucleor_llvm_rt.c:3653-3705` (Win32 reference impl)
- `stdlib/runtime/nucleor_llvm_rt.c:3841-3844` (POSIX stubs)

## Notes for main agent

The probe agent runs Windows; live POSIX repro requires a Linux CI runner. Recommend adding `tests/concurrency/c2_channel_smoke.nr` to the verify gate **after** the C-2 fix lands, run on a Linux build matrix entry. Until that runner exists, all POSIX-side concurrency findings stay structural (source audit only). C-1 / C-2 / C-3 share that property and should be probed and fixed together.
