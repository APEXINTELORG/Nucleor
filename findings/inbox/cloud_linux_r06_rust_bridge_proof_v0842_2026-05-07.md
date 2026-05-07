# Cloud Linux R06 POSIX rust_bridge Ownership Proof — v0842 (2026-05-07)

Lane: `fix/cloud-linux-r06-rust-bridge-proof-v0842`
Dispatch: `docs/rfcs/CLOUD_LINUX_PKG_R06_DISPATCH_v0842_2026-05-07.md` — Queue 2
Audience: cloud Linux agent only. No WSL / Wine / `.exe` / Python.

## 1. Branch / base

| field        | value                                                          |
| ------------ | -------------------------------------------------------------- |
| branch       | `fix/cloud-linux-r06-rust-bridge-proof-v0842`                  |
| base         | `origin/main`                                                  |
| HEAD         | `4fa86e02 docs: dispatch v0842 parallel agent queues`          |
| merge-base   | `4fa86e027a08f5e83dbc6e931dd42e1234894a21` (= HEAD; clean off main) |
| working tree | clean — **no source files modified**                            |

`git status --short --branch` after the proof:

```
## fix/cloud-linux-r06-rust-bridge-proof-v0842...origin/main
```

Started from a fresh `git fetch origin` after Queue 1 (`fix/cloud-linux-pkg1-signed-publish-v0842`)
was pushed, exactly as the dispatch's "Start this only after Queue 1 is pushed
or explicitly blocked" gate requires.

## 2. Host

```
$ uname -a
Linux vm 6.18.5 #2 SMP PREEMPT_DYNAMIC Wed Jan 14 17:56:08 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux
```

True native Linux x86_64 (kernel 6.18.5). `/proc` present. No WSL / Wine /
copied Windows artifacts.

### Tool inventory

| tool          | path                              | version / note                                                  |
| ------------- | --------------------------------- | --------------------------------------------------------------- |
| `clang`       | `/usr/bin/clang`                  | Ubuntu clang version 18.1.3                                     |
| `cargo`       | `/root/.cargo/bin/cargo`          | cargo 1.94.1 (29ea6fb6a 2026-03-24)                             |
| `rustc`       | `/root/.cargo/bin/rustc`          | rustc 1.94.1 (e408947bf 2026-03-25)                             |
| `bash`        | `/usr/bin/bash`                   | GNU bash 5.x                                                    |
| `valgrind`    | `/usr/bin/valgrind`               | valgrind-3.22.0 (used as the leak/ownership signal — see §6)    |
| `bin/nucleor` | `/home/user/Nucleor/bin/nucleor`  | nucleor 0.8.323 (self-hosted, llvm backend); ELF 64-bit LSB pie, x86-64, GNU/Linux 3.2.0 |

`bin/nucleor` is the same native-ELF stage-1 binary built by
`tools/bootstrap_linux.sh --seed-only` during Queue 1 of dispatch v0842
(`bootstrap/nucleor_s1_seed.ll` + `stdlib/runtime/nucleor_llvm_rt.c` linked
by `/usr/bin/clang` 18.1.3, `BuildID 2addc7af…`). The bootstrap is
deterministic from the checked-in seed; rebuilding produces an equivalent
ELF. The shipped Windows binaries in `bin/` (`nucleor.exe`,
`nucleor-lsp.exe`) are **not** used.

## 3. Required survey (per dispatch)

| path                                                                                    | status                                                     |
| --------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| `tools/check_rust_bridge_ownership.ps1`                                                 | present, 23 874 B (PowerShell harness; not exercised here) |
| `tools/check_rust_bridge_ownership.sh`                                                  | present, 19 881 B — POSIX harness (this lane)              |
| `stdlib/rods/rust.nr`                                                                   | present, 2 716 B — Nucleor-side `extern fn` declarations + `rust_free_str` |
| `stdlib/rods/rust_bridge/Cargo.toml` + `src/lib.rs`                                     | present (Cargo crate compiled to `libnucleor_rust_bridge.a`) |
| `stdlib/runtime/rust_bridge*`                                                           | **DOES NOT EXIST** — see §3.1                              |
| `findings/inbox/helper2_r06_rust_bridge_ownership_harness_v0828_2026-05-06.md`          | present, 11 KB                                             |

### 3.1 Dispatch path correction (does NOT require a patch)

The dispatch's required-survey block lists `stdlib/runtime/rust_bridge*`,
but no such file exists on `origin/main` and grepping confirms the
rust_bridge implementation lives entirely outside `stdlib/runtime/`:

```
$ ls stdlib/runtime/ | grep -iE "rust|bridge"
(empty)

$ grep -rln "rust_free_str" --include="*.c" --include="*.nr" --include="*.h" --include="*.rs"
stdlib/rods/rust.nr
stdlib/rods/rust_bridge/src/lib.rs
tests/features/rust_bridge_hash_determinism_smoke.nr
tests/features/rust_bridge_string_free_smoke.nr
tests/features/rust_bridge_string_free_repeat_smoke.nr
```

The actual sources for the rust_bridge ownership boundary are:

- `stdlib/rods/rust_bridge/src/lib.rs` — the Rust crate (compiled by
  `cargo build --release` into `target/release/libnucleor_rust_bridge.a`).
  Defines all `rust_*` C-ABI functions and the `rust_free_str` reclaim
  path. Documented header comment locks the R06-D1 Phase 1 ownership
  convention in place (v0.8.270 / 2026-05-05).
- `stdlib/rods/rust.nr` — Nucleor-side `extern fn` declarations the harness
  fixtures import.

No change to either of these files was needed; this is a documentation
mismatch in the dispatch only. Smallest doc fix would be to amend the
dispatch's survey list from `stdlib/runtime/rust_bridge*` to
`stdlib/rods/rust_bridge/{Cargo.toml,src/lib.rs}` — but per dispatch
"do not edit … RFC-0063, laws, units, or quantum lanes" and the dispatch
itself is on `docs/rfcs/`, so this lane intentionally does **not** patch
the dispatch in-place; flagged here for the integration owner.

### 3.2 Main integration note

The proof branch was findings-only and based on `4fa86e02`. It was reviewed
and cherry-picked after main advanced through Helper2 Wave 6, PKG-1 proof, and
the R05 transitive restricts recovery. No source files, generated binaries,
bootstrap seed, scripts, or fixtures were changed. Integration validation for
this findings-only merge was `git diff --check` on the added report.

## 4. POSIX harness — doctor + self-test

Both gating modes pass without touching cargo or building anything:

```
$ bash tools/check_rust_bridge_ownership.sh --doctor
doctor cargo: OK - /root/.cargo/bin/cargo
doctor bridge-crate: OK - /home/user/Nucleor/stdlib/rods/rust_bridge
doctor release-artifact: OK - not present yet; normal run will attempt cargo build --release; expected /home/user/Nucleor/stdlib/rods/rust_bridge/target/release/libnucleor_rust_bridge.a
doctor compiler-binary: OK - /home/user/Nucleor/bin/nucleor
doctor focused-fixture:string-free: OK - /home/user/Nucleor/tests/features/rust_bridge_string_free_smoke.nr
doctor fixture-buildable: OK - prerequisites are sufficient to build selector string-free
doctor result: ready for POSIX rust_bridge ownership harness
exit 0

$ bash tools/check_rust_bridge_ownership.sh --self-test
self-test selector:string-free: OK
self-test selector:hash: OK
self-test selector:all: OK
self-test selector:invalid: OK
self-test json:required-keys: OK
self-test fail-closed:cargo: OK
self-test json:fail-closed:cargo: OK
self-test fail-closed:compiler: OK
self-test json:fail-closed:compiler: OK
self-test fail-closed:bridge-artifact: OK
self-test json:fail-closed:bridge-artifact: OK
self-test result: passed
exit 0
```

## 5. POSIX harness — fixture runs (100 iterations, exact dispatch contract)

### 5.1 string-free (rust_to_uppercase + rust_regex_find loop, R06-D1 Phase 1 baseline fixture)

```
$ bash tools/check_rust_bridge_ownership.sh --iterations 100 --fixture string-free
   Compiling regex v1.12.3
   Compiling nucleor_rust_bridge v0.1.0 (/home/user/Nucleor/stdlib/rods/rust_bridge)
    Finished `release` profile [optimized] target(s) in 10.44s
building focused fixture: tests/features/rust_bridge_string_free_smoke.nr
  source: tests/features/rust_bridge_string_free_smoke.nr (5764 bytes)
  mode: fast (ownership + type)
  functions: 10
  strings: 8
  optimized: 2 instructions
  DCE: 5 of 10 fns elided as unreachable
  emitted: target/_rust_bridge_ownership_check.ll (45814 bytes)
/usr/bin/ld: warning: -z stacksize=16777216 ignored
  compiled: target/_rust_bridge_ownership_check
OK rust_bridge ownership: fixture_selector=string-free iterations=100 fixture_executions=100 fixture_alloc_free_cycles=10000 bridge_artifact=/home/user/Nucleor/stdlib/rods/rust_bridge/target/release/libnucleor_rust_bridge.a executable=/home/user/Nucleor/target/_rust_bridge_ownership_check
exit 0
```

### 5.2 hash (rust_hash_* — primitive returns, control fixture)

```
$ bash tools/check_rust_bridge_ownership.sh --iterations 100 --fixture hash
... (cached release artifact reused — no recompile)
OK rust_bridge ownership: fixture_selector=hash iterations=100 fixture_executions=100 fixture_alloc_free_cycles=200 bridge_artifact=/home/user/Nucleor/stdlib/rods/rust_bridge/target/release/libnucleor_rust_bridge.a executable=/home/user/Nucleor/target/_rust_bridge_ownership_check
exit 0
```

### 5.3 string-free-repeat (Scope C — covers all 7 string-returning Rust fns)

```
$ bash tools/check_rust_bridge_ownership.sh --iterations 100 --fixture string-free-repeat
OK rust_bridge ownership: fixture_selector=string-free-repeat iterations=100 fixture_executions=100 fixture_alloc_free_cycles=70000 bridge_artifact=/home/user/Nucleor/stdlib/rods/rust_bridge/target/release/libnucleor_rust_bridge.a executable=/home/user/Nucleor/target/_rust_bridge_ownership_check
exit 0
```

The repeat fixture's body explicitly cycles each of the seven
string-returning fns with paired `rust_free_str`:

```
let s: str = rust_regex_find("[0-9]+", "abc 42 def");          rust_free_str(s);
let s: str = rust_regex_replace_all("[0-9]+", "abc 42 def", "N"); rust_free_str(s);
let s: str = rust_sort_ints("3,1,2");                            rust_free_str(s);
let s: str = rust_sort_strings("pear,apple,banana");             rust_free_str(s);
let s: str = rust_to_uppercase("hello");                         rust_free_str(s);
let s: str = rust_base64_encode("hello");                        rust_free_str(s);
let s: str = rust_base64_decode("aGVsbG8=");                     rust_free_str(s);
```

70 000 alloc/free cycles across all 7 returners completed without process
abort, segfault, or harness failure on native Linux (kernel 6.18.5).

### 5.4 `--fixture all` JSON contract (machine-readable transcript)

```
$ bash tools/check_rust_bridge_ownership.sh --iterations 100 --fixture all --json
{
  "schema_version": 1,
  "host_family": "posix",
  "mode": "run",
  "fixture_selector": "all",
  "iterations_requested": 100,
  "fixture_executions_completed": 200,
  "cargo":   {"present": true, "native": true, "path": "/root/.cargo/bin/cargo"},
  "bridge_artifact": {"present": true, "path": "/home/user/Nucleor/stdlib/rods/rust_bridge/target/release/libnucleor_rust_bridge.a"},
  "compiler": {"present": true, "path": "/home/user/Nucleor/bin/nucleor"},
  "result_status": "passed",
  "failure_reason": "",
  "simulated_missing": "none",
  "fixtures": [
    {"key": "string-free", "path": "/home/user/Nucleor/tests/features/rust_bridge_string_free_smoke.nr", "present": true, "rust_owned_free_cycles_per_execution": 100},
    {"key": "hash",        "path": "/home/user/Nucleor/tests/features/rust_bridge_hash_determinism_smoke.nr", "present": true, "rust_owned_free_cycles_per_execution": 2}
  ],
  "self_test_checks": []
}
exit 0
```

`host_family: "posix"`, `cargo.native: true` — confirms the harness sees a
real POSIX cargo, not a copied Windows interop artifact (the harness's
own `--fixture all` selector exits non-zero if it detects a Windows
cargo via PATH heuristics; here it is the apex POSIX cargo).

## 6. Leak / ownership signal — valgrind 3.22.0 (memcheck, full leak-check)

The harness only proves "no abort across N runs". To produce an actual
leak signal across the R06-D1 Phase 1 ownership convention
(`CString::into_raw` paired with `rust_free_str → CString::from_raw`),
each fixture binary was rebuilt under a stable basename and run under
valgrind memcheck with `--leak-check=full --show-leak-kinds=definite,indirect`:

```
$ bash tools/check_rust_bridge_ownership.sh --iterations 1 --fixture string-free        --out-name _rbo_string_free
$ bash tools/check_rust_bridge_ownership.sh --iterations 1 --fixture string-free-repeat --out-name _rbo_string_free_repeat
$ bash tools/check_rust_bridge_ownership.sh --iterations 1 --fixture hash               --out-name _rbo_hash

$ valgrind --error-exitcode=99 --leak-check=full \
    --show-leak-kinds=definite,indirect \
    --errors-for-leak-kinds=definite,indirect ./target/_rbo_string_free
==24481==     in use at exit: 0 bytes in 0 blocks
==24481==   total heap usage: 900 allocs, 900 frees, 113,442 bytes allocated
==24481== All heap blocks were freed -- no leaks are possible
==24481== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)
exit 0

$ valgrind ... ./target/_rbo_string_free_repeat
==24484==     in use at exit: 0 bytes in 0 blocks
==24484==   total heap usage: 73,000 allocs, 73,000 frees, 11,466,600 bytes allocated
==24484== All heap blocks were freed -- no leaks are possible
==24484== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)
exit 0

$ valgrind ... ./target/_rbo_hash
==24487==     in use at exit: 0 bytes in 0 blocks
==24487==   total heap usage: 4 allocs, 4 frees, 38 bytes allocated
==24487== All heap blocks were freed -- no leaks are possible
==24487== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)
exit 0
```

| fixture              | allocs   | frees    | bytes        | leaks | covered fns                                                                                              |
| -------------------- | -------- | -------- | ------------ | ----- | -------------------------------------------------------------------------------------------------------- |
| string-free          | 900      | 900      | 113 442      | 0     | `rust_to_uppercase`, `rust_regex_find` (× 100 alloc/free cycles per binary run)                          |
| string-free-repeat   | 73 000   | 73 000   | 11 466 600   | 0     | all 7: `rust_regex_find`, `rust_regex_replace_all`, `rust_sort_ints`, `rust_sort_strings`, `rust_to_uppercase`, `rust_base64_encode`, `rust_base64_decode` |
| hash                 | 4        | 4        | 38           | 0     | (control — `rust_hash_*` returns `i64`, no string reclaim path)                                          |

**Result: zero definite or indirect leaks across all seven Rust
string-returning bridge functions and the `rust_free_str` reclaim path.**
This is a real ownership signal, not just a "process did not crash"
signal: every Rust-side `CString::into_raw` allocation has a matching
`CString::from_raw` reclaim. Allocator accounting is balanced
byte-for-byte.

(Valgrind itself is not a build-time prerequisite for the harness; this
lane added it as a strengthening signal because `valgrind` was already
on the cloud Linux image. The harness contract proper does not require
it.)

## 7. Patches

**None.** No edits to compiler, runtime, CLI, tools-suite, bootstrap,
fixtures, scripts, or docs were necessary. Working tree at end of lane:

```
$ git status --short --branch
## fix/cloud-linux-r06-rust-bridge-proof-v0842...origin/main
$ git diff --stat
(empty)
```

The dispatch's "smallest repo patch or docs correction" deliverable
collapses to:

- The `stdlib/runtime/rust_bridge*` survey path in the dispatch is stale
  (§3.1) — the actual sources live under `stdlib/rods/rust_bridge/`.
  Out-of-scope to patch the dispatch RFC from this lane.

## 8. Remaining R06 gaps

R06 Phase 1 (ownership convention + reclaim path) is **closed on
POSIX** by this evidence. Open items intentionally **not** addressed by
this lane (dispatch did not request them):

1. **Hash determinism cross-platform check.** The `hash` fixture only
   exercises one host's hash output; cross-platform determinism between
   Windows `nucleor_rust_bridge.lib` and POSIX `libnucleor_rust_bridge.a`
   is the subject of `tests/features/rust_bridge_hash_determinism_smoke.nr`
   but a transcript pairing Windows + POSIX hash bytes is not yet on
   record in `findings/`.
2. **R06-D1 Phase 2 (`unsafe { rust_free_str(...) }` enforcement).** The
   compiler currently emits the `info[FFI-DIRECT]` warning per RFC-0062
   G-9 Phase 2a (printed every harness build) but does not yet require
   `#[allow(direct_ffi)]` or `unsafe { }`. Phase 2b/4 promotion is
   future-scope and does not change the v0842 leak signal.
3. **Concurrent ownership.** All fixtures run single-threaded. Running
   the same alloc/free loop across multiple OS threads would prove the
   `rust_free_str` reclaim path is also race-free, but the harness
   deliberately stays single-process per the v0828 contract.

None of these are blockers for the v0842 dispatch goal.

## 9. Lane scope hygiene

- No edits to Windows / compiler semantics, R05, ROBO-7, RFC-0063, laws,
  units, or quantum lanes.
- No Python helpers used.
- No WSL / Wine / copied Windows `.exe` artifacts used as POSIX evidence.
- Did not touch Queue 1 (`fix/cloud-linux-pkg1-signed-publish-v0842`)
  source or report; this branch is independent and merge-base-clean off
  current `origin/main`.

## 10. Reproducer

```bash
# Branch:
git fetch origin
git checkout -B fix/cloud-linux-r06-rust-bridge-proof-v0842 origin/main

# Native ELF nucleor (idempotent if already built by Queue 1):
bash tools/bootstrap_linux.sh --seed-only

# Harness gates:
bash tools/check_rust_bridge_ownership.sh --doctor
bash tools/check_rust_bridge_ownership.sh --self-test

# Documented runs (each builds release artifact on first call, then caches):
bash tools/check_rust_bridge_ownership.sh --iterations 100 --fixture string-free
bash tools/check_rust_bridge_ownership.sh --iterations 100 --fixture hash
bash tools/check_rust_bridge_ownership.sh --iterations 100 --fixture string-free-repeat
bash tools/check_rust_bridge_ownership.sh --iterations 100 --fixture all --json

# Optional valgrind leak signal (not in harness contract; needs valgrind on PATH):
bash tools/check_rust_bridge_ownership.sh --iterations 1 --fixture string-free        --out-name _rbo_string_free
bash tools/check_rust_bridge_ownership.sh --iterations 1 --fixture string-free-repeat --out-name _rbo_string_free_repeat
bash tools/check_rust_bridge_ownership.sh --iterations 1 --fixture hash               --out-name _rbo_hash
for fx in string_free string_free_repeat hash; do
    valgrind --error-exitcode=99 --leak-check=full \
        --show-leak-kinds=definite,indirect \
        --errors-for-leak-kinds=definite,indirect ./target/_rbo_$fx
done
```

End-to-end wall time on this host: ~30 s after Queue 1's release artifact
is on disk; ~45 s if cargo has to compile the bridge crate cold (`regex`
dominates).
