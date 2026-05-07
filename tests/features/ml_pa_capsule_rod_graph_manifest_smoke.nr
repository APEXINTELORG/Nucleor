import "stdlib/rods/ml/capsule_facade.nr"

fn main() -> i32 {
    let manifest: CapsuleRodGraphManifest = capsule_rod_graph_manifest(
        "capsule_rod_graph_manifest_smoke",
        "nucleor_ml_suite",
        "nuc::capsule::rod_graph_manifest",
        "jsonl",
        "stdlib/rods/jsonl.nr",
        "evidence_emitter",
        policy_strict(),
        1,
        1,
        1
    );
    capsule_rod_graph_manifest_print(&manifest);
    capsule_rod_graph_manifest_emit_jsonl(&manifest);
    capsule_emit_status(1);
    return 0;
}
