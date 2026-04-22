// Nucleor stdlib: manifest_core
// Package manifest parsing for bootstrap compiler.
// Models Nucleor.toml structure.

// Manifest field identifiers
const MF_NAME: i32 = 0;
const MF_VERSION: i32 = 1;
const MF_ENTRY: i32 = 2;
const MF_BACKEND: i32 = 3;
const MF_OVERFLOW: i32 = 4;

// Backend options
const BE_CRANELIFT: i32 = 0;
const BE_LLVM: i32 = 1;

// Overflow options
const OVF_TRAP: i32 = 0;
const OVF_WRAP: i32 = 1;
const OVF_SATURATE: i32 = 2;

struct ManifestConfig {
    has_name: bool,
    has_version: bool,
    has_entry: bool,
    backend: i32,
    overflow: i32,
    dependency_count: i32,
}

fn default_manifest() -> ManifestConfig {
    ManifestConfig {
        has_name: false,
        has_version: false,
        has_entry: false,
        backend: BE_CRANELIFT,
        overflow: OVF_TRAP,
        dependency_count: 0,
    }
}

fn manifest_is_valid(m: ManifestConfig) -> bool {
    m.has_name && m.has_entry
}

fn manifest_has_dependencies(m: ManifestConfig) -> bool {
    m.dependency_count > 0
}

fn backend_name(b: i32) -> str {
    if b == BE_CRANELIFT { "cranelift" }
    else if b == BE_LLVM { "llvm" }
    else { "unknown" }
}

fn overflow_name(o: i32) -> str {
    if o == OVF_TRAP { "trap" }
    else if o == OVF_WRAP { "wrap" }
    else if o == OVF_SATURATE { "saturate" }
    else { "unknown" }
}

fn main() -> i32 {
    let m: ManifestConfig = default_manifest();
    print_bool(manifest_is_valid(m));
    print(backend_name(BE_CRANELIFT));
    print(overflow_name(OVF_TRAP));

    // Simulate a valid manifest
    let valid: ManifestConfig = ManifestConfig {
        has_name: true,
        has_version: true,
        has_entry: true,
        backend: BE_LLVM,
        overflow: OVF_WRAP,
        dependency_count: 3,
    };
    let valid_backend: i32 = valid.backend;
    let valid_deps: i32 = valid.dependency_count;
    print_bool(manifest_is_valid(valid));
    print_bool(valid_deps > 0);
    print(backend_name(valid_backend));
    0
}
