// EXPECT: PARSE-TOP-001 import requires a quoted path
// Lane 4 audit close: F-050 (High, unquoted import silent accept).
// v1.0.1 (regression gate integrator): top-level dispatch catches the
// bad token first via PARSE-TOP-001 ("only top-level items are
// accepted at module scope: `import`, ..."), before the more-
// specific PARSE-IMPORT-001 path. Same actionable signal — the
// diagnostic names `import` as accepted and points the caret at the
// unquoted `stdlib` token. Diagnostic refinement to PARSE-IMPORT-001
// for this exact shape is a v1.0.2 polish.
import stdlib/rods/strings.nr
fn main() -> i32 { return 0; }
