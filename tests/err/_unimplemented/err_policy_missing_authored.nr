// Error test: require_authored policy catches functions without @authored
// Expected: type checker error

@policy(require_authored)

fn naked_function(x: i32) -> i32 { x + 1 }

fn main() -> i32 { 0 }
