# RFC-0052 — Photonic Compute Types

**Status:** Draft (frontier — V2.7, language + rod split)
**Date:** 2026-05-03

## Motivation

Optical / photonic accelerators (Lightmatter, Lightelligence, PsiQuantum classical, Luminous, integrated SiPh research) execute matmul / convolution / FFT in the optical domain at fJ/op energy and 100x bandwidth. The frontier writeup positions photonic as a first-class execution form alongside CPU/GPU/quantum.

Nucleor's stdlib has zero photonic surface today. This RFC adds:
- LANGUAGE-LEVEL: types (OpticalTensor, ComplexAmplitude, Phase, Wavelength, MZIMesh) + placement attribute `@photonic`
- ROD-LEVEL: `std.photonic` ops (optical_matmul, configure_mesh, calibrate_phase, model_crosstalk, modulator/detector)

## Language-level surface

```nucleor
struct OpticalTensor<T: ComplexScalar, Shape, Wavelength: u64> {
    data: i64,    // opaque handle to optical buffer (memristor / photonic memory / DAC table)
}

struct ComplexAmplitude { real: f64, imag: f64 }
struct Phase(f64)            // radians
struct Wavelength(f64)       // nanometers
struct MZIMesh<Rows, Cols>   // Mach-Zehnder Interferometer mesh, Rows×Cols configuration

@photonic[device=lightmatter_x1]
fn optical_layer(x: OpticalTensor<C64, [B, M, K], 1550>,
                 w: OpticalTensor<C64, [K, N],     1550>) -> OpticalTensor<C64, [B, M, N], 1550> {
    // dispatched to photonic device
    optical_matmul(x, w)
}
```

Key type-system effects:
- Wavelength as type param: `1550` and `1310` are different types. Mixing them in the same op fails type-check (`mux_dispatch` is the explicit conversion).
- Linear ownership of MZIMesh handle: an `MZIMesh<R, C>` value is move-only — you can't accidentally use the same physical mesh twice in concurrent paths.
- Effect tag `optical_path`: placed on any fn that runs on the photonic device. Composes with the existing capability/effect surface.

## Rod-level surface (`std.photonic`)

- `optical_matmul(a, b)` — primary op
- `configure_mesh(mesh: MZIMesh<R, C>, phase_shifts: [Phase; R*C]) -> MZIMesh<R, C>` (consumes + produces; linear)
- `calibrate_phase(mesh) -> Result<(), PhaseDriftError>`
- `assign_wavelengths(channels: [Wavelength; N]) -> WDMSchedule`
- `model_crosstalk(mesh) -> CrosstalkMatrix`
- `Modulator`, `Detector`, `ADC`, `DAC` op types (electrical ↔ optical conversion)

## Implementation

- Parser: the parameterized types use existing generic-param + string-literal-param machinery (RFC-0051 inheritance).
- Type-check: wavelength + shape + complex-scalar params compared by value at type-equality.
- Codegen: photonic ops dispatch to runtime helpers `__nucleor_optical_matmul_*`. Today these are STUBS that fall back to CPU complex-matmul with a runtime warning. Hardware dispatch is a future ship.
- Effect: `@photonic` placement attribute parsed and emitted as fn metadata.

## Cost

V2.7 ship: ~600 LOC compiler (types + placement attribute) + ~800 LOC stdlib (`std.photonic` rod with CPU-fallback ops). NO hardware backend in this ship.

Hardware backend: future v2.x ship per device family (Lightmatter SDK, others).

## Hot-path risk

None. Photonic types are orthogonal to existing hot paths.

## Frontier connection

Direct frontier writeup §3.2.3 "Photonic / optical compute." Pairs with **RFC-0048 hardware capability queries** (use `target.has(PHOTONIC)` to gate the hardware path).

## Closure criteria

- `OpticalTensor<C64, [B, M, K], 1550>` parses and type-checks.
- Mixing 1550 and 1310 wavelengths in the same op fails TYP-008.
- `optical_matmul` falls back to CPU complex-matmul when no photonic hardware available.
- Round-2 self-host fixed-point holds.
