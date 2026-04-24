// rods/octree — Sparse octree for 3D occupancy grids and broad-
// phase collision pruning.
//
// An octree recursively subdivides 3D space into 8 cube-shaped
// children. For occupancy mapping, each leaf stores a binary
// occupied/free state. For collision pruning, the tree's depth
// gives a hierarchical bounding-volume description of the
// occupied space.
//
// Foundation for:
// - Occupancy-grid SLAM (octomap-style probabilistic mapping
//   from depth sensors).
// - Collision broad-phase: prune motion-plan checks against a
//   precomputed octree of the static environment.
// - Voxel-based collision detection in cluttered scenes.
//
// Workflow:
//   // Root cube centered at (0,0,0), half-size 10m, max depth 6.
//   // Resolution at leaves = 20 / 2^6 = 0.3125 m.
//   let oct = oct_new(f(0.0), f(0.0), f(0.0), f(10.0), 6);
//
//   // Insert occupancy from depth scan.
//   oct_insert(oct, f(2.5), f(1.0), f(0.5), 1);     // 1 = occupied
//   oct_insert(oct, f(3.0), f(1.0), f(0.5), 0);     // 0 = free
//
//   // Query: 0 = unknown, 1 = free, 2 = occupied.
//   let state = oct_query(oct, f(2.5), f(1.0), f(0.5));
//
//   oct_free(oct);
//
// **Limitations** (probabilistic occupancy + log-odds storage +
// raycast-based occupancy carve land in v0.6 if needed):
// - Binary occupancy (occupied / free / unknown).
// - No raycast carve.
// - No prune-on-merge of equal-state siblings.
//
// See `stdlib/runtime/octree_rt.c`.
#cfile "../runtime/octree_rt.c"

extern fn nuc_oct_new(cx_b: i64, cy_b: i64, cz_b: i64,
                      half_size_b: i64, max_depth: i64) -> i64;
extern fn nuc_oct_insert(h: i64, x_b: i64, y_b: i64, z_b: i64, occupied: i64) -> i64;
extern fn nuc_oct_query(h: i64, x_b: i64, y_b: i64, z_b: i64) -> i64;
extern fn nuc_oct_node_count(h: i64) -> i64;
extern fn nuc_oct_leaf_resolution(h: i64) -> i64;
extern fn nuc_oct_free(h: i64);

// Create a new octree with root centered at (cx, cy, cz) and a
// half-side of `half_size`. Total spatial extent is
// `[c - half_size, c + half_size]³`. `max_depth` controls leaf
// resolution: leaves are `2·half_size / 2^max_depth` per side.
fn oct_new(cx_b: i64, cy_b: i64, cz_b: i64,
           half_size_b: i64, max_depth: i64) -> i64 {
    return nuc_oct_new(cx_b, cy_b, cz_b, half_size_b, max_depth);
}

// Insert an occupancy point. `occupied` is 1 for OCCUPIED, 0 for
// FREE. Returns 0 on success, -1 if the point falls outside the
// root cube.
fn oct_insert(h: i64, x_b: i64, y_b: i64, z_b: i64, occupied: i64) -> i64 {
    return nuc_oct_insert(h, x_b, y_b, z_b, occupied);
}

// Query occupancy at a point. Returns:
//   0 = unknown (or outside tree)
//   1 = free
//   2 = occupied
fn oct_query(h: i64, x_b: i64, y_b: i64, z_b: i64) -> i64 {
    return nuc_oct_query(h, x_b, y_b, z_b);
}

fn oct_node_count(h: i64) -> i64 { return nuc_oct_node_count(h); }
fn oct_leaf_resolution(h: i64) -> i64 { return nuc_oct_leaf_resolution(h); }
fn oct_free(h: i64) { nuc_oct_free(h); }
