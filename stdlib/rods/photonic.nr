// rods/photonic — RFC-0052 Phase A: photonic-compute type
// surface (rod-only, no compiler change).
//
// The full RFC-0052 ship adds language-level types
// `OpticalTensor<T: ComplexScalar, Shape, Wavelength: u64>` +
// `MZIMesh<Rows, Cols>` + placement attribute `@photonic` plus
// hardware dispatch (~600 LOC compiler + ~800 LOC stdlib with
// CPU-fallback ops). Phase A (this rod) lands the canonical
// type-tag surface + wavelength registry + CPU-fallback hooks
// that adopters can use today, ahead of compiler enforcement.
//
// Sister to RFC-0046 (frame markers), RFC-0049 (memspace tags),
// RFC-0050 (energy budgets), RFC-0051 (model provenance) — all
// stdlib-first, compiler-enforcement-later. This is the V2
// frontier Tier-B follow-on after the Tier-A close-out at
// v0.7.90.
//
// Nucleor v0.7 has NO photonic hardware backend; every op in
// this rod falls back to host RAM with a runtime warning.
// Hardware dispatch (Lightmatter SDK, Lightelligence, etc.) is
// the v2.x post-Phase-B ship.
//
// Workflow today:
//
//   import "stdlib/rods/photonic.nr"
//
//   let amp: ComplexAmplitude = complex_amplitude(0.7071, 0.7071);
//   let p: Phase = phase_radians(0);
//   let w: Wavelength = wavelength_nm(1550);
//   if wavelength_compatible(w, wavelength_telecom_c()) == 1 { ... };
//
//   // CPU-fallback matmul stub (logs a warning, returns 0):
//   let r: i64 = optical_matmul_stub(0, 0, w);

#cfile "../runtime/photonic_rt.c"

extern fn nuc_photonic_optical_matmul_stub(a_handle: i64, b_handle: i64, wavelength_nm: i64) -> i64;
extern fn nuc_photonic_warn_count() -> i64;
extern fn nuc_photonic_warn_clear() -> i64;

// =====================================================
// Marker structs (zero-size; phantom-typed in Phase B).
// =====================================================
struct OpticalTensor { data: i64, shape: i64, wavelength: i64 }
struct ComplexAmplitude { real: i64, imag: i64 }
struct Phase { radians_q1616: i64 }   // Q1.16 fixed-point radians (Phase A)
struct Wavelength { nm: i64 }          // nanometers
struct MZIMesh { rows: i64, cols: i64, handle: i64 }

// =====================================================
// Wavelength constructor + canonical bands.
// =====================================================
fn wavelength_nm(nm: i64) -> Wavelength {
    return Wavelength { nm: nm };
}

// Canonical telecom + visible bands.
fn wavelength_telecom_o() -> Wavelength { return wavelength_nm(1310); }
fn wavelength_telecom_c() -> Wavelength { return wavelength_nm(1550); }
fn wavelength_telecom_l() -> Wavelength { return wavelength_nm(1625); }
fn wavelength_visible_red()   -> Wavelength { return wavelength_nm(700); }
fn wavelength_visible_green() -> Wavelength { return wavelength_nm(550); }
fn wavelength_visible_blue()  -> Wavelength { return wavelength_nm(450); }
fn wavelength_uv()    -> Wavelength { return wavelength_nm(380); }
fn wavelength_ir_far() -> Wavelength { return wavelength_nm(10000); }

fn wavelength_band_name(w: Wavelength) -> str {
    if w.nm == 1310 { return "telecom_o"; };
    if w.nm == 1550 { return "telecom_c"; };
    if w.nm == 1625 { return "telecom_l"; };
    if w.nm == 700  { return "visible_red"; };
    if w.nm == 550  { return "visible_green"; };
    if w.nm == 450  { return "visible_blue"; };
    if w.nm == 380  { return "uv"; };
    if w.nm == 10000 { return "ir_far"; };
    return "custom";
}

// Compatibility predicate — adopters pre-flight ops here in
// Phase A; Phase B promotes to type-level wavelength-mismatch
// TYP-008.
fn wavelength_compatible(a: Wavelength, b: Wavelength) -> i64 {
    if a.nm == b.nm { return 1; };
    return 0;
}

// =====================================================
// ComplexAmplitude + Phase constructors.
//
// Encoding: real/imag stored as f64-bits via complex.nr's
// f64_from_int / f64_encode pipeline. Phase stored as Q1.16
// signed-fixed for compatibility with the v0.7.91 fixed-point
// rod (full f64-bits land in Phase B).
// =====================================================
fn complex_amplitude(real_q1616: i64, imag_q1616: i64) -> ComplexAmplitude {
    return ComplexAmplitude { real: real_q1616, imag: imag_q1616 };
}

fn phase_q1616(radians_q1616: i64) -> Phase {
    return Phase { radians_q1616: radians_q1616 };
}

fn phase_radians(int_part: i64) -> Phase {
    return Phase { radians_q1616: int_part * 65536 };
}

fn phase_to_q1616(p: Phase) -> i64 { return p.radians_q1616; }

// =====================================================
// MZIMesh constructor — adopters pass an opaque hardware
// handle (or 0 for the CPU-fallback). rows × cols is the
// physical mesh shape.
// =====================================================
fn mzi_mesh(rows: i64, cols: i64, handle: i64) -> MZIMesh {
    return MZIMesh { rows: rows, cols: cols, handle: handle };
}

fn mzi_mesh_size(m: MZIMesh) -> i64 { return m.rows * m.cols; }

// =====================================================
// OpticalTensor constructor + accessors.
// =====================================================
fn optical_tensor(data: i64, shape: i64, w: Wavelength) -> OpticalTensor {
    return OpticalTensor { data: data, shape: shape, wavelength: w.nm };
}

fn optical_tensor_wavelength(t: OpticalTensor) -> Wavelength {
    return wavelength_nm(t.wavelength);
}

// =====================================================
// CPU-fallback ops. Each logs a one-line warning at first
// call and returns the placeholder value (0). Adopters
// using this rod today get a clean "no hardware" path; the
// Phase B / hardware backend ship swaps the body without a
// source change at adopter sites.
// =====================================================
fn optical_matmul_stub(a_handle: i64, b_handle: i64, w: Wavelength) -> i64 {
    return nuc_photonic_optical_matmul_stub(a_handle, b_handle, w.nm);
}

fn photonic_warning_count() -> i64 { return nuc_photonic_warn_count(); }
fn photonic_warning_clear() -> i64 { return nuc_photonic_warn_clear(); }

// =====================================================
// Format dispatch by tag.
// =====================================================
fn photonic_op_id_matmul()   -> i64 { return 1; }
fn photonic_op_id_fft()      -> i64 { return 2; }
fn photonic_op_id_convolve() -> i64 { return 3; }

fn photonic_op_name(id: i64) -> str {
    if id == 1 { return "matmul"; };
    if id == 2 { return "fft"; };
    if id == 3 { return "convolve"; };
    return "unknown";
}
