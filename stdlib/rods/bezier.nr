// rods/bezier — Bezier curve evaluation in 2-D and 3-D via the
// numerically-stable de Casteljau recurrence. Works for arbitrary
// degree.
//
// Use:
//   - Path authoring (UI handle widgets).
//   - Bezier-spline trajectory generators.
//   - Smooth interpolation between a handful of waypoints (more
//     local control than a cubic spline through the same points).
//
// Workflow:
//
//   import "stdlib/rods/bezier.nr"
//
//   // 2-D: ctrl_xy is double[2*N] interleaved (x,y)
//   let xy: [2]double;
//   let _ = bezier_eval_2d(ctrl_xy_ptr, N, t_b, f64_ptr(&xy[0]));
//
//   // 3-D: ctrl_xyz is double[3*N] interleaved (x,y,z)
//   let xyz: [3]double;
//   let _ = bezier_eval_3d(ctrl_xyz_ptr, N, t_b, f64_ptr(&xyz[0]));
//
// Limitations (rational Bezier / NURBS / arc-length
// reparameterization land in v0.6 if needed):
// - Polynomial Bezier only.
// - Caller-supplied parameter t (no arc-length reparam).
// - Numerically stable up to ~20 control points; higher degrees
//   prefer piecewise cubic Bezier or B-spline.
//
// See `stdlib/runtime/bezier_rt.c`.
#cfile "../runtime/bezier_rt.c"

extern fn nuc_bezier_eval_2d(ctrl_xy_ptr: i64, n_ctrl_: i64,
    t_b: i64, out_ptr: i64) -> i64;
extern fn nuc_bezier_eval_3d(ctrl_xyz_ptr: i64, n_ctrl_: i64,
    t_b: i64, out_ptr: i64) -> i64;

// Sample 2-D Bezier curve at parameter t in [0,1]. Writes 2 f64
// values (x, y) to `out_ptr`. Returns 1 on success, 0 on bad input.
fn bezier_eval_2d(ctrl_xy_ptr: i64, n_ctrl_: i64,
    t_b: i64, out_ptr: i64) -> i64
{
    return nuc_bezier_eval_2d(ctrl_xy_ptr, n_ctrl_, t_b, out_ptr);
}

// Sample 3-D Bezier curve at parameter t in [0,1]. Writes 3 f64
// values (x, y, z) to `out_ptr`. Returns 1 on success, 0 on bad input.
fn bezier_eval_3d(ctrl_xyz_ptr: i64, n_ctrl_: i64,
    t_b: i64, out_ptr: i64) -> i64
{
    return nuc_bezier_eval_3d(ctrl_xyz_ptr, n_ctrl_, t_b, out_ptr);
}
