# RFC-0021 — Test Framework: `#[test]`, `nuc test`, assertions

| Field | Value |
|---|---|
| **Number** | 0021 |
| **Title** | Test framework — `#[test]`, `nuc test`, assertions, parallel execution |
| **Status** | Draft |
| **Author** | Joseph Wescott + Claude |
| **Created** | 2026-04-22 |
| **Target release** | v0.2.0 |
| **Depends on** | RFC-0016 (Result for assertions), RFC-0018 (modules for `mod tests`) |

---

## 1. Summary

`#[test]` attribute on functions, `nuc test` discovers and runs them
in parallel, with rich assertions and per-test isolation.

```nucleor
#[test]
fn add_works() {
    assert_eq!(2 + 2, 4);
}

#[test]
#[should_panic(expected = "divide by zero")]
fn div_zero_panics() {
    let _ = 1 / 0;
}

#[test]
#[ignore = "slow integration test"]
fn long_running() { ... }

#[bench]
fn bench_hash(b: &mut Bencher) {
    b.iter(|| { hash("test data") });
}
```

```bash
$ nuc test
running 47 tests
test add_works ............ ok
test div_zero_panics ...... ok
test long_running ......... IGNORED
test ekf_update_safe ...... FAILED
  note: assertion failed at src/control.nr:42
        expected: Ok(_)
        got:      Err(InvalidInput)

test result: 45 passed; 1 failed; 1 ignored; 0 measured; 12.4ms
```

Replaces today's `fn main() { print "OK" }` convention.

---

## 2. Motivation

Today's tests are full programs that print "OK". No assertions, no
test discovery, no parallel run, no isolation. Doesn't scale. Users
need a real framework on day one.

Prior art: Rust `cargo test` (canonical), Go `testing`, Python pytest,
JS jest. All converge on `#[test]`-attribute + auto-discover model.

---

## 3. Design

### 3.1 The `#[test]` attribute

Marks a fn as a test. Test fns must:
- Take no arguments
- Return `()` or `Result<(), E>` (Err = test fails)
- Be in a `mod tests { ... }` module by convention (not enforced)

### 3.2 Assertion macros

```nucleor
assert!(cond);
assert!(cond, "message: {}", x);
assert_eq!(left, right);
assert_eq!(left, right, "with message");
assert_ne!(left, right);
debug_assert!(cond);     // elided in release
debug_assert_eq!(...);
```

All produce a panic with span + values on failure. Pretty-print
side-by-side diff for `assert_eq!` failures.

### 3.3 Test attributes

| Attribute | Meaning |
|---|---|
| `#[test]` | Marks a test function |
| `#[ignore]` / `#[ignore = "reason"]` | Skip unless `--ignored` |
| `#[should_panic]` / `#[should_panic(expected = "msg")]` | Test passes iff function panics |
| `#[bench]` | Benchmark (not run by default) |
| `#[cfg(test)]` | Code only compiled in test builds |

### 3.4 `nuc test` CLI

```
nuc test                        # all tests, parallel
nuc test pattern                # only tests matching pattern
nuc test --release              # release-mode tests
nuc test --jobs N               # N parallel workers
nuc test --ignored              # also run ignored
nuc test --quiet                # less output
nuc test --no-capture           # show test stdout/stderr
nuc test --bench                # also run benches
nuc test -- --filter foo        # pass args to test binary
```

### 3.5 Per-test isolation

Each test runs in its own thread (or process if `--isolation=process`).
Captures stdout/stderr per test. Restores global state via test
cleanup (the `Drop` chain).

### 3.6 Setup / teardown

```nucleor
#[test_setup]
fn before_each(ctx: &mut TestContext) { ... }

#[test_teardown]
fn after_each(ctx: &mut TestContext) { ... }

#[test_setup_module]
fn before_all(ctx: &mut TestContext) { ... }
```

Optional. If absent, no setup/teardown runs.

### 3.7 Bencher API

```nucleor
struct Bencher { ... }

impl Bencher {
    pub fn iter<F: FnMut() -> R, R>(&mut self, f: F);
    pub fn iter_with_setup<S, F, R>(&mut self, setup: impl FnMut() -> S, body: F)
        where F: FnMut(S) -> R;
}
```

Statistical analysis: runs many iterations, computes median/p99,
reports cycles/op.

### 3.8 Integration tests

`tests/` directory siblings to `src/`. Each `tests/*.nr` is a
separate test crate, runs independently. Useful for end-to-end tests.

### 3.9 Property tests / fuzz

Out of scope for this RFC; covered by `proptest` and `fuzz` rods
(per Decisions §B6, v0.4).

### 3.10 Diagnostics

| Code | Meaning |
|---|---|
| TEST-001 | `#[test]` fn has wrong signature |
| TEST-002 | `#[should_panic]` test didn't panic |
| TEST-003 | `#[should_panic(expected = ...)]` mismatch |
| TEST-004 | Test setup/teardown missing context arg |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| Parser | `#[test]`, `#[bench]`, `#[ignore]`, `#[should_panic]`, `#[cfg(test)]` | ~250 |
| Compiler | Test discovery + driver synthesis | ~500 |
| Stdlib | `assert.nr`, test runner | ~600 |
| `nuc test` CLI | Subcommand | ~400 |
| Per-test isolation | Thread/process management | ~350 |
| Bencher | Statistical run + reporting | ~400 |
| Diagnostics | TEST-001…004 | ~150 |
| **Total** | | **~2650** |

---

## 5. Alternatives considered

- **Stay with main()-prints-OK** — doesn't scale.
- **External test runner** (like JS) — requires extra tooling; ship
  in core.
- **Pytest-style fixtures** — heavier than needed; ship setup/teardown
  attribute pair instead.

## 6. Open questions

1. Default isolation — thread (fast, shared global state risk) vs
   process (slow, full isolation). Recommend thread by default,
   `--isolation=process` opt-in.
2. Test ordering — random by default to surface order-dependent bugs.
3. Snapshot testing — defer to community rod.
4. Doc tests (Rust's `///` examples that compile + run) — defer to
   v0.4 with `nuc doc` (RFC-0029).

## 7. Definition of done

- [ ] All attributes parse
- [ ] `nuc test` discovers + runs in parallel
- [ ] Assertions work, including diff display
- [ ] Bencher reports statistics
- [ ] `tests/` integration tests work
- [ ] Verify gate refactored to use `nuc test` (replace PowerShell
      driver where possible)
- [ ] CHANGELOG documents

## 8. Future extensions

- Doc tests (with v0.4 doc gen)
- Snapshot testing (community)
- Coverage reports (`nuc test --coverage`)
- Distributed test execution

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] LOC budget ~2650 fits
- [ ] Verify gate migration covered
- [ ] Pitch survives ("real test framework — verify gate's PowerShell
      driver retired in v0.3")
