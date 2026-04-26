# ML_Suite Feedback Queue (inbound from Nucleor_ML_Suite)

This doc mirrors `Nucleor_ML_Suite/docs/NUCLEOR_LANGUAGE_FEEDBACK.md`
into a cron-driven punchlist queue so the compiler-side fixes can land
in priority order.

The full upstream-side response with diagnosis, agree/disagree, and
fix-plan is at:
`C:\Users\JoeWe\Desktop\Nucleor_ML_Suite\docs\NUCLEOR_LANGUAGE_FEEDBACK_RESPONSE.md`

## Active queue

### NUC-FEEDBACK-002 — `Vec<f32>` round-trip silent miscompute
**Status: PARTIAL CLOSED in v0.3.119 (diag landed; real type-prop fix queued). Fixture t396.**
**Priority: HIGH (silent miscompute, ML-launch blocker)**

Reproducer pinned upstream:
```rust
fn main() -> i64 {
    let mut v: Vec<f32> = Vec::new();
    v.push(1.0f32);
    v.push(2.0f32);
    let s: f32 = f32_add(v[0], v[1]);
    print_f32(s);   // prints "0", expected "3"
    return 0;
}
```

Standalone f32 ops work; the bug is the `Vec<f32>` storage path losing
the f32 type tag through the `vec_get` chain so `f32_add` ends up
operating on raw i64 storage values (which decode as 0).

Fix options (pick one for first ship):
1. Make `expr_struct_type` propagate the element type when the receiver
   is a `Vec<T>` and the operation is indexing — so subsequent uses
   dispatch through the typed binop helper.
2. Add a hard diagnostic that rejects `Vec<f32>` / `Vec<f64>` /
   `Vec<bf16>` / `Vec<f16>` until proper element-type wiring lands.
   Suggest the workaround: `Vec<i64>` of bit patterns + manual
   `f*_*` helpers (the workaround the ML_Suite agent already adopted),
   or `Tensor::*` for ML work.

Either way, must ship before v1 OSS public release.

### NUC-FEEDBACK-003 — `clang` toolchain detection on Windows
**Status: CLOSED in v0.3.119. Windows install paths probed + clang path now quoted in shell command. NUCLEOR_CLANG env override honored.**
**Priority: LOW (UX, easy)**

The compiler emits LLVM IR successfully then dies at link with
`'clang' is not recognized as an internal or external command` if LLVM
isn't on `PATH` — even when `C:\Program Files\LLVM\bin\clang.exe`
exists. Adopters get no signal what to install or where.

Fix:
1. After PATH lookup fails, probe `C:\Program Files\LLVM\bin\clang.exe`
   (Windows), `C:\msys64\mingw64\bin\clang.exe`,
   `/opt/homebrew/opt/llvm/bin/clang` (macOS), `/usr/lib/llvm-*/bin/clang`
   (Linux).
2. If none found, emit a clear diagnostic naming what was tried and
   suggesting the LLVM download URL.
3. Add `NUCLEOR_CLANG` env override and `[toolchain] clang = "<path>"`
   in `Nucleor.toml`.

### NUC-FEEDBACK-001 — `nuc test` parse error + harness divergence
**Priority: MEDIUM (test-surface trust)**

The generated test harness emits a parse error
(`Parse error at token position 8927: expected token 51 got 1`) on the
ML_Suite tensor smoke test, even though the same code compiles via
`nuc run`. Suspect interaction with the `Vec<f32>` issue; try after 002.

Fix targets:
1. Reproduce minimal harness shape that triggers the parse error.
2. Make harness path compile iff `nuc run` does.
3. Pin a verify-gate fixture against the harness shape.

## Backlog (not actively queued)

### NUC-IMPROVE-001 / NUC-IMPROVE-003 — JSON-line metric output for parity testing
**Status: CLOSED in v0.3.120 (`stdlib/rods/jsonl.nr` shipped). Fixture t397.**
Schema delivered exactly as agent specified in NUC-IMPROVE-003.
Deferred: SHA-256 in array entries (needs runtime helper for hashing — schema is forward-compatible).

### NUC-IMPROVE-002 — First-class `Tensor<T, Shape, Device>`
RFC-scale. Post-v1.

## Sync protocol

When a fix ships:
1. Update CHANGELOG with the `NUC-FEEDBACK-NNN` reference in the body.
2. Update `Nucleor_ML_Suite/docs/NUCLEOR_LANGUAGE_FEEDBACK_RESPONSE.md`
   with the closing version and the fixture id.
3. Mark the entry in this queue as `[CLOSED in vX.Y.Z, fixture tNNN]`.
