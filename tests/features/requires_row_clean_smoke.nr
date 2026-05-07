// R05-D3 v0.8.323 / dispatch v0839 positive smoke for direct
// `requires [...]` row covering: a caller declared with the broader
// effect family `io` directly calls a callee declared with the
// sub-effect `io.read`. The current source-level enforcement
// (`effect_row_allows_effect`) accepts dotted sub-effects when the
// caller row names the family root, so this build must succeed and
// the program must print 0.
//
// Sister to `tests/features/effect_requires_direct_ok.nr`, which uses
// an intermediate `middle()` hop. This fixture pins the single-hop
// caller-broader-row path directly.

fn read_data() -> i32 requires [io.read] {
    42
}

fn caller() -> i32 requires [io] {
    read_data()
}

fn main() -> i32 requires [io] {
    if caller() == 42 { 0 } else { 1 }
}
