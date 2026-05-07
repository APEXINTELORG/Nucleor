// rods/ml/lab_facade — nuc lab workbench manifest (deterministic cell graph, viewer counts, agent mounts, port)
//
import "stdlib/rods/jsonl.nr"

// lab_facade.nr - first nuc-lab style workbench manifest surface.
//
// The MVP records the front-door facts for a deterministic workbench session:
// project path, capsule path, runtime mode, cell graph size, mounted viewers,
// agent access, local port, and Python bridge dependency accounting.

#[repr(C)]
struct LabManifest {
    project_name: str,
    workbook_path: str,
    capsule_path: str,
    runtime_mode: str,
    graph_schema: str,
    cell_count: i64,
    data_view_count: i64,
    tensor_view_count: i64,
    plot_count: i64,
    agent_mount_count: i64,
    port: i64,
    deterministic_dag: i64,
    python_bridge_count: i64
}

fn lab_manifest(
    project_name: str,
    workbook_path: str,
    capsule_path: str,
    runtime_mode: str,
    graph_schema: str,
    cell_count: i64,
    data_view_count: i64,
    tensor_view_count: i64,
    plot_count: i64,
    agent_mount_count: i64,
    port: i64,
    deterministic_dag: i64,
    python_bridge_count: i64
) -> LabManifest {
    return LabManifest {
        project_name: project_name,
        workbook_path: workbook_path,
        capsule_path: capsule_path,
        runtime_mode: runtime_mode,
        graph_schema: graph_schema,
        cell_count: cell_count,
        data_view_count: data_view_count,
        tensor_view_count: tensor_view_count,
        plot_count: plot_count,
        agent_mount_count: agent_mount_count,
        port: port,
        deterministic_dag: deterministic_dag,
        python_bridge_count: python_bridge_count
    };
}

fn lab_manifest_view_count(m: &LabManifest) -> i64 {
    return m.data_view_count + m.tensor_view_count + m.plot_count;
}

fn lab_manifest_print(m: &LabManifest) -> i64 {
    print("lab manifest:");
    print("project_name:");
    print(m.project_name);
    print("workbook_path:");
    print(m.workbook_path);
    print("capsule_path:");
    print(m.capsule_path);
    print("runtime_mode:");
    print(m.runtime_mode);
    print("graph_schema:");
    print(m.graph_schema);
    print("cell_count:");
    print_int(m.cell_count);
    print("data_view_count:");
    print_int(m.data_view_count);
    print("tensor_view_count:");
    print_int(m.tensor_view_count);
    print("plot_count:");
    print_int(m.plot_count);
    print("agent_mount_count:");
    print_int(m.agent_mount_count);
    print("port:");
    print_int(m.port);
    print("deterministic_dag:");
    print_int(m.deterministic_dag);
    print("python_bridge_count:");
    print_int(m.python_bridge_count);
    return 0;
}

fn lab_manifest_emit_jsonl(m: &LabManifest) -> i64 {
    emit_json_run_meta(
        m.project_name,
        "nucleor_lab",
        "nuc::lab::manifest",
        m.graph_schema,
        m.cell_count,
        lab_manifest_view_count(m),
        m.runtime_mode
    );
    emit_json_metric_i64("data_view_count", m.data_view_count);
    emit_json_metric_i64("tensor_view_count", m.tensor_view_count);
    emit_json_metric_i64("plot_count", m.plot_count);
    emit_json_metric_i64("agent_mount_count", m.agent_mount_count);
    emit_json_metric_i64("port", m.port);
    emit_json_metric_i64("deterministic_dag", m.deterministic_dag);
    emit_json_metric_i64("python_bridge_count", m.python_bridge_count);
    return 0;
}

fn lab_manifest_emit_status(passed: i64) -> i64 {
    emit_json_status(passed);
    return 0;
}
