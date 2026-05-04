// v0.7.94 RFC-0061 Tier 2 Phase A smoke fixture — graph render
// formatters. Builds a 3-node directed graph with 3 edges
// (0->1, 1->2, 2->0) and verifies each format includes the
// expected substrings.
import "stdlib/rods/graph.nr"
import "stdlib/rods/complex.nr"
import "stdlib/rods/graph_render.nr"

fn main() -> i64 {
    let g: i64 = graph_new(3);
    graph_add_edge(g, 0, 1, f64_from_int(2));
    graph_add_edge(g, 1, 2, f64_from_int(3));
    graph_add_edge(g, 2, 0, f64_from_int(1));

    let names: Vec<str> = Vec::new();
    names.push("alpha");
    names.push("beta");
    names.push("gamma");

    // Text format includes adjacency lines.
    let txt: str = graph_render_text(g, names);
    if str_contains(txt, "alpha:") == 0 { graph_free(g); return 1; };
    if str_contains(txt, "beta") == 0 { graph_free(g); return 2; };

    // JSON format includes "nodes" + "edges" keys.
    let j: str = graph_render_json(g, names);
    if str_contains(j, "\"nodes\"") == 0 { graph_free(g); return 3; };
    if str_contains(j, "\"edges\"") == 0 { graph_free(g); return 4; };
    if str_contains(j, "\"alpha\"") == 0 { graph_free(g); return 5; };

    // DOT format starts with `digraph` and contains arrow.
    let d: str = graph_render_dot(g, names);
    if str_contains(d, "digraph") == 0 { graph_free(g); return 6; };
    if str_contains(d, "->") == 0 { graph_free(g); return 7; };

    // Mermaid format starts with `graph TD` and contains -->.
    let mm: str = graph_render_mermaid(g, names);
    if str_contains(mm, "graph TD") == 0 { graph_free(g); return 8; };
    if str_contains(mm, "-->") == 0 { graph_free(g); return 9; };

    // Format dispatch by ID.
    let txt2: str = graph_render_with_format(g, names, graph_render_format_text());
    if str_contains(txt2, "alpha:") == 0 { graph_free(g); return 10; };

    let dot2: str = graph_render_with_format(g, names, graph_render_format_dot());
    if str_contains(dot2, "digraph") == 0 { graph_free(g); return 11; };

    // Format-name round trip.
    if graph_render_format_id("dot") != graph_render_format_dot() { graph_free(g); return 12; };
    if str_eq(graph_render_format_name(4), "mermaid") == 0 { graph_free(g); return 13; };

    // Anonymous-names fallback.
    let anon: Vec<str> = graph_render_anon_names();
    let txt_anon: str = graph_render_text(g, anon);
    if str_contains(txt_anon, "n0:") == 0 { graph_free(g); return 14; };

    graph_free(g);
    return 0;
}
