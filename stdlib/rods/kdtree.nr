// =====================================================
// rods/kdtree — k-d tree spatial index
// =====================================================
// Import: import "stdlib/rods/kdtree.nr"
// =====================================================

#cfile "../runtime/kdtree_rt.c"

extern fn nuc_kd_build(points: i64, n: i64, dim: i64) -> i64;
extern fn nuc_kd_nearest(tree: i64, query: i64, k: i64) -> i64;
extern fn nuc_kd_range_search(tree: i64, center: i64, radius: i64) -> i64;
extern fn nuc_kd_free(tree: i64);

fn kd_build(points: i64, n: i64, dim: i64) -> i64 { return nuc_kd_build(points, n, dim); }
fn kd_nearest(tree: i64, query: i64, k: i64) -> i64 { return nuc_kd_nearest(tree, query, k); }
fn kd_range(tree: i64, center: i64, radius: i64) -> i64 { return nuc_kd_range_search(tree, center, radius); }
fn kd_free(tree: i64) { nuc_kd_free(tree); }
