// R05-D4 Phase 2b delta: a
// `restricts [net]` block may call a same-file function declared
// `requires [io.read]` because the callee row is in a disjoint effect
// family. Build and run must succeed.

fn read_data() -> i32 requires [io.read] {
    42
}

fn main() -> i32 requires [io] {
    restricts [net] {
        if read_data() == 42 { 0 } else { 1 }
    }
}
