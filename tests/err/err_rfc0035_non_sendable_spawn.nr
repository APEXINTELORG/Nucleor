// EXPECT: RACE-001

trait Sendable {}

struct PlainHandle {
    raw: i64,
}

fn worker(h: PlainHandle) -> i64 {
    return h.raw;
}

fn main() -> i32 {
    let h: PlainHandle = PlainHandle { raw: 7 };
    let task: i64 = async_spawn(worker, h);
    return async_await(task) as i32;
}
