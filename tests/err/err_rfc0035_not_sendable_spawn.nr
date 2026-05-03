// EXPECT: RACE-008

trait Sendable {}

#[not_sendable]
struct LocalHandle {
    raw: i64,
}

impl Sendable for LocalHandle {}

fn worker(h: LocalHandle) -> i64 {
    return h.raw;
}

fn main() -> i32 {
    let h: LocalHandle = LocalHandle { raw: 7 };
    let task: i64 = async_spawn(worker, h);
    return async_await(task) as i32;
}
