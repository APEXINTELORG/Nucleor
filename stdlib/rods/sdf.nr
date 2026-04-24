// rods/sdf — 2D Signed Distance Field on a regular grid.
//
// Stores a distance field `φ(x, y)` discretized on a `W × H` grid
// with cell size `dx` and world origin `(ox, oy)`. By convention,
// `φ > 0` outside obstacles, `φ < 0` inside, `φ = 0` on the
// boundary.
//
// Queries between cell centers use bilinear interpolation;
// gradients use the same bilinear field via partial derivatives
// (piecewise constant within each cell).
//
// Foundation for:
//   - Continuous collision queries: `φ(x, y) ≤ 0` ⇔ inside obstacle.
//   - Repulsive potential fields (`apf.nr`-style): force `∝ −∇φ`
//     scaled by some monotone function of `φ`.
//   - Cost-aware planning: feed `φ` into A* / D* Lite as a
//     traversal-cost field that softens around obstacle boundaries.
//   - Distance-aware MPC stage cost to keep the robot away from
//     obstacles.
//
// Workflow:
//
//   import "stdlib/rods/sdf.nr"
//
//   let h = sdf_new(W, H, dx_b, ox_b, oy_b);
//
//   // Either: fill cells manually
//   sdf_set(h, ix, iy, value_b);
//
//   // Or: compute from a list of circular obstacles. centers_ptr is
//   // double[n_obs][2] (cx, cy per obstacle); radii_ptr is double[n_obs].
//   sdf_compute_from_circles(h, centers_ptr, radii_ptr, n_obs);
//
//   // Query
//   let d_b = sdf_query(h, x_b, y_b);
//   sdf_gradient(h, x_b, y_b, gx_out_ptr, gy_out_ptr);
//
//   sdf_free(h);
//
// **Limitations** (3D / Eikonal sweep / fast-marching land in v0.6
// if needed):
// - 2D only.
// - Only built-in shape primitive is circles. For arbitrary
//   polygons, fill cells manually (or run an external Eikonal sweep
//   and copy the result in).
// - Bilinear interpolation only.
//
// See `stdlib/runtime/sdf_rt.c`.
#cfile "../runtime/sdf_rt.c"

extern fn nuc_sdf_new(W: i64, H: i64, dx_b: i64, ox_b: i64, oy_b: i64) -> i64;
extern fn nuc_sdf_width(h: i64) -> i64;
extern fn nuc_sdf_height(h: i64) -> i64;
extern fn nuc_sdf_dx(h: i64) -> i64;
extern fn nuc_sdf_set(h: i64, ix: i64, iy: i64, v_b: i64);
extern fn nuc_sdf_get(h: i64, ix: i64, iy: i64) -> i64;
extern fn nuc_sdf_query(h: i64, x_b: i64, y_b: i64) -> i64;
extern fn nuc_sdf_gradient(h: i64, x_b: i64, y_b: i64,
    gx_out_ptr: i64, gy_out_ptr: i64);
extern fn nuc_sdf_compute_from_circles(h: i64,
    centers_ptr: i64, radii_ptr: i64, n_obs: i64);
extern fn nuc_sdf_free(h: i64);

// Create a W × H grid with cell size `dx` and world origin
// `(ox, oy)`. All cells initialize to `+1e18` (everything is free).
fn sdf_new(W: i64, H: i64, dx_b: i64, ox_b: i64, oy_b: i64) -> i64 {
    return nuc_sdf_new(W, H, dx_b, ox_b, oy_b);
}

fn sdf_width(h: i64)  -> i64 { return nuc_sdf_width(h); }
fn sdf_height(h: i64) -> i64 { return nuc_sdf_height(h); }
fn sdf_dx(h: i64)     -> i64 { return nuc_sdf_dx(h); }

// Set / read the φ value at integer grid cell (ix, iy).
fn sdf_set(h: i64, ix: i64, iy: i64, v_b: i64) { nuc_sdf_set(h, ix, iy, v_b); }
fn sdf_get(h: i64, ix: i64, iy: i64) -> i64 { return nuc_sdf_get(h, ix, iy); }

// Bilinear-interpolated φ at world (x, y). Out-of-grid queries are
// clamped to the boundary cell.
fn sdf_query(h: i64, x_b: i64, y_b: i64) -> i64 {
    return nuc_sdf_query(h, x_b, y_b);
}

// Bilinear-interpolated gradient (∂φ/∂x, ∂φ/∂y) at (x, y); writes
// to caller-allocated double pointers.
fn sdf_gradient(h: i64, x_b: i64, y_b: i64, gx_out_ptr: i64, gy_out_ptr: i64) {
    nuc_sdf_gradient(h, x_b, y_b, gx_out_ptr, gy_out_ptr);
}

// Populate cells from a list of circular obstacles.
// `centers_ptr` is `double[n_obs * 2]` (cx, cy interleaved);
// `radii_ptr`   is `double[n_obs]`.
fn sdf_compute_from_circles(h: i64, centers_ptr: i64, radii_ptr: i64, n_obs: i64) {
    nuc_sdf_compute_from_circles(h, centers_ptr, radii_ptr, n_obs);
}

fn sdf_free(h: i64) { nuc_sdf_free(h); }
