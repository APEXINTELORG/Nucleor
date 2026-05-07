// rods/ml/parity_manifest — ML Suite parity-claim metadata (suite/case/surface/dtype/shape/policy/seed/tolerance)
//
import "stdlib/rods/ml/dtype_core.nr"
import "stdlib/rods/ml/shape_core.nr"

#[repr(C)]
struct ParityManifest {
    case_name: str,
    python_library: str,
    nucleor_surface: str,
    dtype: i64,
    accumulator_dtype: i64,
    policy: i64,
    rows: i64,
    cols: i64,
    tolerance_abs: f64
}

fn parity_manifest(
    case_name: str,
    python_library: str,
    nucleor_surface: str,
    dtype: i64,
    accumulator_dtype: i64,
    policy: i64,
    rows: i64,
    cols: i64,
    tolerance_abs: f64
) -> ParityManifest {
    return ParityManifest {
        case_name: case_name,
        python_library: python_library,
        nucleor_surface: nucleor_surface,
        dtype: dtype,
        accumulator_dtype: accumulator_dtype,
        policy: policy,
        rows: rows,
        cols: cols,
        tolerance_abs: tolerance_abs
    };
}

fn parity_manifest_print(m: &ParityManifest) -> i64 {
    print("parity manifest:");
    print(m.case_name);
    print("python_library:");
    print(m.python_library);
    print("nucleor_surface:");
    print(m.nucleor_surface);
    print("dtype:");
    print(dtype_name(m.dtype));
    print("accumulator_dtype:");
    print(dtype_name(m.accumulator_dtype));
    print("policy:");
    print(policy_name(m.policy));
    print("shape rows cols:");
    print_int(m.rows);
    print_int(m.cols);
    print("tolerance_abs:");
    print_f64(m.tolerance_abs);
    return 0;
}
