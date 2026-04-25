# RFC-0030 — Async / Await — Decision and Phased Plan

| Field | Value |
|---|---|
| **Number** | 0030 |
| **Title** | Async / await — explicit decision, opt-in pathways, phased rollout |
| **Status** | Decision (accepted v0.2) — no first-class async in v0.x; `rod/tokio.nr` opt-in v0.5, native sugar v0.8 |
| **Author** | Joseph Wescott + Claude |
| **Created** | 2026-04-22 |
| **Target release** | v0.4 (decision doc only) → v0.5 (`rod/tokio.nr`) → v0.8 (sugar) |
| **Depends on** | RFC-0001, RFC-0007 |

---

## 1. Summary

**Decision:** Nucleor will **not** ship a first-class async runtime
in v0.x. Concurrency model is threads + channels + arenas. Async is
opt-in via three escape hatches:

1. **`rod/tokio.nr`** (v0.5) — bind tokio via FFI for users who want
   futures-based concurrency. Marked `#[unsafe_async]` because tokio
   violates Nucleor's deadline guarantees.
2. **`rod/glommio.nr`** (v0.6, optional) — thread-per-core async for
   high-throughput servers. Less popular than tokio; ship if demand.
3. **Native `async`/`await` syntax** (v0.8) — sugar over deterministic
   state-machine codegen. No runtime opinion. Compiles to a
   poll-based future the user runs in their own loop.

Robotics + RT users do NOT use async. Web/services users do.

---

## 2. Motivation

Async/await is contentious in systems languages:
- **Pro:** ergonomic for I/O-bound code, web servers, high concurrency.
- **Con:** hidden allocations, hidden scheduling, executor latency,
  function-color problem (sync/async can't easily compose).

Robotics-first languages (Nucleor's stated target) have hard
real-time tier where async is a footgun. But L4 autonomy + cloud
robotics use async heavily.

The honest answer: ship a **clear non-decision** rather than a
half-baked runtime. Don't pretend Nucleor is async-first; don't
pretend users never need it.

Prior art tradeoffs:
- **Rust** — full async/await with no first-class executor; tokio /
  async-std / smol compete. Function-color problem real.
- **Go** — goroutines + channels; no explicit async. Works for most
  cases.
- **C++** — coroutines (C++20) but ecosystem fragmented.
- **Zig** — async removed in 0.11; revisiting.

---

## 3. Design

### 3.1 First-class concurrency: threads + channels

```nucleor
use std::thread;
use std::sync::mpsc::channel;

let (tx, rx) = channel::<Reading>();

let producer = thread::spawn(move || {
    loop {
        let r = sensor.read();
        if tx.send(r).is_err() { break; }
    }
});

while let Ok(r) = rx.recv() { process(r) }
```

Plus RFC-0007's `Atomic<T>` and `SpscQueue<T, N>` for lock-free
patterns. **This is the recommended concurrency model.**

### 3.2 Opt-in: `rod/tokio.nr` (v0.5)

```nucleor
#[unsafe_async]
async fn handle_connection(stream: TcpStream) -> Result<()> {
    let mut buf = vec![0u8; 1024];
    let n = stream.read(&mut buf).await?;
    stream.write_all(&buf[..n]).await?;
    Ok(())
}

#[tokio::main]
async fn main() {
    let listener = TcpListener::bind("0.0.0.0:8080").await.unwrap();
    loop {
        let (stream, _) = listener.accept().await.unwrap();
        tokio::spawn(handle_connection(stream));
    }
}
```

Marked `#[unsafe_async]` because:
- tokio uses global allocator
- `await` points are scheduling boundaries with no deadline guarantee
- Cannot compose with `#[no_alloc]`, `#[deadline]`, `#[no_panic]`

### 3.3 Native `async` / `await` syntax (v0.8)

When v0.8 ships, the `async fn` keyword pair desugars to a state
machine implementing `Future`:

```nucleor
async fn fetch(url: &str) -> Result<String> {
    let resp = http_get(url).await?;
    let body = resp.body().await?;
    Ok(body)
}

// desugars to:
fn fetch(url: &str) -> impl Future<Output = Result<String>> {
    FetchFuture::new(url)
}

struct FetchFuture<'a> {
    state: FetchState,
    url: &'a str,
}

impl Future for FetchFuture { ... }
```

User runs the future in their own poll loop, on tokio, on glommio,
or on a custom executor. Nucleor takes no opinion on the runtime.

### 3.4 Composition with RFC-0001 attributes

`async fn` cannot have RT attributes (RFC-0001 RT-006 errors). They
fundamentally don't compose: `await` points have unbounded latency.

For deadline-checked async, users wrap a sync `#[deadline]` function
in a small async adapter — explicit, not transparent.

### 3.5 Diagnostics

| Code | Meaning |
|---|---|
| ASYNC-001 | RT attribute on async fn (RT-006 dup; deprecate one) |
| ASYNC-002 | `await` outside async fn |
| ASYNC-003 | Tokio-specific feature without `[dependencies] tokio` |

---

## 4. Implementation

| Phase | Component | LOC |
|---|---|---|
| v0.4 (this RFC) | Decision doc only | 0 |
| v0.5 | `rod/tokio.nr` (bindgen + thin wrappers) | ~800 |
| v0.6 | `rod/glommio.nr` (optional) | ~600 |
| v0.8 | Native `async`/`await` syntax + state machine codegen | ~2500 |

---

## 5. Alternatives considered

- **First-class async runtime (Rust + tokio model)** — couples
  language to one runtime; we don't want that.
- **Goroutine model (Go)** — would need GC or sophisticated stack
  management; conflicts with no-GC.
- **No async ever** — abandons L4 web/cloud users; rejected.

## 6. Open questions

1. Function-color problem mitigation — can sync code call into async
   without spawning an executor? Recommend "no" for v0.8; user must
   opt in.
2. Async closures — defer to v0.8.5+.
3. Async iterators (Stream trait) — defer.
4. Whether to standardize on tokio or stay agnostic — stay agnostic.

## 7. Definition of done

- [ ] This RFC published as the canonical async stance
- [ ] v0.5 ships `rod/tokio.nr`
- [x] v0.2.353 (T2.8) ships the **threads-only** threaded
      fallback: `async fn` + `<ident>.await` syntactic sugar
      desugaring to `async_spawn` / `async_await` runtime
      helpers on top of CreateThread/pthread_create.
      RFC-0027 phase-1 parked pending the v0.8 state-machine
      rewrite.
- [ ] v0.8 ships native syntax (separate RFC at that time;
      supersedes the threaded fallback for users who need
      zero-thread concurrency)

### v0.2.353 threaded fallback details

Ship scope:
- Lex: no new tokens; `async` is just an identifier the
  resolver treats specially.
- Resolver rewrite: `async <ws> fn` drops the `async` (the
  function is a regular fn); `<ident>.await` rewrites to
  `async_await(<ident>)`. Restricted to the
  `<ident>.await` form — complex receivers need a
  let-binding first.
- Runtime (both Windows + POSIX): `__nucleor_async_spawn(fn_ptr,
  arg) -> task_handle` allocates an `NAsyncTask` struct,
  spawns a real OS thread running the fn with the arg,
  captures the i64 return into the struct's `result` slot.
  `__nucleor_async_await(task_handle) -> i64` joins the
  thread, reads `result`, frees the struct, returns the
  value.
- Policy: thread priority is NOT set to IDLE like
  `thread_spawn` — `async_spawn` uses default priority
  because async tasks typically need to make progress
  (unlike the legacy IDLE-priority `thread_spawn` which is
  background-only).

Users who want real async semantics (no per-task thread,
cooperative scheduling, single-address-space polling) wait
for v0.8. Users who want a "it works today and I don't
care about 8 MB per task" path get the threaded fallback.

## 8. Future extensions

- async closures, async iterators, async traits — v0.8+
- Cancellation primitives — design pending

## 9. Acceptance checklist

- [ ] Maintainer approves the no-first-class-runtime stance
- [ ] Pitch survives ("async is opt-in, robotics-first means
      threads-first")
