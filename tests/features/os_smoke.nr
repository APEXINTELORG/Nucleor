// v0.8.224 stdlib/rods/os.nr first test coverage.
//
// Operating-system interface — getenv, getcwd, getpid, system,
// exit. Pre-v0.8.224: zero coverage on the standalone rod
// (sister to os_info.nr family / pointer-width / env mutation).
//
// Locks four invariants. os_exit and os_system not exercised
// (would side-effect the test process).
//
//   1. **getpid is positive** — no process has PID 0 on
//      Windows or Linux.
//   2. **getcwd is non-empty** — every process has a current
//      working directory.
//   3. **Missing env var returns empty** — os_getenv on a
//      definitely-not-set name returns "".
//   4. **Set env round-trip** — env_set "X"="value" → getenv
//      "X" == "value" (cross-checks os_info env mutation).
//
// Expected: rc=0.

import "stdlib/rods/os.nr"
import "stdlib/rods/os_info.nr"

fn check_pid_positive() -> i64 {
    let pid: i64 = os_getpid();
    if pid <= 0 { return 1; };
    return 0;
}

fn check_getcwd_nonempty() -> i64 {
    let cwd: str = os_getcwd();
    if str_len(cwd) == 0 { return 2; };
    return 0;
}

fn check_missing_env_empty() -> i64 {
    let v: str = os_getenv("NUCLEOR_OS_SMOKE_DEFINITELY_NOT_SET_XYZZY");
    if str_len(v) != 0 { return 4; };
    return 0;
}

fn check_set_env_round_trip() -> i64 {
    os_env_set("NUCLEOR_OS_SMOKE_RT", "value42");
    if str_eq(os_getenv("NUCLEOR_OS_SMOKE_RT"), "value42") != 1 { return 8; };
    os_env_unset("NUCLEOR_OS_SMOKE_RT");
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_pid_positive();
    fails = fails + check_getcwd_nonempty();
    fails = fails + check_missing_env_empty();
    fails = fails + check_set_env_round_trip();
    return fails;
}
