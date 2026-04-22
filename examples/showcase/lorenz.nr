// lorenz.nr — The Lorenz strange attractor + sensitive dependence on
// initial conditions, rendered as a 256-color ASCII heatmap.
//
// Integrate the Lorenz system with classical RK4. Accumulate trajectory
// hits into a 2D occupancy grid. Color cells by visit density.
//
// Two trajectories are tracked in parallel from initial conditions
// separated by 1e-5 in x. By the end of the integration they are O(10)
// units apart — sensitive dependence on initial conditions, the
// fingerprint of chaos.
//
// Lorenz system (sigma=10, rho=28, beta=8/3):
//   dx/dt = sigma * (y - x)
//   dy/dt = x * (rho - z) - y
//   dz/dt = x * y - beta * z
//
// Build: nuc build examples/showcase/lorenz.nr -o lorenz
// Run:   target\lorenz.exe

import "stdlib/rods/complex.nr"
import "examples/showcase/_viz.nr"

fn lrhs_x(x: i64, y: i64, z: i64, sigma: i64) -> i64 {
    return f64_mul(sigma, f64_sub(y, x));
}
fn lrhs_y(x: i64, y: i64, z: i64, rho: i64) -> i64 {
    return f64_sub(f64_mul(x, f64_sub(rho, z)), y);
}
fn lrhs_z(x: i64, y: i64, z: i64, beta: i64) -> i64 {
    return f64_sub(f64_mul(x, y), f64_mul(beta, z));
}

// One classical RK4 step. Updates a Vec [x, y, z] in place.
fn rk4_step(state: i64, sigma: i64, rho: i64, beta: i64, h: i64) {
    let x: i64 = vec_get(state, 0);
    let y: i64 = vec_get(state, 1);
    let z: i64 = vec_get(state, 2);
    let half: i64 = f64(0, 500000);
    let two: i64 = f64_from_int(2);
    let h_half: i64 = f64_mul(h, half);
    let k1x: i64 = lrhs_x(x, y, z, sigma);
    let k1y: i64 = lrhs_y(x, y, z, rho);
    let k1z: i64 = lrhs_z(x, y, z, beta);
    let xm: i64 = f64_add(x, f64_mul(h_half, k1x));
    let ym: i64 = f64_add(y, f64_mul(h_half, k1y));
    let zm: i64 = f64_add(z, f64_mul(h_half, k1z));
    let k2x: i64 = lrhs_x(xm, ym, zm, sigma);
    let k2y: i64 = lrhs_y(xm, ym, zm, rho);
    let k2z: i64 = lrhs_z(xm, ym, zm, beta);
    let xn: i64 = f64_add(x, f64_mul(h_half, k2x));
    let yn: i64 = f64_add(y, f64_mul(h_half, k2y));
    let zn: i64 = f64_add(z, f64_mul(h_half, k2z));
    let k3x: i64 = lrhs_x(xn, yn, zn, sigma);
    let k3y: i64 = lrhs_y(xn, yn, zn, rho);
    let k3z: i64 = lrhs_z(xn, yn, zn, beta);
    let xp: i64 = f64_add(x, f64_mul(h, k3x));
    let yp: i64 = f64_add(y, f64_mul(h, k3y));
    let zp: i64 = f64_add(z, f64_mul(h, k3z));
    let k4x: i64 = lrhs_x(xp, yp, zp, sigma);
    let k4y: i64 = lrhs_y(xp, yp, zp, rho);
    let k4z: i64 = lrhs_z(xp, yp, zp, beta);
    let sixth: i64 = f64_div(h, f64_from_int(6));
    let nx: i64 = f64_add(x, f64_mul(sixth, f64_add(k1x, f64_add(f64_mul(two, k2x), f64_add(f64_mul(two, k3x), k4x)))));
    let ny: i64 = f64_add(y, f64_mul(sixth, f64_add(k1y, f64_add(f64_mul(two, k2y), f64_add(f64_mul(two, k3y), k4y)))));
    let nz: i64 = f64_add(z, f64_mul(sixth, f64_add(k1z, f64_add(f64_mul(two, k2z), f64_add(f64_mul(two, k3z), k4z)))));
    vec_set(state, 0, nx);
    vec_set(state, 1, ny);
    vec_set(state, 2, nz);
}

fn main() -> i64 {
    let sigma: i64 = f64_from_int(10);
    let rho: i64 = f64_from_int(28);
    let beta: i64 = f64_div(f64_from_int(8), f64_from_int(3));
    let h: i64 = f64(0, 5000);          // 0.005 s timestep
    let n_steps: i64 = 12000;

    let width: i64 = 80;
    let height: i64 = 24;
    let cells: i64 = width * height;

    viz_banner("The Lorenz Attractor",
               "12000 RK4 steps  -  sigma=10  rho=28  beta=8/3");
    print("");
    print(paint("  Two initial conditions separated by 1e-5 in x.", col_grey()));
    print(paint("  Watch them diverge under chaotic dynamics.", col_grey()));
    print("");

    // Initialize states
    let stateA: i64 = vec_new();
    vec_push(stateA, f64_from_int(1));
    vec_push(stateA, f64_from_int(1));
    vec_push(stateA, f64_from_int(1));
    let stateB: i64 = vec_new();
    vec_push(stateB, f64(1, 10));   // 1 + 10/1e6 = 1.00001
    vec_push(stateB, f64_from_int(1));
    vec_push(stateB, f64_from_int(1));

    // Occupancy grids — one per trajectory.
    let gridA: i64 = vec_new();
    let gridB: i64 = vec_new();
    let mut k: i64 = 0;
    while k < cells { vec_push(gridA, 0); vec_push(gridB, 0); k = k + 1; };

    // Track maximum 3D separation
    let mut max_sep_sq: i64 = f64_from_int(0);

    // CSV log: sample every 60th step to keep the file ~200 rows
    let csv: i64 = sb_new();
    sb_append(csv, "step,t,ax,ay,az,bx,by,bz,separation\n");

    let mut step: i64 = 0;
    while step < n_steps {
        rk4_step(stateA, sigma, rho, beta, h);
        rk4_step(stateB, sigma, rho, beta, h);

        // Sample every 60th step to the CSV
        if step - (step / 60) * 60 == 0 {
            let dxa: i64 = f64_sub(vec_get(stateB, 0), vec_get(stateA, 0));
            let dya: i64 = f64_sub(vec_get(stateB, 1), vec_get(stateA, 1));
            let dza: i64 = f64_sub(vec_get(stateB, 2), vec_get(stateA, 2));
            let sep_sq_now: i64 = f64_add(f64_add(f64_mul(dxa, dxa), f64_mul(dya, dya)), f64_mul(dza, dza));
            let sep_now: i64 = f64_sqrt(sep_sq_now);
            let t_now: i64 = f64_mul(f64_from_int(step), h);
            sb_append(csv, viz_int_to_str(step));         sb_append(csv, ",");
            sb_append(csv, viz_f64_str(t_now, 4));        sb_append(csv, ",");
            sb_append(csv, viz_f64_str(vec_get(stateA, 0), 6)); sb_append(csv, ",");
            sb_append(csv, viz_f64_str(vec_get(stateA, 1), 6)); sb_append(csv, ",");
            sb_append(csv, viz_f64_str(vec_get(stateA, 2), 6)); sb_append(csv, ",");
            sb_append(csv, viz_f64_str(vec_get(stateB, 0), 6)); sb_append(csv, ",");
            sb_append(csv, viz_f64_str(vec_get(stateB, 1), 6)); sb_append(csv, ",");
            sb_append(csv, viz_f64_str(vec_get(stateB, 2), 6)); sb_append(csv, ",");
            sb_append(csv, viz_f64_str(sep_now, 6));      sb_append(csv, "\n");
        };

        if step > 200 {
            // Project to grid (x in [-25, 25], z in [0, 50])
            let ax: i64 = vec_get(stateA, 0);
            let az: i64 = vec_get(stateA, 2);
            let nxa: i64 = f64_div(f64_add(ax, f64_from_int(25)), f64_from_int(50));
            let nza: i64 = f64_div(az, f64_from_int(50));
            let mut ca: i64 = f64_to_int(f64_floor(f64_mul(nxa, f64_from_int(width - 1))));
            let mut ra: i64 = f64_to_int(f64_floor(f64_mul(nza, f64_from_int(height - 1))));
            if ca < 0 { ca = 0; }; if ca >= width { ca = width - 1; };
            if ra < 0 { ra = 0; }; if ra >= height { ra = height - 1; };
            let idxA: i64 = (height - 1 - ra) * width + ca;
            vec_set(gridA, idxA, vec_get(gridA, idxA) + 1);

            let bx: i64 = vec_get(stateB, 0);
            let bz: i64 = vec_get(stateB, 2);
            let nxb: i64 = f64_div(f64_add(bx, f64_from_int(25)), f64_from_int(50));
            let nzb: i64 = f64_div(bz, f64_from_int(50));
            let mut cb: i64 = f64_to_int(f64_floor(f64_mul(nxb, f64_from_int(width - 1))));
            let mut rb: i64 = f64_to_int(f64_floor(f64_mul(nzb, f64_from_int(height - 1))));
            if cb < 0 { cb = 0; }; if cb >= width { cb = width - 1; };
            if rb < 0 { rb = 0; }; if rb >= height { rb = height - 1; };
            let idxB: i64 = (height - 1 - rb) * width + cb;
            vec_set(gridB, idxB, vec_get(gridB, idxB) + 1);

            // Track separation
            let dx: i64 = f64_sub(vec_get(stateB, 0), vec_get(stateA, 0));
            let dy: i64 = f64_sub(vec_get(stateB, 1), vec_get(stateA, 1));
            let dz: i64 = f64_sub(vec_get(stateB, 2), vec_get(stateA, 2));
            let sep_sq: i64 = f64_add(f64_add(f64_mul(dx, dx), f64_mul(dy, dy)), f64_mul(dz, dz));
            if f64_gt(sep_sq, max_sep_sq) == 1 { max_sep_sq = sep_sq; };
        };
        step = step + 1;
    };

    // Find max counts for normalization
    let mut maxA: i64 = 1;
    let mut maxB: i64 = 1;
    let mut q: i64 = 0;
    while q < cells {
        if vec_get(gridA, q) > maxA { maxA = vec_get(gridA, q); };
        if vec_get(gridB, q) > maxB { maxB = vec_get(gridB, q); };
        q = q + 1;
    };

    // Render trajectory A
    print(paint("  Trajectory A (initial x = 1.00000):", col_cyan()));
    print("");
    let mut ridx: i64 = 0;
    while ridx < height {
        let mut row_str: str = "  ";
        let mut cidx: i64 = 0;
        while cidx < width {
            let count: i64 = vec_get(gridA, ridx * width + cidx);
            if count == 0 {
                row_str = str_concat(row_str, " ");
            } else {
                let intensity: i64 = f64_div(f64_from_int(count), f64_from_int(maxA));
                row_str = str_concat(row_str, viz_heat_cell(intensity));
            };
            cidx = cidx + 1;
        };
        print(row_str);
        ridx = ridx + 1;
    };
    print("");

    // Render trajectory B
    print(paint("  Trajectory B (initial x = 1.00001):", col_yellow()));
    print("");
    let mut ridx2: i64 = 0;
    while ridx2 < height {
        let mut row_str2: str = "  ";
        let mut cidx2: i64 = 0;
        while cidx2 < width {
            let count2: i64 = vec_get(gridB, ridx2 * width + cidx2);
            if count2 == 0 {
                row_str2 = str_concat(row_str2, " ");
            } else {
                let intensity2: i64 = f64_div(f64_from_int(count2), f64_from_int(maxB));
                row_str2 = str_concat(row_str2, viz_heat_cell(intensity2));
            };
            cidx2 = cidx2 + 1;
        };
        print(row_str2);
        ridx2 = ridx2 + 1;
    };
    print("");

    // Final separation
    let max_sep: i64 = f64_sqrt(max_sep_sq);
    print(paint("  --- divergence summary ---", col_grey()));
    print(str_concat("  initial 3D separation:  ", viz_f64_str(f64(0, 10), 6)));
    print(str_concat("  maximum 3D separation:  ", viz_f64_str(max_sep, 6)));
    print("");
    file_write_string("lorenz_data.csv", sb_to_str(csv));
    print(paint("  Wrote ~200 sampled trajectory rows to lorenz_data.csv", col_grey()));
    print("");
    print(paint("  Two trajectories started 0.00001 apart end up O(10) apart.", col_yellow()));
    print(paint("  This is sensitive dependence on initial conditions.", col_yellow()));
    print(paint("  Both grids have the SAME shape (the strange attractor).", col_grey()));
    print(paint("  The points along it visit at uncorrelated times.", col_grey()));
    return 0;
}
