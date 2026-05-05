// v0.8.245 stdlib/rods/urdf.nr first test coverage.
//
// Minimal URDF parser + FK chain integration. Pre-v0.8.245:
// zero coverage on the standalone rod. urdf_parse takes a raw
// NUL-terminated src_ptr (no Nucleor `str_to_ptr` exists in the
// OSS surface yet); deferred to dedicated robotics ships once
// the str→ptr bridge lands.
//
// Locks four lifecycle invariants:
//
//   1. **urdf_new returns valid handle** — non-zero.
//   2. **joint_count == 0 pre-parse** — empty parser state.
//   3. **Multiple distinct URDF parsers** — two constructions
//      → distinct handles.
//   4. **urdf_free does not crash** on a freshly constructed
//      handle.
//
// Expected: rc=0.

import "stdlib/rods/urdf.nr"

fn check_new_valid() -> i64 {
    let h: i64 = urdf_new();
    if h == 0 { return 1; };
    urdf_free(h);
    return 0;
}

fn check_joint_count_zero_pre_parse() -> i64 {
    let h: i64 = urdf_new();
    if urdf_joint_count(h) != 0 { urdf_free(h); return 2; };
    urdf_free(h);
    return 0;
}

fn check_distinct_handles() -> i64 {
    let a: i64 = urdf_new();
    let b: i64 = urdf_new();
    let same: i64 = if a == b { 1 } else { 0 };
    urdf_free(a);
    urdf_free(b);
    if same == 1 { return 4; };
    return 0;
}

fn check_free_non_crashing() -> i64 {
    let h: i64 = urdf_new();
    urdf_free(h);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_new_valid();
    fails = fails + check_joint_count_zero_pre_parse();
    fails = fails + check_distinct_handles();
    fails = fails + check_free_non_crashing();
    return fails;
}
