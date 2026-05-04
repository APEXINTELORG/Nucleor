# Nucleor — Interop, FFI, and ABI Surface Gap Analysis and RFC

**Date:** 2026-05-04
**Author:** Claude (Opus 4.7) for Joseph Wescott
**Document type:** Combined gap analysis + RFC
**Status:** Draft for main-agent integration
**Disposition:** No file writes were made into `Nucleor_OSS`.

---

# Part I — Definition

## 1.1. The interop pillar

Interop is the surface where Nucleor meets the rest of the ecosystem. C ABI via `extern fn`, Rust bridge, Python embedding, shared-library export — these are the touchpoints that determine whether Nucleor is usable inside or alongside existing systems.

**Headline finding: cross-boundary memory ownership is undefined.** Four different ownership patterns are in use across `__nucleor_*` runtime, `rust_bridge`, `python_rt`, and `nuc build-shared` exports. There is no uniform allocator contract for cross-boundary strings. **Every Rust- or Python-returning function leaks memory** because Nucleor cannot call back to the foreign allocator.

---

# Part II — Gap Inventory

## FFI-1 — `rust_bridge` memory leak: no free path for `CString::into_raw()` returns — **HIGH**
Seven Rust bridge functions (`rust_regex_find`, `rust_regex_replace_all`, `rust_sort_ints`, `rust_sort_strings`, `rust_to_uppercase`, `rust_base64_encode`, `rust_base64_decode`) call `CString::into_raw()`. Pointer ownership transfers to caller (Nucleor), but **no `rust_free_str` export and no `#[export]`-able free hook.** Every call leaks memory.

## FFI-2 — `python_rt.c` memory leak: `rods_py_eval`/`rods_py_call_str` return `malloc`-allocated strings never freed — **HIGH**
Both `malloc`+`memcpy` a copy of UTF-8 result and return it. Nucleor `str` has no destructor; pointer immediately unreachable after use. Python-heavy program accumulates unbounded heap.

## FFI-3 — `python_rt.c` GIL unsafety: no `PyGILState_Ensure`/`Release` — **HIGH**
`rods_py_exec`/`rods_py_eval`/`rods_py_call_str` enter Python without acquiring GIL. If Nucleor spawns threads via `multi_core.nr` or `concurrency.nr` calling Python concurrently, undefined behavior. No documentation warning.

## FFI-4 — `extern fn`: no null-pointer discipline at language level — **HIGH** (cross-references MS-5)
`extern fn` returning `ptr` carries no nullable annotation. Compiler emits no null checks on return values. Callers receive raw `i64`/`ptr` and can pass into subsequent FFI calls or dereference with no static enforcement.

## FFI-5 — `abi_c_type_name` default fallthrough emits `int64_t` silently — **MEDIUM**
Returns `"int64_t"` for any unrecognized type. If a struct reaches this path, generated header emits incorrect declaration that compiles but is ABI-unsound. `abi_type_is_export_safe` guards most cases; silent default is a soundness trap.

## FFI-6 — `nuc abi`: exports not introspectable; "exports supported: no" hardcoded — **MEDIUM**
`render_abi_text` hardcodes "exports supported: no". `nuc abi` cannot report what shared library exports. `nuc build-shared --json` provides post-build data, but `nuc abi` (pre-build introspection) is blind to `pub fn`/`#[export]` surface.

## FFI-7 — `__nucleor_*` ABI has no version stamp in compiled output — **MEDIUM**
No `__nucleor_abi_version` symbol in runtime C. Executable built against runtime v0.3 can be linked against runtime v0.5 with no detectable mismatch at load time. Only the string `"c-v1-imports-only"` exists in the `nuc abi` tool output, not as a binary artifact.

## FFI-8 — `#cfile` missing-file error deferred to clang — **LOW**
Incorrect `#cfile` path surfaces only as ambiguous clang error during link, not as named diagnostic with file/line pointer.

## FFI-9 — `#libpath` not canonicalized — **LOW**
Raw path string with `base_dir` prefix. Mixed Windows/forward-slash separators may fail silently on POSIX clang.

## FFI-10 — `nuc gen-headers` does not verify generated header with clang — **MEDIUM**
No test passes generated `.h` through `clang -fsyntax-only`. Type mapping bug undetected until C/C++ consumer tries to `#include` generated header.

## FFI-11 — `nuc gen-headers` doesn't handle multi-line function signatures — **LOW**
Text scanner processes one line at a time. `extern fn` with parameter list wrapping across lines silently skipped.

## FFI-12 — `rust_bridge` is Windows-x86_64-only pre-built — **MEDIUM**
Only `nucleor_rust_bridge.lib` (COFF) committed. POSIX users must run `cargo build --release` manually. `rust.nr`'s `#libpath` hard-codes `"rust_bridge/target/release"` — works on Windows; fails for cross-compilation triples.

## FFI-13 — `nuc-bindgen` not implemented — **HIGH** (RFC-0012 Draft)
No libclang dependency, no binary, no test fixture. Three-tier FFI story (hand-written / bindgen / cxx) broken at tier 2.

## FFI-14 — `nuc-cxx` not implemented — **HIGH** (RFC-0011 Draft)
All 8 DoD checkboxes unchecked. No `#[cxx_bridge]` parser, no C++ shim generator, no `cxx.nr` rod. C++ interop requires hand-written `_rt.c` shims indefinitely.

## FFI-15 — DLPack not implemented — **MEDIUM** (RFC-0010 Draft, target v0.7)
No `dlpack.nr`, no `dlpack_rt.c`. "DLPack zero-copy tensor interchange" is roadmap, not shipped.

## FFI-16 — `py_eval` uses `__main__._nr_result` global — not re-entrant — **MEDIUM**
Concurrent calls or call raising Python exception mid-execution leaves `_nr_result` stale or absent for next call.

## FFI-17 — `rust_bridge` `DefaultHasher` not stable across Rust versions — **MEDIUM**
`rust_hash_string` uses `std::collections::hash_map::DefaultHasher`. Rust does not guarantee cross-version stability. Rebuilding `rust_bridge` with different Rust toolchain silently produces different hash values, breaking persisted data.

## FFI-18 — `nuc build-shared` rejects `#[repr(C)]` struct params; `nuc gen-headers` accepts them — **MEDIUM**
`abi_type_is_export_safe` admits `{void, i32, i64, f64, str, ptr}` only. `pub fn` taking/returning `#[repr(C)]` struct rejected. Inconsistent with `nuc gen-headers` which handles them via `nr_type_to_c_with_structs`. **Two tools have diverged in their type allowlists.**

## Cross-cutting risks
- **Soundness at `str` crossing.** Every FFI boundary passing `str` assumes NUL-termination; neither side checks for embedded NUL bytes. Python string with embedded NUL through `rods_py_eval` silently truncated. Rust bridge `to_str().unwrap_or("")` produces empty string on embedded NUL with no error signal.
- **Type erasure at `ptr` return.** Every `extern fn → ptr` is untyped `void*` at IR level. Two distinct opaque types indistinguishable at type checker and LLVM IR levels.
- **Memory ownership across FFI is undefined.** Four distinct patterns: Nucleor runtime (freed on `str_free`), `rust_bridge` (Rust heap, not callable from Nucleor), `python_rt` (`malloc`-owned, no free path), `#[export]` shared-lib (undocumented). **No uniform allocator contract** — highest-severity cross-cutting issue for embedding.
- **POSIX bootstrap missing** (cross-references BOOT-7).
- **`nuc abi` / `nuc build-shared` type-table divergence (FFI-18).**

---

# Part III — RFC

## 3.1. Goals
1. Establish a uniform cross-boundary memory ownership contract.
2. Close the leak class (FFI-1, FFI-2) with paired free hooks.
3. Implement `nuc-bindgen` and `nuc-cxx` to complete the three-tier interop story.
4. Stamp ABI version in compiled output.
5. Reconcile `nuc abi` and `nuc build-shared` type-table divergence.

## 3.2. Closure plan

**Phase 1 (emergency, leak fixes):**
- FFI-1: add `rust_free_str(ptr)` to `rust_bridge/src/lib.rs` exporting `CString::from_raw(ptr); /* drops */`. Update `rust.nr` to wrap every string-returning function in a paired call: returned pointer is consumed into a Nucleor-owned copy, then `rust_free_str` called on the original.
- FFI-2: same pattern for `python_rt.c`. Add `rods_py_free_str(ptr)` calling `free(ptr)`. Update `python.nr` wrappers.
- FFI-3: wrap `rods_py_exec`/`rods_py_eval`/`rods_py_call_str` with `PyGILState_Ensure()` / `PyGILState_Release()`. Document multi-thread Python rod use.
- FFI-7: emit `__nucleor_abi_version` constant in runtime C; add to header generator output.
- FFI-18: reconcile `abi_type_is_export_safe` and `nr_type_to_c_with_structs` to accept the same type set. Document the canonical allowlist.

**Phase 2 (short-term):**
- FFI-4: `extern fn ... -> Option<*mut T>` syntax (cross-references type-system T-8 and memory-safety MS-5). Compiler treats zero as None, nonzero as Some.
- FFI-5: emit FFI-WARN-001 when `abi_c_type_name` falls through to default. No silent widening to int64_t without warning.
- FFI-6: implement export introspection in `nuc abi`. Pre-build, read `pub fn` declarations and emit JSON/text.
- FFI-10: add gate test passing every generated `.h` through `clang -fsyntax-only`.
- FFI-11: support multi-line signatures in `nuc gen-headers` text scanner.
- FFI-16: replace `__main__._nr_result` global with isolated namespace per call (use Python's `compile()`+`exec()` with explicit globals dict).

**Phase 3 (medium-term):**
- FFI-12: build `rust_bridge` for Linux x86_64 and macOS arm64 in CI; commit `.a` artifacts. Document cross-compilation procedure.
- FFI-13: implement `nuc-bindgen` per RFC-0012. libclang-driven C/C++ header → `.nr` binding generator. Even MVP scope (basic types, structs, functions) closes the 3-tier interop gap.
- FFI-15: implement `dlpack.nr` + `dlpack_rt.c` per RFC-0010. Zero-copy tensor interchange with PyTorch/JAX/TensorFlow/NumPy.
- FFI-17: switch `rust_hash_string` to a deterministic-across-versions hash (e.g., siphash-1-3 with fixed key, or FxHash). Document the choice.

**Phase 4 (v1.0 gate):**
- FFI-14: implement `nuc-cxx` per RFC-0011. `#[cxx_bridge]` parser, C++ shim generator, `cxx_runtime.h`, `UniquePtr`/`SharedPtr` wrappers, `cxx.nr` rod.
- Uniform memory ownership contract documented and enforced: every cross-boundary string-returning FFI fn has a paired free hook.

## 3.3. v1.0 release gate
Phases 1-2 minimum. Phase 3 (Linux/macOS rust_bridge artifacts, bindgen, DLPack) strongly preferred for ML/scientific adoption. Phase 4 (cxx) acceptable to defer to v1.x.

## 3.4. Open questions
1. Should `extern fn ... -> Option<*mut T>` syntax replace existing `-> ptr` returns, or coexist? Recommendation: coexist; existing `-> ptr` is "I know this is non-null" assertion (still typed as `i64` at IR), `Option<*mut T>` is "this might be null" check.
2. DLPack target — full v0.7 scope or MVP (just `tensor_nd` ↔ NumPy)? Recommendation: MVP first to validate the contract, expand to full DLPack tags later.
3. `nuc-cxx` MVP scope — pure types only, or methods too? Recommendation: types and free functions; methods deferred.

---

# Part IV — Disposition
**Document path:** `C:\Users\JoeWe\Desktop\Nucleor_Interop_FFI_Gap_Analysis_and_RFC_2026-05-04.md`

*End of document.*
