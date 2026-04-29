# Parallel Agent — Spike Integration Blockers

**STATUS (2026-04-29): all 5 spikes integrated.**

| Spike | Tag | Result |
|---|---|---|
| v04-string-basic | v0.4.114 | clean rebase, 1st pass |
| v04-question-from | v0.4.115 | clean rebase, 1st pass |
| v04-fnmut-capture | v0.4.116 | clean rebase, 1st pass |
| v04-trait-objects | v0.4.118 | 2nd pass — needed `-X theirs` rebase + manual `prog` arg patch on call-site I added in v0.4.117 |
| v04-pattern-matching | v0.4.120 | 2nd pass — agent fixed the TYP-010 over-fire on Result/Option Err arms; clean rebase |

Audit doc-#1 §3 (From/Into), §5 (rich patterns), §7 (FnMut),
§9 (trait objects) all closed; string_basic feature shipped;
the `_unimplemented/` directory is now empty.

---

# Original blockers (resolved — kept for history)


Written by the main-line agent during integration sweep. Two spikes
won't merge cleanly because of regressions on existing fixtures.
Both rebase OK structurally; both produce broken builds when their
new logic runs over the existing test suite.

## spike/v04-pattern-matching (HEAD `8977464`)

**Blocker: new `TYP-010` "tuple/slice patterns require a known
non-scalar scrutinee" misfires on `Err(e)` arms of `Result<T, E>`.**

Repro after rebase onto current main:

```nucleor
// tests/features/option_result_f64.nr (existing fixture)
let v1: f64 = match ok {
    Ok(x)  => x,
    Err(e) => 0.0,   // <- TYP-010 fires here
};
```

Diagnostic emitted:

```
error[TYP-010]: struct pattern type mismatch:
  expected Err but scrutinee is Result<f64, i32>
```

Fix direction: the new TYP-010 check needs to recognize that
`Result<T, E>` (and `Option<T>`) IS a non-scalar tag/payload
type — Nucleor's i64-everywhere ABI represents both as a
`Vec<i32>`-backed (tag, payload) cell. The check is correct in
spirit (block scalar scrutinees from tuple/slice destructure)
but the predicate needs to whitelist `Result` / `Option` arm
patterns — those resolve via the existing kind-12 enum-variant
path, not the new tuple/slice path.

Validation harness: parallel verify lost
`tests/features/option_result_f64.nr` after rebase
(168 PASS / 3 FAIL vs baseline 167 PASS / 2 FAIL).

## spike/v04-trait-objects — INTEGRATED v0.4.118 (was blocker)

Resolved in 2nd-pass merge. Two fixes:
1. Used `git rebase -X theirs` to take spike's full compiler.nr
   wholesale (auto-merge had been dropping the agent's
   `type_expr` signature changes mid-call-site).
2. Added the new `prog: i64` arg to my v0.4.117 `type_expr`
   call inside `lift_undefined_fn_link_errors`'s sibling
   call-arg walker (line 11355). Auto-merge missed it because
   that call-site was added in main AFTER the spike branched.

Positive fixture t368 returns 47 as expected. Negative fixture
TYP-008-rejects when no impl exists. 169 PASS / 2 baseline-FAIL.

## spike/v04-trait-objects (HEAD `4c1f257`) — HISTORICAL

**Original blocker (resolved): the new context-aware
`Box<Concrete>` → `Box<dyn Trait>` coercion check fails to
find a registered impl even when `impl Trait for Concrete`
is in the program.**

Repro after rebase onto current main:

```nucleor
// tests/fixtures/t368_dyn_keyword_parse.nr (positive fixture
// the spike SHIPPED to pin behavior)
trait Greet { fn hello(self) -> i64; }
struct A { n: i64 }
impl Greet for A { fn hello(self) -> i64 { return self.n; } }

fn take_greet(_g: Box<dyn Greet>) -> i64 { return 5; }

fn main() -> i64 {
    let _b: Box<dyn Greet> = Box::new(A { n: 7 });   // <- TYP-008
    return take_greet(Box::new(A { n: 8 }));         // <- TYP-006
}
```

Diagnostic:

```
error[TYP-008]: type mismatch for binding '_b'
error[TYP-006]: argument type mismatch in call to 'take_greet'
```

The negative fixture (`tests/err/err_box_dyn_missing_impl.nr`)
correctly rejects `Box<B>` → `Box<dyn Greet>` when no impl
exists — so the strict path works. The bug is on the lookup
side: the impl registry isn't seeing `impl Greet for A`.

Fix direction: audit the impl-table key the new check uses
against the key under which `collect_impls` registers
`impl Trait for Type`. Likely a string-mangling mismatch
(`Greet__A` vs `A__Greet` or similar).

Validation harness: parallel verify still passes (negative
fixture exercises the rejection path) but the t368 positive
fixture in `tests/fixtures/` (NOT auto-run by verify) fails
the manual smoke I ran at integration time.

## Successfully integrated this round

| Spike | Tag | Notes |
|-------|-----|-------|
| v04-string-basic | v0.4.114 | clean rebase |
| v04-question-from | v0.4.115 | clean rebase |
| v04-fnmut-capture | v0.4.116 | clean rebase |

## Coordination notes

- Versions v0.4.107, .109, .110, .112 in spike commit messages were
  labels, not tags — those tag numbers belong to the main-line
  silent-miscompute / cryptic-error closes I've shipped. Use the
  next free tag number when re-publishing (currently v0.4.117+).
- The rebase + bootstrap-fixed-point + drift-gate pattern is
  documented in the v0.4.114/115/116 commit messages; replicate
  that flow before pushing the next spike round.
- Touch `bin/nucleor.exe` and `bootstrap/nucleor_s1_seed.ll` only
  via re-emit (rebuild compiler with the rebased source, then
  copy `target/nucleor.{exe,ll}` over the seed). Don't ship a
  spike with a stale seed — T1.7 will fail and so will every
  subsequent rebase.
- File locks on `bin/nucleor.exe` (Windows) bite during rebase
  — when `git rebase --abort` errors with "unable to unlink",
  `rm -f bin/nucleor.exe && sleep 2 && git rebase --abort` works.
