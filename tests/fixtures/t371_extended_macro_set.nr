// t371_extended_macro_set.nr — v0.3.95 regression fixture.
//
// Pins the extended macro set added in v0.3.95: assert_eq!,
// assert_ne!, todo!, unimplemented!, unreachable! (in addition to
// panic!/assert!/dbg! from v0.3.94). The textual macro
// preprocessor strips the `!` so the existing fn call dispatch
// handles them via the corresponding runtime helpers.
//
// Returns 0 on success — assert_eq! and assert_ne! are no-ops
// when the assertion holds.

fn main() -> i64 {
    assert_eq!(2 + 2, 4);
    assert_ne!(1, 2);
    return 0;
}
