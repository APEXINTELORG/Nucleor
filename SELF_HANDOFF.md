# Self-handoff — Nucleor_OSS main-line agent

Written 2026-04-29 at the end of a long session (v0.4.101 →
v0.4.134). Pick this up by reading top-to-bottom; do NOT skim.

## Absolute paths for every doc + repo location

**Project root (cwd for everything):**
`C:\Users\JoeWe\Desktop\Nucleor_OSS\`

**Punchlists / handoffs (read FIRST when picking up):**
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\PARALLEL_AGENT_HANDOFF_v0.4_RESIDUALS.md`
  — current parallel-agent contract (4 multi-day items: trait-bound
  call-site impl-existence, saturating per-op, verify_parallel
  fold-in, var-RHS shift bounds).
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\PARALLEL_AGENT_BLOCKERS.md`
  — historical blockers from round 1; useful for the Windows
  file-lock workaround at the bottom.
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\SELF_HANDOFF.md` — this file.
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\CHANGELOG.md` — every tag's
  rationale + which silent miscompute it closed.
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\RELEASES.md` — generated
  index of all 134+ releases.

**Compiler source (where 95% of edits land):**
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\compiler\nucleor_s1_compiler.nr`
  — main compiler (~21000 lines). Edit here for any
  parser/type-check/lower change.
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\compiler\nucleor_tools_suite.nr`
  — sister compiler. Mirror IR declares + `is_ptr_arg` +
  `get_rt_name` + `is_ptr_ret` for any new runtime helper. Drift
  gate enforces parity.

**Runtime + bootstrap:**
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\stdlib\runtime\nucleor_llvm_rt.c`
  — C runtime helpers. Append near related helpers.
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\bootstrap\nucleor_s1_seed.ll`
  — canonical seed IR. Refresh after every compiler change
  (T1.7 fixed-point gate).
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\bin\nucleor.exe` — current
  compiler binary. Replaced by every successful self-host build.

**Test fixtures:**
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\tests\err\` — negative
  fixtures. Each must have an `EXPECT:` comment header (verify.sh
  enforces).
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\tests\features\` — positive
  fixtures.
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\tests\features\_unimplemented\`
  — empty as of v0.4.134. If the parallel agent reopens an item,
  fixtures land here until the runtime support catches up.
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\tests\fixtures\` — repro /
  punchlist regression fixtures (NOT auto-run by verify.sh —
  spot-test manually with `bin/nucleor.exe build tests/fixtures/X.nr`).
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\tests\lang\`,
  `\tests\attrs\`, `\tests\runtime\`, `\tests\rods\` — verify.sh
  auto-runs these.

**Tools (gates, generators, helpers):**
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\tools\verify.sh` — full
  sequential gate (~5min). Use sparingly.
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\tools\verify_parallel.sh`
  — fast parallel verifier (~17s at -j 12). USE THIS PER SHIP.
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\tools\check_compiler_drift.sh`
  — drift gate. Must return 0 before commit.
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\tools\gen_helper_manifest.py`
  — re-run when adding C runtime helpers.
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\tools\gen_rod_manifest.py`
  — re-run when adding `.nr` rod files.
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\tools\gen_releases_index.py`
  — re-run BEFORE every commit (CHANGELOG↔RELEASES drift check).
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\tools\verify_timings.csv`
  — per-step timing CSV (CRITICAL — user directive: monitor for
  perf regressions every cycle).
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\tools\examples.list` — list
  of stdlib example builds verify.sh runs.
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\tools\check_perf_regression.ps1`
  — drift gate. **Run before every ship.** Compares cold + hot
  self-build wall + peak RSS to `tools/perf_baseline.json`. Exit 1
  = regression. Ceilings are baseline +10% (cold ≤ 7.20s, hot
  ≤ 0.86s, peak RSS ≤ 552 MB). NEVER `-Update` to absorb a
  regression — only after a justified perf change. NEVER chain
  +10% bumps (compounding bloat is worse than a single big regression
  because nobody notices until we're 50% slower).
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\tools\run_capped.ps1`
  — e-stop wrapper (1024 MB RSS hard kill). Probe agent uses it for
  every rebuild + probe run. You can use it too if you're running
  something that might blow up. Independent of the drift gate.
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\tools\perf_baseline.json`
  — locked baseline + ceilings. Touch only with explicit user
  approval and a justified perf change.

**Specs / RFCs (for "why does this work this way" questions):**
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\docs\spec\` — spec docs.
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\docs\rfcs\` — RFC docs
  (`RFC-0015-numeric-types.md`, `RFC-0016-result-option-match.md`,
  `RFC-0017-collections.md`, `RFC-0023-pattern-matching.md`,
  `RFC-0024-iterators.md`, `RFC-0028-format.md`).
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\docs\rfcs\helper_manifest.toml`
  — per-helper manifest. Regenerated by `gen_helper_manifest.py`.
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\docs\rfcs\rod_manifest.toml`
  — per-rod manifest. Regenerated by `gen_rod_manifest.py`.

**Inbound feedback (check periodically for new items from
ML_Suite agent):**
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\docs\ML_SUITE_FEEDBACK_QUEUE.md`
  — mirror of `Nucleor_ML_Suite/docs/NUCLEOR_LANGUAGE_FEEDBACK.md`.
  As of v0.4.134 ALL items in this queue are CLOSED.

**Parallel agent's worktrees (Windows file-lock prone — see
`PARALLEL_AGENT_BLOCKERS.md` for `rm -f bin/nucleor.exe && sleep 2`
workaround):**
- `C:\Users\JoeWe\Desktop\Nucleor_OSS_wt_string_basic\`
- `C:\Users\JoeWe\Desktop\Nucleor_OSS_wt_question_from\`
- `C:\Users\JoeWe\Desktop\Nucleor_OSS_wt_fnmut_capture\`
- `C:\Users\JoeWe\Desktop\Nucleor_OSS_wt_trait_objects\`
- `C:\Users\JoeWe\Desktop\Nucleor_OSS_wt_pattern_matching\`
- `C:\Users\JoeWe\Desktop\Nucleor_OSS_wt_display_debug\`
- `C:\Users\JoeWe\Desktop\Nucleor_OSS_wt_generic_type_prop\`
  These all have `ahead=0` from main as of session end — empty
  unless the agent restarts work. New worktrees will appear with
  the topic name from the round-2 handoff doc.

**External, NOT THIS REPO (mentioned in user's CLAUDE.md memory
but DO NOT EDIT):**
- `C:\Users\JoeWe\Desktop\Nucleor\` — the canonical full Nucleor
  repo (this OSS repo is the public-distro subset).
- `C:\Users\JoeWe\Desktop\Nucleor_Archive\` — archived old builds.
- `C:\Users\JoeWe\Desktop\Nucleor_ML_Suite\` — ML adopter agent's
  workspace; their feedback flows here through
  `NUCLEOR_LANGUAGE_FEEDBACK.md`.

**User memory (always loaded into your context):**
- `C:\Users\JoeWe\.claude\projects\C--windows-system32\memory\MEMORY.md`
  — index of all the user-memory entries.
- Specifically relevant: `feedback_no_time_estimates.md`,
  `feedback_honesty_rules.md`, `feedback_memory_budget.md`,
  `feedback_perf_regression_pattern.md`,
  `feedback_nucleor_verify_timing.md`,
  `feedback_nucleor_launch_quality.md`. Read these before doing
  anything novel.


## Where we are right now

- **Main HEAD:** v0.4.152 (commit `79e55fe`). 18 ships this session
  (v0.4.135 → v0.4.152). All commits + tags pushed to origin.
- **Bootstrap fixed-point:** holds at v0.4.152 (first-pass on every
  ship). Drift gate green.
- **Verify:** parallel verifier (`tools/verify_parallel.sh -j 12`)
  reports 217 PASS / 1 baseline-FAIL / ~10s wall (as of v0.4.170+).
- **Baseline FAILs (NEVER count as regressions):**
  `lang/mod_decl_aux` (multi-file module that needs verify.sh's
  special setup) and `runtime/stdin_read` (needs a stdin pipe).
  Anything else FAILing is YOUR break — bisect.
- **`tests/features/_unimplemented/` is empty.** All v0.4 audit
  doc-#1 sections (§3 / §5 / §6 partial / §7 / §8 NAME-only /
  §9 / §10) are closed.

### Ships v0.4.135–v0.4.152 (this session)

Each ship: dual-compiler edit (where applicable), T1.7 first-pass,
drift clean, parallel verifier no regression, fixture, CHANGELOG,
RELEASES regen, single-bug single-tag.

- **v0.4.135** — `"abc".len()` returned 0. kind-2 (str-literal)
  receiver routed to vec_len; now stamps stype="str" → str_*.
- **v0.4.136** — `let x = print_int(5);` silently bound x=0
  (TYP-021 bare-let void RHS).
- **v0.4.137** — `5 == 5.0` returned FALSE; `5 < 5.0` returned
  TRUE. NUM-022 cmp int-vs-float.
- **v0.4.138** — `let e: E = E;` failed with cryptic clang `@E
  undefined`. TYP-022 struct-as-value at kind-3.
- **v0.4.139** — `v.push(N).len()` and `let x = v.push(N);`
  silently returned 0. Void-mutator route to "void" + TYP-023.
- **v0.4.140** — `match n: i64 { 1 => ..., "a" => ... }` for
  n=2 SIGSEGV'd. MATCH-011 pattern-literal-vs-scrutinee mismatch.
- **v0.4.141** — `5 + 5.0` produced garbage i64. NUM-022 ext to
  arith ops 20-24.
- **v0.4.142** — `fn f() { return 42; }` silently discarded the
  value. TYP-010 ext for void/implicit-void rtype with non-void val.
- **v0.4.143** — `let s: str = x as str;` for x:f64 SIGSEGV'd
  on print. NUM-023 float/bool as-cast to str.
- **v0.4.144** — `print_int(add(5))` for 2-param add silently
  lowered with garbage second param. TYP-005 ext: kind-7 generic
  arg walker for non-sig non-dynamic-helper callees (mirrors
  v0.4.117 fix for dynamic-helper path).
- **v0.4.145** — `let x = if c { 1 } else { "two" };` silently
  picked then-type. TYP-024 incompatible if-expr branches.
- **v0.4.146** — `let f = |x,y| x+y; f(5);` ran with garbage
  second param. TYP-005 ext: closure call argc check via new
  `__closure_argc_<vname>` tenv entry.
- **v0.4.147** — `a == b` for two equal-field structs returned
  FALSE. TYP-011 ext for struct == / != / ord (sister to
  v0.4.52 str== and v0.4.61 Vec==).
- **v0.4.148** — `P(42)` for struct P silently emitted `call
  @P` (cryptic clang link error). TYP-022 ext at kind-7
  (sister to v0.4.138 at kind-3).
- **v0.4.149** — `print(struct)` printed heap garbage bytes.
  TYP-006 ext: print/println/eprint/eprintln added to
  needs_str_arg0 list.
- **v0.4.150** — `s + 5` for s:String silently did i64_add on
  heap ptr (wild pointer). TYP-011 ext for String arith. Also
  fixed kind-12 type_expr to return "String"/"Vec"/"HashMap"/
  "HashSet"/"BTreeMap"/"BTreeSet"/"VecDeque" (was "" — the
  let-stmt logic stored "" in tenv even with explicit
  annotation, breaking every downstream type check).
- **v0.4.151** — `s == s2` for two String values returned FALSE.
  TYP-011 ext for String == / != (sister to v0.4.52, v0.4.147).
- **v0.4.152** — `for c in s` for s:str silently produced 0
  iterations. TYP-011 ext for kind-49 with non-iterable type
  (str / String / scalar / bool).

## What just happened (don't repeat)

**Session ending v0.4.152:** 18 ships from probe-driven hunting
across 6 probe rounds. Patterns hit: type-mismatch in let RHS
(v0.4.136), method-dispatch fall-through (v0.4.135/.139/.149),
match exhaustiveness/literal-type gaps (v0.4.140), cryptic clang
errors lifted (v0.4.138/.143/.148), parser/type-check fall-throughs
(v0.4.142/.144/.145/.146), silent ptr-compare on heap types
(v0.4.147/.151), arith on heap types (v0.4.150), unsupported
iteration shapes (v0.4.152). All ships tagged + pushed.

### Earlier session notes (kept for context)

- 34 ships in the previous session before this one: silent-
  miscompute closes, parallel-agent spike integrations (5 of
  them, all in main), residual #1 / #4 / #5 from the v0.4
  punchlist.
- Parallel agent has a handoff doc at
  `PARALLEL_AGENT_HANDOFF_v0.4_RESIDUALS.md` (commit `7530246`).
  They have 4 multi-day items: trait-bound call-site impl-existence
  check, saturating per-op via LLVM intrinsics, verify_parallel.sh
  fold-in to verify.sh, var-RHS shift bounds. As of v0.4.152
  spike branches all have `ahead=0` from main.
- The v0.4.135 mid-flight `let mut stype` issue mentioned in
  earlier handoff is **CLOSED** (shipped as v0.4.135 this
  session — first ship of the run).

## Workflow protocol — READ THIS

1. **Every loop tick** starts with `git fetch --all` to see if the
   parallel agent pushed new commits to any spike branch. If
   `git rev-list --count main..origin/spike/<topic>` is non-zero
   for any spike, integrate it BEFORE doing anything else. Use
   the v0.4.114-style rebase + bootstrap procedure (see
   PARALLEL_AGENT_BLOCKERS.md for the file-lock workaround that
   bites on Windows).

2. **Probe triage is the highest-value steady work.** Each cycle
   write 5-7 small `.nr` fixtures to `/tmp/p_*.nr` exercising
   specific corner cases. Run them all in one batched bash block.
   Anything that "compiles silently and runs to garbage" is a
   silent-miscompute close worth shipping. Anything that
   "compiles silently and SIGSEGVs" is urgent. Anything that
   "produces a clean panic" is already covered — skip.

3. **Each ship is ONE bug, ONE tag.** Don't batch silent
   miscomputes into a single tag — adopters bisect against tags,
   so each tag should map to one specific behavior change.

4. **Ship gate (in order):** edit → rebuild compiler → promote to
   bin/ + bootstrap/seed → 2-pass T1.7 fixed-point → drift gate →
   parallel verifier → write fixture → CHANGELOG → regen RELEASES
   → drift gate again → commit → tag → push (main + tag).

5. **DO NOT use full sequential `verify.sh` per ship.** Parallel
   verifier (~17s) + manual T1.7 + drift gate is enough. Full
   sequential is for once-per-session sanity. (User caught me
   wasting 5min/ship on this earlier — don't repeat.)

6. **Bootstrap fixed-point:** if T1.7 fails, copy the fresh
   `target/nucleor.{exe,ll}` over `bin/` and `bootstrap/seed`,
   then RE-run the build to verify a 2-pass match. Manifest
   regeneration (helper / rod) sometimes shifts bytes and
   requires a 2nd re-emit before convergence — this is normal.

## What I've been hunting (probe patterns that consistently find bugs)

- **Type-mismatch in struct init / assignment / let-RHS.**
  v0.4.108, .113, .126, .128, .129, .131, .132, .133.
- **Method-dispatch fall-through to vec_*.** v0.4.107, .117,
  .123, .127.
- **Match exhaustiveness gaps (int / str / bool).** v0.4.109,
  .134.
- **Cryptic clang link errors (lift to TYP-005 / NR022).**
  v0.4.106, .110.
- **Parser silent fall-throughs (NR020 / NR021 etc.).** v0.4.111,
  .121.
- **Control flow silent no-ops (break/continue outside loop, bare
  return; in non-void).** v0.4.112.
- **No-arg / wrong-arg fn calls coerced silently.** v0.4.111 (chained
  assign), v0.4.121 (print no-arg), v0.4.122 (call non-callable
  type), v0.4.132 (void in binop).

## Known mid-flight or punted (ship the next time you find them)

**Session ending v0.4.152: all 4 prior held items SHIPPED** —
v0.4.135 (`"abc".len()`), v0.4.136 (`let x = print_int(5)`),
v0.4.137 (`5 == 5.0`), v0.4.138 (`let e: E = E;`).

Items confirmed via probe but **deferred** (need infrastructure
beyond a single-tag fix):

- **Use-after-move on String/Vec.** Probe `let s = String::new();
  let t = s; s.len()` returns 0 silently. Nucleor's ownership
  tracker has no move state today — adding it is a v0.5-class
  change (broad surface, breaks current test fixtures that pass
  values around freely).
- **Uninit-mut binding.** Probe `let mut x: i64; if false { x =
  5; }; print_int(x);` reads uninit (alloca zero-slot) → prints
  0. Needs flow-sensitive uninit detection. v0.4.83 caught the
  immutable-no-init form; the mutable case requires conditional
  assignment tracking.
- **Reverse range `for i in 5..0`.** Currently produces 0
  iterations silently. Rust does the same — leaving this alone
  unless adopter feedback says otherwise.

## What NOT to attack

- **Trait bounds runtime full enforcement** (residual #1 round 2)
  — handed to parallel agent.
- **Saturating per-op** (residual #3) — handed to parallel agent.
- **verify_parallel.sh fold-in** (residual #6) — handed to parallel
  agent. Don't re-attempt; the structural-not-race nature of the
  76-files-missing pattern needs a focused trace session, not
  another iteration in the loop.
- **Var-RHS shift bounds** (residual #7) — handed to parallel agent.
- **Slice patterns full exhaustiveness** (residual #2) — genuinely
  v0.5-class (needs constraint solver). Don't ship.

## File-system landmarks

- `compiler/nucleor_s1_compiler.nr` — main compiler. ~21000 lines.
  Edit here; the 5-table mirror in `nucleor_tools_suite.nr` is
  required for any new runtime helper (drift gate enforces).
- `compiler/nucleor_tools_suite.nr` — sister compiler. Mirror
  changes for IR declares + `is_ptr_arg` + `get_rt_name` etc.
- `stdlib/runtime/nucleor_llvm_rt.c` — C runtime helpers. Append
  near related helpers (e.g. string_* near string_*).
- `tests/err/*.nr` — negative fixtures. Each must have an `EXPECT:`
  comment header (verify.sh checks this).
- `tests/features/*.nr` — positive fixtures. Auto-picked up by
  the verify gate.
- `bootstrap/nucleor_s1_seed.ll` — the canonical seed. Refresh
  after every compiler change.
- `tools/verify_parallel.sh` — fast parallel verifier (~17s).
- `tools/verify.sh` — full sequential gate (~5min). Use sparingly.
- `tools/check_compiler_drift.sh` — drift gate. Must return 0.
- `tools/gen_helper_manifest.py` / `gen_rod_manifest.py` /
  `gen_releases_index.py` — re-run when adding helpers / rods /
  before commit (CHANGELOG↔RELEASES drift check).
- `CHANGELOG.md` — newest entry at top under the `## [VERSION]`
  heading. Drift gate enforces tag↔heading parity.
- `PARALLEL_AGENT_HANDOFF_v0.4_RESIDUALS.md` — current parallel
  workstream items.
- `PARALLEL_AGENT_BLOCKERS.md` — historical, useful for the
  Windows file-lock + rebase workaround at the bottom.

## Probe + Prep orchestration — REVISED 2026-04-30 (v0.4.181)

The probe agent **proposes**; you **integrate**. He preps each
fix on `probe/exploration` (compiler edit + fixture + all gates
green) and pushes only to `origin/probe/exploration`. He never
pushes to `main`, never tags, never edits `CHANGELOG.md` directly.
You pull his branch, merge into main, assign the version, splice
his `CHANGELOG_PROBE_QUEUE.md` entry into `CHANGELOG.md`, move his
`findings/staged/<slug>.md` to `findings/promoted/<slug>.md` with
the `Fix shipped: v0.4.NNN` footer, run integration gates, tag,
push.

The earlier "he ships directly to main + tags himself" model is
retired — it caused a v0.4.163 tag collision and orphan-commit
problems. Mandate at `PARALLEL_AGENT_PROBE_MANDATE.md`.

### Your integration cadence

Pull + integrate when his `findings/_heartbeat.md` shows a
`ready_for_integration:` list with one or more slugs. Otherwise
keep working on punchlist on main directly.

### Per-integration workflow (what you do)

```sh
# 1. Pull his branch
git fetch origin
git log main..origin/probe/exploration --oneline   # see what he's queued

# 2. Either rebase his commits onto main, or cherry-pick. Squash
#    multiple wip commits into one ship commit per finding.
git checkout main
git cherry-pick <commit-sha>   # or merge --no-ff with squash

# 3. Pick the next version. v0.4.NNN where NNN = top of CHANGELOG + 1.

# 4. Splice CHANGELOG_PROBE_QUEUE.md entry into CHANGELOG.md.
#    Rewrite the unreleased header to ## [0.4.NNN] — yyyy-mm-dd.
#    Delete the spliced entry from CHANGELOG_PROBE_QUEUE.md.

# 5. Move findings/staged/<slug>.md → findings/promoted/<slug>.md.
#    Fill in Fix shipped: v0.4.NNN (commit <sha-after-your-tag>).

# 6. Run your own gates against the integrated state:
bash tools/check_compiler_drift.sh
bash tools/verify_parallel.sh -j 12
.\tools\check_perf_regression.ps1

# 7. Regen RELEASES.md
python tools/gen_releases_index.py

# 8. (Maybe) -Update perf_baseline if a justified perf change is in
#    this integration. NEVER bump baseline to absorb regression.

# 9. Commit + tag + push
git add -A
git commit -m "v0.4.NNN: <summary> (integrated from probe-agent prep)"
git tag v0.4.NNN
git push origin main && git push origin v0.4.NNN
```

### Your own punchlist work on main (parallel to integrations)

You still ship features yourself directly on main as v0.4.NNN.
The probe-agent integration cycle is interleaved — you bump the
next version when integrating his queued items, and you bump the
NEXT next version when shipping your own punchlist work. Linear
sequence, no holes.

### What you do NOT do

- Don't edit `findings/inbox/` (his).
- Don't edit `findings/staged/` (transitional, only YOU MOVE files
  out of it during integration; you don't add to it).
- Don't push fixes for findings you spotted yourself unless they're
  also v0.4/v0.5 punchlist items — file via `findings/_questions.md`
  for him to pick up, OR ship as your own punchlist if the timing's
  right (e.g., the probe agent went silent and a bug is blocking).

### Reading `findings/promoted/` (optional)

`promoted/` is a historical record of every closed silent miscompute.
Useful context for retro / paper / postmortem material.

### Stuck-signal etiquette

If you're stuck in a long debug, write a one-liner to "Where we are
right now" naming the area under repair. He reads it each rebase
and steers clear of that region in his prep work.

### Why this split is the right shape

- Probes-on-main bloated the verify suite (~30s of step-time
  accumulated across 24 ships at ~1.2s each); probes-off-main
  let the regression-guard value land via promoted fixtures
  without paying the exploratory churn cost.
- Probes caught spike B's accidental revert in this very
  session — that signal is what we keep. The exploratory
  thrash is what we move off-main.
- Three-way agent isolation already proven by
  `PARALLEL_AGENT_RESCUE.md` branch namespacing
  (`spike/<topic>-v3` for fresh, `-v2` for thrash,
  `probe/exploration` for the probe agent).

### Historical (reference only)

Probes shipped v0.4.135–v0.4.162 by main agent are the prior
art the probe agent should NOT re-cover. The "Already covered"
table in `PARALLEL_AGENT_PROBE_MANDATE.md` enumerates the dead
lanes. The probe agent picks fresh corners.

## Tag numbering

Main is at v0.4.158. Next ship is v0.4.159 (or higher if parallel
agent pushes a tag during your fetch). Every tag is created by
`git tag vX.Y.Z` AFTER checking `git tag -l | sort -V | tail` —
if the agent shipped v0.4.160 between fetches, move to v0.4.161.
The drift gate catches CHANGELOG↔tag mismatches.

**Pivot to v0.5 punchlist.** Read `docs/milestones/v0.5.0.md`
first. Each unchecked `[ ]` is a v0.5 work item. v0.5.0 ships
when every checkbox is closed. The major themes are:

- DbC (RFC-0006): `#[require], #[ensure], #[invariant]` (5 phases)
- Atomics (RFC-0007): `#[atomic]` + SPSC/MPMC queues (5 phases)
- `#[max_depth = N]` (RFC-0014): bounded recursion (4 phases)
- Package manager (RFC-0019): registry + PubGrub + git deps + publish/yank
- Cross-platform (RFC-0022): sysroots + cross-compile + pre-built top-5
- `nuc fmt` + LSP server + editor extension
- Capsule signing (RFC-0031): native SHA-256 / Ed25519 + NCAP envelope
- `nuc port` Python migration MVP
- RFC-0033 (effects-as-types) + RFC-0034 (compile-time `[]` params): design only
- Content-addressed compilation cache: `target/.nuc_cache/<hash>.ll`

## You-have-context defaults

- User wants progress, not narration. End-of-turn summary should
  be 1-2 sentences. No "let me explain what I did" preambles.
- **The probe-driven hunt is RETIRED.** Probes built up too much
  verify-suite step time. Don't go back to probing unless
  explicitly told. Work the v0.5 punchlist.
- Use the PARALLEL_AGENT_HANDOFF + PARALLEL_AGENT_RESCUE docs as
  the authoritative contract for what's NOT mine. The fresh
  parallel agent owns residual #7 (var-RHS shift bounds), the
  thrashing v2 agent owns residual #6 (verify_parallel.sh
  fold-in). Don't touch either.
- Don't ship-batch (one tag per coherent unit of work). Don't
  run full sequential verify per ship (parallel + drift + T1.7
  only). Don't write multi-paragraph commit messages.

## FAQ from incoming agent (answered 2026-04-29)

**Q1 — Is the v0.4.135 mid-flight partial recoverable from reflog
or stash?**
No. Reflog shows the doc commits directly on top of v0.4.134 with
no intervening WIP commit, and none of the 3 stash entries are
mine for v0.4.135 (stash@{0,1} are parallel-agent worktree state,
stash@{2} is unrelated v0.4.22-v0.4.35 era). My `git checkout HEAD
--` reverted the working tree without stashing first, so the
edit is gone. Re-derive from scratch — it's small (the diff was
~10 lines: declare `stype` as `let mut` and add a 6-line
kind-2-receiver detection block that clears `recv_is_vec` and
stamps `stype = "str"`). Detail in §"Mid-flight" of this doc.

**Q2 — Is kind 2 the str-literal AST node tag in a numeric
dispatch switch?**
Confirmed yes. Line 1106 in `compiler/nucleor_s1_compiler.nr`:
`if tt == 3 { return pr(pos + 1, mk2(pool, 2, pkv(tokens, pos))); };`
That's the parser turning lexer token type 3 (string literal) into
AST kind 2 (str literal). Other relevant kinds you'll see:
1=int_lit, 3=var-ref, 4=binop, 7=call, 8=method-call, 9=field-
access, 10=index, 12=Type::method or enum constructor, 17=block,
20=let, 21=assign, 22=return, 23=if, 25=tail-expr-stmt, 30=fn,
38=match-expr, 39=match-arm, 42=closure, 43=trait-decl, 44=trait-
method, 45=impl-block, 52=passthrough/wrapped block, 99=as-cast.
This list isn't exhaustive but covers >90% of what you'll touch.

**Q3 — Push authorization?**
Per-ship autonomous push is the established pattern this entire
session (34 ships, all auto-pushed). Workflow is:
`commit → tag → git push origin main → git push origin v0.4.NNN`.
Confirm once at the start of session if you're cautious; I never
re-confirmed after the first push. If a push hits an unexpected
non-fast-forward (parallel agent shipped between your fetch and
your push), `git fetch && git rebase origin/main` and re-tag at
the new HEAD before retrying.

**Q4 — Parallel-agent fetch cadence?**
Every loop tick. Cost is ~1s on typical network and the agent
can push at any time. Even when prior tick showed `ahead=0`, the
agent might push a fresh spike commit during the inter-tick
sleep. The fetch also keeps the local view of `origin/spike/*`
fresh which matters if you `git rebase origin/main` mid-tick.

**Q5 — ML_Suite feedback queue cadence?**
`docs/ML_SUITE_FEEDBACK_QUEUE.md` — currently all entries CLOSED
as of v0.4.134. Check at the START of every session (not every
tick — file is mirrored manually from `Nucleor_ML_Suite/docs/
NUCLEOR_LANGUAGE_FEEDBACK.md` and updates are infrequent). If the
ML_Suite agent has pushed new findings, my user memory entry
`project_nucleor_ml_suite_feedback.md` will mention it
("user wants me to re-check each cron cycle and fold new entries
into the punchlist"). Don't poll mid-session unless the user
flags an inbound item.

**Q6 — Drift-gate scope for v0.4.135 (str-literal `.len()` fix)?**
The fix lives in the kind-8 method-dispatch path in
`nucleor_s1_compiler.nr` around line 14418-14430 (the `recv_is_vec`
+ `stype` resolution block). It steers method dispatch but adds
no new C runtime helpers and no new IR declares.
**HOWEVER:** `nucleor_tools_suite.nr` has `iter_method_for_vec`
(line 4709) and uses it for its own method-dispatch path (line
8262). Search the tools_suite for an analogous `recv_is_vec`
block — if it exists, mirror the kind-2 detection there too.
If it doesn't, the v0.4.135 change is s1-only. Drift gate runs
the existing parity checks (ABI tables, manifest freshness,
RELEASES freshness, CHANGELOG↔tag) and won't fire on dispatch-
logic divergence — but tools_suite IS exercised by some verify
steps, so a divergence could surface as a fixture failure rather
than a drift-gate fail. Run parallel verifier after building to
confirm.

In short: **no `helper_manifest.toml` regen**, **no
`rod_manifest.toml` regen**, **no IR declare changes** for
v0.4.135. Only `gen_releases_index.py` (every commit) and
CHANGELOG entry. Mirror to tools_suite IF it has the same
dispatch path (verify by grep).
