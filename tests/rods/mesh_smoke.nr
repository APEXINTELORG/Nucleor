// rods/mesh — verify rod wrapper compiles + links (v0.2.124 orphan)
import "stdlib/rods/mesh.nr"

fn main() -> i64 {
    let m: i64 = mesh_rect(4, 4, 1, 1);
    if m == 0 { print("FAIL mesh_rect"); return 1; };
    let nn: i64 = mesh_n_nodes(m);
    if nn <= 0 { print("FAIL mesh_n_nodes"); return 1; };
    print("OK mesh_smoke");
    return 0;
}
