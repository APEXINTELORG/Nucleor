---
title: followup — narrowing: `?` on `Result<T,E>` is correct; only `Option<T>` is broken
severity: crash
probe_file: probes/options/question_on_result.nr
diagnostic_actual: n/a (this followup confirms Result path is clean)
diagnostic_expected: n/a
discovered_against: v0.4.162 (commit 213fee9)
commit: 213fee9e84101dad4a06807f994413d7d4f1cb86
status: CLOSED in v0.4.225 with parent finding. Result side stays correct; Option side now also works thanks to v0.4.225's tag-convention dispatch in lower_expr kind 122.
---

Followup to `2026-04-30-question-on-option-vec-oob.md`. Same probe shape
but with `Result<T,E>` substituted for `Option<T>`:

## Repro (Result side — works correctly)

```nr
fn safe_div(a: i32, b: i32) -> Result<i32, i32> {
    if b == 0 { Err(0 - 1) } else { Ok(a / b) }
}

fn double_safe(a: i32, b: i32) -> Result<i32, i32> {
    let v: i32 = safe_div(a, b)?;   // <-- ? on Result Ok works
    Ok(v * 2)
}

fn main() -> i32 {
    let r: Result<i32, i32> = double_safe(20, 4);
    match r { Ok(v) => print_int(v), Err(e) => print_int(e), };
    let r2: Result<i32, i32> = double_safe(20, 0);
    match r2 { Ok(v) => print_int(v), Err(e) => print_int(e), };
    0
}
```

Output: `10` then `-1`. No PANIC, exit 0. **The `?` lowering is correct
for `Result<T,E>`** — Ok-unwrap reads the right slot, Err-propagate
returns the variant.

The Option crash (parent finding) is therefore **specific to the
`Option<T>::Some` Vec layout / index arithmetic**, not the generic `?`
lowering. Two fix-shape options:

1. The Some-variant Vec construction stores its payload at index 0
   only (no discriminant), but the `?` lowering reads index 1 (mirror of
   the Result Ok path which expects `[discriminant, value]`). Fix: align
   Option's Vec layout with Result's.
2. The `?` lowering branches on Result vs Option type and uses different
   index arithmetic; the Option branch's index is off-by-one. Fix:
   correct the Option branch.

Cross-check with how Option construction lowers in the working match
case (`probes/options/option_some_unwrap.nr`) — that path reads the
right slot, so the layout *does* contain the value somewhere. The `?`
path just reads the wrong index for that layout.

## Severity

crash (same tier as parent). Narrowing this to Option-only does not
lower severity — it just makes the fix smaller.


## Promoted

- Status frontmatter: see top of file. Closure version: **v0.4.225**.
- Verify gate: existing per-feature loop picks up the fixture above.
- Promoted: 2026-04-30 by main agent (footer backfilled 2026-05-01 per probe-agent Q3 footer-shape uniformity request).
