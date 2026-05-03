// EXPECT: error[ISR-008] `#[isr]` may only be applied to fn items
// err_isr_008_placement_on_struct — v0.6.31 negative fixture (orig.
// ISR-004; renamed to ISR-008 in v0.6.32 because ISR-004 is reserved
// for the planned "Vector name not recognized" diag, RFC-0008 §3.1).
// Closes gap (a) of probe finding 2026-05-02-isr-attr-validation-gaps.
// Pre-fix `#[isr]` on a non-fn item (struct/enum/impl/trait/mod/use/
// const/static/type) was silently dropped on that item AND leaked
// to the next fn in the file, producing a misleading ISR-001 diag
// pointing at the wrong fn (typically `main`). v0.6.31 catches the
// misplaced attribute at the attribute's own source line.
//
// EXPECT: ISR-008 fires; build halts.

#[isr]
struct S { x: i64 }

fn main() -> i32 { print("ok"); 0 }
