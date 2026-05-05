// EXPECT: warning[RACE-007]
// v0.8.300 R04-D3 Phase 1.5 — #[deadline] + async_await fires RACE-007.

extern fn async_spawn(fn_ptr: i64, arg: i64) -> i64;
extern fn async_await(handle: i64) -> i64;

fn worker(x: i64) -> i64 {
    return x * 2;
}

#[deadline = 1ms]
fn deadline_with_await() -> i64 {
    let fp: i64 = worker;
    let h: i64 = async_spawn(fp, 5);
    let r: i64 = async_await(h);
    return r;
}

fn main() -> i32 {
    return 0;
}
