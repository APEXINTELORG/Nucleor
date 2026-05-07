// EXPECT: error[EFF-003]
// R05-D4 Phase 2b delta (cloud Claude2 review v0841): block-form
// `restricts [alloc]` enforcement catches direct namespaced allocation
// constructors inside the block body. `Vec::new` is checked by the
// body-level builtin table because the direct-call scanner sees only
// the suffix `new`.

fn main() -> i32 {
    restricts [alloc] {
        let v: Vec<i64> = Vec::new();
        let _len: i64 = vec_len(v);
        0
    }
}
