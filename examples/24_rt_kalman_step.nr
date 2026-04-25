// 24_rt_kalman_step.nr — Kalman-style state update step.
//
// Synthesis of the production-readiness arc (v0.3.51 → v0.3.69).
// Combines the patterns from examples 19-23 with the
// nested-indexing / matrix patterns shipped in v0.3.65-69:
//
//   - 3x3 transition matrix as Vec<Vec<f64>> (v0.3.55 + v0.3.68)
//   - State as Vec<V3> trajectory (v0.3.59)
//   - Position struct with f64 fields (v0.3.53)
//   - Trait method on struct (v0.3.60)
//   - Cast i64 → f64 inline (v0.3.61)
//   - All composed in inline arithmetic without lifted-let
//     workarounds
//
// What it computes:
//   1. Apply transition matrix A to state vector x: x' = A * x
//   2. Compute the velocity-magnitude-squared via trait method
//   3. Compute the cumulative path delta from the trajectory
//
// All four output values are mathematically pinned by T3.45 in
// the verify gate so any regression that breaks composition is
// caught immediately.

trait Mag { fn norm_sq(self) -> f64; }

#[repr(C)]
struct V3 { x: f64, y: f64, z: f64 }

impl Mag for V3 {
    fn norm_sq(self) -> f64 {
        // Inline binop on struct fields (v0.3.53).
        self.x * self.x + self.y * self.y + self.z * self.z
    }
}

fn main() -> i32 {
    print("Kalman-style state update synthesis (v0.3.51-69):");

    // -- 3x3 transition matrix (Vec<Vec<f64>>) -----------------
    let mut A: Vec<Vec<f64>> = Vec::new();
    let mut row1: Vec<f64> = Vec::new(); row1.push(1.0); row1.push(0.0); row1.push(0.5);
    let mut row2: Vec<f64> = Vec::new(); row2.push(0.0); row2.push(1.0); row2.push(0.5);
    let mut row3: Vec<f64> = Vec::new(); row3.push(0.0); row3.push(0.0); row3.push(1.0);
    A.push(row1); A.push(row2); A.push(row3);

    // -- State vector x = (2, 4, 6) ----------------------------
    let mut x: Vec<f64> = Vec::new();
    x.push(2.0); x.push(4.0); x.push(6.0);

    // -- x' = A * x via nested indexing (v0.3.68 closes this) --
    let mut x_next: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < 3 {
        let mut acc: f64 = 0.0;
        let mut j: i64 = 0;
        while j < 3 {
            acc = acc + A[i][j] * x[j];
            j = j + 1;
        };
        x_next.push(acc);
        i = i + 1;
    };
    print("x_next[0]:");
    print_f64(x_next[0]);   // 1*2 + 0*4 + 0.5*6 = 5.0
    print("x_next[1]:");
    print_f64(x_next[1]);   // 0*2 + 1*4 + 0.5*6 = 7.0
    print("x_next[2]:");
    print_f64(x_next[2]);   // 0*2 + 0*4 + 1.0*6 = 6.0

    // -- Velocity magnitude squared via trait method -----------
    let v: V3 = V3 { x: 3.0, y: 4.0, z: 0.0 };
    let speed_sq: f64 = v.norm_sq();
    print("speed_sq:");
    print_f64(speed_sq);    // 25.0

    // -- Trajectory cumulative dist_sq via Vec<V3> indexing ----
    let mut path: Vec<V3> = Vec::new();
    path.push(V3 { x: 0.0, y: 0.0, z: 0.0 });
    path.push(V3 { x: 3.0, y: 4.0, z: 0.0 });
    path.push(V3 { x: 6.0, y: 8.0, z: 0.0 });

    let mut total: f64 = 0.0;
    let mut k: i64 = 1;
    while k < 3 {
        let dx: f64 = path[k].x - path[k - 1].x;
        let dy: f64 = path[k].y - path[k - 1].y;
        let dz: f64 = path[k].z - path[k - 1].z;
        total = total + dx * dx + dy * dy + dz * dz;
        k = k + 1;
    };
    print("path total dist_sq:");
    print_f64(total);       // 50.0

    // -- Cast + inline binop (v0.3.61) -------------------------
    let n: i64 = 3;
    let avg_dist: f64 = total / (n as f64);
    print("avg dist_sq per step:");
    print_f64(avg_dist);    // 50/3 ≈ 16.666...

    return 0;
}
