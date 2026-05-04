/* photonic_rt.c — RFC-0052 Phase A: photonic-compute CPU-
 * fallback runtime stubs.
 *
 * Nucleor v0.7 has no photonic hardware backend; every op
 * falls back to host-RAM placeholder + one-shot warning.
 * Hardware dispatch (Lightmatter SDK, Lightelligence, etc.)
 * is the v2.x post-Phase-B ship. */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int _nuc_photonic_warn_emitted = 0;

static void _nuc_photonic_warn_once(const char *msg) {
    if (_nuc_photonic_warn_emitted == 0) {
        fprintf(stderr, "warning: %s\n", msg);
        _nuc_photonic_warn_emitted = 1;
    }
}

long long nuc_photonic_optical_matmul_stub(long long a_handle, long long b_handle,
                                            long long wavelength_nm) {
    _nuc_photonic_warn_once(
        "Nucleor v0.7 photonic ops fall back to CPU RAM with placeholder semantics. "
        "Hardware dispatch (Lightmatter / Lightelligence / SiPh) lands in v2.x. "
        "RFC-0052 Phase A surface only.");
    /* Suppress unused-param warnings without compiler-specific pragmas. */
    (void)a_handle; (void)b_handle; (void)wavelength_nm;
    return 0;
}

long long nuc_photonic_warn_count(void) {
    return (long long)_nuc_photonic_warn_emitted;
}

long long nuc_photonic_warn_clear(void) {
    _nuc_photonic_warn_emitted = 0;
    return 0;
}
