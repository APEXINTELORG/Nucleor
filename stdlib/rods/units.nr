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

// =====================================================
// v0.7.84 — RFC-0047 Phase A: 7-vector SI dimensional surface.
//
// The full RFC-0047 ship phantom-types numeric values with a
// `[i8; 7]` SI dimension vector enforced at type-check
// (kg, m, s, A, K, mol, cd) — ~400 LOC of compiler work +
// ~200 LOC of literal-suffix lex.
//
// Phase A (this rod surface): adopters can build, compose, and
// compare dimension vectors as runtime Vec<i64> values today.
// Multiplication adds dim vectors element-wise; division
// subtracts; equality requires identical vectors. Adopters wrap
// their own numeric-with-dim values via a (value, dim_vec) pair
// and call the helpers below to enforce dimensional consistency
// before the Phase B compiler enforcement lands.
//
// Encoding: 7-element Vec<i64> in [kg, m, s, A, K, mol, cd] order.
// =====================================================

fn dim_kg()     -> Vec<i64> { let mut v: Vec<i64> = Vec::new(); v.push(1); v.push(0); v.push(0); v.push(0); v.push(0); v.push(0); v.push(0); return v; }
fn dim_m()      -> Vec<i64> { let mut v: Vec<i64> = Vec::new(); v.push(0); v.push(1); v.push(0); v.push(0); v.push(0); v.push(0); v.push(0); return v; }
fn dim_s()      -> Vec<i64> { let mut v: Vec<i64> = Vec::new(); v.push(0); v.push(0); v.push(1); v.push(0); v.push(0); v.push(0); v.push(0); return v; }
fn dim_A()      -> Vec<i64> { let mut v: Vec<i64> = Vec::new(); v.push(0); v.push(0); v.push(0); v.push(1); v.push(0); v.push(0); v.push(0); return v; }
fn dim_K()      -> Vec<i64> { let mut v: Vec<i64> = Vec::new(); v.push(0); v.push(0); v.push(0); v.push(0); v.push(1); v.push(0); v.push(0); return v; }
fn dim_mol()    -> Vec<i64> { let mut v: Vec<i64> = Vec::new(); v.push(0); v.push(0); v.push(0); v.push(0); v.push(0); v.push(1); v.push(0); return v; }
fn dim_cd()     -> Vec<i64> { let mut v: Vec<i64> = Vec::new(); v.push(0); v.push(0); v.push(0); v.push(0); v.push(0); v.push(0); v.push(1); return v; }

// Common derived dimensions (built from the 7 base vectors).
fn dim_dimensionless() -> Vec<i64> { let mut v: Vec<i64> = Vec::new(); v.push(0); v.push(0); v.push(0); v.push(0); v.push(0); v.push(0); v.push(0); return v; }
fn dim_velocity()      -> Vec<i64> { let mut v: Vec<i64> = Vec::new(); v.push(0); v.push(1); v.push(0 - 1); v.push(0); v.push(0); v.push(0); v.push(0); return v; }
fn dim_acceleration()  -> Vec<i64> { let mut v: Vec<i64> = Vec::new(); v.push(0); v.push(1); v.push(0 - 2); v.push(0); v.push(0); v.push(0); v.push(0); return v; }
fn dim_force()         -> Vec<i64> { let mut v: Vec<i64> = Vec::new(); v.push(1); v.push(1); v.push(0 - 2); v.push(0); v.push(0); v.push(0); v.push(0); return v; }
fn dim_energy()        -> Vec<i64> { let mut v: Vec<i64> = Vec::new(); v.push(1); v.push(2); v.push(0 - 2); v.push(0); v.push(0); v.push(0); v.push(0); return v; }
fn dim_power()         -> Vec<i64> { let mut v: Vec<i64> = Vec::new(); v.push(1); v.push(2); v.push(0 - 3); v.push(0); v.push(0); v.push(0); v.push(0); return v; }
fn dim_pressure()      -> Vec<i64> { let mut v: Vec<i64> = Vec::new(); v.push(1); v.push(0 - 1); v.push(0 - 2); v.push(0); v.push(0); v.push(0); v.push(0); return v; }
fn dim_frequency()     -> Vec<i64> { let mut v: Vec<i64> = Vec::new(); v.push(0); v.push(0); v.push(0 - 1); v.push(0); v.push(0); v.push(0); v.push(0); return v; }
fn dim_voltage()       -> Vec<i64> { let mut v: Vec<i64> = Vec::new(); v.push(1); v.push(2); v.push(0 - 3); v.push(0 - 1); v.push(0); v.push(0); v.push(0); return v; }

fn dim_eq(a: Vec<i64>, b: Vec<i64>) -> i64 {
    if vec_len(a) != 7 { return 0; };
    if vec_len(b) != 7 { return 0; };
    let mut i: i64 = 0;
    while i < 7 {
        if vec_get(a, i) != vec_get(b, i) { return 0; };
        i = i + 1;
    };
    return 1;
}

fn dim_mul(a: Vec<i64>, b: Vec<i64>) -> Vec<i64> {
    let mut r: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < 7 { r.push(vec_get(a, i) + vec_get(b, i)); i = i + 1; };
    return r;
}

fn dim_div(a: Vec<i64>, b: Vec<i64>) -> Vec<i64> {
    let mut r: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < 7 { r.push(vec_get(a, i) - vec_get(b, i)); i = i + 1; };
    return r;
}

fn dim_pow(a: Vec<i64>, n: i64) -> Vec<i64> {
    let mut r: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < 7 { r.push(vec_get(a, i) * n); i = i + 1; };
    return r;
}

fn dim_inv(a: Vec<i64>) -> Vec<i64> {
    let mut r: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < 7 { r.push(0 - vec_get(a, i)); i = i + 1; };
    return r;
}

fn dim_to_string(a: Vec<i64>) -> str {
    if vec_len(a) != 7 { return "<bad-dim>"; };
    let mut out: str = "[";
    let mut i: i64 = 0;
    while i < 7 {
        if i > 0 { out = str_concat(out, ","); };
        out = str_concat(out, str_from_int(vec_get(a, i)));
        i = i + 1;
    };
    out = str_concat(out, "]");
    return out;
}

fn dim_check_or_panic(have: Vec<i64>, want: Vec<i64>, label: str) -> i64 {
    if dim_eq(have, want) == 1 { return 1; };
    print(str_concat("ERROR: dim_check failed at ", str_concat(label, str_concat(": have=", str_concat(dim_to_string(have), str_concat(" want=", dim_to_string(want)))))));
    panic(str_concat("nucleor: dim_check failed at ", label));
    return 0;
}
