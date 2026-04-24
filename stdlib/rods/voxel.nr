// rods/voxel — Dense 3D voxel grid for occupancy.
//
// Complements `octree.nr`: dense storage is faster than the
// sparse octree for cluttered scenes (no tree traversal per
// query) but memory-intensive for sparse scenes.
//
// Use cases:
// - Inflated obstacle costmap for dense-environment local
//   planning.
// - Voxel-based collision check in tightly-packed cells.
// - Signed distance field caching for rapid distance queries.
//
// Storage: dense `nx · ny · nz` byte array (1 byte / voxel).
// At 1cm resolution and a 5m cube, that's ~125 MB — fine for
// indoor robotics. For larger scenes, prefer octree.
//
// Workflow:
//   // 5m cube centered at origin, 5cm resolution → 100³ = 1M voxels.
//   let v = vox_new(f(0.0), f(0.0), f(0.0), f(0.05), 100, 100, 100);
//   vox_insert(v, f(1.0), f(0.5), f(0.0), 1);   // 1 = OCCUPIED
//   let state = vox_query(v, f(1.0), f(0.5), f(0.0));   // 0=unknown 1=free 2=occ
//   vox_free(v);
//
// See `stdlib/runtime/voxel_rt.c`.
#cfile "../runtime/voxel_rt.c"

extern fn nuc_vox_new(cx_b: i64, cy_b: i64, cz_b: i64,
    res_b: i64, nx: i64, ny: i64, nz: i64) -> i64;
extern fn nuc_vox_insert(h: i64, x_b: i64, y_b: i64, z_b: i64,
    occupied: i64) -> i64;
extern fn nuc_vox_query(h: i64, x_b: i64, y_b: i64, z_b: i64) -> i64;
extern fn nuc_vox_occupied_count(h: i64) -> i64;
extern fn nuc_vox_total_count(h: i64) -> i64;
extern fn nuc_vox_free(h: i64);

// Construct a voxel grid centered at (cx, cy, cz) with the given
// resolution (voxel side length) and dimensions. Total spatial
// extent: `[c - res·n/2, c + res·n/2]` per axis.
fn vox_new(cx_b: i64, cy_b: i64, cz_b: i64,
    res_b: i64, nx: i64, ny: i64, nz: i64) -> i64
{
    return nuc_vox_new(cx_b, cy_b, cz_b, res_b, nx, ny, nz);
}

// Insert occupancy. occupied = 1 (OCCUPIED) or 0 (FREE). Returns
// 0 on success, -1 if the point is outside the grid.
fn vox_insert(h: i64, x_b: i64, y_b: i64, z_b: i64, occupied: i64) -> i64 {
    return nuc_vox_insert(h, x_b, y_b, z_b, occupied);
}

// Query occupancy: 0 = unknown, 1 = free, 2 = occupied.
fn vox_query(h: i64, x_b: i64, y_b: i64, z_b: i64) -> i64 {
    return nuc_vox_query(h, x_b, y_b, z_b);
}

fn vox_occupied_count(h: i64) -> i64 { return nuc_vox_occupied_count(h); }
fn vox_total_count(h: i64) -> i64 { return nuc_vox_total_count(h); }
fn vox_free(h: i64) { nuc_vox_free(h); }
