// R05-D4 Phase 2b first slice: block-form
// `restricts [...] { ... }` real enforcement positive smoke. A clean
// block whose body contains only arithmetic and let-binding with no
// effectful direct call must build and run successfully — pre-v0840
// this same source halted at parse_primary with the parse-time
// EFF-003 fail-closed panic. Sister to the negative fixture
// `err_restricts_block_builtin_io.nr`.

fn main() -> i32 {
    restricts [io] {
        let x: i32 = 1 + 2;
        if x == 3 { 0 } else { 1 }
    }
}
