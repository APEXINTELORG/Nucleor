// =====================================================
// rods/geom — Computational Geometry (2D)
// =====================================================
// Import: import "stdlib/rods/geom.nr"
// Provides: convex hull, point-in-polygon, line-segment
//   intersection, polygon area, closest pair, bounding box,
//   point-to-line-segment distance.
// =====================================================

#cfile "../runtime/geom_rt.c"

extern fn nuc_geom_convex_hull_2d(points: i64) -> i64;
extern fn nuc_geom_point_in_polygon(px: i64, py: i64, poly: i64) -> i64;
extern fn nuc_geom_line_intersect(a1x: i64, a1y: i64, a2x: i64, a2y: i64, b1x: i64, b1y: i64, b2x: i64, b2y: i64) -> i64;
extern fn nuc_geom_polygon_area(poly: i64) -> i64;
extern fn nuc_geom_closest_pair(points: i64) -> i64;
extern fn nuc_geom_bbox(points: i64) -> i64;
extern fn nuc_geom_distance_point_line(px: i64, py: i64, ax: i64, ay: i64, bx: i64, by: i64) -> i64;

fn geom_convex_hull(points: i64) -> i64 { return nuc_geom_convex_hull_2d(points); }
fn geom_point_in_polygon(px: i64, py: i64, poly: i64) -> i64 { return nuc_geom_point_in_polygon(px, py, poly); }
fn geom_line_intersect(a1x: i64, a1y: i64, a2x: i64, a2y: i64, b1x: i64, b1y: i64, b2x: i64, b2y: i64) -> i64 {
    return nuc_geom_line_intersect(a1x, a1y, a2x, a2y, b1x, b1y, b2x, b2y);
}
fn geom_polygon_area(poly: i64) -> i64 { return nuc_geom_polygon_area(poly); }
fn geom_closest_pair(points: i64) -> i64 { return nuc_geom_closest_pair(points); }
fn geom_bbox(points: i64) -> i64 { return nuc_geom_bbox(points); }
fn geom_distance_point_line(px: i64, py: i64, ax: i64, ay: i64, bx: i64, by: i64) -> i64 {
    return nuc_geom_distance_point_line(px, py, ax, ay, bx, by);
}
