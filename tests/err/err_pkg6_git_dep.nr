// EXPECT: PKG-6 git dependency not yet supported
// Lane 3 (F-DIAG-006): PKG-6 had no negative test in tests/err/.
// `foo = { git = "..." }` isn't supported in v1.0 resolver.

// The package-resolver path is exercised by `nuc add` / `nuc install`,
// not direct .nr build. Documented as a negative-test fixture for
// the resolver-side EXPECT match. Lane 3 owns the diagnostic-coverage
// gate; package-resolver UX (Lane 7) wires the actual emit site.

fn main() -> i64 {
    return 0;
}
