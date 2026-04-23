// EXPECT: OWN-009 cannot return reference to local value
// Scope-escape via return.
// Phase 2d: Reference cannot outlive referent scope (block expr version)

fn make_ref() -> &i32 {
    let x: i32 = 42;
    &x              // ERROR: returns reference to local
}

fn main() -> i32 {
    0
}
