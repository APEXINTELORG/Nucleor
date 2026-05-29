import "stdlib/rods/ml/cli_facade.nr"

fn main() -> i64 {
    let manifest = cli_manifest(
        "nucleor_ml_suite",
        "nuc",
        "single_binary_plus_rods",
        "nuc_cli_v0",
        8,
        5,
        2,
        1,
        1,
        1,
        1,
        0
    );

    cli_manifest_print(&manifest);
    cli_manifest_emit_jsonl(&manifest);
    cli_manifest_emit_status(1);
    if cli_native_available() != 0 { panic("cli_facade falsely advertises a native backend"); };
    return 0;
}
