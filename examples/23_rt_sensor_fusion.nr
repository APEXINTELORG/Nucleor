// 23_rt_sensor_fusion.nr — Production-style sensor-fusion
// step combining all the operand-kind shapes the v0.3.51 →
// v0.3.63 codegen-fix arc covered.
//
// What's exercised inline (no lifted-let workarounds —
// natural production form):
//
//   - Struct field access on a struct instance (V3.x)
//   - Trait method on struct (Sensor::magnitude, returns f64)
//   - Fixed-array indexing (`imu[0]`, type [f64; 3])
//   - Vec indexing (`samples[i]`, type Vec<f64>)
//   - Fn-call result inline (make_bias())
//   - i64 → f64 cast inline (`(n as f64)`)
//   - Nested binops mixing all of the above
//
// All composed in a single sensor-fusion step that:
//   1. Takes an accelerometer reading [f64; 3] and a velocity V3
//   2. Maintains a recent-sample buffer Vec<f64>
//   3. Computes a magnitude via trait method
//   4. Subtracts a per-sensor bias from a fn call
//   5. Averages over a counted history (cast i64 → f64)
//
// Pre-v0.3.51 every one of these inline forms had at least
// one combination that silently miscomputed or failed
// compilation. Post-v0.3.63 the natural code below produces
// the correct result with no compiler errors.

#[repr(C)]
struct V3 { x: f64, y: f64, z: f64 }

trait Mag {
    fn magnitude(self) -> f64;
}

impl Mag for V3 {
    fn magnitude(self) -> f64 {
        // Inline binop on struct fields (v0.3.53).
        self.x * self.x + self.y * self.y + self.z * self.z
    }
}

// Fn-call result returns f64 (v0.3.54).
fn make_bias() -> f64 { return 0.5; }

// Nested struct on fn-call result (v0.3.58).
fn current_velocity() -> V3 { return V3 { x: 1.0, y: 2.0, z: 3.0 }; }

fn main() -> i32 {
    let imu: [f64; 3] = [0.4, 0.3, 9.8];   // (v0.3.62)
    let mut samples: Vec<f64> = Vec::new();  // (v0.3.55)
    samples.push(0.1);
    samples.push(0.2);
    samples.push(0.3);

    print("Sensor fusion step (v0.3.51-63 production lock):");

    // Pattern 1: trait method on struct + inline f64 binop
    // (v0.3.60 trait method dispatch).
    let v: V3 = V3 { x: 3.0, y: 0.0, z: 4.0 };
    let speed_sq: f64 = v.magnitude();
    print("speed_sq:");
    print_f64(speed_sq);   // 25.0

    // Pattern 2: fixed-array indexing + struct field + cast all
    // inline (v0.3.62 [T;N] + v0.3.53 field + v0.3.61 cast).
    let n: i64 = 3;
    let avg: f64 = (imu[0] + imu[1] + imu[2]) / (n as f64);
    print("imu avg:");
    print_f64(avg);        // 3.5

    // Pattern 3: Vec indexing + fn-call result + chained field
    // (v0.3.55 Vec + v0.3.54 fn-call + v0.3.58 chained).
    let drift: f64 = samples[0] - make_bias() + current_velocity().x;
    print("drift:");
    print_f64(drift);      // 0.1 - 0.5 + 1.0 = 0.6

    // Pattern 4: trait method + fn-call + cast all in one
    // expression (v0.3.60 + v0.3.54 + v0.3.61).
    let weight: f64 = current_velocity().magnitude() / (n as f64);
    print("weighted velocity magnitude:");
    print_f64(weight);     // 14 / 3 = 4.666...

    return 0;
}
