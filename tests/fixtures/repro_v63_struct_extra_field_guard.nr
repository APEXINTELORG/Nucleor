// repro_v63_struct_extra_field_guard.nr
//
// v0.4.63 NUC-FEEDBACK silent-extra-field close.
// Pre-fix `Point { x: 1, y: 2, z: 3 }` for a 2-field Point silently
// dropped the extra `z` field — the lower walked the init list in
// declared order so any past-end entries were ignored. Rust errors
// here with E0560.
//
// v0.4.63 walks the init-list and validates each field name via
// struct_field_idx; emits TYP-013 with location pointing right at
// the unknown field name.

struct Point { x: i64, y: i64, }

fn main() -> i64 {
    let p: Point = Point { x: 1, y: 2, z: 3 };   // TYP-013 expected on z
    println!("{}", p.x);
    return 0;
}
