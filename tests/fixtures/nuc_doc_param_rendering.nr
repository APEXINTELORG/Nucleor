//! Module-level doc test fixture for v0.4.165 + v0.4.166 RFC-0029
//! follow-on. This `//!` block is recognized by `nuc doc` as the
//! crate intro and rendered between the title and function index.
//!
//! Multi-paragraph support: blank lines between `//!` lines preserve
//! as paragraph breaks in both markdown and HTML output.

// v0.4.165 RFC-0029: per-parameter rendering. `nuc doc` now emits a
// **Parameters:** bulleted list and a **Returns:** line for every fn
// (markdown + HTML). Closes the param-rendering deferral from the
// v0.2 RFC-0029 skeleton ship.
//
// v0.4.166: also emits the `//!` module-doc block above as the intro.
//
// This is a fixture for `tests/fixtures/` (not auto-run by verify).
// To exercise: `nuc doc tests/fixtures/nuc_doc_param_rendering.nr --out /tmp/out.md`
// Expect: each fn block contains:
//   - **Parameters:** with `- `name: type`` lines
//   - **Returns:** with `<type>` (or absent for void return)

/// Adds two integers, returning the sum. Two's-complement
/// wrapping on overflow.
fn add(a: i64, b: i64) -> i64 { return a + b; }

/// Zero-parameter constant. Used to verify zero-arg rendering
/// emits only a Returns block, not an empty Parameters block.
fn answer() -> i32 { return 42; }

/// Higher-order function: applies an i64-typed callable to a value.
fn apply(f: i64, x: i64) -> i64 { return f(x); }

/// Generic-parameter signature with nested `<>` to verify the
/// param splitter respects nested angle brackets.
fn first_or_zero(items: Vec<i32>, fallback: i64) -> i64 {
    if items.len() > 0 { return items.get(0); };
    return fallback;
}

fn main() -> i32 {
    print_int(add(3, 4));
    print_int(answer());
    0
}
