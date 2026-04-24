# Memory architecture overhaul (v0.2.158 → v0.2.169)

A 12-ship arc that took the compiler's self-host memory footprint
from **19 GB to 67 MB** (283× reduction) and the wall-clock from
**25 s to 5.2 s** (~5× speedup), while adding a gate-enforced
**100 MB allocation budget** that prevents future regressions.

## TL;DR

| Stage              | Tracked  | Wall-clock | Notes |
|--------------------|---------:|-----------:|-------|
| Pre-fix baseline   | 19 GB    | 25 s       | OOM cascades during gate runs |
| **v0.2.169**       | **67 MB**| **5.2 s**  | Gate-enforced budget at 100 MB |
| **Cumulative**     | **283×** | **~5×**    | **memory · speed** |

The compiler now compiles itself in roughly the time and memory of
running a moderately large Python script.

## What shipped

| Tag      | Headline | Summary |
|----------|----------|---------|
| v0.2.158 | Infrastructure | `NUC_TRACE_ALLOC=1` per-category counters; `vec_free` builtin; format-builtin trio (`format2_fi`/`format2_if`/`format3_fff`) |
| v0.2.159 | **52× drop** | New non-allocating `str_eq_at`/`str_starts_with`; replaces the `str_eq(str_substring(source, i, i+tlen), target)` source-scan anti-pattern. **9.7 GB → 185 MB.** |
| v0.2.160 | Anti-pattern purged | Remaining 13 cold-path occurrences of the same anti-pattern converted; the codebase no longer contains the leak class |
| v0.2.161 | **Budget gate** | Verify gate enforces `TOTAL TRACKED <= 400 MB` on the s1 self-host, locking in the v0.2.159 win against future regressions |
| v0.2.162 | Release polish | `SECURITY.md` added; README updated with current rod count (132), helper count (686), test counts, and self-host metrics |
| v0.2.163 | UAF audit | Bisected the env-snapshot UAF: type-pass `vec_free` calls re-enabled (safe); check-pass calls documented as deferred (downstream consumers) |
| v0.2.164 | `str_intern` | Identifier interner — stable canonical pointer per unique input string. Foundation for pointer-equality fast paths and the v0.4 TypeId interner. |
| v0.2.165 | `str_arena_*` | Lifetime-scoped string arena — 5 builtins (`new`/`free`/`bytes`/`concat`/`substring`). Bump-allocate transient strings, free in one shot. |
| v0.2.166 | SB sizing | Initial string-builder capacity 4 KB → 256 B. **185 → 137 MB**, sb_new dropped 60 MB → 11 MB. Budget tightened to 250 MB. |
| v0.2.167 | Vec sizing | Initial Vec capacity 16 → 4 elements. **137 → 67 MB**, vec_new dropped 119 MB → 49 MB. Budget tightened to 100 MB. Cumulative reduction crosses 283×. |
| v0.2.168 | Architecture doc | New `docs/memory-architecture.md` — case study of the entire arc with troubleshooting guide for future contributors |
| v0.2.169 | `str_free` | Builtin to release heap-allocated strings (`str_concat`/`str_substring`/`sb_to_str`/`format_*` results). Foundation for explicit-free patterns in user code and rods. |

## Methodology

Every memory decision was driven by data, not intuition:

1. **Trace first.** v0.2.158's first move was adding per-category
   allocation counters. Without `NUC_TRACE_ALLOC=1`, every
   subsequent fix would have been guesswork.
2. **Identify the dominant cost.** The trace showed
   `str_substring` was 9.5 GB of 9.7 GB total. Fix the dominant
   cost first.
3. **Fix architecturally where possible, structurally where
   easy.** The `str_substring` leak was an architectural
   anti-pattern (allocate-then-discard inside source-scan loops);
   fix architecturally with non-allocating helpers. The SB / Vec
   initial-capacity wins were structural (just tune the constant);
   fix structurally because the cost is bounded.
4. **Lock in wins.** Each significant reduction tightens the
   gate's allocation budget so future ships can't silently regress.
5. **Document.** Every CHANGELOG entry includes before/after
   numbers so the audit trail is machine-readable. The
   architecture doc explains *why* each decision was made for
   future contributors.

## Critical bugs caught along the way

- **`str_eq_at` first cut hung the compiler for 5+ minutes.**
  Initial implementation called `str_len(source)` for a bounds
  check. `str_len` is O(n); placing it inside an O(n) outer loop
  creates O(n²). Fixed by omitting the bounds check and
  documenting the caller's loop-bound invariant.
- **Env-snapshot `vec_free` caused use-after-free in
  match/enum/if-let.** Bisected: type-pass snapshots are safe
  (recursive consumer fully drains them before next iteration);
  check-pass snapshots are NOT (downstream `check_expr` helpers
  hold pointers into the snapshot's storage). Type-pass frees
  shipped; check-pass frees deferred with documented reason.
- **Wrong binary in `bin/nucleor.exe` masked the broken
  `str_eq_at`.** A `git checkout` from earlier diagnostic work
  reverted `bin/nucleor.exe` to a stale version; the gate
  failures looked like a different bug. Diagnosed by `md5sum`
  comparison against built artifacts.

## Where to next

`MEMORY_FIX_PUNCHLIST.md` tracks the remaining items:

- **TypeId interner (Ship 3)** — replace stringly-typed types
  with canonical IDs throughout the type checker. Estimated
  additional reduction: 67 MB → ~50 MB plus significant speedup
  on type comparisons.
- **Type-checker arena migration (Ship 4)** — move transient
  diag-message construction onto the v0.2.165 arena. Estimated
  additional reduction: ~5 MB.
- **Check-pass UAF audit (Ship 6 continuation)** — identify
  downstream consumers of `own_restore` / `own_merge_moved`
  snapshots, then re-enable the free pattern. Estimated
  additional reduction: ~10 MB.

Each has clear pass/fail criteria via the gate budget and the
self-host fixed point.
