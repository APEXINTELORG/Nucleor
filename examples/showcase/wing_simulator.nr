// wing_simulator.nr — Coupled aerodynamic + electromagnetic simulator.
//
// 2D Lattice Boltzmann fluid flow around an airfoil cross-section,
// simultaneously simulated under FDTD electromagnetics, sharing the same
// geometry. Animated color heatmaps of density and EM field intensity.
//
// What other ecosystems need:
//   OpenFOAM (~1 GB) for the fluid + Meep for the EM + a custom mesh
//   bridge + Python orchestrator + matplotlib for visualization.
// What Nucleor needs:
//   This file.
//
// Build: nuc build examples/showcase/wing_simulator.nr -o wing_simulator
// Run:   target\wing_simulator.exe
// Best viewed in a 120x40 terminal with 256-color support.

import "stdlib/rods/fluid.nr"
import "stdlib/rods/emag.nr"
import "stdlib/rods/complex.nr"
import "examples/showcase/_viz.nr"

// --- Airfoil geometry ----------------------------------------------------
// Simple symmetric "lens" airfoil: thicker in the middle, sharp edges.
// y_half(x) = thickness * sin(pi * x)  for x in [0, 1]
fn airfoil_half_thickness(local_x: i64, max_t: i64) -> i64 {
    let arg: i64 = f64_mul(f64_pi(), local_x);
    return f64_mul(max_t, f64_sin(arg));
}

fn point_in_airfoil(px: i64, py: i64,
                    x_origin: i64, chord_len: i64, max_t: i64) -> i64 {
    let local_x: i64 = f64_div(f64_sub(px, x_origin), chord_len);
    if f64_lt(local_x, f64_from_int(0)) == 1 { return 0; };
    if f64_gt(local_x, f64_from_int(1)) == 1 { return 0; };
    let half_h: i64 = airfoil_half_thickness(local_x, max_t);
    if f64_lt(f64_abs(py), half_h) == 1 { return 1; };
    return 0;
}

// --- Field-to-cell rendering --------------------------------------------

// Map raw density (~1.0 in free stream) to [0, 1] color intensity.
// Real LBM density variation is small (a few percent), so scale tightly.
fn density_to_color(d: i64) -> str {
    // Map [0.995, 1.005] -> [0, 1].
    let normalized: i64 = f64_div(f64_sub(d, f64(0, 995000)), f64(0, 10000));
    return viz_heat(normalized);
}

// Vorticity is signed; we use |omega| with a small scale factor.
fn vorticity_to_color(omega: i64) -> str {
    let mag: i64 = f64_abs(omega);
    let normalized: i64 = f64_div(mag, f64(0, 5000));
    return viz_heat(normalized);
}

// Map EM Ez magnitude to [0, 1] color intensity.
fn ez_to_color(ez: i64) -> str {
    let mag: i64 = f64_abs(ez);
    let normalized: i64 = f64_div(mag, f64(0, 200000));
    return viz_heat(normalized);
}

// Render one row of the LBM density field.
fn render_density_row(lbm: i64, Nx: i64, y: i64,
                      x_origin: i64, chord: i64, max_t: i64,
                      Ny: i64) -> str {
    let mut row: str = "";
    let mut x: i64 = 0;
    let py: i64 = f64_from_int(y - Ny / 2);
    while x < Nx {
        let px: i64 = f64_from_int(x);
        if point_in_airfoil(px, py, x_origin, chord, max_t) == 1 {
            // Render the airfoil itself in white
            row = str_concat(row, paint("X", col_white()));
        } else {
            let d: i64 = lbm_get_density(lbm, x, y);
            row = str_concat(row, paint("#", density_to_color(d)));
        };
        x = x + 1;
    };
    return row;
}

// Render one row of the LBM vorticity field (color magnitude).
fn render_vorticity_row(lbm: i64, Nx: i64, y: i64,
                        x_origin: i64, chord: i64, max_t: i64,
                        Ny: i64) -> str {
    let mut row: str = "";
    let mut x: i64 = 0;
    let py: i64 = f64_from_int(y - Ny / 2);
    while x < Nx {
        let px: i64 = f64_from_int(x);
        if point_in_airfoil(px, py, x_origin, chord, max_t) == 1 {
            row = str_concat(row, paint("X", col_white()));
        } else {
            let v: i64 = lbm_get_vorticity(lbm, x, y);
            row = str_concat(row, paint("o", vorticity_to_color(v)));
        };
        x = x + 1;
    };
    return row;
}

// Render one row of the EM Ez field.
fn render_em_row(em: i64, Nx: i64, y: i64,
                 x_origin: i64, chord: i64, max_t: i64,
                 Ny: i64) -> str {
    let mut row: str = "";
    let mut x: i64 = 0;
    let py: i64 = f64_from_int(y - Ny / 2);
    while x < Nx {
        let px: i64 = f64_from_int(x);
        if point_in_airfoil(px, py, x_origin, chord, max_t) == 1 {
            row = str_concat(row, paint("X", col_white()));
        } else {
            let ez: i64 = em_get_Ez(em, x, y);
            row = str_concat(row, paint("*", ez_to_color(ez)));
        };
        x = x + 1;
    };
    return row;
}

// --- Frame rendering ----------------------------------------------------

fn render_frame(lbm: i64, em: i64, Nx: i64, Ny: i64, step: i64,
                x_origin: i64, chord: i64, max_t: i64,
                em_total_energy: i64) {
    print(paint(str_concat("  Step ", str_concat(viz_int_to_str(step),
                str_concat("  |  EM energy: ",
                str_concat(viz_f64_str(em_total_energy, 4),
                "  |  airfoil = X"))))), col_white());
    print(paint("  --- Fluid density (Lattice Boltzmann, D2Q9) ---", col_grey()));
    let mut y: i64 = 0;
    while y < Ny {
        print(str_concat("  ", render_density_row(lbm, Nx, y, x_origin, chord, max_t, Ny)));
        y = y + 1;
    };
    print(paint("  --- Vorticity magnitude ---", col_grey()));
    let mut y2: i64 = 0;
    while y2 < Ny {
        print(str_concat("  ", render_vorticity_row(lbm, Nx, y2, x_origin, chord, max_t, Ny)));
        y2 = y2 + 1;
    };
    print(paint("  --- EM E_z field intensity (FDTD, Yee grid) ---", col_grey()));
    let mut y3: i64 = 0;
    while y3 < Ny {
        print(str_concat("  ", render_em_row(em, Nx, y3, x_origin, chord, max_t, Ny)));
        y3 = y3 + 1;
    };
}

// --- Main ---------------------------------------------------------------

fn main() -> i64 {
    let Nx: i64 = 80;
    let Ny: i64 = 16;

    // Airfoil: x = 16..40 (chord 24), max half-thickness 3
    let x_origin: i64 = f64_from_int(16);
    let chord: i64 = f64_from_int(24);
    let max_t: i64 = f64_from_int(3);

    viz_banner("Coupled Fluid + Electromagnetic Wing Simulator",
               "LBM aerodynamics + FDTD electromagnetics on the SAME geometry");
    print("");
    print(paint("  Two PDE solvers, one airfoil cross-section, one file.", col_grey()));
    print(paint("  Equivalent in the standard stack: OpenFOAM + Meep + glue + matplotlib.", col_grey()));
    print("");

    // Set up fluid
    let lbm: i64 = lbm_new_2d(Nx, Ny, f64(0, 80000));   // viscosity 0.08
    lbm_set_inlet(lbm, f64(0, 60000));                   // 0.06 inflow vel

    // Set up EM
    let em: i64 = em_new_2d(Nx, Ny, f64(0, 100000), f64(0, 1000));
    em_set_source(em, 4, Ny / 2, f64(0, 200000), f64_from_int(1));  // EM transmitter on left

    // Install airfoil obstacle in both solvers
    let mut x: i64 = 0;
    while x < Nx {
        let mut y: i64 = 0;
        while y < Ny {
            let px: i64 = f64_from_int(x);
            let py: i64 = f64_from_int(y - Ny / 2);
            if point_in_airfoil(px, py, x_origin, chord, max_t) == 1 {
                lbm_set_obstacle(lbm, x, y);
                em_set_material(em, x, y, x + 1, y + 1, f64_from_int(1), f64(100, 0));  // metallic
            };
            y = y + 1;
        };
        x = x + 1;
    };

    print(paint("  Airfoil installed in both solvers. Stepping simulation...", col_grey()));
    print("");

    // Settle the simulation
    let mut warm: i64 = 0;
    while warm < 30 { lbm_step(lbm); em_step(em); warm = warm + 1; };

    // Run a sequence of frames
    let n_frames: i64 = 4;
    let steps_per_frame: i64 = 25;
    let mut frame: i64 = 0;
    while frame < n_frames {
        let mut s: i64 = 0;
        while s < steps_per_frame { lbm_step(lbm); em_step(em); s = s + 1; };
        let total_e: i64 = em_energy(em);
        render_frame(lbm, em, Nx, Ny, warm + (frame + 1) * steps_per_frame,
                     x_origin, chord, max_t, total_e);
        print("");
        frame = frame + 1;
    };

    print(paint("  --- simulation complete ---", col_green()));
    print("");
    print(paint("  Heat scale (cool to hot):", col_grey()));
    let mut k: i64 = 0;
    let mut bar: str = "  ";
    while k < 16 {
        let t: i64 = f64_div(f64_from_int(k), f64_from_int(15));
        bar = str_concat(bar, paint("#", viz_heat(t)));
        k = k + 1;
    };
    print(bar);

    lbm_free(lbm);
    em_free(em);
    return 0;
}
