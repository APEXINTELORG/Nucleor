// Error test: bare number cannot become unit value (MCO prevention)
// This is the exact class of bug that destroyed the Mars Climate Orbiter
fn main() -> i32 {
    let force: unit<i32, N> = 42;
    0
}
