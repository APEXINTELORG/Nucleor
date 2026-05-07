// rods/ml/ncap_facade — .ncap package manifest contract (route count, evidence count, source hashes, signature state)
//
import "stdlib/rods/jsonl.nr"

// ncap_facade.nr - package-level capsule manifest surface.
//
// This is the deployment/reproducibility bridge between parity evidence,
// capsule records, and the eventual `nuc serve model.ncap` command.

#[repr(C)]
struct NcapPackageManifest {
    package_name: str,
    schema_name: str,
    model_name: str,
    model_format: str,
    route_count: i64,
    evidence_case_count: i64,
    source_hash_count: i64,
    signed: i64,
    external_backend_count: i64
}

fn ncap_package_manifest(
    package_name: str,
    schema_name: str,
    model_name: str,
    model_format: str,
    route_count: i64,
    evidence_case_count: i64,
    source_hash_count: i64,
    signed: i64,
    external_backend_count: i64
) -> NcapPackageManifest {
    return NcapPackageManifest {
        package_name: package_name,
        schema_name: schema_name,
        model_name: model_name,
        model_format: model_format,
        route_count: route_count,
        evidence_case_count: evidence_case_count,
        source_hash_count: source_hash_count,
        signed: signed,
        external_backend_count: external_backend_count
    };
}

fn ncap_package_manifest_print(m: &NcapPackageManifest) -> i64 {
    print("ncap package manifest:");
    print("package_name:");
    print(m.package_name);
    print("schema_name:");
    print(m.schema_name);
    print("model_name:");
    print(m.model_name);
    print("model_format:");
    print(m.model_format);
    print("route_count:");
    print_int(m.route_count);
    print("evidence_case_count:");
    print_int(m.evidence_case_count);
    print("source_hash_count:");
    print_int(m.source_hash_count);
    print("signed:");
    print_int(m.signed);
    print("external_backend_count:");
    print_int(m.external_backend_count);
    return 0;
}

fn ncap_package_manifest_emit_jsonl(m: &NcapPackageManifest) -> i64 {
    emit_json_run_meta(
        m.package_name,
        "nucleor_capsule",
        "nuc::ncap::package_manifest",
        m.model_format,
        m.evidence_case_count,
        m.route_count,
        "hash_addressed_unsigned"
    );
    emit_json_metric_i64("source_hash_count", m.source_hash_count);
    emit_json_metric_i64("signed", m.signed);
    emit_json_metric_i64("external_backend_count", m.external_backend_count);
    return 0;
}

fn ncap_package_manifest_emit_status(passed: i64) -> i64 {
    emit_json_status(passed);
    return 0;
}
