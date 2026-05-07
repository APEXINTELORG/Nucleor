// EXPECT: error[EFF-003]
// R05-D5 v0841 transitive restricts ship: a restricts block calls
// an un-rowed same-file user fn `helper`, and `helper`'s body
// directly calls a rowed effectful function `read_sensor()` whose
// `requires [io.read]` row overlaps the deny `[io]`. Pre-v0841
// this shape only surfaced EFF-001 from
// `enforce_requires_direct_calls`; v0841 adds bounded same-file
// transitive enforcement so the restricts surface itself emits
// EFF-003 too. Sister to `err_effect_inference.nr` (which uses
// `middle()` as the un-rowed hop).

fn read_sensor() -> i64 requires [io.read] { 1 }

fn helper() -> i64 {
    read_sensor()
}

fn main() -> i64 {
    restricts [io] {
        helper()
    }
}
