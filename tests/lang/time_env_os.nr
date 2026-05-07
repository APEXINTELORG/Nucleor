// time_env_os.nr — typed time + env vars + OS info builtins

fn main() -> i32 {
    let mut fail: i64 = 0;

    // Monotonic time progresses
    let t1: i64 = time_monotonic_ns();
    let t2: i64 = time_monotonic_ns();
    if t2 < t1 { fail = fail + 1; print("FAIL: monotonic went backwards\n"); };

    // Wall time non-zero (Unix epoch start of 1970)
    let wall: i64 = time_wall_seconds();
    if wall < 1700000000 {  // ~2023-11-14
        fail = fail + 1; print("FAIL: wall clock unreasonable\n");
    };

    // ms <= ns / 1e6
    let m_ms: i64 = time_monotonic_ms();
    let m_ns: i64 = time_monotonic_ns();
    if m_ns / 1000000 < m_ms - 1000 {
        fail = fail + 1; print("FAIL: monotonic ms/ns mismatch\n");
    };

    // Sleep is best-effort verifiable
    let before: i64 = time_monotonic_ms();
    sleep_ms(20);
    let after: i64 = time_monotonic_ms();
    if after - before < 15 { fail = fail + 1; print("FAIL: sleep_ms too fast\n"); };

    // Process id present
    if process_id() <= 0 { fail = fail + 1; print("FAIL: process_id\n"); };

    // OS family known
    let osf: i64 = os_family();
    if osf == 0 { fail = fail + 1; print("FAIL: unknown OS family\n"); };

    // Pointer width
    let pw: i64 = os_pointer_width();
    if pw != 64 { fail = fail + 1; print("FAIL: pointer width != 64\n"); };

    // Env: set + get + unset
    env_set("NUCLEOR_TEST_VAR", "hello");
    let v: str = env_get("NUCLEOR_TEST_VAR");
    if str_eq(v, "hello") == 0 { fail = fail + 1; print("FAIL: env_get value mismatch\n"); };
    env_unset("NUCLEOR_TEST_VAR");

    if fail == 0 { print("OK time_env_os\n"); return 0; };
    return 1;
}
