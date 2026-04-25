// T3.40 (v0.3.65) — regression test for nested-operand
// indexing: `self.samples[i]` (Vec/array indexing on a
// struct field) miscompiled inside inline f64 binops.
//
// Pre-v0.3.65: v0.3.55's kind==10 branch in binop_float_type
// only handled direct variable indexing (`v[i]` where v is
// kind 3). When the operand was a kind 9 (struct field
// access) — `self.samples[i]` — type info was lost and the
// dispatcher fell through to integer add. v0.3.65 extends
// the kind==10 branch to ALSO handle kind 9 operands by
// walking expr_struct_type → struct_field_type to recover
// the full field type.
//
// Production-relevant: trait method bodies often access
// Vec/array fields by index, sensor windows store
// `samples: Vec<f64>` and bias / weight scalars in the
// same struct, IMU drivers expose `[f64; 3]` fields.
//
// Verify gate (T3.40) asserts the trait method body
// computes the correct weighted average across both
// Vec<f64> field and [f64; N] field shapes.

trait Sample {
    fn weighted(self) -> f64;
}

#[repr(C)]
struct Window { samples: Vec<f64>, weight: f64 }

impl Sample for Window {
    fn weighted(self) -> f64 {
        let n: i64 = 3;
        // self.samples[i] is the production pattern fixed in v0.3.65.
        let sum: f64 = self.samples[0] + self.samples[1] + self.samples[2];
        return self.weight * sum / (n as f64);
    }
}

trait FixedSample {
    fn weighted_arr(self) -> f64;
}

#[repr(C)]
struct ArrWindow { samples: [f64; 3], weight: f64 }

impl FixedSample for ArrWindow {
    fn weighted_arr(self) -> f64 {
        let n: i64 = 3;
        // [f64; N] field indexing in trait body.
        let sum: f64 = self.samples[0] + self.samples[1] + self.samples[2];
        return self.weight * sum / (n as f64);
    }
}

fn main() -> i32 {
    let mut s: Vec<f64> = Vec::new();
    s.push(1.0);
    s.push(2.0);
    s.push(3.0);
    let w: Window = Window { samples: s, weight: 2.0 };
    print_f64(w.weighted());           // 4.0

    let a: ArrWindow = ArrWindow { samples: [4.0, 5.0, 6.0], weight: 0.5 };
    print_f64(a.weighted_arr());       // 2.5
    0
}
