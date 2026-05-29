// rods/ml/capsule_facade — Capsule manifest contract + 10 sub-aspect variants (artifact/device/input/output/rod_graph/source/suite/tolerance/toolchain/verifier)
// Maturity: CONTRACT-ONLY — records manifest/contract metadata; no native engine or runtime is linked behind it. Enforced by capsule_native_available()==0 (HON-1).
//
import "stdlib/rods/ml/tensor_facade.nr"
import "stdlib/rods/jsonl.nr"

// capsule_facade.nr - first reproducible capsule surface.
//
// The MVP records stable run metadata and machine-readable JSONL evidence.
// SHA-256 is computed by the Python verifier until Nucleor has a runtime
// hashing helper.

#[repr(C)]
struct CapsuleManifest {
    case_name: str,
    suite_name: str,
    nucleor_surface: str,
    dtype: i64,
    rows: i64,
    cols: i64,
    policy: i64,
    seed: i64,
    input_count: i64,
    output_count: i64
}

#[repr(C)]
struct CapsuleSuiteManifest {
    suite_name: str,
    nucleor_surface: str,
    policy: i64,
    manifest_version: i64,
    numeric_case_count: i64,
    capsule_case_count: i64,
    total_report_count: i64
}

#[repr(C)]
struct CapsuleInputManifest {
    case_name: str,
    suite_name: str,
    nucleor_surface: str,
    input_path: str,
    dtype: i64,
    rows: i64,
    cols: i64,
    policy: i64,
    value_count: i64
}

#[repr(C)]
struct CapsuleOutputManifest {
    case_name: str,
    suite_name: str,
    nucleor_surface: str,
    output_path: str,
    output_role: str,
    output_format: str,
    dtype: i64,
    rows: i64,
    cols: i64,
    policy: i64,
    value_count: i64,
    hash_count: i64
}

#[repr(C)]
struct CapsuleToolchainManifest {
    case_name: str,
    suite_name: str,
    nucleor_surface: str,
    compiler_name: str,
    compiler_path: str,
    runtime_name: str,
    policy: i64,
    manifest_version: i64,
    tool_count: i64,
    hash_count: i64
}

#[repr(C)]
struct CapsuleToleranceManifest {
    case_name: str,
    suite_name: str,
    nucleor_surface: str,
    metric_name: str,
    dtype: i64,
    rows: i64,
    cols: i64,
    policy: i64,
    tolerance_abs: f64,
    tolerance_rel: f64,
    metric_count: i64
}

#[repr(C)]
struct CapsuleSourceManifest {
    case_name: str,
    suite_name: str,
    nucleor_surface: str,
    source_path: str,
    language: str,
    source_role: str,
    policy: i64,
    manifest_version: i64,
    source_count: i64,
    hash_count: i64
}

#[repr(C)]
struct CapsuleDeviceManifest {
    case_name: str,
    suite_name: str,
    nucleor_surface: str,
    os_name: str,
    arch_name: str,
    device_kind: str,
    runtime_name: str,
    policy: i64,
    profile_version: i64,
    device_count: i64,
    runtime_count: i64
}

#[repr(C)]
struct CapsuleRodGraphManifest {
    case_name: str,
    suite_name: str,
    nucleor_surface: str,
    rod_name: str,
    rod_path: str,
    rod_role: str,
    policy: i64,
    manifest_version: i64,
    rod_count: i64,
    hash_count: i64
}

#[repr(C)]
struct CapsuleVerifierManifest {
    case_name: str,
    suite_name: str,
    nucleor_surface: str,
    verifier_tool: str,
    verifier_command: str,
    policy: i64,
    manifest_version: i64,
    check_count: i64,
    expected_capsule_count: i64
}

#[repr(C)]
struct CapsuleArtifactManifest {
    case_name: str,
    suite_name: str,
    nucleor_surface: str,
    artifact_path: str,
    artifact_role: str,
    artifact_format: str,
    policy: i64,
    manifest_version: i64,
    artifact_count: i64,
    hash_count: i64
}

fn capsule_manifest(
    case_name: str,
    suite_name: str,
    nucleor_surface: str,
    dtype: i64,
    rows: i64,
    cols: i64,
    policy: i64,
    seed: i64,
    input_count: i64,
    output_count: i64
) -> CapsuleManifest {
    return CapsuleManifest {
        case_name: case_name,
        suite_name: suite_name,
        nucleor_surface: nucleor_surface,
        dtype: dtype,
        rows: rows,
        cols: cols,
        policy: policy,
        seed: seed,
        input_count: input_count,
        output_count: output_count
    };
}

fn capsule_input_manifest(
    case_name: str,
    suite_name: str,
    nucleor_surface: str,
    input_path: str,
    dtype: i64,
    rows: i64,
    cols: i64,
    policy: i64,
    value_count: i64
) -> CapsuleInputManifest {
    return CapsuleInputManifest {
        case_name: case_name,
        suite_name: suite_name,
        nucleor_surface: nucleor_surface,
        input_path: input_path,
        dtype: dtype,
        rows: rows,
        cols: cols,
        policy: policy,
        value_count: value_count
    };
}

fn capsule_output_manifest(
    case_name: str,
    suite_name: str,
    nucleor_surface: str,
    output_path: str,
    output_role: str,
    output_format: str,
    dtype: i64,
    rows: i64,
    cols: i64,
    policy: i64,
    value_count: i64,
    hash_count: i64
) -> CapsuleOutputManifest {
    return CapsuleOutputManifest {
        case_name: case_name,
        suite_name: suite_name,
        nucleor_surface: nucleor_surface,
        output_path: output_path,
        output_role: output_role,
        output_format: output_format,
        dtype: dtype,
        rows: rows,
        cols: cols,
        policy: policy,
        value_count: value_count,
        hash_count: hash_count
    };
}

fn capsule_artifact_manifest(
    case_name: str,
    suite_name: str,
    nucleor_surface: str,
    artifact_path: str,
    artifact_role: str,
    artifact_format: str,
    policy: i64,
    manifest_version: i64,
    artifact_count: i64,
    hash_count: i64
) -> CapsuleArtifactManifest {
    return CapsuleArtifactManifest {
        case_name: case_name,
        suite_name: suite_name,
        nucleor_surface: nucleor_surface,
        artifact_path: artifact_path,
        artifact_role: artifact_role,
        artifact_format: artifact_format,
        policy: policy,
        manifest_version: manifest_version,
        artifact_count: artifact_count,
        hash_count: hash_count
    };
}

fn capsule_verifier_manifest(
    case_name: str,
    suite_name: str,
    nucleor_surface: str,
    verifier_tool: str,
    verifier_command: str,
    policy: i64,
    manifest_version: i64,
    check_count: i64,
    expected_capsule_count: i64
) -> CapsuleVerifierManifest {
    return CapsuleVerifierManifest {
        case_name: case_name,
        suite_name: suite_name,
        nucleor_surface: nucleor_surface,
        verifier_tool: verifier_tool,
        verifier_command: verifier_command,
        policy: policy,
        manifest_version: manifest_version,
        check_count: check_count,
        expected_capsule_count: expected_capsule_count
    };
}

fn capsule_rod_graph_manifest(
    case_name: str,
    suite_name: str,
    nucleor_surface: str,
    rod_name: str,
    rod_path: str,
    rod_role: str,
    policy: i64,
    manifest_version: i64,
    rod_count: i64,
    hash_count: i64
) -> CapsuleRodGraphManifest {
    return CapsuleRodGraphManifest {
        case_name: case_name,
        suite_name: suite_name,
        nucleor_surface: nucleor_surface,
        rod_name: rod_name,
        rod_path: rod_path,
        rod_role: rod_role,
        policy: policy,
        manifest_version: manifest_version,
        rod_count: rod_count,
        hash_count: hash_count
    };
}

fn capsule_device_manifest(
    case_name: str,
    suite_name: str,
    nucleor_surface: str,
    os_name: str,
    arch_name: str,
    device_kind: str,
    runtime_name: str,
    policy: i64,
    profile_version: i64,
    device_count: i64,
    runtime_count: i64
) -> CapsuleDeviceManifest {
    return CapsuleDeviceManifest {
        case_name: case_name,
        suite_name: suite_name,
        nucleor_surface: nucleor_surface,
        os_name: os_name,
        arch_name: arch_name,
        device_kind: device_kind,
        runtime_name: runtime_name,
        policy: policy,
        profile_version: profile_version,
        device_count: device_count,
        runtime_count: runtime_count
    };
}

fn capsule_source_manifest(
    case_name: str,
    suite_name: str,
    nucleor_surface: str,
    source_path: str,
    language: str,
    source_role: str,
    policy: i64,
    manifest_version: i64,
    source_count: i64,
    hash_count: i64
) -> CapsuleSourceManifest {
    return CapsuleSourceManifest {
        case_name: case_name,
        suite_name: suite_name,
        nucleor_surface: nucleor_surface,
        source_path: source_path,
        language: language,
        source_role: source_role,
        policy: policy,
        manifest_version: manifest_version,
        source_count: source_count,
        hash_count: hash_count
    };
}

fn capsule_tolerance_manifest(
    case_name: str,
    suite_name: str,
    nucleor_surface: str,
    metric_name: str,
    dtype: i64,
    rows: i64,
    cols: i64,
    policy: i64,
    tolerance_abs: f64,
    tolerance_rel: f64,
    metric_count: i64
) -> CapsuleToleranceManifest {
    return CapsuleToleranceManifest {
        case_name: case_name,
        suite_name: suite_name,
        nucleor_surface: nucleor_surface,
        metric_name: metric_name,
        dtype: dtype,
        rows: rows,
        cols: cols,
        policy: policy,
        tolerance_abs: tolerance_abs,
        tolerance_rel: tolerance_rel,
        metric_count: metric_count
    };
}

fn capsule_toolchain_manifest(
    case_name: str,
    suite_name: str,
    nucleor_surface: str,
    compiler_name: str,
    compiler_path: str,
    runtime_name: str,
    policy: i64,
    manifest_version: i64,
    tool_count: i64,
    hash_count: i64
) -> CapsuleToolchainManifest {
    return CapsuleToolchainManifest {
        case_name: case_name,
        suite_name: suite_name,
        nucleor_surface: nucleor_surface,
        compiler_name: compiler_name,
        compiler_path: compiler_path,
        runtime_name: runtime_name,
        policy: policy,
        manifest_version: manifest_version,
        tool_count: tool_count,
        hash_count: hash_count
    };
}

fn capsule_suite_manifest(
    suite_name: str,
    nucleor_surface: str,
    policy: i64,
    manifest_version: i64,
    numeric_case_count: i64,
    capsule_case_count: i64,
    total_report_count: i64
) -> CapsuleSuiteManifest {
    return CapsuleSuiteManifest {
        suite_name: suite_name,
        nucleor_surface: nucleor_surface,
        policy: policy,
        manifest_version: manifest_version,
        numeric_case_count: numeric_case_count,
        capsule_case_count: capsule_case_count,
        total_report_count: total_report_count
    };
}

fn capsule_manifest_print(m: &CapsuleManifest) -> i64 {
    print("capsule manifest:");
    print("case:");
    print(m.case_name);
    print("suite:");
    print(m.suite_name);
    print("nucleor_surface:");
    print(m.nucleor_surface);
    print("dtype:");
    print(dtype_name(m.dtype));
    print("shape rows cols:");
    print_int(m.rows);
    print_int(m.cols);
    print("policy:");
    print(policy_name(m.policy));
    print("seed:");
    print_int(m.seed);
    print("input_count:");
    print_int(m.input_count);
    print("output_count:");
    print_int(m.output_count);
    return 0;
}

fn capsule_manifest_emit_jsonl(m: &CapsuleManifest) -> i64 {
    emit_json_run_meta(
        m.case_name,
        m.suite_name,
        m.nucleor_surface,
        dtype_name(m.dtype),
        m.rows,
        m.cols,
        policy_name(m.policy)
    );
    emit_json_metric_i64("seed", m.seed);
    emit_json_metric_i64("input_count", m.input_count);
    emit_json_metric_i64("output_count", m.output_count);
    return 0;
}

fn capsule_input_manifest_print(m: &CapsuleInputManifest) -> i64 {
    print("capsule input manifest:");
    print("case:");
    print(m.case_name);
    print("suite:");
    print(m.suite_name);
    print("nucleor_surface:");
    print(m.nucleor_surface);
    print("input_path:");
    print(m.input_path);
    print("dtype:");
    print(dtype_name(m.dtype));
    print("shape rows cols:");
    print_int(m.rows);
    print_int(m.cols);
    print("policy:");
    print(policy_name(m.policy));
    print("value_count:");
    print_int(m.value_count);
    return 0;
}

fn capsule_input_manifest_emit_jsonl(m: &CapsuleInputManifest) -> i64 {
    emit_json_run_meta(
        m.case_name,
        m.suite_name,
        m.nucleor_surface,
        dtype_name(m.dtype),
        m.rows,
        m.cols,
        policy_name(m.policy)
    );

    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"kind\":\"input\",\"path\":");
    sb_append(sb, jsonl_quote(m.input_path));
    sb_append(sb, ",\"dtype\":");
    sb_append(sb, jsonl_quote(dtype_name(m.dtype)));
    sb_append(sb, ",\"shape\":[");
    sb_append(sb, str_from_int(m.rows));
    sb_append(sb, ",");
    sb_append(sb, str_from_int(m.cols));
    sb_append(sb, "],\"value_count\":");
    sb_append(sb, str_from_int(m.value_count));
    sb_append(sb, "}");
    print(sb_to_str(sb));

    emit_json_metric_i64("value_count", m.value_count);

    let mut shape: Vec<i64> = Vec::new();
    shape.push(m.rows);
    shape.push(m.cols);
    shape.push(m.value_count);
    emit_json_array_i64("input_shape", shape, 1, 3);
    return 0;
}

fn capsule_output_manifest_print(m: &CapsuleOutputManifest) -> i64 {
    print("capsule output manifest:");
    print("case:");
    print(m.case_name);
    print("suite:");
    print(m.suite_name);
    print("nucleor_surface:");
    print(m.nucleor_surface);
    print("output_path:");
    print(m.output_path);
    print("output_role:");
    print(m.output_role);
    print("output_format:");
    print(m.output_format);
    print("dtype:");
    print(dtype_name(m.dtype));
    print("shape rows cols:");
    print_int(m.rows);
    print_int(m.cols);
    print("policy:");
    print(policy_name(m.policy));
    print("value_count:");
    print_int(m.value_count);
    print("hash_count:");
    print_int(m.hash_count);
    return 0;
}

fn capsule_output_manifest_emit_jsonl(m: &CapsuleOutputManifest) -> i64 {
    emit_json_run_meta(
        m.case_name,
        m.suite_name,
        m.nucleor_surface,
        dtype_name(m.dtype),
        m.rows,
        m.cols,
        policy_name(m.policy)
    );

    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"kind\":\"output\",\"path\":");
    sb_append(sb, jsonl_quote(m.output_path));
    sb_append(sb, ",\"role\":");
    sb_append(sb, jsonl_quote(m.output_role));
    sb_append(sb, ",\"format\":");
    sb_append(sb, jsonl_quote(m.output_format));
    sb_append(sb, ",\"dtype\":");
    sb_append(sb, jsonl_quote(dtype_name(m.dtype)));
    sb_append(sb, ",\"shape\":[");
    sb_append(sb, str_from_int(m.rows));
    sb_append(sb, ",");
    sb_append(sb, str_from_int(m.cols));
    sb_append(sb, "],\"value_count\":");
    sb_append(sb, str_from_int(m.value_count));
    sb_append(sb, ",\"hash_count\":");
    sb_append(sb, str_from_int(m.hash_count));
    sb_append(sb, "}");
    print(sb_to_str(sb));

    emit_json_metric_i64("value_count", m.value_count);
    emit_json_metric_i64("hash_count", m.hash_count);

    let mut shape: Vec<i64> = Vec::new();
    shape.push(m.rows);
    shape.push(m.cols);
    shape.push(m.value_count);
    emit_json_array_i64("output_shape", shape, 1, 3);
    return 0;
}

fn capsule_artifact_manifest_print(m: &CapsuleArtifactManifest) -> i64 {
    print("capsule artifact manifest:");
    print("case:");
    print(m.case_name);
    print("suite:");
    print(m.suite_name);
    print("nucleor_surface:");
    print(m.nucleor_surface);
    print("artifact_path:");
    print(m.artifact_path);
    print("artifact_role:");
    print(m.artifact_role);
    print("artifact_format:");
    print(m.artifact_format);
    print("policy:");
    print(policy_name(m.policy));
    print("manifest_version:");
    print_int(m.manifest_version);
    print("artifact_count:");
    print_int(m.artifact_count);
    print("hash_count:");
    print_int(m.hash_count);
    return 0;
}

fn capsule_artifact_manifest_emit_jsonl(m: &CapsuleArtifactManifest) -> i64 {
    emit_json_run_meta(
        m.case_name,
        m.suite_name,
        m.nucleor_surface,
        "i64",
        1,
        3,
        policy_name(m.policy)
    );

    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"kind\":\"artifact\",\"path\":");
    sb_append(sb, jsonl_quote(m.artifact_path));
    sb_append(sb, ",\"role\":");
    sb_append(sb, jsonl_quote(m.artifact_role));
    sb_append(sb, ",\"format\":");
    sb_append(sb, jsonl_quote(m.artifact_format));
    sb_append(sb, ",\"manifest_version\":");
    sb_append(sb, str_from_int(m.manifest_version));
    sb_append(sb, "}");
    print(sb_to_str(sb));

    emit_json_metric_i64("manifest_version", m.manifest_version);
    emit_json_metric_i64("artifact_count", m.artifact_count);
    emit_json_metric_i64("hash_count", m.hash_count);

    let mut counts: Vec<i64> = Vec::new();
    counts.push(m.manifest_version);
    counts.push(m.artifact_count);
    counts.push(m.hash_count);
    emit_json_array_i64("artifact_counts", counts, 1, 3);
    return 0;
}

fn capsule_verifier_manifest_print(m: &CapsuleVerifierManifest) -> i64 {
    print("capsule verifier manifest:");
    print("case:");
    print(m.case_name);
    print("suite:");
    print(m.suite_name);
    print("nucleor_surface:");
    print(m.nucleor_surface);
    print("verifier_tool:");
    print(m.verifier_tool);
    print("verifier_command:");
    print(m.verifier_command);
    print("policy:");
    print(policy_name(m.policy));
    print("manifest_version:");
    print_int(m.manifest_version);
    print("check_count:");
    print_int(m.check_count);
    print("expected_capsule_count:");
    print_int(m.expected_capsule_count);
    return 0;
}

fn capsule_verifier_manifest_emit_jsonl(m: &CapsuleVerifierManifest) -> i64 {
    emit_json_run_meta(
        m.case_name,
        m.suite_name,
        m.nucleor_surface,
        "i64",
        1,
        3,
        policy_name(m.policy)
    );

    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"kind\":\"verifier\",\"tool\":");
    sb_append(sb, jsonl_quote(m.verifier_tool));
    sb_append(sb, ",\"command\":");
    sb_append(sb, jsonl_quote(m.verifier_command));
    sb_append(sb, ",\"manifest_version\":");
    sb_append(sb, str_from_int(m.manifest_version));
    sb_append(sb, ",\"expected_capsule_count\":");
    sb_append(sb, str_from_int(m.expected_capsule_count));
    sb_append(sb, "}");
    print(sb_to_str(sb));

    emit_json_metric_i64("manifest_version", m.manifest_version);
    emit_json_metric_i64("check_count", m.check_count);
    emit_json_metric_i64("expected_capsule_count", m.expected_capsule_count);

    let mut counts: Vec<i64> = Vec::new();
    counts.push(m.manifest_version);
    counts.push(m.check_count);
    counts.push(m.expected_capsule_count);
    emit_json_array_i64("verifier_counts", counts, 1, 3);
    return 0;
}

fn capsule_rod_graph_manifest_print(m: &CapsuleRodGraphManifest) -> i64 {
    print("capsule rod graph manifest:");
    print("case:");
    print(m.case_name);
    print("suite:");
    print(m.suite_name);
    print("nucleor_surface:");
    print(m.nucleor_surface);
    print("rod_name:");
    print(m.rod_name);
    print("rod_path:");
    print(m.rod_path);
    print("rod_role:");
    print(m.rod_role);
    print("policy:");
    print(policy_name(m.policy));
    print("manifest_version:");
    print_int(m.manifest_version);
    print("rod_count:");
    print_int(m.rod_count);
    print("hash_count:");
    print_int(m.hash_count);
    return 0;
}

fn capsule_rod_graph_manifest_emit_jsonl(m: &CapsuleRodGraphManifest) -> i64 {
    emit_json_run_meta(
        m.case_name,
        m.suite_name,
        m.nucleor_surface,
        "i64",
        1,
        3,
        policy_name(m.policy)
    );

    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"kind\":\"rod_graph\",\"rod\":");
    sb_append(sb, jsonl_quote(m.rod_name));
    sb_append(sb, ",\"path\":");
    sb_append(sb, jsonl_quote(m.rod_path));
    sb_append(sb, ",\"role\":");
    sb_append(sb, jsonl_quote(m.rod_role));
    sb_append(sb, ",\"manifest_version\":");
    sb_append(sb, str_from_int(m.manifest_version));
    sb_append(sb, "}");
    print(sb_to_str(sb));

    emit_json_metric_i64("manifest_version", m.manifest_version);
    emit_json_metric_i64("rod_count", m.rod_count);
    emit_json_metric_i64("hash_count", m.hash_count);

    let mut counts: Vec<i64> = Vec::new();
    counts.push(m.manifest_version);
    counts.push(m.rod_count);
    counts.push(m.hash_count);
    emit_json_array_i64("rod_graph_counts", counts, 1, 3);
    return 0;
}

fn capsule_device_manifest_print(m: &CapsuleDeviceManifest) -> i64 {
    print("capsule device manifest:");
    print("case:");
    print(m.case_name);
    print("suite:");
    print(m.suite_name);
    print("nucleor_surface:");
    print(m.nucleor_surface);
    print("os_name:");
    print(m.os_name);
    print("arch_name:");
    print(m.arch_name);
    print("device_kind:");
    print(m.device_kind);
    print("runtime_name:");
    print(m.runtime_name);
    print("policy:");
    print(policy_name(m.policy));
    print("profile_version:");
    print_int(m.profile_version);
    print("device_count:");
    print_int(m.device_count);
    print("runtime_count:");
    print_int(m.runtime_count);
    return 0;
}

fn capsule_device_manifest_emit_jsonl(m: &CapsuleDeviceManifest) -> i64 {
    emit_json_run_meta(
        m.case_name,
        m.suite_name,
        m.nucleor_surface,
        "i64",
        1,
        3,
        policy_name(m.policy)
    );

    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"kind\":\"device\",\"os\":");
    sb_append(sb, jsonl_quote(m.os_name));
    sb_append(sb, ",\"arch\":");
    sb_append(sb, jsonl_quote(m.arch_name));
    sb_append(sb, ",\"device\":");
    sb_append(sb, jsonl_quote(m.device_kind));
    sb_append(sb, ",\"runtime\":");
    sb_append(sb, jsonl_quote(m.runtime_name));
    sb_append(sb, ",\"profile_version\":");
    sb_append(sb, str_from_int(m.profile_version));
    sb_append(sb, "}");
    print(sb_to_str(sb));

    emit_json_metric_i64("profile_version", m.profile_version);
    emit_json_metric_i64("device_count", m.device_count);
    emit_json_metric_i64("runtime_count", m.runtime_count);

    let mut counts: Vec<i64> = Vec::new();
    counts.push(m.profile_version);
    counts.push(m.device_count);
    counts.push(m.runtime_count);
    emit_json_array_i64("device_counts", counts, 1, 3);
    return 0;
}

fn capsule_source_manifest_print(m: &CapsuleSourceManifest) -> i64 {
    print("capsule source manifest:");
    print("case:");
    print(m.case_name);
    print("suite:");
    print(m.suite_name);
    print("nucleor_surface:");
    print(m.nucleor_surface);
    print("source_path:");
    print(m.source_path);
    print("language:");
    print(m.language);
    print("source_role:");
    print(m.source_role);
    print("policy:");
    print(policy_name(m.policy));
    print("manifest_version:");
    print_int(m.manifest_version);
    print("source_count:");
    print_int(m.source_count);
    print("hash_count:");
    print_int(m.hash_count);
    return 0;
}

fn capsule_source_manifest_emit_jsonl(m: &CapsuleSourceManifest) -> i64 {
    emit_json_run_meta(
        m.case_name,
        m.suite_name,
        m.nucleor_surface,
        "i64",
        1,
        3,
        policy_name(m.policy)
    );

    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"kind\":\"source\",\"path\":");
    sb_append(sb, jsonl_quote(m.source_path));
    sb_append(sb, ",\"language\":");
    sb_append(sb, jsonl_quote(m.language));
    sb_append(sb, ",\"role\":");
    sb_append(sb, jsonl_quote(m.source_role));
    sb_append(sb, ",\"manifest_version\":");
    sb_append(sb, str_from_int(m.manifest_version));
    sb_append(sb, "}");
    print(sb_to_str(sb));

    emit_json_metric_i64("manifest_version", m.manifest_version);
    emit_json_metric_i64("source_count", m.source_count);
    emit_json_metric_i64("hash_count", m.hash_count);

    let mut counts: Vec<i64> = Vec::new();
    counts.push(m.manifest_version);
    counts.push(m.source_count);
    counts.push(m.hash_count);
    emit_json_array_i64("source_counts", counts, 1, 3);
    return 0;
}

fn capsule_tolerance_manifest_print(m: &CapsuleToleranceManifest) -> i64 {
    print("capsule tolerance manifest:");
    print("case:");
    print(m.case_name);
    print("suite:");
    print(m.suite_name);
    print("nucleor_surface:");
    print(m.nucleor_surface);
    print("metric_name:");
    print(m.metric_name);
    print("dtype:");
    print(dtype_name(m.dtype));
    print("shape rows cols:");
    print_int(m.rows);
    print_int(m.cols);
    print("policy:");
    print(policy_name(m.policy));
    print("tolerance_abs:");
    print_f64(m.tolerance_abs);
    print("tolerance_rel:");
    print_f64(m.tolerance_rel);
    print("metric_count:");
    print_int(m.metric_count);
    return 0;
}

fn capsule_tolerance_manifest_emit_jsonl(m: &CapsuleToleranceManifest) -> i64 {
    emit_json_run_meta(
        m.case_name,
        m.suite_name,
        m.nucleor_surface,
        dtype_name(m.dtype),
        m.rows,
        m.cols,
        policy_name(m.policy)
    );

    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"kind\":\"tolerance\",\"metric\":");
    sb_append(sb, jsonl_quote(m.metric_name));
    sb_append(sb, ",\"dtype\":");
    sb_append(sb, jsonl_quote(dtype_name(m.dtype)));
    sb_append(sb, ",\"absolute\":");
    sb_append(sb, f64_to_str(m.tolerance_abs));
    sb_append(sb, ",\"relative\":");
    sb_append(sb, f64_to_str(m.tolerance_rel));
    sb_append(sb, "}");
    print(sb_to_str(sb));

    emit_json_metric_f64("tolerance_abs", m.tolerance_abs);
    emit_json_metric_f64("tolerance_rel", m.tolerance_rel);
    emit_json_metric_i64("metric_count", m.metric_count);

    let mut counts: Vec<i64> = Vec::new();
    counts.push(m.rows);
    counts.push(m.cols);
    counts.push(m.metric_count);
    emit_json_array_i64("tolerance_counts", counts, 1, 3);
    return 0;
}

fn capsule_toolchain_manifest_print(m: &CapsuleToolchainManifest) -> i64 {
    print("capsule toolchain manifest:");
    print("case:");
    print(m.case_name);
    print("suite:");
    print(m.suite_name);
    print("nucleor_surface:");
    print(m.nucleor_surface);
    print("compiler_name:");
    print(m.compiler_name);
    print("compiler_path:");
    print(m.compiler_path);
    print("runtime_name:");
    print(m.runtime_name);
    print("policy:");
    print(policy_name(m.policy));
    print("manifest_version:");
    print_int(m.manifest_version);
    print("tool_count:");
    print_int(m.tool_count);
    print("hash_count:");
    print_int(m.hash_count);
    return 0;
}

fn capsule_toolchain_manifest_emit_jsonl(m: &CapsuleToolchainManifest) -> i64 {
    emit_json_run_meta(
        m.case_name,
        m.suite_name,
        m.nucleor_surface,
        "i64",
        1,
        3,
        policy_name(m.policy)
    );

    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"kind\":\"toolchain\",\"compiler\":");
    sb_append(sb, jsonl_quote(m.compiler_name));
    sb_append(sb, ",\"compiler_path\":");
    sb_append(sb, jsonl_quote(m.compiler_path));
    sb_append(sb, ",\"runtime\":");
    sb_append(sb, jsonl_quote(m.runtime_name));
    sb_append(sb, ",\"manifest_version\":");
    sb_append(sb, str_from_int(m.manifest_version));
    sb_append(sb, "}");
    print(sb_to_str(sb));

    emit_json_metric_i64("manifest_version", m.manifest_version);
    emit_json_metric_i64("tool_count", m.tool_count);
    emit_json_metric_i64("hash_count", m.hash_count);

    let mut counts: Vec<i64> = Vec::new();
    counts.push(m.manifest_version);
    counts.push(m.tool_count);
    counts.push(m.hash_count);
    emit_json_array_i64("toolchain_counts", counts, 1, 3);
    return 0;
}

fn capsule_suite_manifest_print(m: &CapsuleSuiteManifest) -> i64 {
    print("capsule suite manifest:");
    print("suite:");
    print(m.suite_name);
    print("nucleor_surface:");
    print(m.nucleor_surface);
    print("policy:");
    print(policy_name(m.policy));
    print("manifest_version:");
    print_int(m.manifest_version);
    print("numeric_case_count:");
    print_int(m.numeric_case_count);
    print("capsule_case_count:");
    print_int(m.capsule_case_count);
    print("total_report_count:");
    print_int(m.total_report_count);
    return 0;
}

fn capsule_suite_manifest_emit_jsonl(case_name: str, m: &CapsuleSuiteManifest) -> i64 {
    emit_json_run_meta(
        case_name,
        m.suite_name,
        m.nucleor_surface,
        "i64",
        1,
        3,
        policy_name(m.policy)
    );
    emit_json_metric_i64("manifest_version", m.manifest_version);
    emit_json_metric_i64("numeric_case_count", m.numeric_case_count);
    emit_json_metric_i64("capsule_case_count", m.capsule_case_count);
    emit_json_metric_i64("total_report_count", m.total_report_count);

    let mut counts: Vec<i64> = Vec::new();
    counts.push(m.numeric_case_count);
    counts.push(m.capsule_case_count);
    counts.push(m.total_report_count);
    emit_json_array_i64("suite_counts", counts, 1, 3);
    return 0;
}

fn capsule_seeded_output_f64(input: &TensorF64, seed: i64) -> TensorF64 {
    let scale: f64 = (seed as f64) * 0.125;
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(input) {
        data.push(input.data[i] * scale + (i as f64));
        i = i + 1;
    };
    return tensor_f64_from_vec(input.shape.rows, input.shape.cols, data);
}

fn capsule_emit_tensor_f64(name: str, t: &TensorF64) -> i64 {
    let mut bits: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(t) {
        bits.push(f64_to_bits(t.data[i]));
        i = i + 1;
    };
    emit_json_array_f64(name, bits, t.shape.rows, t.shape.cols);
    return 0;
}

fn capsule_emit_status(passed: i64) -> i64 {
    emit_json_status(passed);
    return 0;
}

// HON-1: this rod is a contract/manifest surface — no native capsule engine or
// runtime is linked behind it. Machine-checkable honesty probe (mirrors
// gpu_compute_available); it must return 0 until a real native backend lands
// and is asserted ==0 by the facade smoke test.
fn capsule_native_available() -> i64 {
    return 0;
}
