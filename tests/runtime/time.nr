// time.nr — time rod (now_ms returns monotonically non-decreasing)
import "stdlib/rods/time.nr"

fn main() -> i64 {
    let t1: i64 = time_now_ms();
    let t2: i64 = time_now_ms();
    if t2 < t1 {
        print("FAIL time: clock went backwards");
        return 1;
    };
    print("OK time");
    return 0;
}
