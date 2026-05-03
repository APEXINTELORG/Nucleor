// EXPECT: ERROR: `#[cfg(...)]` and `#[cfg_attr(...)]` attributes are not yet supported
//
// v0.6.25 (probe finding 2026-05-01-cfg-attribute-silently-ignored):
// pre-fix `#[cfg(target_os="X")] fn foo() ... #[cfg(not(target_os="X"))] fn foo()`
// silently dropped both attributes at lex time, left both fn definitions
// live, and produced a misleading "duplicate pub fn name across modules"
// PANIC. Single `#[cfg(test)]` items leaked into release builds. Cross-
// platform Rust translation produced unbuildable Nucleor with a wrong-
// error diagnostic.
//
// v0.6.25 fix: clean parse-time halt with workaround pointer (manually
// delete the inactive branch, or move test-only code to a separate file).

#[cfg(target_os="windows")]
fn os_name() -> str { return "windows"; }

#[cfg(not(target_os="windows"))]
fn os_name() -> str { return "other"; }

fn main() -> i32 {
    print(os_name());
    return 0;
}
