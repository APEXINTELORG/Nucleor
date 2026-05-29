# RFC-0010 — DLPack Tensor Interchange

| Field | Value |
|---|---|
| **Number** | 0010 |
| **Title** | DLPack — zero-copy tensor handoff with PyTorch / JAX / TensorFlow / MLX |
| **Status** | Draft |
| **Author** | Nucleor maintainers |
| **Created** | 2026-04-22 |
| **Target release** | v0.7.0 ("AI Training + Real-Time Linux") |
| **Depends on** | RFC-0001 (allocator typing for GPU memory), RFC-0011 (`nuc-cxx` for some interop paths) |

---

## 1. Summary

Implement **DLPack** — the cross-framework tensor interchange standard
adopted by PyTorch, JAX, TensorFlow, MLX, NumPy, CuPy, MXNet, and
others. Enables zero-copy tensor handoff between Nucleor and any
DLPack-compatible framework.

```nucleor
// Receive a PyTorch tensor as a Nucleor Tensor
fn run_inference(py_tensor: PyTensor) -> Tensor<f32, [Dyn, 3, 224, 224]> {
    let dl: DLManagedTensor = py_tensor.to_dlpack();
    let nuc_tensor: Tensor<f32, _> = Tensor::from_dlpack(dl);
    // ...
    nuc_tensor
}

// Hand a Nucleor Tensor to PyTorch
fn export_to_torch(t: Tensor<f32, [Dyn]>) -> PyTensor {
    let dl: DLManagedTensor = t.to_dlpack();
    PyTensor::from_dlpack(dl)
}
```

Critical for the AI training story (v0.7) and AI inference story
(v0.6 onward): **the user can train a policy in PyTorch, export it,
inference it in Nucleor, all without copying tensor data**.

---

## 2. Motivation

Every modern ML framework supports DLPack:
- PyTorch: `torch.from_dlpack`, `torch.to_dlpack`
- JAX: `jax.dlpack`
- TensorFlow: `tf.experimental.dlpack`
- MLX: `mlx.from_dlpack`
- NumPy 1.22+: `np.from_dlpack`
- CuPy: `cupy.from_dlpack`

Without DLPack, every Nucleor↔framework boundary requires a
malloc + memcpy. For training-loop scale, this is 10-100× overhead.

Without DLPack, Nucleor cannot meaningfully participate in modern ML
pipelines. **DLPack is to ML what JSON is to APIs** — adopt it or be
isolated.

---

## 3. Design

### 3.1 The DLPack ABI

DLPack defines a small C struct:

```c
typedef struct {
    void* data;              // tensor data pointer
    DLDevice device;         // CPU / CUDA / ROCm / MetalGPU / etc.
    int32_t ndim;
    DLDataType dtype;        // float32, int64, bfloat16, ...
    int64_t* shape;
    int64_t* strides;        // optional; NULL = contiguous
    uint64_t byte_offset;
} DLTensor;

typedef struct {
    DLTensor dl_tensor;
    void* manager_ctx;       // opaque, framework-managed
    void (*deleter)(struct DLManagedTensor* self);
} DLManagedTensor;

typedef struct {
    DLManagedTensor dl_tensor;
    int32_t flags;           // versioned, read-only, etc.
} DLManagedTensorVersioned;     // DLPack 1.0+
```

We support DLPack 1.0+ (versioned). Backward-compat with 0.x via
shim.

### 3.2 Nucleor `Tensor<T, Shape>` ↔ DLPack

The compiler defines `Tensor<T, Shape>::to_dlpack()` and
`Tensor<T, Shape>::from_dlpack()` for each numeric `T`:

```nucleor
impl<T: TensorElement, S: Shape> Tensor<T, S> {
    pub fn to_dlpack(self) -> DLManagedTensor;
    pub fn from_dlpack(dl: DLManagedTensor) -> Result<Self, DLPackError>;
}
```

`to_dlpack` consumes the Nucleor tensor (move semantics) and
transfers ownership of the underlying buffer. The deleter pointer
inside `DLManagedTensor` calls Nucleor's allocator on drop.

`from_dlpack` takes a managed DLPack tensor; the Nucleor side now
owns the buffer; on Nucleor-side drop, it calls the original
deleter.

### 3.3 Device support

DLPack devices:
- `kDLCPU = 1`
- `kDLCUDA = 2`
- `kDLCUDAHost = 3`
- `kDLOpenCL = 4`
- `kDLVulkan = 7`
- `kDLMetal = 8`
- `kDLVPI = 9`
- `kDLROCM = 10`
- `kDLROCMHost = 11`
- `kDLExtDev = 12`
- `kDLOneAPI = 14`

Nucleor v0.7 supports CPU + CUDA. Vulkan / Metal / ROCm in v0.8 with
GPU compute rod (Decisions §B2).

### 3.4 dtype support

DLPack `DLDataType`:
- `kDLInt(8/16/32/64)`
- `kDLUInt(8/16/32/64)`
- `kDLFloat(16/32/64)` — bfloat16 + float16 + float32 + float64
- `kDLBfloat(16)` — explicit BF16
- `kDLComplex(64/128)` — complex types
- `kDLBool` — boolean
- `kDLE4M3 / kDLE5M2` — FP8 (v0.7 ML era)

Map all of these to Nucleor numeric types (RFC's T1.1 numeric
refactor + `bf16` / `f16` / `f8e4m3` / `f8e5m2`).

### 3.5 Stride handling

DLPack supports non-contiguous tensors via strides. Nucleor's
`Tensor<T, Shape>` is contiguous by default. `from_dlpack` of a
non-contiguous tensor either:
- Returns `Err(NonContiguous)` (default; safer)
- Copies into a contiguous buffer (opt-in via `from_dlpack_owned`)
- Constructs a `StridedTensor<T, Shape>` (new type, v0.8)

### 3.6 Lifetime management

DLPack's deleter mechanism is the key to safety. When Nucleor
receives a DLPack tensor:
- The Nucleor `Tensor<T, S>` wrapper holds the `DLManagedTensor*`.
- On `Drop`, calls `dl.deleter(&dl)`.
- The deleter is provided by the source framework and does the right
  thing (decrement Python refcount for PyTorch, free Arena for JAX,
  etc.).

When Nucleor exports:
- Provide a Nucleor-specific deleter that calls the appropriate
  Nucleor allocator's free.
- The framework receiving the DLPack will call this deleter when
  done.

### 3.7 Error handling

```nucleor
enum DLPackError {
    NullPointer,
    UnsupportedDevice(DLDevice),
    UnsupportedDtype(DLDataType),
    ShapeMismatch { expected: Vec<i64>, got: Vec<i64> },
    NonContiguous,
    VersionTooOld,
}
```

`from_dlpack` returns `Result<Tensor<T, S>, DLPackError>`.

### 3.8 Composition with `#[no_alloc]` (RFC-0001)

DLPack import allocates wrapping metadata (tiny, but allocates).
`from_dlpack` is `may_alloc`; cannot be called from `#[no_alloc]`
functions. Pre-import outside the RT loop.

### 3.9 Composition with `Allocator` (RFC-0002)

`Tensor<T, S, A: Allocator>` carries its allocator. `to_dlpack()`
consumes the tensor, transferring buffer ownership and providing a
deleter that calls `A::dealloc`. `from_dlpack` constructs a
`Tensor<T, S, ExternalAllocator>` (new allocator type whose `dealloc`
calls the DLPack `deleter`).

### 3.10 Diagnostics

| Code | Meaning |
|---|---|
| DLPACK-001 | Unsupported device (e.g., import a Vulkan tensor on CPU-only build) |
| DLPACK-002 | Unsupported dtype |
| DLPACK-003 | Shape mismatch (compile-time-known shape vs runtime DLPack) |
| DLPACK-004 | Non-contiguous tensor and no copy requested |
| DLPACK-005 | DLPack version too old (pre-1.0) |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| `runtime/dlpack_rt.c` | DLPack ABI structs, deleter machinery | ~400 |
| `stdlib/rods/dlpack.nr` | Nucleor wrapper, `to_dlpack`/`from_dlpack` for `Tensor<T, S>` | ~500 |
| Generic instantiation | All `T × S` combinations | ~200 |
| External-allocator wrapper | `ExternalAllocator` for imports | ~150 |
| Diagnostics | DLPACK-001…005 | ~100 |
| **Total** | | **~1350** |

---

## 5. Alternatives considered

- Custom serialization (Nucleor-native format) — fragments
  ecosystem; users would convert to/from anyway. Rejected.
- Apache Arrow — broader scope (columnar data); use for
  dataframes (RFC-?), not tensors.
- Protobuf-encoded tensors — slow, copy-required. Rejected for
  ML use.
- Skip DLPack, route everything through ONNX Runtime — works for
  inference; doesn't help training.

## 6. Open questions

1. DLPack `flags` field handling — read-only / aligned / etc.
   Recommend respect on import; ignore on export (Nucleor tensors
   are always writable).
2. Multi-device tensors (e.g., split CUDA tensor)? Out of scope.
3. Quantized dtypes (`kDLInt(4)`) — recently added. Recommend
   support for v0.7 ML era.
4. Bidirectional CUDA stream synchronization? DLPack provides
   `__dlpack__(stream=...)` protocol; recommend support.

## 7. Definition of done

- [ ] DLPack 1.0+ ABI implemented
- [ ] CPU + CUDA tensors round-trip with PyTorch (test)
- [ ] CPU tensors round-trip with NumPy + JAX + TensorFlow + MLX
- [ ] All numeric dtypes (i8…i64, u8…u64, f8e4m3, f8e5m2, bf16, f16,
      f32, f64, complex64, complex128, bool) supported
- [ ] DLPACK-001…005 diagnostics
- [ ] Demo: load PyTorch model weights into Nucleor `Tensor` for
      inference, zero-copy

## 8. Future extensions

- Vulkan / Metal / ROCm device support (with v0.8 GPU rods)
- Strided tensor type (`StridedTensor`)
- Multi-device unified-memory tensors
- Ragged-tensor protocol (DLPack 2.0+ if/when standardized)

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] Compatible with v0.7 schedule and the autograd/training stack
- [ ] LOC budget ~1350 fits
- [ ] Pitch survives ("zero-copy tensor exchange with every modern ML
      framework")
