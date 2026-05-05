// v0.8.219 stdlib/rods/photonic.nr first test coverage.
//
// RFC-0052 Phase A: photonic-compute type surface (rod-only).
// Pre-v0.8.219: zero coverage on the standalone rod. Phase B
// (~600 LOC compiler + ~800 LOC stdlib + Lightmatter / Light-
// elligence backend dispatch) is deferred.
//
// Locks four invariants Phase B compiler enforcement of TYP-008
// wavelength-mismatch must NOT regress:
//
//   1. **Canonical wavelength bands** — telecom-O = 1310nm,
//      telecom-C = 1550nm, telecom-L = 1625nm; visible RGB =
//      700/550/450 nm.
//   2. **Wavelength compatibility** — same nm = 1; cross-band
//      = 0 (the core silent-miscompute guard).
//   3. **Phase Q1.16 fixed-point** — phase_radians(2) → q1616
//      = 2 * 65536 = 131072.
//   4. **CPU-fallback warning counter** — clear → count = 0;
//      one matmul stub call → count > 0 (hardware-mode mirror
//      ships in Phase B).
//
// Expected: rc=0.

import "stdlib/rods/photonic.nr"

fn check_wavelength_bands() -> i64 {
    let o: Wavelength = wavelength_telecom_o();
    let c: Wavelength = wavelength_telecom_c();
    let l: Wavelength = wavelength_telecom_l();
    if o.nm != 1310 { return 1; };
    if c.nm != 1550 { return 2; };
    if l.nm != 1625 { return 4; };
    if wavelength_visible_red().nm != 700 { return 8; };
    if wavelength_visible_green().nm != 550 { return 16; };
    if wavelength_visible_blue().nm != 450 { return 32; };
    return 0;
}

fn check_wavelength_compat() -> i64 {
    let c1: Wavelength = wavelength_nm(1550);
    let c2: Wavelength = wavelength_telecom_c();
    if wavelength_compatible(c1, c2) != 1 { return 64; };
    let r: Wavelength = wavelength_visible_red();
    if wavelength_compatible(c1, r) != 0 { return 128; };
    return 0;
}

fn check_phase_q1616() -> i64 {
    let p: Phase = phase_radians(2);
    if phase_to_q1616(p) != (2 * 65536) { return 256; };
    let p_zero: Phase = phase_q1616(0);
    if phase_to_q1616(p_zero) != 0 { return 512; };
    return 0;
}

fn check_warn_counter() -> i64 {
    photonic_warning_clear();
    if photonic_warning_count() != 0 { return 1024; };
    let w: Wavelength = wavelength_telecom_c();
    optical_matmul_stub(0, 0, w);
    if photonic_warning_count() <= 0 { return 2048; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_wavelength_bands();
    fails = fails + check_wavelength_compat();
    fails = fails + check_phase_q1616();
    fails = fails + check_warn_counter();
    return fails;
}
