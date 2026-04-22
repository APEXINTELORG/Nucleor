// rods/mesh — 2D rectangular finite-element meshes + Laplacian assembly + VTK output.
#cfile "../runtime/mesh_rt.c"

extern fn nuc_mesh_rect(Nx: i64, Ny: i64, Lx: i64, Ly: i64) -> i64;
extern fn nuc_mesh_n_nodes(h: i64) -> i64;
extern fn nuc_mesh_n_elements(h: i64) -> i64;
extern fn nuc_mesh_node_x(h: i64, id: i64) -> i64;
extern fn nuc_mesh_node_y(h: i64, id: i64) -> i64;
extern fn nuc_mesh_elem_node(h: i64, elem_id: i64, local: i64) -> i64;
extern fn nuc_mesh_is_boundary(h: i64, node_id: i64) -> i64;
extern fn nuc_mesh_boundary_nodes(h: i64) -> i64;
extern fn nuc_mesh_assemble_laplacian(h: i64) -> i64;
extern fn nuc_mesh_save_vtk(h: i64, field: i64, path: str);
extern fn nuc_mesh_free(h: i64);

fn mesh_rect(Nx: i64, Ny: i64, Lx: i64, Ly: i64) -> i64 { return nuc_mesh_rect(Nx, Ny, Lx, Ly); }
fn mesh_n_nodes(h: i64) -> i64 { return nuc_mesh_n_nodes(h); }
fn mesh_n_elements(h: i64) -> i64 { return nuc_mesh_n_elements(h); }
fn mesh_node_x(h: i64, id: i64) -> i64 { return nuc_mesh_node_x(h, id); }
fn mesh_node_y(h: i64, id: i64) -> i64 { return nuc_mesh_node_y(h, id); }
fn mesh_elem_node(h: i64, elem: i64, local: i64) -> i64 { return nuc_mesh_elem_node(h, elem, local); }
fn mesh_is_boundary(h: i64, node: i64) -> i64 { return nuc_mesh_is_boundary(h, node); }
fn mesh_boundary_nodes(h: i64) -> i64 { return nuc_mesh_boundary_nodes(h); }
fn mesh_assemble_laplacian(h: i64) -> i64 { return nuc_mesh_assemble_laplacian(h); }
fn mesh_save_vtk(h: i64, field: i64, path: str) { nuc_mesh_save_vtk(h, field, path); }
fn mesh_free(h: i64) { nuc_mesh_free(h); }
