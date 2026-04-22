// =====================================================
// rods/fft — Fast Fourier Transform
// =====================================================
// Import: import "stdlib/rods/fft.nr"
// Provides: 1D complex / real FFT, fast convolution,
//   power spectrum, cross-correlation.
// =====================================================

#cfile "../runtime/fft_rt.c"

extern fn nuc_fft_1d(data: i64, n: i64, forward: i64) -> i64;
extern fn nuc_fft_1d_real(data: i64, n: i64) -> i64;
extern fn nuc_fft_convolve(a: i64, b: i64, n: i64) -> i64;
extern fn nuc_fft_power_spectrum(data: i64, n: i64) -> i64;
extern fn nuc_fft_correlate(a: i64, b: i64, n: i64) -> i64;

fn fft_1d(data: i64, n: i64, forward: i64) -> i64 { return nuc_fft_1d(data, n, forward); }
fn fft_1d_real(data: i64, n: i64) -> i64 { return nuc_fft_1d_real(data, n); }
fn fft_convolve(a: i64, b: i64, n: i64) -> i64 { return nuc_fft_convolve(a, b, n); }
fn fft_power_spectrum(data: i64, n: i64) -> i64 { return nuc_fft_power_spectrum(data, n); }
fn fft_correlate(a: i64, b: i64, n: i64) -> i64 { return nuc_fft_correlate(a, b, n); }
