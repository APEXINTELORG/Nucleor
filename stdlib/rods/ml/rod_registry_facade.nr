// rods/ml/rod_registry_facade — nuc add lockfile contract (pinned rod count, transitive deps, registry count, offline replay)
//
import "stdlib/rods/jsonl.nr"

// rod_registry_facade.nr - rod registry and lockfile manifest surface.
//
// The MVP records the dependency facts needed by `nuc add` and reproducible
// suite packaging: pinned rods, stdlib/local/external split, registry count,
// and offline replay eligibility.

#[repr(C)]
struct RodRegistryManifest {
    suite_name: str,
    lockfile_schema: str,
    resolver_policy: str,
    registry_mode: str,
    rod_count: i64,
    pinned_version_count: i64,
    stdlib_rod_count: i64,
    local_rod_count: i64,
    external_rod_count: i64,
    transitive_dependency_count: i64,
    registry_count: i64,
    offline_reproducible: i64,
    zero_python_runtime: i64
}

fn rod_registry_manifest(
    suite_name: str,
    lockfile_schema: str,
    resolver_policy: str,
    registry_mode: str,
    rod_count: i64,
    pinned_version_count: i64,
    stdlib_rod_count: i64,
    local_rod_count: i64,
    external_rod_count: i64,
    transitive_dependency_count: i64,
    registry_count: i64,
    offline_reproducible: i64,
    zero_python_runtime: i64
) -> RodRegistryManifest {
    return RodRegistryManifest {
        suite_name: suite_name,
        lockfile_schema: lockfile_schema,
        resolver_policy: resolver_policy,
        registry_mode: registry_mode,
        rod_count: rod_count,
        pinned_version_count: pinned_version_count,
        stdlib_rod_count: stdlib_rod_count,
        local_rod_count: local_rod_count,
        external_rod_count: external_rod_count,
        transitive_dependency_count: transitive_dependency_count,
        registry_count: registry_count,
        offline_reproducible: offline_reproducible,
        zero_python_runtime: zero_python_runtime
    };
}

fn rod_registry_manifest_print(m: &RodRegistryManifest) -> i64 {
    print("rod registry manifest:");
    print("suite_name:");
    print(m.suite_name);
    print("lockfile_schema:");
    print(m.lockfile_schema);
    print("resolver_policy:");
    print(m.resolver_policy);
    print("registry_mode:");
    print(m.registry_mode);
    print("rod_count:");
    print_int(m.rod_count);
    print("pinned_version_count:");
    print_int(m.pinned_version_count);
    print("stdlib_rod_count:");
    print_int(m.stdlib_rod_count);
    print("local_rod_count:");
    print_int(m.local_rod_count);
    print("external_rod_count:");
    print_int(m.external_rod_count);
    print("transitive_dependency_count:");
    print_int(m.transitive_dependency_count);
    print("registry_count:");
    print_int(m.registry_count);
    print("offline_reproducible:");
    print_int(m.offline_reproducible);
    print("zero_python_runtime:");
    print_int(m.zero_python_runtime);
    return 0;
}

fn rod_registry_manifest_emit_jsonl(m: &RodRegistryManifest) -> i64 {
    emit_json_run_meta(
        m.suite_name,
        "nucleor_registry",
        "nuc::registry::rod_lock_manifest",
        m.lockfile_schema,
        m.rod_count,
        m.transitive_dependency_count,
        m.resolver_policy
    );
    emit_json_metric_i64("pinned_version_count", m.pinned_version_count);
    emit_json_metric_i64("stdlib_rod_count", m.stdlib_rod_count);
    emit_json_metric_i64("local_rod_count", m.local_rod_count);
    emit_json_metric_i64("external_rod_count", m.external_rod_count);
    emit_json_metric_i64("registry_count", m.registry_count);
    emit_json_metric_i64("offline_reproducible", m.offline_reproducible);
    emit_json_metric_i64("zero_python_runtime", m.zero_python_runtime);
    return 0;
}

fn rod_registry_manifest_emit_status(passed: i64) -> i64 {
    emit_json_status(passed);
    return 0;
}

// HON-1: this rod is a contract/manifest surface — no native rod_registry engine or
// runtime is linked behind it. Machine-checkable honesty probe (mirrors
// gpu_compute_available); it must return 0 until a real native backend lands
// and is asserted ==0 by the facade smoke test.
fn rod_registry_native_available() -> i64 {
    return 0;
}
