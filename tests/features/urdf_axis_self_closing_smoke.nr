// Audit CRIT-LAYER9B-001 / HIGH-LAYER9B-007: URDF joints without an
// explicit axis default to the URDF x-axis, and self-closing joint tags are
// parsed as one joint instead of corrupting the scan.

import "stdlib/rods/urdf.nr"
import "stdlib/rods/string_type.nr"

fn close(a: f64, b: f64, eps: f64) -> i64 {
    let d: f64 = a - b;
    let ad: f64 = if d < 0.0 { 0.0 - d } else { d };
    if ad < eps { return 1; };
    return 0;
}

fn check_axis_x_default() -> i64 {
    let src: i64 = string_of("<robot><joint name='j0' type='revolute'><parent link='base'/><child link='tip'/></joint></robot>");
    let u: i64 = urdf_new();
    if urdf_parse(u, string_cstr(src)) != 1 { urdf_free(u); string_drop(src); return 1; };
    let ax: f64 = f64_from_bits(urdf_joint_axis(u, 0, 0));
    let ay: f64 = f64_from_bits(urdf_joint_axis(u, 0, 1));
    let az: f64 = f64_from_bits(urdf_joint_axis(u, 0, 2));
    urdf_free(u);
    string_drop(src);
    if close(ax, 1.0, 0.000001) != 1 { return 2; };
    if close(ay, 0.0, 0.000001) != 1 { return 4; };
    if close(az, 0.0, 0.000001) != 1 { return 8; };
    return 0;
}

fn check_self_closing_joint() -> i64 {
    let src: i64 = string_of("<robot><joint name='j0' type='fixed'/><joint name='j1' type='revolute'><axis xyz='0 0 1'/></joint></robot>");
    let u: i64 = urdf_new();
    if urdf_parse(u, string_cstr(src)) != 2 { urdf_free(u); string_drop(src); return 16; };
    let ax0: f64 = f64_from_bits(urdf_joint_axis(u, 0, 0));
    let az1: f64 = f64_from_bits(urdf_joint_axis(u, 1, 2));
    urdf_free(u);
    string_drop(src);
    if close(ax0, 1.0, 0.000001) != 1 { return 32; };
    if close(az1, 1.0, 0.000001) != 1 { return 64; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_axis_x_default();
    fails = fails + check_self_closing_joint();
    return fails;
}
