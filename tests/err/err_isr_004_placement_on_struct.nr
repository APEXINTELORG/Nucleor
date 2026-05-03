// EXPECT: error[ISR-004] `#[isr]` may only be applied to fn items
// err_isr_004_placement_on_struct — v0.6.31 negative fixture
// closes gap (a) of probe finding 2026-05-02-isr-attr-validation-gaps.
// Pre-fix `#[isr]` on a non-fn item (struct/enum/impl/trait/mod/use/
// const/static/type) was silently dropped on that item AND leaked
// to the next fn in the file, producing a misleading ISR-001 diag
// pointing at the wrong fn (typically `main`). v0.6.31 catches the
// misplaced attribute at the attribute's own source line.
//
// EXPECT: ISR-004 fires; build halts.

#[isr]
struct S { x: i64 }

fn main() -> i32 { print("ok"); 0 }
