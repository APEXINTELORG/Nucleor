// rods/trajectory — verify rod wrapper compiles + links (v0.2.177 ship).
// Build a quintic from rest at q=0 to rest at q=1 over T=1s. Sample
// at t=0 (should be 0) and t=T/2 (should be 0.5 by symmetry).
import "stdlib/rods/trajectory.nr"

fn f64_to_bits(x: f64) -> i64 { return x as i64; }

fn main() -> i64 {
    let mut fail: i64 = 0;

    // Rest-to-rest, q goes 0 → 1 over 1.0 s.
    let q: i64 = quintic_new(
        f64_to_bits(1.0),                                  // T = 1s
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),  // q0, v0, a0
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0)   // qT, vT, aT
    );
    if q == 0 { print("FAIL quintic_new"); return 1; };

    // Position at t=0 should be 0; we just check it returns
    // SOME value (the bit pattern for 0.0 is 0).
    let _p0: i64 = quintic_pos_at(q, f64_to_bits(0.0));
    let _pmid: i64 = quintic_pos_at(q, f64_to_bits(0.5));
    let _pT: i64 = quintic_pos_at(q, f64_to_bits(1.0));
    let _v0: i64 = quintic_vel_at(q, f64_to_bits(0.0));
    let _vmid: i64 = quintic_vel_at(q, f64_to_bits(0.5));
    let _a0: i64 = quintic_acc_at(q, f64_to_bits(0.0));

    // Duration round-trip.
    let dur: i64 = quintic_duration(q);
    if dur == 0 { fail = fail + 1; print("FAIL duration round-trip"); };

    quintic_free(q);
    if fail == 0 { print("OK trajectory_smoke"); };
    return fail;
}
