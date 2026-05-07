// EXPECT: error[EFF-003]
// R05-D4 Phase 2b first slice (local-claude v0840): block-form
// `restricts [...] { ... }` is now really enforced by s1 against a
// minimum builtin-effect table. A direct `putchar` call (io.write
// builtin) inside `restricts [io.write]` must trap with EFF-003.
// Distinct from `err_restricts_builtin_io.nr` (deny family `io`,
// builtin `print_int`) — this fixture pins the sub-effect-specific
// deny row plus a different print-family builtin to exercise the
// row-overlap path.

fn main() -> i32 {
    restricts [io.write] {
        putchar(65);
        0
    }
}
