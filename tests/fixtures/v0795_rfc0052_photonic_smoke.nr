// v0.7.95 RFC-0052 Phase A smoke fixture — photonic-compute
// type surface. Validates:
//   - ComplexAmplitude / Phase / Wavelength / MZIMesh /
//     OpticalTensor constructors compile + round-trip
//   - Canonical wavelength bands return correct nm values
//   - wavelength_band_name returns canonical strings
//   - wavelength_compatible accepts same-nm, rejects different
//   - phase_radians / phase_to_q1616 round-trip
//   - mzi_mesh_size returns rows * cols
//   - optical_matmul_stub returns 0 + warning fires once
import "stdlib/rods/photonic.nr"

fn main() -> i64 {
    let amp: ComplexAmplitude = complex_amplitude(46341, 46341);
    if amp.real != 46341 { return 1; };
    if amp.imag != 46341 { return 2; };

    let p: Phase = phase_radians(3);
    if phase_to_q1616(p) != 3 * 65536 { return 3; };

    let p2: Phase = phase_q1616(32768);
    if phase_to_q1616(p2) != 32768 { return 4; };

    let w_c: Wavelength = wavelength_telecom_c();
    if w_c.nm != 1550 { return 5; };
    if str_eq(wavelength_band_name(w_c), "telecom_c") == 0 { return 6; };

    let w_o: Wavelength = wavelength_telecom_o();
    if w_o.nm != 1310 { return 7; };

    let w_red: Wavelength = wavelength_visible_red();
    if str_eq(wavelength_band_name(w_red), "visible_red") == 0 { return 8; };

    if wavelength_compatible(w_c, wavelength_telecom_c()) != 1 { return 9; };
    if wavelength_compatible(w_c, w_o) != 0 { return 10; };

    let mesh: MZIMesh = mzi_mesh(8, 8, 0);
    if mzi_mesh_size(mesh) != 64 { return 11; };

    let tensor: OpticalTensor = optical_tensor(0, 0, w_c);
    let recovered: Wavelength = optical_tensor_wavelength(tensor);
    if recovered.nm != 1550 { return 12; };

    photonic_warning_clear();
    if photonic_warning_count() != 0 { return 13; };

    let r: i64 = optical_matmul_stub(0, 0, w_c);
    if r != 0 { return 14; };
    if photonic_warning_count() != 1 { return 15; };

    // Second call doesn't increment the warn counter (one-shot).
    let r2: i64 = optical_matmul_stub(0, 0, w_c);
    if r2 != 0 { return 16; };
    if photonic_warning_count() != 1 { return 17; };

    if photonic_op_id_matmul() != 1 { return 18; };
    if photonic_op_id_fft() != 2 { return 19; };
    if str_eq(photonic_op_name(1), "matmul") == 0 { return 20; };
    if str_eq(photonic_op_name(99), "unknown") == 0 { return 21; };

    return 0;
}
