// test_isolation_smoke — RFC-0021 phase 2: `nuc test --isolation=process`.
//
// Exercises the same getenv/env_set/env_unset runtime that the test
// driver itself uses to switch the harness into single-test mode. This
// is also a regression test for the historical bug where the tools
// binary's IR-gen was missing get_rt_name + is_ptr_ret entries for
// these env helpers (the `nuc test` harness then emitted plain
// `@getenv` instead of `@__nucleor_getenv`).

fn main() -> i64 {
    let mut fail: i64 = 0;

    // env_set / env_get round-trip.
    env_set("NUC_TEST_HARNESS_PROBE", "ok42");
    let v: str = env_get("NUC_TEST_HARNESS_PROBE");
    if str_eq(v, "ok42") == 0 { fail = fail + 1; print("FAIL env_get round-trip"); };

    // env_unset clears the value.
    env_unset("NUC_TEST_HARNESS_PROBE");
    let v2: str = env_get("NUC_TEST_HARNESS_PROBE");
    if str_len(v2) != 0 { fail = fail + 1; print("FAIL env_unset"); };

    // getenv works for a name that's never set.
    let absent: str = getenv("NUC_TEST_DEFINITELY_NOT_SET_X9Y3Z");
    if str_len(absent) != 0 { fail = fail + 1; print("FAIL getenv absent"); };

    // getenv works for a name we just set via env_set.
    env_set("NUC_TEST_HARNESS_PROBE_2", "via_getenv");
    let v3: str = getenv("NUC_TEST_HARNESS_PROBE_2");
    if str_eq(v3, "via_getenv") == 0 { fail = fail + 1; print("FAIL getenv after env_set"); };
    env_unset("NUC_TEST_HARNESS_PROBE_2");

    if fail == 0 { print("OK test_isolation_smoke"); return 0; };
    return 1;
}
