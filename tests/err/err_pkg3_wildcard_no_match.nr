// EXPECT: PKG-3 wildcard version constraint not yet supported
// Lane 3 (F-DIAG-006): PKG-3 had no negative test in tests/err/.
// Wildcard ranges (`*`, `1.*`, `1.0.*`) aren't supported in v1.0
// resolver.

// The package-resolver path is exercised by `nuc add` / `nuc install`,
// not direct .nr build. This file documents the negative case as a
// fixture; the resolver-side test in tests/err/ assertion runs via
// the EXPECT header against `nuc build` (which runs preflight checks
// and emits PKG-3 if it sees a wildcard in Nucleor.toml — when that
// path is wired post-Lane-3).

fn main() -> i64 {
    // Stub source. The PKG-3 emit comes from the package-resolver
    // pre-pass, not from this file's body. Lane 3 leaves the
    // wired-emit-path question open as cross-lane (Lane 7 owns
    // package-resolver UX / docs).
    return 0;
}
