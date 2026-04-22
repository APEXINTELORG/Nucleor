// =====================================================
// rods/toml — Minimal TOML parser (RFC-0019 phase 1)
// =====================================================
// Import: import "stdlib/rods/toml.nr"
//
// Subset suitable for nuc.toml manifests:
//   - [section] headers (any depth via [a.b.c])
//   - key = "string"  (heap-allocated, returned as ptr)
//   - key = 42        (i64)
//   - key = true      (1)  / false (0)
//   - # line comments
//
// Values stored in an underlying HashMap<str, i64>. Use the
// type-specific accessors below — they all return i64 cells but
// the documentation tells you what the cell encodes.
//
// Out of scope (full v0.4 toml.nr): arrays, inline tables,
// floats, dates, multi-line strings, quoted keys.
// =====================================================

// Construct from source text or file path.
fn toml(src: str) -> i64 { return toml_parse_string(src); }
fn toml_load(path: str) -> i64 { return toml_parse_file(path); }

// Accessors. Keys use dotted form for nested sections:
//   [package]   →  package.name
//   [profile.release]   →  profile.release.opt_level
fn toml_string(t: i64, key: str) -> i64 { return toml_get_str(t, key); }
fn toml_int(t: i64, key: str) -> i64 { return toml_get_int(t, key); }
fn toml_bool(t: i64, key: str) -> i64 { return toml_get_int(t, key); }

// Predicates
fn toml_contains(t: i64, key: str) -> i64 { return toml_has(t, key); }

// Default-value accessors (returns default if missing).
fn toml_int_or(t: i64, key: str, default: i64) -> i64 {
    if toml_has(t, key) == 1 { return toml_get_int(t, key); };
    return default;
}
fn toml_string_or(t: i64, key: str, default: i64) -> i64 {
    if toml_has(t, key) == 1 { return toml_get_str(t, key); };
    return default;
}

// Free underlying HashMap when done.
fn toml_free(t: i64) -> i64 { return hashmap_free(t); }

// ---- Manifest validation (RFC-0019 phase 1) ----
// Returns 0 if all required fields present + well-formed; bitfield
// of issues otherwise (see __nucleor_manifest_validate header
// for bit meanings). Use toml_manifest_report to render.
fn toml_manifest_check(t: i64) -> i64 { return manifest_validate(t); }
fn toml_manifest_describe(issues: i64) -> str { return manifest_report(issues); }
fn toml_manifest_ok(t: i64) -> i64 {
    if manifest_validate(t) == 0 { return 1; };
    return 0;
}
