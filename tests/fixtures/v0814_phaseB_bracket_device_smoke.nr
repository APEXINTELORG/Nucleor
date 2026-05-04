// v0.8.14 Phase B step-3 smoke fixture — extract device name
// from `@photonic[device=...]` and `@neuromorphic[device=...]`
// bracket-form attributes. Build emits:
//   audit: @photonic fns in build: 2
//   audit:   photonic devices: lightmatter_x1; psiquantum_classical
//   audit: @neuromorphic fns in build: 2
//   audit:   neuromorphic devices: loihi2; northpole
// rc = 4.

@photonic[device=lightmatter_x1]
fn optical_layer_a() -> i64 { return 1; }

@photonic[device=psiquantum_classical]
fn optical_layer_b() -> i64 { return 1; }

@neuromorphic[device=loihi2]
fn snn_a() -> i64 { return 1; }

@neuromorphic[device=northpole]
fn snn_b() -> i64 { return 1; }

fn main() -> i64 {
    return optical_layer_a() + optical_layer_b() + snn_a() + snn_b();
}
