// EXPECT: error[EFF-001]
// R05-D3 v0.8.323 / dispatch v0839: when the caller already declares a
// `requires [...]` row, a same-file direct call into a callee whose row
// is NOT covered by the caller row must still fail with EFF-001. This
// case is distinct from `err_effect_requires_direct.nr`, which proves
// the empty-caller-row path. Here the caller declares `requires [net]`
// and the callee declares `requires [io.read]` — the rows are disjoint,
// so the caller cannot silently absorb the callee effect.

fn read_data() -> i32 requires [io.read] {
    42
}

fn caller() -> i32 requires [net] {
    read_data()
}

fn main() -> i32 {
    caller()
}
