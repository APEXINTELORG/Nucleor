// v0.8.294 R12-D7 Phase 1 — acyclic dedupe regression.
// Verifies that the new MOD-005 cycle detector does NOT
// false-flag on legitimate diamond imports. Here `main`
// imports `import_dedupe_lib.nr` directly; the lib has no
// re-imports. Runs cleanly + prints "ok".
import "import_dedupe_lib.nr"

fn main() -> i32 {
    let r: i32 = lib_value();
    if r == 42 {
        print("ok");
    } else {
        print("bad");
    };
    return 0;
}
