// helper1 ROBO-6 -- URDF parent/child topology smoke.
//
// Locks Phase 1 behavior:
// - parent/child link metadata is parsed and queryable;
// - serial topology can be reconstructed even when joints are out of order;
// - branched topology is detected and refused by serial FK export instead of
//   being silently flattened.

import "stdlib/rods/urdf.nr"
import "stdlib/rods/string_type.nr"
import "stdlib/rods/f64_buffer.nr"

fn close(a: f64, b: f64, eps: f64) -> i64 {
    let d: f64 = a - b;
    let ad: f64 = if d < 0.0 { 0.0 - d } else { d };
    if ad < eps { return 1; };
    return 0;
}

fn check_branch_refused() -> i64 {
    let s: i64 = string_of("<robot><joint name='left' type='fixed'><parent link='base'/><child link='left'/><origin xyz='1 0 0' rpy='0 0 0'/></joint><joint name='right' type='fixed'><parent link='base'/><child link='right'/><origin xyz='0 1 0' rpy='0 0 0'/></joint></robot>");
    let u: i64 = urdf_new();
    if urdf_parse(u, string_cstr(s)) != 2 { urdf_free(u); string_drop(s); return 1; };
    if urdf_has_topology(u) != 1 { urdf_free(u); string_drop(s); return 2; };
    if urdf_has_branching(u) != 1 { urdf_free(u); string_drop(s); return 4; };
    if urdf_topology_is_serial(u) != 0 { urdf_free(u); string_drop(s); return 8; };
    if urdf_joint_child_count(u, 0 - 1) != 2 { urdf_free(u); string_drop(s); return 16; };
    if urdf_joint_parent_index(u, 0) != (0 - 1) { urdf_free(u); string_drop(s); return 32; };
    if urdf_joint_parent_index(u, 1) != (0 - 1) { urdf_free(u); string_drop(s); return 64; };
    if urdf_to_fk_chain(u) != 0 { urdf_free(u); string_drop(s); return 128; };
    urdf_free(u);
    string_drop(s);
    return 0;
}

fn check_out_of_order_serial_fk() -> i64 {
    let s: i64 = string_of("<robot><joint name='j1' type='fixed'><parent link='link1'/><child link='link2'/><origin xyz='0 2 0' rpy='0 0 0'/></joint><joint name='j0' type='fixed'><parent link='base'/><child link='link1'/><origin xyz='1 0 0' rpy='0 0 0'/></joint></robot>");
    let u: i64 = urdf_new();
    if urdf_parse(u, string_cstr(s)) != 2 { urdf_free(u); string_drop(s); return 256; };
    if urdf_has_topology(u) != 1 { urdf_free(u); string_drop(s); return 512; };
    if urdf_has_branching(u) != 0 { urdf_free(u); string_drop(s); return 1024; };
    if urdf_topology_is_serial(u) != 1 { urdf_free(u); string_drop(s); return 2048; };
    if urdf_joint_parent_index(u, 0) != 1 { urdf_free(u); string_drop(s); return 4096; };
    if urdf_joint_parent_index(u, 1) != (0 - 1) { urdf_free(u); string_drop(s); return 8192; };
    if urdf_joint_child_count(u, 1) != 1 { urdf_free(u); string_drop(s); return 16384; };

    let ch: i64 = urdf_to_fk_chain(u);
    if ch == 0 { urdf_free(u); string_drop(s); return 32768; };
    let vars: i64 = f64_buf_new(2);
    f64_buf_set(vars, 0, 0.0);
    f64_buf_set(vars, 1, 0.0);
    if fk_chain_update(ch, f64_buf_ptr(vars)) != 0 {
        f64_buf_free(vars); fk_chain_free(ch); urdf_free(u); string_drop(s); return 65536;
    };
    if close(fk_chain_link_pos_x_f64(ch, 0), 1.0, 0.000001) != 1 {
        f64_buf_free(vars); fk_chain_free(ch); urdf_free(u); string_drop(s); return 131072;
    };
    if close(fk_chain_link_pos_y_f64(ch, 1), 2.0, 0.000001) != 1 {
        f64_buf_free(vars); fk_chain_free(ch); urdf_free(u); string_drop(s); return 262144;
    };
    if close(fk_chain_link_pos_x_f64(ch, 1), 1.0, 0.000001) != 1 {
        f64_buf_free(vars); fk_chain_free(ch); urdf_free(u); string_drop(s); return 524288;
    };
    f64_buf_free(vars);
    fk_chain_free(ch);
    urdf_free(u);
    string_drop(s);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_branch_refused();
    fails = fails + check_out_of_order_serial_fk();
    return fails;
}
