// RFC-0006 — NUCLEOR_DBC_MODE validation.
//
// v0.4.275: probe-agent finding 2026-05-01 — unrecognized
// values like `off` / `disabled` / `0` / `none` silently fell
// into a partial-strip bucket (require ran, ensure/invariant
// stripped — effectively unintended `safe-release`). Adopter
// got no signal that their value was wrong. CONTRACT-009 now
// halts cleanly at compile entry naming the bad value and
// the recognized set.
//
// EXPECT: build with NUCLEOR_DBC_MODE=off fails with CONTRACT-009.
// (Verify gate harness sets the env var before invoking nucleor.exe.)

#[require(x > 0)]
fn pos(x: i64) -> i64 { x }

fn main() -> i32 {
    print_int(pos(5) as i32);
    0
}
