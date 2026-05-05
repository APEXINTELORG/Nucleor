// v0.8.270 R06-D1 Phase 1 — rust_free_str reclamation path coverage.
//
// Per audit `BUILD_PLAN_R06_interop_ffi.md` §1 R06-D1 (CRITICAL):
// pre-v0.8.270 seven `rust_*` string-returning functions transferred
// heap ownership via `CString::into_raw()` with no exported
// reclaim path. Every call to `rust_regex_find`, `rust_regex_replace_all`,
// `rust_sort_ints`, `rust_sort_strings`, `rust_to_uppercase`,
// `rust_base64_encode`, `rust_base64_decode` leaked memory by design.
//
// Phase 1 (this ship): adds `rust_free_str(ptr)` calling
// `CString::from_raw(ptr)` in the bridge; documents ownership
// convention in the bridge header. Adopters now have a documented
// free path.
//
// Phase 1 acceptance criteria (this ship):
//   - every Rust string-return function has documented ownership
//     and a free path: ✅ all 7 listed in the bridge header;
//   - repeated fixture does not grow live allocation under available
//     leak signal: ⚙️ this fixture exercises 100 round-trips
//     through find→free + uppercase→free; ASAN-style leak checking
//     is Phase 2 (would require valgrind harness on Linux or
//     similar);
//   - cold compile <= 4s (preserved).
//
// Prerequisites: rust_bridge prebuilt at
// `stdlib/rods/rust_bridge/target/release/nucleor_rust_bridge.lib`.
// `cargo build --release` from `stdlib/rods/rust_bridge/` produces it.
// v0.8.270 ship verified the rebuild on Windows (cargo 1.x; finished
// in 1.12s on dev machine).
//
// Locks 4 invariants:
//   1. **Round-trip uppercase** — `rust_to_uppercase("hello")` returns
//      "HELLO" (str_eq); free does not crash.
//   2. **Round-trip regex_find** — find a pattern in text, free the
//      result; no crash.
//   3. **Free of "0" (empty match)** — `rust_regex_find` returns ""
//      when no match; free of "" pointer must not crash.
//   4. **100 repeated alloc+free cycles** — exercise the reclaim
//      path heavily; runtime must not crash. (Memory growth check
//      is Phase 2.)
//
// Expected: rc=0.

import "stdlib/rods/rust.nr"

fn check_uppercase_round_trip() -> i64 {
    let s: str = rust_to_uppercase("hello");
    if str_eq(s, "HELLO") != 1 { return 1; };
    rust_free_str(s);
    return 0;
}

fn check_regex_find_round_trip() -> i64 {
    let m: str = rust_regex_find("[0-9]+", "abc 42 def");
    if str_eq(m, "42") != 1 { return 2; };
    rust_free_str(m);
    return 0;
}

fn check_empty_match_free() -> i64 {
    let m: str = rust_regex_find("[0-9]+", "no digits");
    // Non-match returns "" — still a valid pointer that needs freeing.
    if str_eq(m, "") != 1 { return 4; };
    rust_free_str(m);
    return 0;
}

fn check_repeated_cycles() -> i64 {
    // 100 alloc+free rounds. If reclaim is broken, runtime crashes
    // or hangs; if it works, all 100 complete.
    let mut i: i64 = 0;
    while i < 100 {
        let s: str = rust_to_uppercase("a");
        rust_free_str(s);
        i = i + 1;
    };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_uppercase_round_trip();
    fails = fails + check_regex_find_round_trip();
    fails = fails + check_empty_match_free();
    fails = fails + check_repeated_cycles();
    return fails;
}
