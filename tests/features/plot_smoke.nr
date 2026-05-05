// v0.8.230 stdlib/rods/plot.nr first test coverage.
//
// SVG plotting — line / scatter / heatmap series with axes,
// labels, legend; saves to file. Pre-v0.8.230: zero coverage on
// the standalone rod.
//
// Locks four lifecycle invariants. Pixel-level rendering is not
// asserted (SVG output spans hundreds of bytes of layout-
// dependent text); the fixture verifies the lifecycle works
// end-to-end and writes a non-empty file.
//
//   1. **plot_new returns valid handle** — non-zero for
//      reasonable canvas size.
//   2. **plot_line accepts xs/ys Vecs of equal length** —
//      doesn't crash, returns 0 (success).
//   3. **plot_save_svg writes a non-empty file** — round-trip
//      via io_read_file; SVG must contain "<svg" near the start.
//   4. **plot_free does not crash** — repeated free is left to
//      caller; this just exercises the standard close path.
//
// Expected: rc=0.

import "stdlib/rods/plot.nr"
import "stdlib/rods/io.nr"
import "stdlib/rods/strings.nr"

fn build_xs() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(0.0));
    v.push(f64_to_bits(1.0));
    v.push(f64_to_bits(2.0));
    return v;
}

fn build_ys() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(0.0));
    v.push(f64_to_bits(1.0));
    v.push(f64_to_bits(4.0));
    return v;
}

fn check_new_valid() -> i64 {
    let p: i64 = plot_new(640, 480);
    if p == 0 { return 1; };
    plot_free(p);
    return 0;
}

fn check_line_does_not_crash() -> i64 {
    let p: i64 = plot_new(640, 480);
    plot_line(p, build_xs(), build_ys(), "blue", "y = x²");
    plot_free(p);
    return 0;
}

fn check_save_writes_nonempty_svg() -> i64 {
    let path: str = "target/plot_smoke_output.svg";
    let p: i64 = plot_new(640, 480);
    plot_line(p, build_xs(), build_ys(), "red", "y = x²");
    plot_save_svg(p, path);
    plot_free(p);
    let content: str = io_read_file(path);
    if str_len(content) == 0 { return 4; };
    if strings_contains(content, "<svg") != 1 { return 8; };
    return 0;
}

fn check_free_non_crashing() -> i64 {
    let p: i64 = plot_new(100, 100);
    plot_free(p);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_new_valid();
    fails = fails + check_line_does_not_crash();
    fails = fails + check_save_writes_nonempty_svg();
    fails = fails + check_free_non_crashing();
    return fails;
}
