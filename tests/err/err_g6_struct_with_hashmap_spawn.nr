// EXPECT: SEND-G6-HASHMAP non-Sendable struct type
// G6-A-1: a user struct is Sendable only if all transitive fields
// are Sendable. HashMap inside a struct must not cross spawn.
struct Container { m: HashMap<str, i64> }

fn worker(c: Container) -> i64 {
    return 0;
}

fn main() -> i32 {
    let c: Container = Container { m: HashMap::new() };
    let task: i64 = async_spawn(worker, c);
    return async_await(task) as i32;
}
