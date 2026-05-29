import "stdlib/rods/ml/capsule_facade.nr"

// ml_capsule_facade_smoke — exercises CapsuleManifest construction and
// field round-trip from stdlib/rods/ml/capsule_facade.nr. Self-contained
// and fixture-free. Deeper deterministic-output / seeded-tensor evidence
// lives in subsequent batches once the parity-rod fixture relocation
// lands.

fn main() -> i32 {
    let mut fail: i64 = 0;

    let m: CapsuleManifest = capsule_manifest(
        "ml_capsule_facade_smoke",
        "nucleor_ml_suite",
        "nuc::capsule::manifest",
        dtype_f64(),
        2,
        3,
        policy_strict(),
        7,
        6,
        6
    );

    if m.rows != 2 { print("FAIL capsule rows"); fail = fail + 1; };
    if m.cols != 3 { print("FAIL capsule cols"); fail = fail + 1; };
    if m.dtype != dtype_f64() { print("FAIL capsule dtype"); fail = fail + 1; };
    if m.policy != policy_strict() { print("FAIL capsule policy"); fail = fail + 1; };
    if m.seed != 7 { print("FAIL capsule seed"); fail = fail + 1; };
    if m.input_count != 6 { print("FAIL capsule input_count"); fail = fail + 1; };
    if m.output_count != 6 { print("FAIL capsule output_count"); fail = fail + 1; };

    capsule_manifest_print(&m);

    if fail == 0 {
        print("OK ml_capsule_facade_smoke");
    if capsule_native_available() != 0 { panic("capsule_facade falsely advertises a native backend"); };
        return 0;
    };
    print("FAIL ml_capsule_facade_smoke");
    return 1;
}
