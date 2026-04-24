// rods/urdf — verify rod wrapper compiles + links (v0.2.204 ship).
// Build-only smoke: create a parser handle, exercise the empty-state
// joint accessors, free. Functional URDF parsing requires a string
// pointer convention which is non-trivial in a single-test-file
// smoke; correctness coverage is in the direct C unit test.
import "stdlib/rods/urdf.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    let u: i64 = urdf_new();
    if u == 0 { print("FAIL urdf_new"); return 1; };
    if urdf_joint_count(u) != 0 {
        fail = fail + 1; print("FAIL initial joint count");
    };
    // Out-of-range accessor must not crash.
    if urdf_joint_type(u, 0) != 0 - 1 {
        fail = fail + 1; print("FAIL out-of-range joint_type did not return -1");
    };
    urdf_free(u);

    if fail == 0 { print("OK urdf_smoke"); };
    return fail;
}
