// rods/time_typed — verify the typed-time rod wrapper
import "stdlib/rods/time_typed.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    // Monotonic never decreases
    let t1: i64 = time_mono_ns();
    let t2: i64 = time_mono_ns();
    if t2 < t1 { fail = fail + 1; print("FAIL mono went backwards"); };

    // ms / us / ns consistency
    let mns: i64 = time_mono_ns();
    let mus: i64 = time_mono_us();
    let mms: i64 = time_mono_ms();
    if mns / 1000 < mus - 1000 { fail = fail + 1; print("FAIL mono ns-us"); };
    if mus / 1000 < mms - 1000 { fail = fail + 1; print("FAIL mono us-ms"); };

    // Wall clock plausible
    if time_wall_seconds_since_epoch() < 1700000000 { fail = fail + 1; print("FAIL wall seconds"); };

    // Sleep + elapsed
    let before: i64 = time_mono_ms();
    time_sleep_milliseconds(15);
    let elapsed: i64 = time_elapsed_ms(before);
    if elapsed < 10 { fail = fail + 1; print("FAIL elapsed too short"); };

    if fail == 0 { print("OK time_typed"); return 0; };
    return 1;
}
