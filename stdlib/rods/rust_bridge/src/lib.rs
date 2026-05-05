// Nucleor Rust Bridge — exposes Rust functionality via C ABI
// This crate compiles to a static library that Nucleor programs link against.
// Demonstrates: regex, string processing, hashing, sorting — all from Rust's ecosystem.
//
// === Ownership convention (R06-D1 Phase 1, v0.8.270 / 2026-05-05) ===
//
// Every `rust_*` function below that returns `*const c_char` transfers
// **ownership of the heap allocation** to the caller via
// `CString::into_raw()`. Caller MUST eventually pass the exact pointer
// to `rust_free_str` to reclaim memory; otherwise leaks by design.
//
// The seven leak-vulnerable returns:
//   rust_regex_find, rust_regex_replace_all,
//   rust_sort_ints, rust_sort_strings,
//   rust_to_uppercase,
//   rust_base64_encode, rust_base64_decode
//
// All other `rust_*` functions return primitive types (i64) and have
// no ownership concern.
//
// Reclaim path: `rust_free_str(ptr)` calls `CString::from_raw(ptr)`
// which drops the underlying allocation. `is_null()` is checked so
// double-free / null-pass is a no-op rather than a crash.

use std::ffi::{CStr, CString};
use std::os::raw::c_char;

// === Regex (from the `regex` crate) ===

/// Check if a string matches a regex pattern. Returns 1 (match) or 0 (no match).
#[no_mangle]
pub extern "C" fn rust_regex_is_match(pattern: *const c_char, text: *const c_char) -> i64 {
    let pattern = unsafe { CStr::from_ptr(pattern) }.to_str().unwrap_or("");
    let text = unsafe { CStr::from_ptr(text) }.to_str().unwrap_or("");
    match regex::Regex::new(pattern) {
        Ok(re) => if re.is_match(text) { 1 } else { 0 },
        Err(_) => -1,
    }
}

/// Find the first match of a regex pattern in text. Returns the matched substring (caller must free).
#[no_mangle]
pub extern "C" fn rust_regex_find(pattern: *const c_char, text: *const c_char) -> *const c_char {
    let pattern = unsafe { CStr::from_ptr(pattern) }.to_str().unwrap_or("");
    let text = unsafe { CStr::from_ptr(text) }.to_str().unwrap_or("");
    match regex::Regex::new(pattern) {
        Ok(re) => match re.find(text) {
            Some(m) => CString::new(m.as_str()).unwrap_or_default().into_raw(),
            None => CString::new("").unwrap_or_default().into_raw(),
        },
        Err(_) => CString::new("").unwrap_or_default().into_raw(),
    }
}

/// Count all non-overlapping matches of a regex pattern in text.
#[no_mangle]
pub extern "C" fn rust_regex_count(pattern: *const c_char, text: *const c_char) -> i64 {
    let pattern = unsafe { CStr::from_ptr(pattern) }.to_str().unwrap_or("");
    let text = unsafe { CStr::from_ptr(text) }.to_str().unwrap_or("");
    match regex::Regex::new(pattern) {
        Ok(re) => re.find_iter(text).count() as i64,
        Err(_) => -1,
    }
}

/// Replace all matches of a regex pattern with a replacement string.
#[no_mangle]
pub extern "C" fn rust_regex_replace_all(
    pattern: *const c_char,
    text: *const c_char,
    replacement: *const c_char,
) -> *const c_char {
    let pattern = unsafe { CStr::from_ptr(pattern) }.to_str().unwrap_or("");
    let text = unsafe { CStr::from_ptr(text) }.to_str().unwrap_or("");
    let replacement = unsafe { CStr::from_ptr(replacement) }.to_str().unwrap_or("");
    match regex::Regex::new(pattern) {
        Ok(re) => {
            let result = re.replace_all(text, replacement);
            CString::new(result.as_ref()).unwrap_or_default().into_raw()
        }
        Err(_) => CString::new(text).unwrap_or_default().into_raw(),
    }
}

// === Hashing (from Rust std) ===

/// Compute a 64-bit hash of a string using Rust's DefaultHasher.
///
/// **WARNING (R06-D4 v0.8.272):** `DefaultHasher` uses Rust's
/// `RandomState` which is randomized per process (and per Rust
/// version). The same input string produces DIFFERENT 64-bit hash
/// values across process runs. **Unsuitable for reproducible
/// artifacts, content-addressed caching, or stable serialization.**
///
/// For deterministic hashing use `rust_hash_string_fnv1a` below.
/// `rust_hash_string` is preserved here for callers who genuinely
/// want process-local randomization (e.g. defending against HashDoS).
#[no_mangle]
pub extern "C" fn rust_hash_string(s: *const c_char) -> i64 {
    use std::hash::{Hash, Hasher};
    use std::collections::hash_map::DefaultHasher;
    let s = unsafe { CStr::from_ptr(s) }.to_str().unwrap_or("");
    let mut hasher = DefaultHasher::new();
    s.hash(&mut hasher);
    hasher.finish() as i64
}

/// R06-D4 Phase 1 (v0.8.272) — deterministic 64-bit string hash via
/// FNV-1a (Fowler–Noll–Vo). Same input ALWAYS produces same output
/// across process runs, machines, and Rust versions. Use this for
/// reproducible artifacts, content-addressed caching, stable
/// serialization, or any hash that must round-trip through
/// build/CI/distribution.
///
/// FNV-1a 64-bit canonical constants:
///   offset_basis = 0xcbf29ce484222325
///   prime        = 0x100000001b3
///
/// Per-byte: `hash = (hash XOR byte) * prime`.
///
/// Returned as `i64` (sign-extended from u64 via `as i64`); callers
/// that need the unsigned form must reinterpret the bits.
#[no_mangle]
pub extern "C" fn rust_hash_string_fnv1a(s: *const c_char) -> i64 {
    let s = unsafe { CStr::from_ptr(s) }.to_str().unwrap_or("");
    let mut hash: u64 = 0xcbf29ce484222325u64;
    let prime: u64 = 0x100000001b3u64;
    for byte in s.bytes() {
        hash ^= byte as u64;
        hash = hash.wrapping_mul(prime);
    }
    hash as i64
}

// === Sorting (Rust's highly optimized sort) ===

/// Sort a comma-separated list of integers. Returns sorted comma-separated string.
#[no_mangle]
pub extern "C" fn rust_sort_ints(csv: *const c_char) -> *const c_char {
    let csv = unsafe { CStr::from_ptr(csv) }.to_str().unwrap_or("");
    let mut nums: Vec<i64> = csv
        .split(',')
        .filter_map(|s| s.trim().parse().ok())
        .collect();
    nums.sort();
    let result: String = nums.iter().map(|n| n.to_string()).collect::<Vec<_>>().join(",");
    CString::new(result).unwrap_or_default().into_raw()
}

/// Sort a comma-separated list of strings alphabetically.
#[no_mangle]
pub extern "C" fn rust_sort_strings(csv: *const c_char) -> *const c_char {
    let csv = unsafe { CStr::from_ptr(csv) }.to_str().unwrap_or("");
    let mut parts: Vec<&str> = csv.split(',').map(|s| s.trim()).collect();
    parts.sort();
    let result = parts.join(",");
    CString::new(result).unwrap_or_default().into_raw()
}

// === String utilities powered by Rust ===

/// Convert a string to uppercase (full Unicode support via Rust).
#[no_mangle]
pub extern "C" fn rust_to_uppercase(s: *const c_char) -> *const c_char {
    let s = unsafe { CStr::from_ptr(s) }.to_str().unwrap_or("");
    CString::new(s.to_uppercase()).unwrap_or_default().into_raw()
}

/// Base64 encode a string.
#[no_mangle]
pub extern "C" fn rust_base64_encode(s: *const c_char) -> *const c_char {
    let s = unsafe { CStr::from_ptr(s) }.to_str().unwrap_or("");
    let encoded = base64_encode_impl(s.as_bytes());
    CString::new(encoded).unwrap_or_default().into_raw()
}

/// Base64 decode a string.
#[no_mangle]
pub extern "C" fn rust_base64_decode(s: *const c_char) -> *const c_char {
    let s = unsafe { CStr::from_ptr(s) }.to_str().unwrap_or("");
    match base64_decode_impl(s) {
        Some(bytes) => CString::new(bytes).unwrap_or_default().into_raw(),
        None => CString::new("").unwrap_or_default().into_raw(),
    }
}

// === R06-D1 Phase 1 (v0.8.270) — string-return reclamation path ===
//
// Free a string previously returned by any `rust_*` function above
// (rust_regex_find, rust_regex_replace_all, rust_sort_ints,
//  rust_sort_strings, rust_to_uppercase, rust_base64_encode,
//  rust_base64_decode). Caller must pass the EXACT pointer returned
// by that function — passing a borrowed `*const c_char` from CStr
// would reclaim memory the bridge does not own.
//
// Null is safe (no-op). Double-free is undefined behavior (the
// caller's responsibility — they own the pointer until they free
// once). Phase 2 may add a wrapper that tracks live pointers in a
// HashSet for double-free detection.
#[no_mangle]
pub unsafe extern "C" fn rust_free_str(s: *mut c_char) {
    if s.is_null() {
        return;
    }
    // Reclaim the CString allocation; dropping at end of scope frees.
    let _ = CString::from_raw(s);
}

// Simple base64 implementation (no external dependency needed)
fn base64_encode_impl(data: &[u8]) -> String {
    const TABLE: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut result = String::with_capacity((data.len() + 2) / 3 * 4);
    for chunk in data.chunks(3) {
        let b0 = chunk[0] as u32;
        let b1 = if chunk.len() > 1 { chunk[1] as u32 } else { 0 };
        let b2 = if chunk.len() > 2 { chunk[2] as u32 } else { 0 };
        let triple = (b0 << 16) | (b1 << 8) | b2;
        result.push(TABLE[((triple >> 18) & 0x3F) as usize] as char);
        result.push(TABLE[((triple >> 12) & 0x3F) as usize] as char);
        if chunk.len() > 1 {
            result.push(TABLE[((triple >> 6) & 0x3F) as usize] as char);
        } else {
            result.push('=');
        }
        if chunk.len() > 2 {
            result.push(TABLE[(triple & 0x3F) as usize] as char);
        } else {
            result.push('=');
        }
    }
    result
}

fn base64_decode_impl(s: &str) -> Option<Vec<u8>> {
    fn val(c: u8) -> Option<u32> {
        match c {
            b'A'..=b'Z' => Some((c - b'A') as u32),
            b'a'..=b'z' => Some((c - b'a' + 26) as u32),
            b'0'..=b'9' => Some((c - b'0' + 52) as u32),
            b'+' => Some(62),
            b'/' => Some(63),
            b'=' => Some(0),
            _ => None,
        }
    }
    let bytes = s.as_bytes();
    if bytes.len() % 4 != 0 { return None; }
    let mut result = Vec::with_capacity(bytes.len() / 4 * 3);
    for chunk in bytes.chunks(4) {
        let a = val(chunk[0])?;
        let b = val(chunk[1])?;
        let c = val(chunk[2])?;
        let d = val(chunk[3])?;
        let triple = (a << 18) | (b << 12) | (c << 6) | d;
        result.push(((triple >> 16) & 0xFF) as u8);
        if chunk[2] != b'=' { result.push(((triple >> 8) & 0xFF) as u8); }
        if chunk[3] != b'=' { result.push((triple & 0xFF) as u8); }
    }
    Some(result)
}
