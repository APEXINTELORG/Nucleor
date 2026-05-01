// EXPECT: build fails with FMT-003 naming the placeholder count + arg count + dropped count.
// Probe-agent finding 2026-05-01-format-extra-args-silently-dropped:
// pre-v0.5.11 `format!("just {}", 1, 2, 3)` silently dropped args
// 2 and 3 (including any side effects in dropped expressions).
// v0.5.11 mirrors the v0.4.70 placeholder>args check direction so
// both asymmetries halt cleanly.
//
// EXPECT: build fails with error[FMT-003] mentioning placeholder
// count, arg count, dropped count, and the format body.

fn main() -> i32 {
    let s: str = format!("just {}", 1, 2, 3);
    print(s);
    0
}
