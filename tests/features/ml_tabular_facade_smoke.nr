import "stdlib/rods/ml/tabular_facade.nr"

fn main() -> i64 {
    let manifest = tabular_manifest(
        "nuc_tabular_engine_v0",
        "tiny_orders_table",
        "order_id_i64_group_i64_value_f64",
        "csv_arrow_ipc_parquet_delta_manifest",
        "lazy_pushdown_vectorized_zero_python",
        "dataframe_lazy_sql_scan_join_groupby",
        4,
        5,
        3,
        6,
        7,
        1,
        1,
        4,
        2,
        2,
        3,
        0,
        1
    );

    tabular_manifest_print(&manifest);
    tabular_manifest_emit_jsonl(&manifest);
    tabular_manifest_emit_status(1);
    return 0;
}
