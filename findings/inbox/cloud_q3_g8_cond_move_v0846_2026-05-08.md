# Q3 — G-8 Phase 2b/3/4 conditional-divergence move-state join (OWN-G8-COND-MOVE)

**Branch:** `claude/v1-finish-cloud-Q3-g8-cond-move`
**Base:** `origin/main @ 083b3df` (Q1 already landed at b6b55ae; Q2 still on its own branch awaiting fast-forward)
**Host:** `Linux vm 6.18.5 #2 SMP PREEMPT_DYNAMIC Wed Jan 14 17:56:08 UTC 2026 x86_64`
**Tools:** `clang Ubuntu-18.1.3`
**Mandate:** `CLOUD_AGENT_V1_FINISH_BRIEF_2026-05-07.md` Q3 row.
**Plan ref:** `docs/rfcs/RFC-0062-IMPLEMENTATION-PLAN.md` G-8 row, lines 181-193.

## Bug shape (the gap this closes)

Per the brief: "Today's transitive-handoff fix recognizes wrapper-fn moves
but doesn't reconcile divergent move state across `if/else` branches."
And per RFC-0062 §3.3 G-8: `if cond { take(v) } else { borrow(&v) }` —
one path moves, the other borrows. After the if, `v` is partially
consumed. Today the tracker doesn't reason about it precisely.

What today's `own_merge_moved` (line ~19398) does: "if a variable is
moved in either branch, mark it moved." That's the conservative
all-or-nothing tainting. Subsequent reads then fire OWN-001 ("use of
moved variable"). But the diagnostic is wrong-classification: the
binding is *conditionally* moved, not definitely moved. The brief
wants OWN-G8-COND-MOVE to communicate the divergence precisely.

Phase 2b spec: "compute the join lattice at merge points: any value
moved on one arm but not the other → 'conditionally moved', subsequent
use → diagnostic OWN-G8-COND-MOVE." Phase 4 promotes to error.

## Patch shape

Three additive edits to `compiler/nucleor_s1_compiler.nr`:

1. **Diagnostic registration** (line ~11150). Add `OWN-G8-COND-MOVE`
   to `is_error_code`. Phase 4 promotion via `own_diag` (always emits
   at error severity).

2. **Refined `own_merge_moved`** (line ~19398). New move-state lattice
   on state keys (prefix `__os_`):
   - both arms moved (va == 2 && vb == 2) → state = 2 (OWN-001 catches subsequent read)
   - exactly one arm moved (va == 2 XOR vb == 2) → state stays at pre-arm value, set the cond-moved flag (`__g8_cond_moved_<name>`)
   - neither moved → preserve pre-arm state (no-op)

   Non-state keys keep the legacy "if either arm has value 2, set
   value 2" semantics so any tracker that piggy-backed on this loop
   is unaffected. (In the seed compiler today, no other tracker uses
   the value 2 sentinel on non-state keys; this is just safety belt.)

3. **Cond-moved check in kind-3 read** (`check_expr`, line ~19461,
   *before* the existing OWN-001 use-of-moved branch). Read the
   `__g8_cond_moved_<name>` flag; if set, emit OWN-G8-COND-MOVE at
   error severity citing both possible behaviors (move on every arm
   or no arm). Returns immediately so OWN-001 doesn't double-fire on
   the same node.

The flag is per-fn (lives on the `own` env that's reset per
`check_fn`). Match-arm processing (line ~20084) is left to its
existing per-arm behavior in this Q — the brief's specific example is
if/else and the Phase 2b ship is sound on that. Match-arm
join-lattice is a follow-up if Q3 review reveals cases.

## Validation

### Bootstrap fixed-point

```
seed pre-Q3:    bdb173ebdd7aefc4fd8ed613386934878e8ca503e6f92b38a40aec3de566730f
                (Q1-landed baseline — md5 77096a38ec8038468c202380ca246e8a)
seed post-Q3:   15481d4e0a9485184bed2f76fa3b09dc14dce773a4a8753102730bb8c856e2ad
```

Single seed refresh. Stage-1 and stage-2 IR converge at the new
sha256. Stage-2 self-rebuild compiled clean — none of the seed
compiler's existing if/else patterns trigger OWN-G8-COND-MOVE,
confirming the lattice change is sound on the existing source.

### `bash tools/verify.sh`

**PASS=1485 / SKIP=8 / FAIL=0 across 1493 steps.** (8th SKIP is the
new PROBE-2 ML pipeline opt-in step gated on `NUC_VERIFY_ML_PROBE=1`,
not a regression.) Full log:
`findings/inbox/cloud_q3_g8_cond_move_v0846_2026-05-08_default.log`.

### `bash tools/verify_strict.sh`

**PASS=1485 / SKIP=8 / FAIL=0 across 1493 steps.** Cache-cold +
`NUC_VERIFY_STRICT=1`. Full log:
`findings/inbox/cloud_q3_g8_cond_move_v0846_2026-05-08_strict.log`.

### Fixtures

- **Positive lock-in:**
  `tests/features/g8_both_arms_consume_or_neither_ok.nr` — neither
  arm moves `b`, post-join read prints `7`. Compiles and runs
  cleanly.
- **Negative — cond-move:** `tests/err/err_own_g8_cond_move_if_else.nr`
  — then-arm moves `b` into `consume`; else-arm reads `b.v`. Post-
  join read of `b.v` triggers
  `error[OWN-G8-COND-MOVE]: conditional move of 'b': value is moved
  on one arm of the preceding if/else but not the other...`

### Existing OWN-001 / move-state semantics unaffected

When *both* arms move a binding, state is still set to 2 and OWN-001
fires on subsequent reads — same as before. The new lattice only
changes behavior in the divergent case (where pre-Phase-2b OWN-001
incorrectly fired with the wrong classification).

### Audit-report regen

`tools/audit_dup_fns_report.csv`: only delta is the `check_expr`
line-count column (393 → 406 reflecting the new cond-moved block).
Per-bucket totals unchanged: 30 IDENTICAL / 131 SIG_MATCH_BODY_DIFFERS
/ 19 SIG_DIFFERS — Q5 inventory still aligned.

## Per-step timing notes

T1.7 (bootstrap seed match) and T1.8 (self-host fixed-point) both
within noise vs Q1 baseline. PROBE-1 driver within noise. No step
exceeded 1.3× its baseline.

## Honesty

- Match-expression (kind 38) processing at line ~20084 still uses
  per-arm `own_restore` without a final merge. That means
  `match cond { 0 => move(v), _ => () }` followed by a read of `v`
  *after* the match doesn't track move-state divergence. This is
  pre-existing behavior. Phase 2b sound on the brief's specific
  example (if/else); match join-lattice is a follow-up if review
  flags it. Filing here per the brief's "name partial-state delta"
  rule rather than silently deferring.
- The cond-moved flag is per-name; aliases (`let w = v;`) aren't
  tracked. Same Phase 3 alias-tracking deferral note as Q2.
- `Vec` / `HashMap` / `String` are Copy at the move-state tracker
  (line 19431), so they don't go through the move-state==2 path
  via positional pass — Q3 doesn't help these. That's exactly the
  Q2 OWN-G4-USE-AFTER-DROP territory, which uses a parallel freed
  flag mechanism. Q3's lattice is for non-Copy types (struct, enum,
  Box, Option, Result, Tensor, DeviceBuffer).

## Done

- All Phase 4 acceptance criteria met. Diagnostic registers, fires
  precisely on the cond-move case, fixtures locked in, both verify
  modes GREEN, fixed-point holds, no regression to OWN-001 / OWN-003
  / OWN-009 / OWN-012 / arena_destroy semantics.

Cumulative cloud queue progress: Q1 landed on main, Q2 + Q3 on their
own branches awaiting fast-forward, Q4 + Q5 next.
