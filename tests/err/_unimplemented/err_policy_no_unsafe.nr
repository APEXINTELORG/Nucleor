// Error test: no_unsafe policy rejects unsafe blocks
// Expected: type checker error

@policy(no_unsafe)

fn sneaky() -> i32 {
    unsafe { 42 }
}

fn main() -> i32 { 0 }
