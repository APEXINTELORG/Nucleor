// mod_decl — RFC-0018 phase 1: `mod foo;` directive loads ./foo.nr.
//
// Block-form `mod foo { ... }` requires a parser-level scope and
// ships in phase 2 with the resolver. The single-line form is a thin
// desugar over the existing `import` preprocess step. The helper
// lives in `mod_decl_aux.nr` (the `_aux.nr` suffix tells the gate to
// skip it as a standalone test).

mod mod_decl_aux;

fn main() -> i64 {
    let mut fail: i64 = 0;
    if mod_aux_double(21) != 42 { fail = fail + 1; print("FAIL aux double"); };
    if str_eq(mod_aux_label(), "mod_loaded") == 0 { fail = fail + 1; print("FAIL aux label"); };
    if fail == 0 { print("OK mod_decl"); return 0; };
    return 1;
}
