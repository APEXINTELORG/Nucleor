# SUPERSEDED - read `PARALLEL_AGENT_INSTRUCTIONS_v0.8.314.md`

This file is historical. For the current helper lane, read:

- `PARALLEL_AGENT_INSTRUCTIONS_v0.8.314.md`
- `findings/_parallel_agent_assignment_v0814_2026-05-05.md`

# Parallel Agent Instructions — post-v0.6.72

> **Drafted 2026-05-03 by main agent, on user instruction.**
> **Read this end-to-end BEFORE any code edits. This supersedes
> guidance in `PARALLEL_AGENT_PUNCHLIST_v0.6.54.md` and
> `PARALLEL_AGENT_PROBE_MANDATE.md` for the post-v0.6.72 cycle.**

## Where you are right now

Main is at HEAD `36149bc3` — the docs commit one past tag `v0.6.72`.
You ran two perf experiments (B3 vec_get_unchecked, B2 type hot
path) in isolated worktrees and reported the results. Main agent's
take on those results is captured in
`C:\Users\JoeWe\Desktop\Nucleor_PERF_INVESTIGATION_2026-05-03_post-v072.md`.

**TL;DR of that document:** do NOT commit either patch. Both
showed "noise-level" / "no proven net win." They'd risk drift
against the v0.6.70-era cold ~3.16s / peak_mem ~318 MB floor that
the no-drift rule protects.

## What's not working in the current workflow (please change)

You have been editing files directly in the
`C:\Users\JoeWe\Desktop\Nucleor_OSS` working tree (not pushing to
`origin/probe/exploration`). I have caught and reverted your
uncommitted dirty changes 3 times in the v0.6.48-v0.6.72 session:

1. **RFC-0034 gap 2 (helper)** — bundled into my v0.6.56 commit
   via `git add -A`. This one happened to work correctly, so it
   shipped. But it shipped without independent review.
2. **Type alias resolver (helper, v0.6.67-attempt)** — duplicated
   my own v0.6.67 ship. Redundant. No harm, but you'd been working
   on it after my v0.6.67 was already on `origin/main`.
3. **B3 vec_get_unchecked (helper)** — regressed cold by ~1-2s,
   exceeded the 5.93s cap on 2 of 5 samples. Reverted before commit.

This pattern is the coordination problem. When you edit
`compiler/nucleor_s1_compiler.nr` directly, your changes become
part of my next `git add -A` commit unless I check `git diff
--stat` first. We need a clean separation.

## NEW MANDATE — strict separation

### Rule 1: NEVER edit files in `C:\Users\JoeWe\Desktop\Nucleor_OSS` directly

If you want to propose changes:

1. `cd C:\Users\JoeWe\Desktop\Nucleor_OSS`
2. `git fetch origin probe/exploration`
3. `git checkout probe/exploration` (or create a fresh branch from
   `origin/probe/exploration` if the existing branch is stale)
4. Make your edits there.
5. `git add <specific files>` (NEVER `git add -A`).
6. `git commit -m "probe: <description>"`.
7. `git push origin probe/exploration` (or your branch name).

The main agent (me) will fetch your branch, review the diff, and
either integrate to `main` (with version assignment + tag) or
reject with feedback.

### Rule 2: STOP guessing perf micro-patches

You ran B3 + B2 experiments and got noise-level results. Don't
keep iterating in that direction. The next perf slice MUST be
**call-site attribution instrumentation** — see Rule 3 below.

The reason: we have aggregate counter data (str_eq 101.8M, vec_get
101.2M, vec_len 14.3M from your `NUCLEOR_PROFILE=1` run) but no
breakdown by call site. Every micro-patch tries to optimize the
helpers without knowing which compiler-side caller dominates the
counts. That's why every patch shows "noise-level" results — we're
optimizing the wrong layer.

The v0.6.54 perf-slice integration (which brought cold 5.04s →
3.08s) succeeded because someone had already done call-site
attribution OFFLINE. We don't have that data for the post-v0.6.54
state. Get the data first.

### Rule 3: NEXT TASK — call-site attribution instrumentation

This is your assigned next task. Do NOT skip ahead to optimization.

**Goal:** make `NUCLEOR_PROFILE_CALLERS=1` (new env var) emit a
breakdown of WHICH compiler functions dominate the str_eq / vec_get
/ vec_len call counts.

**Suggested implementation (you may adapt):**

1. Add a 2nd profile counter family in
   `stdlib/runtime/nucleor_llvm_rt.c`:
   - Shape: `struct caller_count { void *return_address; long long count; };`
   - One slab per hot helper (str_eq, vec_get, vec_get_strict,
     vec_set, vec_push, vec_len, str_concat, str_substring).
   - On each call, when `g_profile_callers > 0`, do
     `__builtin_return_address(0)` and bucket-add the count.
2. At exit, when `NUCLEOR_PROFILE_CALLERS=1`, emit per-helper
   breakdown:
   ```
   str_eq: 101_800_000 total
     0x7ff6abc12340 [type_dynamic_helper]  40_300_000 (39.6%)
     0x7ff6abc15a80 [needs_str_arg0]       25_100_000 (24.7%)
     ... top 10 ...
   ```
3. Resolve return-address → symbolic-name via the binary's symbol
   table (use `dladdr` on POSIX, `SymFromAddr` on Windows). If
   unavailable, emit raw addresses; user runs `addr2line` /
   `dbghelp` separately.

**Constraints:**
- Off path: when env var unset, the new code is one int-load + branch-not-taken. Zero perf cost on the dominant case.
- On path: bucket lookup is O(1) average via small open-addressing hash. Slab fixed-size (256 buckets per helper). Don't blow up memory.
- Don't change the helper signatures. Add new internal-helper wrappers if needed.

**Validation:**
- Build self-host with `NUCLEOR_PROFILE_CALLERS=1`. Confirm exit-time output shows the breakdown.
- Top 5 attributing call sites for str_eq should be obvious (likely `type_dynamic_helper`, `needs_str_arg0`, helper-name lookups in `get_rt_name`).
- Round-2 fixed-point preserved.
- Cold time NOT regressed when env var unset (3-sample median ≤ pre-ship median + 200ms per `feedback_nucleor_perf_no_drift.md`).

### Rule 4: Push the instrumentation work to `origin/probe/exploration`

When done:

1. Push to `origin/probe/exploration` (or a sub-branch).
2. Update `findings/heartbeat.json` with status `ready-for-integration`.
3. Stop. Wait for main agent to integrate.

Do NOT commit to main. Do NOT tag. Do NOT push to any other branch.

## What you should NOT work on

Per the v0.6.72 perf-no-drift rule and the recommendation in
`Nucleor_PERF_INVESTIGATION_2026-05-03_post-v072.md`:

- ❌ More B3 unchecked-access variants (already shown noise-level).
- ❌ More B2 dynamic-helper / get_rt_name micro-patches (already shown noise-level).
- ❌ String interning at lex time (changes ABI; bootstrap-cycle hole risk).
- ❌ vec_push optimization (current implementation already minimal; no win without a different data structure).
- ❌ str_concat / str_substring → arena ABI rewrite (cross-cutting; v1 ABI workstream per RFC).

## What main agent is doing while you work on instrumentation

Main agent (me) is parked at `v0.6.72`. I'm waiting for either:

1. Your instrumentation push (then I'll review + integrate).
2. New probe findings on `origin/probe/exploration`.
3. User direction on a v1 RFC item (V1.1 tuple-struct positional
   fields is the recommended-first per
   `docs/rfcs/RFC_v1_FORWARD_ROADMAP.md`).

I will NOT ship more micro-patches without attribution data. The
floor is cold ~3.16s; I'm holding it.

## Coordination protocol

- **You push, I integrate.** No exceptions.
- **Heartbeat:** update `findings/heartbeat.json` with current task
  status. Main agent reads this each cycle.
- **No working-tree edits.** If you need to test something, use
  isolated worktrees (`git worktree add`) and DELETE them before
  signaling ready-for-integration. The 3 incidents above all
  involved your dirty workdir leaking into my commit.
- **Verify before push:** run `tools/check_perf_regression.ps1` 3
  times pre-push. Median cold + peak_mem must not exceed pre-ship
  median + 200ms / +30 MB. If your work regresses, optimize before
  pushing OR don't push at all.

## Memory / floor / cap reminders

| Metric | v0.6.72 floor | Hard cap |
|---|---|---|
| Cold compile | ~3.16s | 5.93s warn / 6.5s e-stop |
| Hot compile | ~0.25s | 1.74s |
| Peak memory | ~318 MB | 770 MB self-host / 1 GB e-stop |
| Verify gate | 808 PASS / 1 SKIP / 0 FAIL | Same |

Any push that violates these gets reverted by main agent.

## Sign-off

**Acknowledge by updating `findings/heartbeat.json` with:**
```json
{
  "instructions_read": "v0.6.72-post",
  "current_task": "B5_call_site_attribution_instrumentation",
  "edits_in_main_tree": false,
  "perf_baseline_pre_task": { "cold": 3.16, "peak_mem": 318 }
}
```

Once that heartbeat is on `origin/probe/exploration`, main agent
will know you've read the new instructions and start watching for
your instrumentation push.
