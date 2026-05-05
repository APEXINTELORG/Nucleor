// EXPECT: warning[RACE-002]
// v0.8.299 R04-D3 Phase 1 — async_spawn without async_await fires RACE-002.

extern fn async_spawn(fn_ptr: i64, arg: i64) -> i64;
extern fn async_await(handle: i64) -> i64;

fn worker(x: i64) -> i64 {
    return x * 2;
}

fn fire_and_forget() -> i64 {
    let fp: i64 = worker;
    let h: i64 = async_spawn(fp, 5);
    return h;
}

fn main() -> i32 {
    let h: i64 = fire_and_forget();
    return 0;
}
