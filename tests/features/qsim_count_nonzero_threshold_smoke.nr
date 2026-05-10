// Audit HIGH-LAYER9B-004: rods_count_nonzero takes an amplitude threshold;
// it must compare probability mass against threshold^2.

import "stdlib/rods/quantum.nr"

fn main() -> i64 {
    let sv: i64 = qsim_init(1);
    if sv == 0 { return 1; };
    qsim_h(sv, 0);

    let count_at_point_six: i64 = rods_count_nonzero(sv, f64(0, 600000));
    if count_at_point_six != 2 { return 2; };

    let count_at_point_eight: i64 = rods_count_nonzero(sv, f64(0, 800000));
    if count_at_point_eight != 0 { return 4; };
    return 0;
}
