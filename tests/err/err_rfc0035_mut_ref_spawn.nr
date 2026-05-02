// EXPECT: RACE-005

struct Cell {
    v: i64,
}

fn worker(x: &mut Cell) -> i64 {
    x.v = x.v + 1;
    return x.v;
}

fn main() -> i32 {
    let mut x: Cell = Cell { v: 1 };
    let h: i64 = thread_spawn(worker, &mut x);
    thread_join(h);
    return 0;
}
