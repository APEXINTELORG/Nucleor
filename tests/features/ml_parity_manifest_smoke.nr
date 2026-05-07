import "stdlib/rods/ml/parity_manifest.nr"

// ml_parity_manifest_smoke — constructs a ParityManifest, prints it, and
// confirms field round-trip via the same surface the ML Suite uses to
// emit parity-claim metadata for every numeric-parity rod.

fn main() -> i32 {
    let mut fail: i64 = 0;

    let m: ParityManifest = parity_manifest(
        "ml_parity_manifest_smoke",
        "internal",
        "stdlib::rods::ml::parity_manifest",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        2,
        3,
        0.000001
    );

    if m.rows != 2 { print("FAIL manifest rows"); fail = fail + 1; };
    if m.cols != 3 { print("FAIL manifest cols"); fail = fail + 1; };
    if m.dtype != dtype_f64() { print("FAIL manifest dtype"); fail = fail + 1; };
    if m.accumulator_dtype != dtype_f64() { print("FAIL manifest accumulator"); fail = fail + 1; };
    if m.policy != policy_strict() { print("FAIL manifest policy"); fail = fail + 1; };

    parity_manifest_print(&m);

    if fail == 0 {
        print("OK ml_parity_manifest_smoke");
        return 0;
    };
    print("FAIL ml_parity_manifest_smoke");
    return 1;
}
