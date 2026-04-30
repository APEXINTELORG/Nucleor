# Parallel Agent — Probe Mandate (persistent, indefinite)

You are the **probe agent**. Your one job is to find more silent
miscomputes, crashes, wrong errors, and missing diagnostics in the
Nucleor compiler. You drop findings into `findings/inbox/`. The main
agent reads that inbox between every ship and promotes confirmed
findings into permanent fixtures + compiler fixes. You never ship
fixes. You never tag. You never edit `compiler/*.nr`.

This contract supersedes any prior probe-related instructions in
`SELF_HANDOFF.md` or `PARALLEL_AGENT_HANDOFF_v0.4_RESIDUALS.md`.

## Absolute paths (no ambiguity)

**Project root (cd here for everything):**
`C:\Users\JoeWe\Desktop\Nucleor_OSS\`

**Your read-only files (never edit these):**
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\compiler\nucleor_s1_compiler.nr`
  — main compiler source (~21000 lines).
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\compiler\nucleor_tools_suite.nr`
  — sister compiler.
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\bin\nucleor.exe`
  — current compiler binary (use this to build probes).
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\bootstrap\nucleor_s1_seed.ll`
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\stdlib\runtime\nucleor_llvm_rt.c`
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\CHANGELOG.md`
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\RELEASES.md`
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\SELF_HANDOFF.md`
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\tools\verify.sh`
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\tools\verify_parallel.sh`
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\tools\check_compiler_drift.sh`
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\tests\` (entire tree —
  promoted fixtures owned by main agent; look but don't edit).

**Your writable workspace (ONLY edit under these):**
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\probes\`
  — exploratory `.nr` files (subdirectories by theme are fine).
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\findings\inbox\`
  — finding files (one per bug, named `YYYY-MM-DD-<slug>.md`).
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\findings\inbox\_questions.md`
  — append-only Q&A surface for asking the main agent things.
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\probes\_tools\`
  — your own helper scripts (not guaranteed to live forever).

**Reference docs to read before starting (all absolute):**
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\PARALLEL_AGENT_PROBE_MANDATE.md`
  — this file.
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\findings\README.md`
  — inbox protocol details.
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\SELF_HANDOFF.md`
  — main agent's journal (read-only for you).
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\docs\milestones\v0.4.0.md`
  — what's intentionally deferred (so you don't file deferred
  features as bugs).
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\docs\rfcs\`
  — RFC directory; check `RFC-0023..0029-*.md` for status of each
  language feature before reporting it as a bug.
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\PARALLEL_AGENT_RESCUE.md`
  — fresh-spike-agent contract (NOT yours, but useful to know what
  the spike agent on `spike/<topic>-v3` is doing so you stay clear).
- `C:\Users\JoeWe\Desktop\Nucleor_OSS\PARALLEL_AGENT_BLOCKERS.md`
  — Windows file-lock workaround
  (`rm -f bin/nucleor.exe && sleep 2`) you may need.

**Bash session quirk:** every `Bash` call resets cwd to
`C:\windows\system32`. Either chain with
`cd /c/Users/JoeWe/Desktop/Nucleor_OSS && <cmd>` or use absolute
paths in every command.

**Your branch (only this one):** `probe/exploration` (long-lived).
Do NOT create `spike/*` branches — those belong to the spike agent.

## Why this split exists

We had probes co-located with main for a long time. That was a
footgun: every probe `.nr` file lived in the verify-suite, and the
suite grew slow (each fixture ≈ 1.2s, 24 probe ships = ~30s of
verify-time bloat). We also had two parallel agents both trying to
ship to spike branches, which produced collision and wasted cycles.

The fix:
- **You probe forever, off-main, on your own branch.** Your
  exploratory `.nr` files do NOT enter the main verify suite.
- **Only confirmed bugs become fixtures**, written by the main agent
  at promote-time as tight 5–15-line `.nr` files in `tests/err/` /
  `tests/features/` / `tests/fixtures/`.
- That gives us the regression-guard value of probes (caught spike B's
  accidental revert in this very session) without paying for the
  exploratory churn on every CI run.

## Workspace setup

Use a dedicated git worktree so you and the main agent don't fight
over `bin/nucleor.exe` file locks or share a dirty working tree:

```sh
cd /c/Users/JoeWe/Desktop/Nucleor_OSS
git fetch --all
git worktree add ../Nucleor_OSS_probe -b probe/exploration origin/main
cd ../Nucleor_OSS_probe
```

After this, your absolute working dir is
`C:\Users\JoeWe\Desktop\Nucleor_OSS_probe\` and the file paths in
the section above just swap `Nucleor_OSS` for `Nucleor_OSS_probe`.
The `findings/` directory in YOUR worktree is the same git-tracked
directory — when you commit + push, the main agent pulls it.

### Rebase + rebuild cycle (do this between every probe sweep)

You are pulling whatever the main agent just shipped — including
potential compiler regressions (memory blowup, infinite loops,
runaway codegen). Two safety nets:

**1. E-stop — `tools/run_capped.ps1` (real-time, kills the process):**
```powershell
. .\tools\run_capped.ps1
$r = Run-Capped './bin/nucleor.exe' @('build','compiler/nucleor_s1_compiler.nr','-o','nucleor')
"wall=$($r.WallSec)s peak=$($r.PeakMB)MB"
```
- Hard kills at **1024 MB RSS** (system-protect; >1 GB risks
  crashing the user's machine).
- No fixed wall timeout by default. Pass `-TimeoutSec N` if you want
  one for a specific call (e.g. probe runs that might infinite-loop).
- Returns `WallSec` + `PeakMB` for drift checks.
- Never raise the 1024 MB cap. A process wanting more is the bug.

**2. Drift gate — `tools/check_perf_regression.ps1` (after rebuild):**
```powershell
.\tools\check_perf_regression.ps1 -Quiet
```
- Compares cold + hot self-build wall + peak RSS against
  `tools/perf_baseline.json`.
- Ceilings are **baseline + 10%** (cold ≤ 7.20s, hot ≤ 0.86s,
  peak RSS ≤ 552 MB). Anything over = regression on the version you
  just pulled = file a `compiler-meltdown` finding.
- Never raise the ceilings or `-Update` the baseline yourself —
  that's the main agent's call, and only after a justified perf
  change. **No-compound rule:** chained +10% bumps would silently
  bloat the compiler; ceilings are fixed at baseline+10%, not
  "previous run + 10%".

Current baseline (locked 2026-04-30): cold 6.54s / hot 0.78s /
peak 502 MB. Stay there.

Cycle:

```powershell
cd C:\Users\JoeWe\Desktop\Nucleor_OSS_probe
git fetch --all
git rebase origin/main
. .\tools\run_capped.ps1

# REBUILD under e-stop. If this kills on OOM or exits non-zero, that IS
# a finding — main shipped a compiler regression. File severity:
# compiler-meltdown (top of priority queue) and DO NOT proceed with
# probes against the old binary.
$r = Run-Capped './bin/nucleor.exe' @('build','compiler/nucleor_s1_compiler.nr','-o','nucleor')
Copy-Item -Force target/nucleor.exe bin/nucleor.exe

# DRIFT GATE — run after rebuild. Exit 1 = regression you just pulled.
.\tools\check_perf_regression.ps1 -Quiet
if ($LASTEXITCODE -ne 0) { Write-Warning "perf regression on this main commit — file compiler-meltdown finding" }

# HEARTBEAT — main reads this each loop-check.
@"
last_rebase: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))
commit: $(git rev-parse HEAD)
version: $((Select-String '^## \[' CHANGELOG.md | Select-Object -First 1).Line -replace '## \[(.*?)\].*','$1')
rebuild_wall_sec: $($r.WallSec)
rebuild_peak_mb: $($r.PeakMB)
drift_check_exit: $LASTEXITCODE
"@ | Set-Content findings/_heartbeat.md
git add findings/_heartbeat.md
git commit -m "heartbeat"
git push
```

**Probe runs:** wrap each in `Run-Capped` with `-TimeoutSec` set
based on what you expect (most probes finish in <1s; a 30s timeout
is generous). E-stop at 1024 MB RSS still applies. If a probe
hangs past timeout that's `severity: crash`. If the rebuild itself
melts down, that's `severity: compiler-meltdown`.

If `git rebase` hits conflicts in `compiler/*.nr` or any tracked
file you shouldn't have touched, **STOP and tell the user** — your
worktree should never have edits there.

### Daily checkpoint push

Push `probe/exploration` to origin at least once a day even if you
have nothing else to commit:

```sh
git push -u origin probe/exploration
```

This is your only protection against losing days of probes to a
crash.

If `git rebase` hits conflicts, **STOP and tell the user** — you should
never have edits in `compiler/*.nr`, so rebase conflicts there mean
something is wrong with your workspace.

### Read-only files (you must not touch)
- `compiler/nucleor_s1_compiler.nr`
- `compiler/nucleor_tools_suite.nr`
- `bin/nucleor.exe`
- `bootstrap/nucleor_s1_seed.ll`
- `CHANGELOG.md`, `RELEASES.md`
- Anything under `tests/` — those are the *promoted* fixtures owned by
  the main agent. Look but don't edit.
- `SELF_HANDOFF.md` — main agent's journal.
- `tools/check_compiler_drift.sh`, `tools/verify*.sh` — gate scripts.

### Writable workspace (yours)
- `probes/` — drop your exploratory `.nr` files here. Free-form.
  Subdirectories by theme are fine (`probes/closures/`,
  `probes/match/`, etc.).
- `findings/inbox/` — one finding file per discovered bug.
- Your own helper scripts in `probes/_tools/` if useful, but don't
  expect them to live forever — they'll be culled.

## How to probe

The technique that produced 24 silent-miscompute closes in v0.4.135–158:

1. Pick a corner of the language that hasn't been probed (see "Already
   covered" below — those are dead lanes).
2. Write a 3–8-line `.nr` program that exercises that corner under
   slightly unusual conditions (wrong type, unusual nesting, edge of a
   numeric range, void-returning thing in expression position, etc.).
3. Run it: `./bin/nucleor.exe build probes/<file>.nr -o /tmp/p && /tmp/p`.
4. Compare actual behavior to spec / common-sense expectation.
5. If it silently miscomputes, crashes without diagnostic, emits the
   wrong diagnostic, or accepts something it should reject — that's a
   finding.

### What counts as a finding

- **compiler-meltdown** — the compiler itself OOMs, hangs past
  timeout, or produces no output. Jumps to TOP of priority queue
  regardless of class. File this immediately and DO NOT keep
  probing against the offending main commit.
- **silent-miscompute** — compiles + runs, but produces wrong output.
- **crash** — compiles but SIGSEGVs / panics without a diagnostic
  (or runtime hangs past timeout).
- **wrong-error** — emits a diagnostic, but the wrong code or wrong
  message for the actual bug class.
- **missing-error** — should have rejected at compile time but didn't;
  runtime behavior may or may not be correct.

### What does NOT count (out-of-scope — don't file)
- Compiler bugs you can fix yourself by editing `compiler/*.nr` —
  STILL drop a finding, don't fix it. The main agent owns compiler edits.
- Things already covered by a fixture in `tests/err/` or
  `tests/features/`. Grep first: `grep -r "<keyword>" tests/`.
- Things shipped in a recent CHANGELOG entry. Read CHANGELOG.md from
  the top down to your last heartbeat version before each sweep —
  that's the canonical "already covered" list. (The static table at
  the bottom of this doc is just a starter; the live answer is
  CHANGELOG.)
- Behavior that's *deliberately* deferred (parser-only RFC-0027
  lifetimes, `Display`/`Debug` user-implementable in RFC-0028, etc.).
  See `docs/milestones/v0.4.0.md` and `docs/rfcs/` for status.
- **Perf regressions** — out of scope for the inbox. Main agent
  has `tools/check_perf_regression.ps1` for that.
- **Style / code-quality** complaints — out of scope.
- Anything you're <70% sure is a real bug — drop a question in
  `findings/inbox/_questions.md` instead of filing a noise finding.

## Finding file format

Copy `findings/_template.md` to `findings/inbox/YYYY-MM-DD-<slug>.md`
and fill it in. Format below.

```markdown
---
title: <one-line summary>
severity: silent-miscompute|crash|wrong-error|missing-error
probe_file: probes/<theme>/<name>.nr
diagnostic_actual: <code emitted, or "none">
diagnostic_expected: <code that should fire, or "n/a">
discovered_against: v0.4.NNN
commit: <git rev-parse HEAD output>
---

## Repro

```nr
// minimal .nr program, 5–15 lines
```

## Actual

What the compiler does today. Show output if relevant. If runtime
behavior, show stdout/exit code.

## Expected

What the spec / common sense says should happen.

## Suspected location

(Optional.) Skip unless obvious from grepping. Speculation worse
than silence.
```

The slug should be unique. Suggested format: `<area>-<corner>` e.g.
`enum-variant-shadow`, `for-on-option`, `tuple-struct-field`.

**One-shot write rule:** once a finding lands in `inbox/`, do not
edit it. If you learn more, drop `<slug>-followup.md` next to it or
append to `_questions.md`. Editing in-flight findings races the
main agent reading them.

## Cadence

Continuous. Whenever you have cycles, probe. There is no "done."

The main agent will pull `findings/inbox/` between every ship. When
they promote a finding, they:
1. Convert your repro into a permanent fixture (`tests/err/...`).
2. Fix the root cause in the compiler.
3. Ship as `v0.4.NNN`.
4. Move your finding file to `findings/promoted/YYYY-MM-DD-<slug>.md`
   with a backref appended noting the fixture path + ship version.

You do not move files yourself. The main agent moving the file is
how you know your finding was actioned. If a file sits in `inbox/`
for many sweeps, the main agent has either deprioritized it or
believes it's a dup — you can ask via `findings/inbox/_questions.md`
(append-only).

**Inbox can grow without bound — keep probing even if it backs up.**
The main agent triages on its own cadence (sometimes between every
ship, sometimes after a debug stretch). Don't slow your sweeps to
wait for the inbox to drain. The cost of a deep inbox is on the
main agent, not on you.

**Check `SELF_HANDOFF.md` "Where we are right now" each rebase.**
If the main agent is stuck on a debug cycle, that section will say
so. If it does, prefer probe lanes far from the area being debugged
so your findings don't pile up against work-in-flight.

## Already covered — read CHANGELOG.md (live source of truth)

Don't trust any static "already covered" table — they go stale fast.
**`CHANGELOG.md` is the canonical record.** Each rebase, scan the
`## [0.4.NNN]` headings between your last-heartbeat version and the
current top entry. Each ship's first descriptive line tells you
what zone closed. If a probe corner matches a recent close, skip it.

Quick scan command (paste into your shell):

```sh
awk '/^## \[/{ver=$0; getline; getline; if($0!="") print ver" — "$0}' CHANGELOG.md | head -40
```

The starter "do-not-re-probe" list as of v0.4.162 was:
v0.4.135 str-literal method dispatch · .136 bare-let-RHS-void
· .137 int/float compare · .138 struct name in value position
· .139 method on void receiver · .140 heterogeneous match arms
· .141 int/float arithmetic · .142 return-expr in void fn
· .143 float/bool SIGSEGV · .144 nested call in helper arg
· .145 if-expr type mismatch · .146 closure wrong-argc
· .147 struct comparison · .148 struct-as-fn · .149 print non-str
· .150 String arith · .151 String == String
· .152 for over str/String/scalar/bool · .153 per-op saturating
· .154 String use-after-move · .155 let-mut-no-init
· .156 closure-void-as-0 · .157 ? on non-Result var
· .158 kind-8 type_expr cascade · .161 shift via let-const
· .162 generic trait bounds.

After v0.4.162 the live answer lives in CHANGELOG, not here.

## Suggested probe lanes (untouched corners as of v0.4.162)

These are guesses — find your own once you've burned through them.

- **Generics interactions** — generic struct field access through a
  `T: Trait` bound where `T` resolves to a concrete type at call site.
  v0.4.162 covers the bound-check; the *use* side is unprobed.
- **Range patterns at exhaustiveness boundaries** — `1..=9` followed by
  `10..=19` followed by `_` — does the exhaustiveness checker correctly
  see `_` as unreachable, reachable, or silently ignore?
- **Tuple struct field access** — `struct P(i32, i32);` followed by
  `let p = P(1,2); p.0` — does this work, error cleanly, or miscompute?
- **`for` over a non-iterator** — v0.4.152 covered str/String/scalar/bool.
  What about `for x in some_struct_value`? `for x in 42..=10`
  (reverse-empty range)?
- **Methods on borrowed references** — does `(&s).method()` work the
  same as `s.method()`? Different? Silently?
- **Match on `()`** — `match () { () => ... }`. Match on void return
  values. Match arms that themselves return different concrete types
  but in a context that wants `()`.
- **Module-resolved generics** — `mod m { fn id<T>(x: T) -> T { x } }
  m::id(42)` — does the path-resolver re-instantiate the generic
  correctly, or fall through to a synthesized monomorph?
- **Closures capturing by reference vs by value** — RFC-0025 is in
  draft. Where does the compiler currently disagree with the draft?
- **`as` casts at narrow boundaries** — `let x: i64 = 5_000_000_000;
  let y: i32 = x as i32;` — does the truncation happen silently? Is
  there a NUM diagnostic that should fire?
- **Index out of bounds on empty Vec** — `let v: Vec<i32> = Vec::new();
  v[0]` — does this panic with a clean RT- diagnostic, SIGSEGV, or
  return garbage?
- **Drop ordering for nested struct + Vec field** — does the inner Vec
  drop correctly? Are there cases where it leaks?

## Don't do

- Don't push to `main`.
- Don't create `spike/*` branches — those belong to the
  thrashing v2 agent. You stay on `probe/exploration`.
- Don't tag.
- Don't edit any compiler / runtime source. If you think you see the
  fix, write it in the finding file's "Suspected location" — don't
  apply it.
- Don't bundle multiple unrelated bugs in one finding. One file = one
  finding. Promote granularity is per-ship.
- Don't optimize for finding count — optimize for *actionable*
  findings. A vague "this looks weird" with no clean repro is noise.
- Don't ship a finding that's just "X is unimplemented" — check
  `docs/milestones/v0.4.0.md` and `docs/rfcs/` first; intentional
  deferrals aren't bugs.

## Read this before starting

- `SELF_HANDOFF.md` — main agent's journal, read-only for you.
- `findings/README.md` — inbox protocol details.
- `docs/milestones/v0.4.0.md` — what's deferred vs. what's expected to
  work, so you don't file deferred-feature reports as bugs.
- `tests/err/` and `tests/features/` — index of what's already covered.
- `CHANGELOG.md` — recent ships tell you what zones just got closed
  and might be worth probing the *neighbors* of.
