// v0.8.212 stdlib/rods/mesh.nr first test coverage.
//
// 2-D rectangular FEM mesh + boundary detection + Laplacian
// assembly + VTK output. Pre-v0.8.212: zero coverage.
//
// Builds a 2×2 cell mesh on the unit square [0,1] × [0,1].
//
//   Layout (idx = j*(Nx+1) + i):
//     6---7---8     y=1
//     |   |   |
//     3---4---5     y=0.5
//     |   |   |
//     0---1---2     y=0
//
//   Nx=Ny=2 → 9 nodes, 2*Nx*Ny = 8 triangles
//   Boundary = {0,1,2,3,5,6,7,8} (8 nodes); interior = {4}
//
// Locks four invariants:
//
//   1. Node + element counts — 9 nodes, 8 triangles.
//   2. Corner coordinates — node 0 at (0,0), node 8 at (1,1).
//   3. Boundary classification — corner 0 is boundary; center
//      node 4 (at (0.5, 0.5)) is interior.
//   4. Triangle has 3 distinct nodes — element 0's three local
//      vertices are pairwise distinct (no degenerate triangles).
//
// Expected: rc=0.

import "stdlib/rods/mesh.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_counts() -> i64 {
    let m: i64 = mesh_rect(2, 2, f64_to_bits(1.0), f64_to_bits(1.0));
    if mesh_n_nodes(m) != 9 { mesh_free(m); return 1; };
    if mesh_n_elements(m) != 8 { mesh_free(m); return 2; };
    mesh_free(m);
    return 0;
}

fn check_corner_coords() -> i64 {
    let m: i64 = mesh_rect(2, 2, f64_to_bits(1.0), f64_to_bits(1.0));
    if close(mesh_node_x(m, 0), f64_to_bits(0.0), 1e-12) != 1 { mesh_free(m); return 4; };
    if close(mesh_node_y(m, 0), f64_to_bits(0.0), 1e-12) != 1 { mesh_free(m); return 8; };
    if close(mesh_node_x(m, 8), f64_to_bits(1.0), 1e-12) != 1 { mesh_free(m); return 16; };
    if close(mesh_node_y(m, 8), f64_to_bits(1.0), 1e-12) != 1 { mesh_free(m); return 32; };
    mesh_free(m);
    return 0;
}

fn check_boundary_classification() -> i64 {
    let m: i64 = mesh_rect(2, 2, f64_to_bits(1.0), f64_to_bits(1.0));
    if mesh_is_boundary(m, 0) != 1 { mesh_free(m); return 64; };
    if mesh_is_boundary(m, 4) != 0 { mesh_free(m); return 128; };
    if mesh_is_boundary(m, 8) != 1 { mesh_free(m); return 256; };
    mesh_free(m);
    return 0;
}

fn check_triangle_distinct() -> i64 {
    let m: i64 = mesh_rect(2, 2, f64_to_bits(1.0), f64_to_bits(1.0));
    let v0: i64 = mesh_elem_node(m, 0, 0);
    let v1: i64 = mesh_elem_node(m, 0, 1);
    let v2: i64 = mesh_elem_node(m, 0, 2);
    mesh_free(m);
    if v0 == v1 { return 512; };
    if v1 == v2 { return 1024; };
    if v0 == v2 { return 2048; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_counts();
    fails = fails + check_corner_coords();
    fails = fails + check_boundary_classification();
    fails = fails + check_triangle_distinct();
    return fails;
}
