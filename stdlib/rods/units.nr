// =====================================================
// rods/units — SI Unit Conversion
// =====================================================
// Import: import "stdlib/rods/units.nr"
// Provides: unit_convert(value, from_id, to_id) and named unit IDs
//   for length, mass, time, temperature, pressure, energy, force,
//   frequency, angle, voltage, current.
// =====================================================

#cfile "../runtime/units_rt.c"

extern fn nuc_unit_convert(val_bits: i64, from: i64, to: i64) -> i64;

// --- Unit ID constants (must match #define block in units_rt.c) ---
fn unit_m()   -> i64 { return 1; }   // meters
fn unit_km()  -> i64 { return 2; }
fn unit_cm()  -> i64 { return 3; }
fn unit_mm()  -> i64 { return 4; }
fn unit_in()  -> i64 { return 5; }   // inches
fn unit_ft()  -> i64 { return 6; }
fn unit_mi()  -> i64 { return 7; }

fn unit_kg()  -> i64 { return 10; }  // kilograms
fn unit_g()   -> i64 { return 11; }
fn unit_lb()  -> i64 { return 12; }
fn unit_oz()  -> i64 { return 13; }

fn unit_s()   -> i64 { return 20; }  // seconds
fn unit_ms()  -> i64 { return 21; }
fn unit_us()  -> i64 { return 22; }
fn unit_min() -> i64 { return 23; }
fn unit_hr()  -> i64 { return 24; }
fn unit_day() -> i64 { return 25; }

fn unit_K()   -> i64 { return 30; }  // Kelvin
fn unit_C()   -> i64 { return 31; }  // Celsius
fn unit_F()   -> i64 { return 32; }  // Fahrenheit

fn unit_Pa()  -> i64 { return 40; }  // Pascal
fn unit_kPa() -> i64 { return 41; }
fn unit_atm() -> i64 { return 42; }
fn unit_bar() -> i64 { return 43; }
fn unit_psi() -> i64 { return 44; }

fn unit_J()   -> i64 { return 50; }  // Joules
fn unit_kJ()  -> i64 { return 51; }
fn unit_cal() -> i64 { return 52; }
fn unit_eV()  -> i64 { return 53; }
fn unit_kWh() -> i64 { return 54; }

fn unit_N()   -> i64 { return 60; }  // Newtons
fn unit_kN()  -> i64 { return 61; }
fn unit_lbf() -> i64 { return 62; }

fn unit_Hz()  -> i64 { return 70; }
fn unit_kHz() -> i64 { return 71; }
fn unit_MHz() -> i64 { return 72; }
fn unit_GHz() -> i64 { return 73; }

fn unit_rad() -> i64 { return 80; }
fn unit_deg() -> i64 { return 81; }

fn unit_V()   -> i64 { return 90; }
fn unit_mV()  -> i64 { return 91; }
fn unit_A()   -> i64 { return 92; }
fn unit_mA()  -> i64 { return 93; }

// Convert val (f64 bits) from `from_id` to `to_id`.
//
// LOW-LEVEL: the val and return are i64 holding the IEEE-754
// bit pattern of the underlying f64 — this matches the i64-
// everywhere ABI of the runtime FFI. Most adopters should
// prefer `unit_convert_f64` below, which wraps this in
// f64_to_bits / f64_from_bits so the f64 value flows naturally.
fn unit_convert(val: i64, from_id: i64, to_id: i64) -> i64 {
    return nuc_unit_convert(val, from_id, to_id);
}

// Convert val (an f64) from `from_id` to `to_id`. Ergonomic
// wrapper around the bits-ABI `unit_convert` — adopters never
// need to touch f64_to_bits / f64_from_bits.
//
// Example:
//   let mm: f64 = unit_convert_f64(2.5, unit_m(), unit_mm());
//   // mm == 2500.0
fn unit_convert_f64(val: f64, from_id: i64, to_id: i64) -> f64 {
    return f64_from_bits(nuc_unit_convert(f64_to_bits(val), from_id, to_id));
}
