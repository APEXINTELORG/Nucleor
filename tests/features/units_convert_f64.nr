// stdlib/rods/units — `unit_convert_f64` ergonomic wrapper.
//
// v0.4.260: the bits-ABI `unit_convert(val: i64, ...) -> i64`
// is a self-host-friendly footgun — adopters writing
// `let mm: f64 = unit_convert(2.5, ...)` got NUM-020 today
// (silent miscompute pre-v0.4.113 era). The wrapper takes
// f64 in, returns f64 out, hides the bits-ABI plumbing.
//
// Pre-v0.4.260: adopter had to write
//   let mm_bits: i64 = unit_convert(f64_to_bits(2.5), ...);
//   let mm: f64 = f64_from_bits(mm_bits);
// Post-v0.4.260: adopter writes
//   let mm: f64 = unit_convert_f64(2.5, unit_m(), unit_mm());
//
// EXPECT: build success, runtime exit 0, output "OK units_convert_f64".

import "stdlib/rods/units.nr"

fn main() -> i32 {
    // Length: 2.5 m → 2500 mm.
    let mm: f64 = unit_convert_f64(2.5, unit_m(), unit_mm());
    if (mm as i32) != 2500 { print("FAIL m→mm"); return 1; };

    // Length: 1000 m → 1 km.
    let km: f64 = unit_convert_f64(1000.0, unit_m(), unit_km());
    if (km as i32) != 1 { print("FAIL m→km"); return 1; };

    // Mass: 5000 g → 5 kg.
    let kg: f64 = unit_convert_f64(5000.0, unit_g(), unit_kg());
    if (kg as i32) != 5 { print("FAIL g→kg"); return 1; };

    // Time: 60 s → 1 min.
    let min: f64 = unit_convert_f64(60.0, unit_s(), unit_min());
    if (min as i32) != 1 { print("FAIL s→min"); return 1; };

    // Frequency: 1 GHz → 1000 MHz.
    let mhz: f64 = unit_convert_f64(1.0, unit_GHz(), unit_MHz());
    if (mhz as i32) != 1000 { print("FAIL GHz→MHz"); return 1; };

    print("OK units_convert_f64");
    0
}
