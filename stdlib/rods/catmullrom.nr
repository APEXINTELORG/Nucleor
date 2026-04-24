// rods/catmullrom — Catmull-Rom spline evaluation in 2-D and 3-D.
//
// Interpolating spline that passes through every control point.
// C¹ continuous, locally controlled (changing one waypoint only
// affects two segments). Centripetal parameterization (alpha=0.5)
// avoids loops/cusps from non-uniform spacing.
//
// alpha guide:
//   0.0 → uniform    (classic; can self-intersect)
//   0.5 → centripetal (recommended; safe)
//   1.0 → chordal    (smoother but can overshoot)
//
// Workflow:
//
//   import "stdlib/rods/catmullrom.nr"
//
//   // 2-D: ctrl_xy = double[2*N], N >= 4
//   let xy: [2]double;
//   let _ = catmullrom_eval_2d(ctrl_xy_ptr, N,
//                                t_global_b, alpha_b,
//                                f64_ptr(&xy[0]));
//
//   // 3-D: ctrl_xyz = double[3*N]
//   let xyz: [3]double;
//   let _ = catmullrom_eval_3d(ctrl_xyz_ptr, N,
//                                t_global_b, alpha_b,
//                                f64_ptr(&xyz[0]));
//
// `t_global` is in `[0, N-3]`. The integer part picks the segment
// between control points (i+1, i+2); fractional part is the local
// parameter within that segment.
//
// **Limitations** (variant tangent scaling / arc-length reparam
// land in v0.6 if needed):
// - Requires N >= 4 (segment between i+1 and i+2 needs neighbors
//   i and i+3).
// - Caller-supplied parameter; no arc-length reparam.
//
// See `stdlib/runtime/catmullrom_rt.c`.
#cfile "../runtime/catmullrom_rt.c"

extern fn nuc_catmullrom_eval_2d(ctrl_xy_ptr: i64, n_ctrl_: i64,
    t_global_b: i64, alpha_b: i64, out_ptr: i64) -> i64;
extern fn nuc_catmullrom_eval_3d(ctrl_xyz_ptr: i64, n_ctrl_: i64,
    t_global_b: i64, alpha_b: i64, out_ptr: i64) -> i64;

// Sample 2-D Catmull-Rom at t_global. Writes (x, y) to out_ptr.
fn catmullrom_eval_2d(ctrl_xy_ptr: i64, n_ctrl_: i64,
    t_global_b: i64, alpha_b: i64, out_ptr: i64) -> i64
{
    return nuc_catmullrom_eval_2d(ctrl_xy_ptr, n_ctrl_, t_global_b, alpha_b, out_ptr);
}

// Sample 3-D Catmull-Rom at t_global. Writes (x, y, z) to out_ptr.
fn catmullrom_eval_3d(ctrl_xyz_ptr: i64, n_ctrl_: i64,
    t_global_b: i64, alpha_b: i64, out_ptr: i64) -> i64
{
    return nuc_catmullrom_eval_3d(ctrl_xyz_ptr, n_ctrl_, t_global_b, alpha_b, out_ptr);
}
