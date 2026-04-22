// _viz.nr — Shared ANSI visualization helpers for the showcase examples.
//
// Provides cursor positioning, 24-bit-safe 256-color palette helpers,
// horizontal bar charts, heatmap palette, and a tiny progress spinner.
// All output is plain text + ANSI escapes, no external deps. Works in
// modern Windows Terminal, PowerShell 7, conhost, and any POSIX terminal.

import "stdlib/rods/complex.nr"

// --- ANSI control --------------------------------------------------------

fn esc() -> str { return chr(27); }     // ESC byte (ANSI prefix)

fn ansi_clear_screen() {
    print(str_concat(esc(), "[2J"));
    print(str_concat(esc(), "[H"));
}

fn ansi_home() {
    print(str_concat(esc(), "[H"));
}

fn ansi_cursor_up(n: i64) -> str {
    return str_concat(esc(), str_concat("[", str_concat(viz_int_to_str(n), "A")));
}

fn ansi_hide_cursor() { print(str_concat(esc(), "[?25l")); }
fn ansi_show_cursor() { print(str_concat(esc(), "[?25h")); }

fn ansi_reset() -> str { return str_concat(esc(), "[0m"); }
fn ansi_bold() -> str { return str_concat(esc(), "[1m"); }
fn ansi_dim() -> str { return str_concat(esc(), "[2m"); }

fn ansi_fg_256(n: i64) -> str {
    return str_concat(esc(), str_concat("[38;5;", str_concat(viz_int_to_str(n), "m")));
}

fn ansi_bg_256(n: i64) -> str {
    return str_concat(esc(), str_concat("[48;5;", str_concat(viz_int_to_str(n), "m")));
}

// Common named colors (256-color palette indices)
fn col_red()    -> str { return ansi_fg_256(196); }
fn col_green()  -> str { return ansi_fg_256(46); }
fn col_yellow() -> str { return ansi_fg_256(226); }
fn col_blue()   -> str { return ansi_fg_256(33); }
fn col_cyan()   -> str { return ansi_fg_256(51); }
fn col_grey()   -> str { return ansi_fg_256(244); }
fn col_white()  -> str { return ansi_fg_256(255); }
fn col_orange() -> str { return ansi_fg_256(208); }

fn paint(s: str, color: str) -> str {
    return str_concat(color, str_concat(s, ansi_reset()));
}

// --- Heatmap palette -----------------------------------------------------
// Cool-to-hot gradient using the 256-color cube.
// Input: t in [0, 1]. Output: ANSI 256-color foreground escape.
fn viz_heat(t: i64) -> str {
    // 7-step palette: deep blue, blue, cyan, green, yellow, orange, red
    let palette: i64 = vec_new();
    vec_push(palette, 17);   // dark blue
    vec_push(palette, 27);   // blue
    vec_push(palette, 39);   // cyan
    vec_push(palette, 46);   // green
    vec_push(palette, 226);  // yellow
    vec_push(palette, 208);  // orange
    vec_push(palette, 196);  // red

    let n_steps: i64 = vec_len(palette);
    let mut idx: i64 = f64_to_int(f64_floor(f64_mul(t, f64_from_int(n_steps - 1))));
    if idx < 0 { idx = 0; };
    if idx >= n_steps { idx = n_steps - 1; };
    return ansi_fg_256(vec_get(palette, idx));
}

// Greyscale gradient using the 24 grey shades 232-255.
fn viz_grey(t: i64) -> str {
    let mut idx: i64 = f64_to_int(f64_floor(f64_mul(t, f64_from_int(23))));
    if idx < 0 { idx = 0; };
    if idx > 23 { idx = 23; };
    return ansi_fg_256(232 + idx);
}

// Pick a unicode block character by intensity (denser = higher t)
fn viz_block(t: i64) -> str {
    if f64_lt(t, f64(0, 125000)) == 1 { return " "; };
    if f64_lt(t, f64(0, 250000)) == 1 { return "."; };
    if f64_lt(t, f64(0, 375000)) == 1 { return ":"; };
    if f64_lt(t, f64(0, 500000)) == 1 { return "+"; };
    if f64_lt(t, f64(0, 625000)) == 1 { return "*"; };
    if f64_lt(t, f64(0, 750000)) == 1 { return "x"; };
    if f64_lt(t, f64(0, 875000)) == 1 { return "%"; };
    return "#";
}

// Combined: paint a heatmap cell — dense block + heat color
fn viz_heat_cell(t: i64) -> str {
    return paint(viz_block(t), viz_heat(t));
}

// --- Bar charts ----------------------------------------------------------

// Horizontal bar of length width filled to value/max.
// Returns a colored ANSI string.
fn viz_bar(value: i64, max_val: i64, width: i64, color: str) -> str {
    let mut frac: i64 = f64_div(value, max_val);
    if f64_lt(frac, f64_from_int(0)) == 1 { frac = f64_from_int(0); };
    if f64_gt(frac, f64_from_int(1)) == 1 { frac = f64_from_int(1); };
    let filled: i64 = f64_to_int(f64_floor(f64_mul(frac, f64_from_int(width))));
    let mut out: str = color;
    let mut i: i64 = 0;
    while i < filled { out = str_concat(out, "#"); i = i + 1; };
    out = str_concat(out, ansi_dim());
    while i < width { out = str_concat(out, "."); i = i + 1; };
    out = str_concat(out, ansi_reset());
    return out;
}

// --- Box drawing ---------------------------------------------------------

fn viz_box_top(w: i64) -> str {
    let mut s: str = "+";
    let mut i: i64 = 0;
    while i < w { s = str_concat(s, "-"); i = i + 1; };
    return str_concat(s, "+");
}

fn viz_box_bottom(w: i64) -> str { return viz_box_top(w); }

fn viz_box_line(content: str, w: i64) -> str {
    let mut s: str = str_concat("| ", content);
    let used: i64 = str_len(content) + 2;
    let mut i: i64 = used;
    while i < w + 1 { s = str_concat(s, " "); i = i + 1; };
    return str_concat(s, "|");
}

// --- Number formatting (local helpers, no clash with rod-defined ones) --

fn viz_int_to_str(n: i64) -> str {
    if n == 0 { return "0"; };
    let mut s: str = ""; let mut v: i64 = n;
    if v < 0 { v = 0 - v; };
    while v > 0 { let d: i64 = v - (v / 10) * 10; s = str_concat(str_substring("0123456789", d, d + 1), s); v = v / 10; };
    if n < 0 { s = str_concat("-", s); };
    return s;
}

// Format f64 (bitcast i64) with `decimals` fractional digits.
fn viz_f64_str(val: i64, decimals: i64) -> str {
    let is_neg: i64 = f64_lt(val, f64_from_int(0));
    let av: i64 = f64_abs(val);
    let ip: i64 = f64_to_int(f64_floor(av));
    let frac: i64 = f64_sub(av, f64_from_int(ip));
    // Build the scale 10^decimals
    let mut scale: i64 = 1;
    let mut k: i64 = 0;
    while k < decimals { scale = scale * 10; k = k + 1; };
    let fs: i64 = f64_to_int(f64_floor(f64_mul(frac, f64_from_int(scale))));
    let mut fstr: str = viz_int_to_str(fs);
    while str_len(fstr) < decimals { fstr = str_concat("0", fstr); };
    let mut r: str = str_concat(viz_int_to_str(ip), str_concat(".", fstr));
    if is_neg == 1 { r = str_concat("-", r); };
    return r;
}

// Right-pad a string to a target width.
fn viz_pad_right(s: str, width: i64) -> str {
    let mut out: str = s;
    let mut i: i64 = str_len(s);
    while i < width { out = str_concat(out, " "); i = i + 1; };
    return out;
}

// Left-pad a string to a target width.
fn viz_pad_left(s: str, width: i64) -> str {
    let mut out: str = "";
    let mut i: i64 = str_len(s);
    while i < width { out = str_concat(out, " "); i = i + 1; };
    return str_concat(out, s);
}

// Banner header
fn viz_banner(title: str, subtitle: str) {
    let w: i64 = 70;
    print(paint(viz_box_top(w), col_cyan()));
    print(paint(viz_box_line(title, w), col_cyan()));
    if str_len(subtitle) > 0 {
        print(paint(viz_box_line(subtitle, w), col_grey()));
    };
    print(paint(viz_box_bottom(w), col_cyan()));
}
