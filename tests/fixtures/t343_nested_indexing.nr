// T3.43 (v0.3.68) — regression test for nested-indexing
// (`grid[i][j]`) inline f64 binops. Closes the LAST cell of
// the v0.3.66 composition matrix.
//
// Pre-v0.3.68: `grid[0][0] + grid[1][1]` (where grid:
// Vec<Vec<f64>>) returned -0.0. The v0.3.55 kind==10
// dispatcher couldn't handle a kind 10 OPERAND of indexing —
// it only knew kind 3, kind 9, kind 7. v0.3.68 introduces a
// recursive `indexed_element_full_type` helper that walks the
// operand chain through any number of nested indexings,
// stripping one container layer per level.
//
// Composition matrix CLOSED in both resolvers after v0.3.68:
//
//   Operand kind of indexed expr | binop | expr_struct
//   3 (var ref v[i])             | v0.3.55 | v0.3.59
//   9 (struct field self.s[i])   | v0.3.65 | v0.3.66
//   7 (fn-call make_vec()[i])    | v0.3.67 | v0.3.67
//   10 (nested vv[i][j])         | v0.3.68 | v0.3.68  (this)
//
// Production-relevant: 2D matrices, image data buffers,
// trajectory grids — all use Vec<Vec<f64>> or [[f64; N]; M].
//
// Verify gate (T3.43) asserts both standalone and inline-
// binop nested indexing produce correct values.

fn main() -> i32 {
    let mut row1: Vec<f64> = Vec::new();
    row1.push(1.0);
    row1.push(2.0);
    let mut row2: Vec<f64> = Vec::new();
    row2.push(3.0);
    row2.push(4.0);
    let mut grid: Vec<Vec<f64>> = Vec::new();
    grid.push(row1);
    grid.push(row2);

    // Standalone (worked pre-v0.3.68).
    print_f64(grid[0][0]);                    // 1.0

    // Inline binop on nested indexing — the original bug.
    print_f64(grid[0][0] + grid[1][1]);       // 5.0
    print_f64(grid[1][0] * grid[0][1]);       // 6.0
    print_f64(grid[1][1] - grid[0][0]);       // 3.0

    return 0;
}
