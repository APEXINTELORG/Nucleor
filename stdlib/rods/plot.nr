// =====================================================
// rods/plot — SVG plotting
// =====================================================
// Import: import "stdlib/rods/plot.nr"
// Provides: line / scatter / heatmap series with axis labels and a
//   legend; saves as SVG that opens in any browser.
// =====================================================

#cfile "../runtime/plot_rt.c"

extern fn nuc_plot_new(w: i64, h: i64) -> i64;
extern fn nuc_plot_line(h: i64, xs: i64, ys: i64, color: str, label: str) -> i64;
extern fn nuc_plot_scatter(h: i64, xs: i64, ys: i64, color: str, size: i64) -> i64;
extern fn nuc_plot_heatmap(h: i64, grid: i64, Nx: i64, Ny: i64) -> i64;
extern fn nuc_plot_set_title(h: i64, s: str);
extern fn nuc_plot_set_xlabel(h: i64, s: str);
extern fn nuc_plot_set_ylabel(h: i64, s: str);
extern fn nuc_plot_set_xlim(h: i64, lo: i64, hi: i64);
extern fn nuc_plot_set_ylim(h: i64, lo: i64, hi: i64);
extern fn nuc_plot_legend(h: i64);
extern fn nuc_plot_save_svg(h: i64, path: str);
extern fn nuc_plot_free(h: i64);

fn plot_new(w: i64, h: i64) -> i64 { return nuc_plot_new(w, h); }
fn plot_line(h: i64, xs: i64, ys: i64, color: str, label: str) -> i64 {
    return nuc_plot_line(h, xs, ys, color, label);
}
fn plot_scatter(h: i64, xs: i64, ys: i64, color: str, size: i64) -> i64 {
    return nuc_plot_scatter(h, xs, ys, color, size);
}
fn plot_heatmap(h: i64, grid: i64, Nx: i64, Ny: i64) -> i64 {
    return nuc_plot_heatmap(h, grid, Nx, Ny);
}
fn plot_title(h: i64, s: str) { nuc_plot_set_title(h, s); }
fn plot_xlabel(h: i64, s: str) { nuc_plot_set_xlabel(h, s); }
fn plot_ylabel(h: i64, s: str) { nuc_plot_set_ylabel(h, s); }
fn plot_xlim(h: i64, lo: i64, hi: i64) { nuc_plot_set_xlim(h, lo, hi); }
fn plot_ylim(h: i64, lo: i64, hi: i64) { nuc_plot_set_ylim(h, lo, hi); }
fn plot_legend(h: i64) { nuc_plot_legend(h); }
fn plot_save_svg(h: i64, path: str) { nuc_plot_save_svg(h, path); }
fn plot_free(h: i64) { nuc_plot_free(h); }
