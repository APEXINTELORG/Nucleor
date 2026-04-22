// mod_decl_aux.nr — RFC-0018 helper file for tests/lang/mod_decl.nr.
//
// Imported via `mod mod_decl_aux;`. Files matching `*_aux.nr` are
// skipped by the standalone gate (see verify.sh / verify.ps1
// TEST_SKIP_REGEX) so this file does not need its own `main`.

fn mod_aux_double(x: i64) -> i64 { return x * 2; }
fn mod_aux_label() -> str { return "mod_loaded"; }
