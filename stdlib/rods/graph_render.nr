// rods/graph_render — RFC-0061 Tier 2 Phase A: graph-rendering
// format helpers (text / JSON / DOT / Mermaid).
//
// The full RFC-0061 Tier 2 ship adds a `nuc deps graph` CLI verb
// with `--format=text|json|dot|mermaid` rendering of the build
// dependency graph (~150-200 LOC compiler-tools-side, deferred).
// Phase A (this rod) lands the format-renderer surface adopters
// can use against any graph they've built via
// `stdlib/rods/graph.nr` — Tier 2's CLI verb becomes a thin
// wrapper around these helpers.
//
// Sister to v0.7.78 / v0.7.80 / v0.7.81 / v0.7.86 RFC-0061 Tier 1
// landings.
//
// Workflow:
//
//   import "stdlib/rods/graph_render.nr"
//
//   let g: i64 = graph_new(4);
//   graph_add_edge(g, 0, 1, f64_from_int(2));
//   graph_add_edge(g, 1, 2, f64_from_int(3));
//   ...
//   let names: Vec<str> = ...;  // optional node labels
//   print(graph_render_dot(g, names));
//   print(graph_render_mermaid(g, names));
//
// Format selection by tag (for table-driven render):
//
//   let fmt: i64 = graph_render_format_dot();
//   print(graph_render_with_format(g, names, fmt));

import "stdlib/rods/graph.nr"
import "stdlib/rods/complex.nr"

// =====================================================
// Format tag IDs (stable).
// =====================================================
fn graph_render_format_text()    -> i64 { return 1; }
fn graph_render_format_json()    -> i64 { return 2; }
fn graph_render_format_dot()     -> i64 { return 3; }
fn graph_render_format_mermaid() -> i64 { return 4; }

fn graph_render_format_name(id: i64) -> str {
    if id == 1 { return "text"; };
    if id == 2 { return "json"; };
    if id == 3 { return "dot"; };
    if id == 4 { return "mermaid"; };
    return "unknown";
}

fn graph_render_format_id(name: str) -> i64 {
    if str_eq(name, "text") == 1 { return 1; };
    if str_eq(name, "json") == 1 { return 2; };
    if str_eq(name, "dot") == 1 { return 3; };
    if str_eq(name, "mermaid") == 1 { return 4; };
    return 0;
}

// =====================================================
// Helper: resolve a node index to a display label. If the
// caller passed a `names` Vec<str> with at least `idx+1`
// entries, return its idx-th entry; otherwise return the
// numeric "n<idx>" form.
// =====================================================
fn _graph_render_label(names: Vec<str>, idx: i64) -> str {
    if vec_len(names) > idx { return vec_get(names, idx); };
    return str_concat("n", str_from_int(idx));
}

// Empty Vec<str> for callers who don't care about labels —
// renderers fall back to "n<idx>". Keeps the public API
// uniform (no nullable handle).
fn graph_render_anon_names() -> Vec<str> {
    let v: Vec<str> = Vec::new();
    return v;
}

// =====================================================
// Text format — flat per-node listing of forward edges.
// One line per node, "name: target1 target2 ...".
// =====================================================
fn graph_render_text(g: i64, names: Vec<str>) -> str {
    let n: i64 = graph_render_node_count(g);
    let mut out: str = "";
    let mut u: i64 = 0;
    while u < n {
        let label_u: str = _graph_render_label(names, u);
        out = str_concat(out, label_u);
        out = str_concat(out, ":");
        let outs: Vec<i64> = graph_render_neighbors(g, u);
        let m: i64 = vec_len(outs);
        let mut i: i64 = 0;
        while i < m {
            let v: i64 = vec_get(outs, i);
            out = str_concat(out, " ");
            out = str_concat(out, _graph_render_label(names, v));
            i = i + 1;
        };
        out = str_concat(out, "\n");
        u = u + 1;
    };
    return out;
}

// =====================================================
// JSON format — `{"nodes": ["n0", ...], "edges": [["n0","n1"],...]}`.
// =====================================================
fn graph_render_json(g: i64, names: Vec<str>) -> str {
    let n: i64 = graph_render_node_count(g);
    let mut out: str = "{\"nodes\":[";
    let mut u: i64 = 0;
    while u < n {
        if u > 0 { out = str_concat(out, ","); };
        out = str_concat(out, "\"");
        out = str_concat(out, _graph_render_label(names, u));
        out = str_concat(out, "\"");
        u = u + 1;
    };
    out = str_concat(out, "],\"edges\":[");
    let mut first: i64 = 1;
    u = 0;
    while u < n {
        let outs: Vec<i64> = graph_render_neighbors(g, u);
        let m: i64 = vec_len(outs);
        let mut i: i64 = 0;
        while i < m {
            let v: i64 = vec_get(outs, i);
            if first == 0 { out = str_concat(out, ","); };
            first = 0;
            out = str_concat(out, "[\"");
            out = str_concat(out, _graph_render_label(names, u));
            out = str_concat(out, "\",\"");
            out = str_concat(out, _graph_render_label(names, v));
            out = str_concat(out, "\"]");
            i = i + 1;
        };
        u = u + 1;
    };
    out = str_concat(out, "]}");
    return out;
}

// =====================================================
// DOT (Graphviz) format — `digraph { n0 -> n1; ... }`.
// =====================================================
fn graph_render_dot(g: i64, names: Vec<str>) -> str {
    let n: i64 = graph_render_node_count(g);
    let mut out: str = "digraph G {\n";
    let mut u: i64 = 0;
    while u < n {
        let outs: Vec<i64> = graph_render_neighbors(g, u);
        let m: i64 = vec_len(outs);
        let mut i: i64 = 0;
        while i < m {
            let v: i64 = vec_get(outs, i);
            out = str_concat(out, "  \"");
            out = str_concat(out, _graph_render_label(names, u));
            out = str_concat(out, "\" -> \"");
            out = str_concat(out, _graph_render_label(names, v));
            out = str_concat(out, "\";\n");
            i = i + 1;
        };
        u = u + 1;
    };
    out = str_concat(out, "}\n");
    return out;
}

// =====================================================
// Mermaid format — `graph TD\n  n0 --> n1\n  ...`.
// =====================================================
fn graph_render_mermaid(g: i64, names: Vec<str>) -> str {
    let n: i64 = graph_render_node_count(g);
    let mut out: str = "graph TD\n";
    let mut u: i64 = 0;
    while u < n {
        let outs: Vec<i64> = graph_render_neighbors(g, u);
        let m: i64 = vec_len(outs);
        let mut i: i64 = 0;
        while i < m {
            let v: i64 = vec_get(outs, i);
            out = str_concat(out, "  ");
            out = str_concat(out, _graph_render_label(names, u));
            out = str_concat(out, " --> ");
            out = str_concat(out, _graph_render_label(names, v));
            out = str_concat(out, "\n");
            i = i + 1;
        };
        u = u + 1;
    };
    return out;
}

// =====================================================
// Format dispatch by tag — useful for CLI / table-driven
// callers.
// =====================================================
fn graph_render_with_format(g: i64, names: Vec<str>, format_id: i64) -> str {
    if format_id == 1 { return graph_render_text(g, names); };
    if format_id == 2 { return graph_render_json(g, names); };
    if format_id == 3 { return graph_render_dot(g, names); };
    if format_id == 4 { return graph_render_mermaid(g, names); };
    return graph_render_text(g, names);
}

// =====================================================
// Internal helpers that bridge to the graph_rt.c API. The
// existing graph rod doesn't expose node-count / per-node
// neighbors at the canonical name surface; these wrappers
// delegate via the adjacency-matrix view (added v0.7.81).
// =====================================================
fn graph_render_node_count(g: i64) -> i64 {
    // Recover n by extracting the matrix and computing sqrt(len).
    let m: i64 = graph_to_adjacency_matrix(g);
    let total: i64 = vec_len(m);
    if total <= 0 { return 0; };
    let mut n: i64 = 0;
    while n * n < total { n = n + 1; };
    return n;
}

fn graph_render_neighbors(g: i64, u: i64) -> Vec<i64> {
    let m: i64 = graph_to_adjacency_matrix(g);
    let total: i64 = vec_len(m);
    let mut n: i64 = 0;
    while n * n < total { n = n + 1; };
    let mut out: Vec<i64> = Vec::new();
    if u < 0 || u >= n { return out; };
    // The adjacency-matrix runtime uses f64-bits(1e30) as the
    // "no edge" sentinel. Real edge weights are smaller, so any
    // weight strictly less than 1e30 indicates a real edge.
    let cap_bits: i64 = f64_from_int(1000000);  // 1e6 — well below the 1e30 sentinel
    let mut v: i64 = 0;
    while v < n {
        let w: i64 = vec_get(m, u * n + v);
        if f64_lt(w, cap_bits) == 1 { out.push(v); };
        v = v + 1;
    };
    return out;
}
