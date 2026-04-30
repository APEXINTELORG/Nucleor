# RFC-0011 — `nuc-cxx` C++ FFI Bridge Generator

| Field | Value |
|---|---|
| **Number** | 0011 |
| **Title** | `nuc-cxx` — paired `.h` + `.nr` C++ FFI codegen modeled on Rust's `cxx` crate |
| **Status** | Partial (audited v0.4.189). The `nuc gen-headers <file> --out <h>` command exists, runs cleanly, and writes a valid C header skeleton with `#include <stdint.h>`, `#include <stdbool.h>`, and `extern "C" {` guards. `extern fn` declarations from `.nr` source flow through to runtime FFI correctly (used heavily in `stdlib/rods/` — every helper rod uses `extern fn nuc_*`). **Deferred:** automatic emission of `pub fn` Nucleor functions as C-callable `extern "C"` declarations in the generated header (currently writes "0 extern decl(s), 0 #[export] decl(s)" because the `#[export]` attribute parser-side recognition isn't wired); paired `.nr` + `.h` codegen for C++-style class bridges. |
| **Author** | Joseph Wescott + Claude |
| **Created** | 2026-04-22 |
| **Target release** | v0.4.0 ("Robotics Stack") |
| **Depends on** | RFC-0001 (FFI attributes), RFC-0002 (allocator types — soft), RFC-0012 (`nuc-bindgen`, parallel) |

---

## 1. Summary

Add a code-generation tool (`nuc-cxx`) that takes a paired `.h` + `.nr`
declaration block and produces:

1. A C++ shim file (`.cxx`) implementing the boundary calls.
2. An `extern "C"` declaration block in Nucleor that calls into the
   shim.
3. Type-mapping glue for `std::string`, `std::vector<T>`, `std::unique_ptr<T>`,
   `std::shared_ptr<T>`, `std::optional<T>`, plus user-defined types.
4. Lifetime-checked Nucleor wrappers that preserve ownership semantics
   across the boundary.

```nucleor
// nuc-cxx bridge declaration
#[cxx_bridge(header = "src/cxx/sensor.h")]
mod sensor_ffi {
    extern "C++" {
        type Sensor;     // opaque C++ type
        fn new_sensor() -> UniquePtr<Sensor>;
        fn read(self: &Sensor) -> Vec<f64>;
        fn name(self: &Sensor) -> String;
    }
    extern "Nucleor" {
        type Callback;   // Nucleor type exposed to C++
        fn on_reading(self: &Callback, value: f64);
    }
}
```

`nuc-cxx` reads this block, generates the C++ shim (which includes
`"src/cxx/sensor.h"` and forwards calls), generates the matching
`extern "C"` decls in Nucleor, and emits build-system glue.

This unblocks **the entire C++ ecosystem**: Drake, MoveIt internals,
PCL, OpenCV C++ APIs, Eigen, ROS 2 internals, and every robotics
vendor SDK that ships C++ headers. Without it, every C++ binding is a
hand-written shim.

---

## 2. Motivation

### 2.1 What's wrong today

Every C++ binding in Nucleor today requires:
1. A hand-written `_rt.c` (in C, not C++) that exposes a flat C API.
2. Hand-written `extern fn` declarations in Nucleor.
3. Hand-written wrappers for `std::string`, `std::vector`,
   `std::unique_ptr`, etc.
4. Manual lifetime tracking — when does the C++ object get destroyed?
   Who owns the memory the C++ side returned?

This works for small libraries (one or two functions). For a library
like Drake (hundreds of classes, thousands of methods), it's
prohibitive.

### 2.2 What other languages do

| Language | Tool | Notes |
|---|---|---|
| **C** | Direct (`extern "C"`) | Trivial; no story for STL types |
| **Python** | pybind11, nanobind, Boost.Python | Single-language solution; runtime overhead |
| **Rust** | **cxx** crate (Dropbox/cxxbridge) | The reference design |
| **Rust** | autocxx | Auto-generates cxx bridges from headers |
| **Swift** | C++ interop in Swift 5.9+ | First-class language feature |
| **Julia** | Cxx.jl | Embedded Clang; runtime cost |
| **Go** | cgo | C only; no C++ |

**Rust's `cxx` is the gold standard.** It works by having both sides
declare the boundary, then generating glue that enforces the
declarations. Trust is bilateral: Rust trusts the C++ shim, C++
trusts the Rust shim, and the bridge generator ensures consistency.

We model `nuc-cxx` on `cxx`. Same design, Nucleor types.

---

## 3. Design

### 3.1 The `#[cxx_bridge]` block

A bridge is a Nucleor module annotated `#[cxx_bridge]`:

```nucleor
#[cxx_bridge(header = "include/sensor.h", cxx_out = "build/sensor.cxx")]
mod sensor_ffi {
    extern "C++" {
        // Opaque C++ types — Nucleor knows nothing about their layout
        type Sensor;
        type Reading;

        // Constructor returning a unique_ptr (heap-allocated)
        fn make_sensor(rate_hz: u32) -> UniquePtr<Sensor>;

        // Methods — `self` denotes the Nucleor &Sensor wrapper
        fn read(self: &Sensor) -> Reading;
        fn name(self: &Sensor) -> String;        // std::string → Nucleor String
        fn samples(self: &Sensor) -> Vec<f64>;   // std::vector<double> → Nucleor Vec
        fn calibrate(self: &mut Sensor, offset: f64);
    }

    extern "Nucleor" {
        // Nucleor types exposed to C++
        type ReadingCallback;
        fn on_reading(self: &ReadingCallback, value: f64);
    }
}
```

`extern "C++"` declares C++ symbols Nucleor can call.
`extern "Nucleor"` declares Nucleor types/functions C++ can call.

### 3.2 Type mappings

`nuc-cxx` ships a baseline type table:

| C++ type | Nucleor type | Ownership |
|---|---|---|
| `int8_t … int64_t` | `i8 … i64` | (value) |
| `uint8_t … uint64_t` | `u8 … u64` | (value) |
| `float`, `double` | `f32`, `f64` | (value) |
| `bool` | `bool` | (value) |
| `std::string` | `String` | move on cross |
| `std::string_view` | `&str` | borrow |
| `std::vector<T>` | `Vec<T>` | move on cross |
| `std::array<T, N>` | `[T; N]` | (value) |
| `std::optional<T>` | `Option<T>` | move on cross |
| `std::variant<T, U, …>` | tagged enum | move on cross |
| `std::unique_ptr<T>` | `UniquePtr<T>` | move-only handle |
| `std::shared_ptr<T>` | `SharedPtr<T>` | refcounted handle |
| `std::function<R(Args)>` | `Box<dyn Fn(Args) -> R>` | with `#[no_dyn]` warning |
| Opaque C++ class `Foo` | `Foo` (opaque type) | Box, ref, or by-value depending on declaration |

User-extensible: a `#[cxx_type_map]` attribute lets a project add
mappings for project-specific C++ types.

### 3.3 Generated C++ shim

Given the bridge in §3.1, `nuc-cxx` generates (skeleton):

```cpp
// build/sensor.cxx — generated by nuc-cxx, do not edit
#include "include/sensor.h"
#include "nucleor_cxx_runtime.h"

extern "C" {
  // Pointer-typed handles to opaque C++ values
  Sensor* nuc_sensor_make(uint32_t rate_hz) {
      return make_sensor(rate_hz).release();
  }
  void nuc_sensor_destroy(Sensor* p) {
      std::unique_ptr<Sensor>(p).reset();
  }

  // Methods — self pointer first
  Reading nuc_sensor_read(const Sensor* self) {
      return self->read();
  }

  // String marshaling — std::string → packed (ptr, len) for Nucleor
  NucString nuc_sensor_name(const Sensor* self) {
      auto s = self->name();
      return nuc_cxx_string_into(std::move(s));
  }

  // Vec marshaling — std::vector<double> → packed (ptr, len, cap)
  NucVecF64 nuc_sensor_samples(const Sensor* self) {
      auto v = self->samples();
      return nuc_cxx_vec_f64_into(std::move(v));
  }

  void nuc_sensor_calibrate(Sensor* self, double offset) {
      self->calibrate(offset);
  }

  // Nucleor → C++ direction (the ReadingCallback)
  // Forward-declared in nucleor_cxx_runtime.h
  void nuc_callback_on_reading(const NucReadingCallback* cb, double value);
}

// C++-side wrapper that satisfies the C++ Callback interface
class NucReadingCallbackAdapter : public ReadingCallback {
    NucReadingCallback* nuc_;
public:
    NucReadingCallbackAdapter(NucReadingCallback* n) : nuc_(n) {}
    void on_reading(double v) override {
        nuc_callback_on_reading(nuc_, v);
    }
};
```

### 3.4 Generated Nucleor side

```nucleor
// stdlib-level extern decls
extern fn nuc_sensor_make(rate_hz: u32) -> *mut Sensor;
extern fn nuc_sensor_destroy(p: *mut Sensor);
extern fn nuc_sensor_read(p: *const Sensor) -> Reading;
extern fn nuc_sensor_name(p: *const Sensor) -> NucString;
extern fn nuc_sensor_samples(p: *const Sensor) -> NucVecF64;
extern fn nuc_sensor_calibrate(p: *mut Sensor, offset: f64);

// User-facing wrappers
pub struct Sensor { _ptr: *mut Sensor }

impl Sensor {
    pub fn make(rate_hz: u32) -> UniquePtr<Sensor> {
        let p = unsafe { nuc_sensor_make(rate_hz) };
        UniquePtr::from_raw(p, |p| unsafe { nuc_sensor_destroy(p) })
    }
    pub fn read(&self) -> Reading { unsafe { nuc_sensor_read(self._ptr) } }
    pub fn name(&self) -> String { unsafe { nuc_sensor_name(self._ptr).into_string() } }
    pub fn samples(&self) -> Vec<f64> { unsafe { nuc_sensor_samples(self._ptr).into_vec() } }
    pub fn calibrate(&mut self, offset: f64) { unsafe { nuc_sensor_calibrate(self._ptr, offset) } }
}

impl Drop for Sensor {
    fn drop(&mut self) { unsafe { nuc_sensor_destroy(self._ptr); } }
}
```

The user calls these as native Nucleor APIs. The `unsafe` blocks are
contained in the generated code; user code is safe.

### 3.5 Build-system integration

`nuc build` learns to recognize `#[cxx_bridge]` modules:

1. Pre-build step: invoke `nuc-cxx` over each bridge to produce the
   C++ shim file (`.cxx`).
2. Compile the C++ shim with `clang++ -std=c++20 -c shim.cxx`
   (configurable via `Nucleor.toml`).
3. Compile the user's C++ source (the original library headers and
   source) similarly.
4. Compile the Nucleor module producing a `.o`.
5. Link all `.o` files together with `clang++` (because we now have
   C++ symbols).

`Nucleor.toml` gains:

```toml
[cxx]
compiler = "clang++"
flags = ["-std=c++20", "-O3"]
include = ["include/", "third_party/eigen/"]
link = ["pthread", "stdc++"]
```

### 3.6 Lifetime and ownership rules

Three patterns supported:

**Pattern A — opaque heap object.** The C++ side returns a
`std::unique_ptr<T>`; Nucleor owns it via `UniquePtr<T>` (move-only,
calls C++ destructor on drop).

**Pattern B — opaque shared object.** `std::shared_ptr<T>` →
`SharedPtr<T>` (Arc-equivalent, refcounted, last drop calls C++
destructor).

**Pattern C — value type marshaled by-value.** `std::array<f64, 3>` →
`[f64; 3]` (copy across boundary, both sides have independent copies).

The borrow checker enforces:
- `&Sensor` parameters cannot outlive the `UniquePtr<Sensor>` they
  borrow from.
- `&mut Sensor` is exclusive (no aliasing).
- Returned `String`/`Vec` move ownership; the C++ side has no
  reference after the move.

This is the same ownership story as today's Nucleor; `nuc-cxx` just
threads it across the C++ boundary.

### 3.7 RFC-0001 attribute interaction

Generated wrappers carry inferred attributes:

```nucleor
impl Sensor {
    #[ffi_no_alloc, ffi_no_panic]
    pub fn read(&self) -> Reading { ... }   // user asserts via #[cxx_attrs(read = "no_alloc, no_panic")]
}
```

The `#[cxx_bridge]` block can carry per-method attribute hints:

```nucleor
#[cxx_bridge(header = "include/sensor.h")]
mod sensor_ffi {
    extern "C++" {
        type Sensor;

        #[ffi_no_alloc, ffi_no_panic, deadline = 100us]
        fn read(self: &Sensor) -> Reading;

        #[ffi_may_alloc, ffi_may_panic]
        fn calibrate(self: &mut Sensor, offset: f64);
    }
}
```

The user is asserting C++ behavior — the compiler can't verify but
it threads the assertion into the RFC-0001 analysis. Critical for
robotics: `#[no_alloc]` callers need to know which C++ methods are
safe.

### 3.8 Composition with `nuc-bindgen` (RFC-0012)

`nuc-bindgen` generates a baseline `.nr` declaration block from a
C++ header. The user then promotes promising bindings to a
`#[cxx_bridge]` for cleaner ergonomics. Three-tier story:

1. **`extern fn` shim** — for one-shot bindings (small surface).
2. **`nuc-bindgen`** — for C-style libraries with broad surface.
3. **`nuc-cxx`** — for C++ libraries with STL types and
   classes.

User picks based on library complexity.

### 3.9 Diagnostics

| Code | Meaning |
|---|---|
| `CXX-001` | C++ header not found at the path declared in `#[cxx_bridge(header=…)]` |
| `CXX-002` | Type mismatch between Nucleor decl and C++ source (caught at link via name-mangling check) |
| `CXX-003` | Use of `std::function` without `#[no_dyn]` opt-out |
| `CXX-004` | `extern "Nucleor"` block declares a type with non-`#[repr(C)]` layout |
| `CXX-005` | C++ exception escapes through bridge (caught by generated `try/catch` and translated to `Result<T, CxxError>`) |

---

## 4. Implementation

### 4.1 The `nuc-cxx` tool

A standalone binary that:
- Parses Nucleor `#[cxx_bridge]` blocks (subset of full Nucleor
  parser — only enough to extract the FFI declarations).
- Emits C++ shim file.
- Emits Nucleor-side `extern fn` declarations.
- Emits build-glue file for `nuc build` consumption.

Estimated size: ~3000 LOC. Self-hosted in Nucleor (eats own dog food).

### 4.2 Compiler changes

| Component | Change | LOC est. |
|---|---|---|
| Parser | Recognize `#[cxx_bridge]` and `extern "C++" { … }` blocks | ~150 |
| AST | New `CxxBridge` node | ~80 |
| Driver | Invoke `nuc-cxx` in pre-build step | ~120 |
| Build orchestration | Link C++ object files alongside Nucleor objects | ~100 |
| Diagnostics | CXX-001…005 | ~150 |
| **Total** | | **~600** |

### 4.3 Runtime changes

| Component | Change | LOC est. |
|---|---|---|
| `runtime/cxx_runtime.h` (header) | `NucString`, `NucVec*`, `NucOption*` packed structs and conversion fns | ~250 |
| `runtime/cxx_runtime.cpp` | Implementations (move semantics, exception translation) | ~400 |
| `runtime/cxx_unwind_rt.c` | C++ exception → Nucleor `Result<T, CxxError>` translation | ~200 |
| **Total** | | **~850** |

### 4.4 Stdlib changes

| Rod | Status |
|---|---|
| `stdlib/rods/cxx.nr` | NEW — `UniquePtr`, `SharedPtr`, `CxxString`, `CxxVec`, `CxxOption` wrapper types |
| `stdlib/rods/cxx_io.nr` | NEW — `std::ios` / `std::cout` for completeness |

### 4.5 Demo bindings (ship with v0.4)

To prove the design works on real C++:
- **Eigen** — `rod/eigen.nr` via `nuc-cxx` over a thin wrapper
  header (Eigen is template-heavy; a wrapper is needed regardless).
- **OpenCV high-level** — `rod/opencv_hi.nr` via `nuc-cxx`,
  complementing the existing C-API `rod/opencv.nr` from §3.10 of
  the Robotics RFC.
- **MuJoCo** — actually fine with `nuc-bindgen` (C API), but ship
  one `nuc-cxx` example for the C++ wrapper headers.

### 4.6 Test plan

- **Unit:** `tests/cxx/hello_cxx.nr` calls a one-line C++ function.
- **STL types:** `tests/cxx/stl_string_vector.nr` round-trips
  `std::string` and `std::vector<double>`.
- **Lifetime:** `tests/cxx/unique_ptr_drop.nr` verifies destructor
  fires.
- **Exceptions:** `tests/cxx/cxx_exception.nr` — C++ throws,
  Nucleor catches as `Result::Err`.
- **Demo:** `examples/15_eigen_solve.nr` — solve `Ax = b` via Eigen.

### 4.7 Migration

`nuc-cxx` is purely additive. Existing `extern fn` shims continue to
work. New users opt in for C++ libraries.

---

## 5. Alternatives considered

### 5.1 Embed Clang in the compiler (Cxx.jl-style)

Run Clang in-process to parse C++ headers and JIT-compile method
bodies.

**Rejected:**
- Massive runtime dependency (the entire Clang library, ~50 MB).
- Slow build times (Clang re-parses headers every run).
- Doesn't help with ABI stability.

### 5.2 Pre-generated bindings only (no runtime tool)

Maintainers hand-write each `.cxx` shim once; ship pre-built.

**Rejected:**
- Doesn't scale; every API change requires re-shimming.
- Defeats the purpose — users still can't bind their own C++ libraries.

### 5.3 Just use `nuc-bindgen`

Skip `nuc-cxx` entirely; let `nuc-bindgen` handle C++ via libclang.

**Rejected as sole solution:**
- libclang's understanding of C++ templates is incomplete (template
  instantiation requires building the type at codegen time, not
  binding time).
- STL types need handwritten conversion glue regardless.
- However, `nuc-bindgen` complements `nuc-cxx` for the C-API subset
  (RFC-0012).

### 5.4 Direct C++ compiler integration (Swift 5.9 model)

Make Nucleor's compiler read C++ headers natively, no separate tool.

**Rejected for v0.4:**
- Massive scope; Swift took years to ship this.
- `nuc-cxx`-as-tool is incrementally improvable to compiler-integrated
  later.
- Tool-based design is less coupled and easier to maintain.

---

## 6. Open questions

1. **Exception handling default.**
   Should generated bridges always wrap C++ calls in `try/catch` and
   return `Result<T, CxxError>`, or only when `#[may_throw]` is
   declared?

   Recommend **wrap by default**, opt-out via `#[no_throw]`. Safer
   default, even if slightly slower.

2. **Header parsing — Clang-driven or hand-written?**
   `nuc-cxx` could re-parse C++ headers via libclang to extract type
   info. Or trust the user's declarations.

   Recommend **trust the user** (cxx-style). Add `nuc-bindgen` as the
   header-parsing tool (RFC-0012). Layer separation.

3. **Build-system integration with non-Nucleor C++ projects.**
   What if the user wants Nucleor as an *imported library* in a CMake
   project?

   Recommend **emit a `find_package(Nucleor)` CMake helper** in v0.5.
   v0.4 ships `nuc build` as the only driver; CMake comes later.

4. **`std::shared_ptr` cycles.**
   Refcounted `SharedPtr` can leak via cycles. Should we ship a
   `WeakPtr`?

   Recommend **yes, alongside `SharedPtr`**. Same as Rust's `Arc`/
   `Weak`.

5. **Templates in the bridge.**
   Can users write `fn solve<T: Real>(a: &Matrix<T>, b: &Vec<T>) -> Vec<T>;`
   in a `#[cxx_bridge]`? Each instantiation is a separate C++
   template instantiation.

   Recommend **defer to v0.5**. v0.4 supports concrete types only;
   v0.5 adds explicit instantiation lists.

6. **Building on Windows.**
   MSVC C++ ABI differs from Itanium (Linux/macOS). Test matrix on
   both?

   Recommend **yes**. CI runs on `windows-latest` (MSVC) and
   `ubuntu-latest` (clang++) from day one.

---

## 7. Definition of done

- [ ] `nuc-cxx` binary builds and ships in `bin/`
- [ ] `#[cxx_bridge]` parses; `extern "C++"` and `extern "Nucleor"`
      blocks recognized
- [ ] Type table from §3.2 implemented
- [ ] Generated C++ shims compile cleanly under clang++ on Linux,
      Windows (MSVC), and macOS
- [ ] Generated Nucleor wrappers compose with RFC-0001 attributes
      (`#[ffi_no_alloc]` etc.)
- [ ] `tests/cxx/*.nr` pass on all three platforms
- [ ] `examples/15_eigen_solve.nr` ships and runs
- [ ] At least one robotics-tier rod (`rod/eigen.nr` or
      `rod/opencv_hi.nr`) ships built atop `nuc-cxx`
- [ ] CHANGELOG documents `nuc-cxx`, `nuc.toml [cxx]` section, and
      build-system integration

---

## 8. Future extensions (out of scope)

- **Direct compiler integration** (Swift 5.9 model) — v1.0+.
- **Template instantiation lists** — v0.5.
- **CMake `find_package(Nucleor)`** — v0.5.
- **C++ coroutines bridging Nucleor async** — v0.8 if/when async
  lands.
- **C++ modules (C++20)** — v0.6 when adoption is widespread.
- **MSVC-only intrinsics, GCC-only intrinsics** — opt-in via
  `#[cfg]`.
- **Bridging C++ ranges (`std::ranges`)** to Nucleor iterators — v0.7
  pending iterator-trait spec.

---

## 9. Acceptance checklist

- [ ] Maintainer (Joseph Wescott) approves the design
- [ ] Compatible with RFC-0001 (`#[ffi_no_alloc]` etc. compose
      cleanly with generated wrappers)
- [ ] Compatible with RFC-0002 (allocators) — `UniquePtr<T>`/
      `SharedPtr<T>` carry no Nucleor allocator (C++ owns)
- [ ] Compatible with v0.4 release schedule
- [ ] LOC estimates (~600 compiler + ~850 runtime + ~3000 nuc-cxx
      tool) fit budget
- [ ] CI matrix covers Linux + Windows + macOS
- [ ] Pitch survives ("cxx-style C++ FFI for Nucleor; unblocks
      Drake, OpenCV, MoveIt, Eigen, every robotics vendor SDK")
