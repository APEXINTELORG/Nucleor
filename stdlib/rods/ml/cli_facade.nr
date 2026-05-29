// rods/ml/cli_facade — nuc CLI front-door command contract (new, add, lab, bench, port, capsule, serve, ship)
// Maturity: CONTRACT-ONLY — records manifest/contract metadata; no native engine or runtime is linked behind it. Enforced by cli_native_available()==0 (HON-1).
//
import "stdlib/rods/jsonl.nr"

// cli_facade.nr - unified nuc command-surface manifest.
//
// This is the product front-door contract for the suite. It records which
// command families are expected in the bundled runtime before those commands
// grow into real subcommand implementations.

#[repr(C)]
struct CliManifest {
    suite_name: str,
    binary_name: str,
    distribution_model: str,
    command_schema: str,
    core_command_count: i64,
    capsule_command_count: i64,
    workbench_command_count: i64,
    agent_command_count: i64,
    package_lock_count: i64,
    bundled_runtime: i64,
    zero_python_runtime: i64,
    signed_distribution: i64
}

fn cli_manifest(
    suite_name: str,
    binary_name: str,
    distribution_model: str,
    command_schema: str,
    core_command_count: i64,
    capsule_command_count: i64,
    workbench_command_count: i64,
    agent_command_count: i64,
    package_lock_count: i64,
    bundled_runtime: i64,
    zero_python_runtime: i64,
    signed_distribution: i64
) -> CliManifest {
    return CliManifest {
        suite_name: suite_name,
        binary_name: binary_name,
        distribution_model: distribution_model,
        command_schema: command_schema,
        core_command_count: core_command_count,
        capsule_command_count: capsule_command_count,
        workbench_command_count: workbench_command_count,
        agent_command_count: agent_command_count,
        package_lock_count: package_lock_count,
        bundled_runtime: bundled_runtime,
        zero_python_runtime: zero_python_runtime,
        signed_distribution: signed_distribution
    };
}

fn cli_manifest_print(m: &CliManifest) -> i64 {
    print("cli manifest:");
    print("suite_name:");
    print(m.suite_name);
    print("binary_name:");
    print(m.binary_name);
    print("distribution_model:");
    print(m.distribution_model);
    print("command_schema:");
    print(m.command_schema);
    print("core_command_count:");
    print_int(m.core_command_count);
    print("capsule_command_count:");
    print_int(m.capsule_command_count);
    print("workbench_command_count:");
    print_int(m.workbench_command_count);
    print("agent_command_count:");
    print_int(m.agent_command_count);
    print("package_lock_count:");
    print_int(m.package_lock_count);
    print("bundled_runtime:");
    print_int(m.bundled_runtime);
    print("zero_python_runtime:");
    print_int(m.zero_python_runtime);
    print("signed_distribution:");
    print_int(m.signed_distribution);
    return 0;
}

fn cli_manifest_emit_jsonl(m: &CliManifest) -> i64 {
    emit_json_run_meta(
        m.suite_name,
        "nucleor_cli",
        "nuc::cli::manifest",
        m.command_schema,
        m.core_command_count,
        m.capsule_command_count,
        m.distribution_model
    );
    emit_json_metric_i64("workbench_command_count", m.workbench_command_count);
    emit_json_metric_i64("agent_command_count", m.agent_command_count);
    emit_json_metric_i64("package_lock_count", m.package_lock_count);
    emit_json_metric_i64("bundled_runtime", m.bundled_runtime);
    emit_json_metric_i64("zero_python_runtime", m.zero_python_runtime);
    emit_json_metric_i64("signed_distribution", m.signed_distribution);
    return 0;
}

fn cli_manifest_emit_status(passed: i64) -> i64 {
    emit_json_status(passed);
    return 0;
}

// HON-1: this rod is a contract/manifest surface — no native cli engine or
// runtime is linked behind it. Machine-checkable honesty probe (mirrors
// gpu_compute_available); it must return 0 until a real native backend lands
// and is asserted ==0 by the facade smoke test.
fn cli_native_available() -> i64 {
    return 0;
}
