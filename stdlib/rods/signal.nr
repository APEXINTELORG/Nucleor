// =====================================================
// rods/signal — Digital Signal Processing
// =====================================================
// Import: import "stdlib/rods/signal.nr"
// Provides: FIR / IIR filtering, Butterworth design,
//   Hamming / Hann / Blackman windows, Hilbert envelope,
//   zero-crossing count, up/down-sampling.
// =====================================================

#cfile "../runtime/signal_rt.c"

extern fn nuc_sig_fir_filter(signal: i64, coeffs: i64) -> i64;
extern fn nuc_sig_iir_filter(signal: i64, b: i64, a: i64) -> i64;
extern fn nuc_sig_butterworth(order: i64, cutoff: i64, sample_rate: i64) -> i64;
extern fn nuc_sig_window_hamming(n: i64) -> i64;
extern fn nuc_sig_window_hann(n: i64) -> i64;
extern fn nuc_sig_window_blackman(n: i64) -> i64;
extern fn nuc_sig_envelope(signal: i64) -> i64;
extern fn nuc_sig_zero_crossings(signal: i64) -> i64;
extern fn nuc_sig_downsample(signal: i64, factor: i64) -> i64;
extern fn nuc_sig_upsample(signal: i64, factor: i64) -> i64;

fn sig_fir(signal: i64, coeffs: i64) -> i64 { return nuc_sig_fir_filter(signal, coeffs); }
fn sig_iir(signal: i64, b: i64, a: i64) -> i64 { return nuc_sig_iir_filter(signal, b, a); }
fn sig_butterworth(order: i64, cutoff: i64, sr: i64) -> i64 { return nuc_sig_butterworth(order, cutoff, sr); }
fn sig_window_hamming(n: i64) -> i64 { return nuc_sig_window_hamming(n); }
fn sig_window_hann(n: i64) -> i64 { return nuc_sig_window_hann(n); }
fn sig_window_blackman(n: i64) -> i64 { return nuc_sig_window_blackman(n); }
fn sig_envelope(signal: i64) -> i64 { return nuc_sig_envelope(signal); }
fn sig_zero_crossings(signal: i64) -> i64 { return nuc_sig_zero_crossings(signal); }
fn sig_downsample(signal: i64, factor: i64) -> i64 { return nuc_sig_downsample(signal, factor); }
fn sig_upsample(signal: i64, factor: i64) -> i64 { return nuc_sig_upsample(signal, factor); }
