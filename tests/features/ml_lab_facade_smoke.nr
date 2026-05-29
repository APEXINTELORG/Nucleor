import "stdlib/rods/ml/lab_facade.nr"

fn main() -> i64 {
    let manifest = lab_manifest(
        "tiny_lab_workbook",
        "workbooks/tiny_lab_workbook.nr",
        "runs/tiny_lab_workbook.ncap",
        "local_deterministic",
        "dag_v0",
        5,
        1,
        2,
        1,
        1,
        8790,
        1,
        0
    );

    lab_manifest_print(&manifest);
    lab_manifest_emit_jsonl(&manifest);
    lab_manifest_emit_status(1);
    if lab_native_available() != 0 { panic("lab_facade falsely advertises a native backend"); };
    return 0;
}
