// v0.8.101 stdlib/rods/geom.nr first test coverage.
//
// Per the zero-coverage rod survey, geom.nr (2D computational
// geometry — convex hull, point-in-polygon, line intersect,
// polygon area, distance) had no existing tests. Silent
// regressions in geometric primitives are correctness-critical
// for any spatial pipeline.
//
// Locks textbook 2D-geometry invariants:
//   1. Polygon area of unit square at origin == 1.0.
//   2. Polygon area of 3-4-5 right triangle == 6.0.
//   3. Point-in-polygon: center of unit square IS inside.
//   4. Point-in-polygon: outside point is NOT inside.
//   5. Distance from origin to line y=1 (segment from (0,1) to
//      (5,1)) is 1.0.
//
// Polygons are interleaved [x0, y0, x1, y1, ...] in a
// Vec<i64> of f64-bits.
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/geom.nr"

fn close(a: i64, b: i64) -> i64 {
    let af: f64 = f64_from_bits(a);
    let bf: f64 = f64_from_bits(b);
    let diff: f64 = af - bf;
    let abs_diff: f64 = if diff < 0.0 { 0.0 - diff } else { diff };
    if abs_diff < 1e-9 { return 1; };
    return 0;
}

fn check_area_unit_square() -> i64 {
    let mut p: Vec<i64> = Vec::new();
    p.push(f64_to_bits(0.0)); p.push(f64_to_bits(0.0));
    p.push(f64_to_bits(1.0)); p.push(f64_to_bits(0.0));
    p.push(f64_to_bits(1.0)); p.push(f64_to_bits(1.0));
    p.push(f64_to_bits(0.0)); p.push(f64_to_bits(1.0));
    let area: i64 = geom_polygon_area(p);
    if close(area, f64_to_bits(1.0)) != 1 { return 1; };
    return 0;
}

fn check_area_345_triangle() -> i64 {
    let mut p: Vec<i64> = Vec::new();
    p.push(f64_to_bits(0.0)); p.push(f64_to_bits(0.0));
    p.push(f64_to_bits(4.0)); p.push(f64_to_bits(0.0));
    p.push(f64_to_bits(0.0)); p.push(f64_to_bits(3.0));
    let area: i64 = geom_polygon_area(p);
    // 1/2 * 4 * 3 = 6
    if close(area, f64_to_bits(6.0)) != 1 { return 2; };
    return 0;
}

fn check_point_in_unit_square_inside() -> i64 {
    let mut sq: Vec<i64> = Vec::new();
    sq.push(f64_to_bits(0.0)); sq.push(f64_to_bits(0.0));
    sq.push(f64_to_bits(1.0)); sq.push(f64_to_bits(0.0));
    sq.push(f64_to_bits(1.0)); sq.push(f64_to_bits(1.0));
    sq.push(f64_to_bits(0.0)); sq.push(f64_to_bits(1.0));
    let r: i64 = geom_point_in_polygon(f64_to_bits(0.5), f64_to_bits(0.5), sq);
    if r != 1 { return 4; };
    return 0;
}

fn check_point_outside_unit_square() -> i64 {
    let mut sq: Vec<i64> = Vec::new();
    sq.push(f64_to_bits(0.0)); sq.push(f64_to_bits(0.0));
    sq.push(f64_to_bits(1.0)); sq.push(f64_to_bits(0.0));
    sq.push(f64_to_bits(1.0)); sq.push(f64_to_bits(1.0));
    sq.push(f64_to_bits(0.0)); sq.push(f64_to_bits(1.0));
    let r: i64 = geom_point_in_polygon(f64_to_bits(2.0), f64_to_bits(0.5), sq);
    if r == 1 { return 8; };
    return 0;
}

fn check_distance_to_horizontal_line() -> i64 {
    // Distance from origin (0, 0) to segment (0, 1) - (5, 1).
    // Closest point on segment is (0, 1). Distance = 1.
    let d: i64 = geom_distance_point_line(
        f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(0.0), f64_to_bits(1.0),
        f64_to_bits(5.0), f64_to_bits(1.0));
    if close(d, f64_to_bits(1.0)) != 1 { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_area_unit_square();
    fails = fails + check_area_345_triangle();
    fails = fails + check_point_in_unit_square_inside();
    fails = fails + check_point_outside_unit_square();
    fails = fails + check_distance_to_horizontal_line();
    return fails;
}
