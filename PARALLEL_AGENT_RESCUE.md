# Parallel Agent — Fresh Start

You are taking over the parallel-agent spike workstream. The previous
parallel session got lost; ignore any stale state in the v2 worktrees
listed in `SELF_HANDOFF.md`. Start clean.

## What "in good shape" means right now (2026-04-29)

- Main HEAD: `951dc0c` (v0.4.155). Drift gate clean. T1.7 first-pass.
  Parallel verifier 208 PASS / 2 baseline-FAIL (`lang/mod_decl_aux`,
  `runtime/stdin_read` — those two NEVER count as regressions).
- Main agent (separate session) is actively shipping silent-miscompute
  closes (probe-driven, broad surface). They will keep pushing tags
  v0.4.156+ throughout your session.

**You will NOT push to `main`. Ever. You push only to spike branches.**
The main agent does ALL integration.

## How to not collide with the main agent

This is the lesson from the previous session: the v2 spikes were
branched at v0.4.149/.153 but cherry-picked when main was at v0.4.155.
The cherry-pick silently REVERTED main's intervening changes. The main
agent had to do manual conflict surgery on every spike. **You must
prevent this.**

### Rules

1. **Always branch from CURRENT main**, never from a stale tag:
   ```sh
   git fetch --all
   git checkout origin/main
   git checkout -b spike/v04-<topic>-v3   # always v3, leave the v2 branches alone
   ```

2. **Pick a topic in a code region the main agent is NOT probing.** The
   main agent probes broadly (type-mismatches, dispatch fall-throughs,
   silent miscomputes across kind-3/4/7/8/12/20/22/23/38/49/52). To
   stay clear, prefer **structural / runtime / tool work** — these
   change different regions than probe ships:

   **Available residuals from `PARALLEL_AGENT_HANDOFF_v0.4_RESIDUALS.md`**:
   - **#6 verify_parallel.sh fold-in** — pure tool-script work in
     `tools/verify_parallel.sh` and `tools/verify.sh`. ZERO compiler
     overlap. **Best first pick.** Previous attempt is parked at
     `spike/v04-verify-parallel-foldin-v2` — review for ideas but
     start fresh on `-v3`.
   - **#7 var-RHS shift bounds** — emit a runtime check when the shift
     amount in `x << n` / `x >> n` is a non-literal var (the
     v0.3.214 panic helper covers literals only). Touches kind-4 binop
     dispatch — overlaps with main's probe area. Coordinate before
     starting.
   - **#1 trait-bound call-site impl-existence** — verify at type-check
     that `T: Trait` bounds have actual `impl Trait for T` blocks.
     Touches kind-7 (call) and kind-12 (Type::method). Heavy compiler
     overlap. Last to attempt.

3. **Rebase frequently** while you work:
   ```sh
   git fetch --all
   git rebase origin/main          # from your spike branch
   ```
   If main moves while you're working and `rebase` produces conflicts
   in `compiler/nucleor_s1_compiler.nr` or `compiler/nucleor_tools_suite.nr`,
   STOP and tell the user. Do not auto-resolve.

4. **NEVER include `bin/nucleor.exe` or `bootstrap/nucleor_s1_seed.ll`
   in your spike commits** if you can avoid it. Those binaries are
   regenerated at integration time by the main agent against the
   then-current source tree. Including them in your push just creates
   noise in the diff. (If a particular gate insists on a fresh seed —
   T1.7 won't pass without it — commit it for your own validation
   then `git rm` it before pushing the final spike commit.)

   Better: validate locally with seed regenerated, but craft your
   final push commit to source-only.

## Per-spike gate (run BEFORE pushing your branch)

```sh
# 1. Build both compilers with current bin/nucleor.exe
./bin/nucleor.exe build compiler/nucleor_s1_compiler.nr -o nucleor
./bin/nucleor.exe build compiler/nucleor_tools_suite.nr -o nucleor_tools

# 2. Promote (locally — DO NOT commit these)
cp -f target/nucleor.exe bin/nucleor.exe
cp -f target/nucleor_tools.exe bin/nucleor_tools.exe
cp -f target/nucleor.ll bootstrap/nucleor_s1_seed.ll

# 3. T1.7 fixed-point — must match first-pass
./bin/nucleor.exe build compiler/nucleor_s1_compiler.nr -o _seed_check
sha256sum bootstrap/nucleor_s1_seed.ll target/_seed_check.ll
# Both lines must be identical sha.

# 4. Drift gate — must return 0
./tools/check_compiler_drift.sh

# 5. Parallel verifier — must show 208 PASS / 2 baseline-FAIL
./tools/verify_parallel.sh -j 12
```

If any of these break, fix it before pushing. The main agent will
re-run all gates at integration time and reject the spike if anything
fails.

## Hand-off back to the main agent

When your spike is ready:

1. Push the source-only branch:
   ```sh
   git checkout -- bin/nucleor.exe bootstrap/nucleor_s1_seed.ll
   git push -u origin spike/v04-<topic>-v3
   ```
2. Notify the user with:
   - Branch path on origin
   - Commit sha
   - Base commit (which main tag you branched from)
   - Validation summary (T1.7 first-pass, drift clean, verify count)
   - Scope: one-line description of the bug/feature
3. The main agent will:
   - Fetch
   - Rebase your spike onto current main (resolving any conflicts)
   - Regenerate bin/seed against the rebased source
   - Run all gates fresh
   - Tag as v0.4.NNN
   - Push main + tag

## Don't do

- Don't push to `main`.
- Don't tag your branch (`git tag` is main-agent-only).
- Don't cherry-pick from `main` into your spike — `git rebase` instead.
- Don't include the seed.ll regeneration in your spike's diff if you
  can keep it source-only.
- Don't bump version numbers in CHANGELOG.md / RELEASES.md / source
  comments — the main agent assigns vN at integration.
- Don't attempt residual #1 (trait-bound) without coordinating — it
  overlaps the main agent's probe area heavily.

## Read this before starting

- `SELF_HANDOFF.md` (the main-agent's session journal — context for
  current state)
- `PARALLEL_AGENT_HANDOFF_v0.4_RESIDUALS.md` (the original spike
  workstream contract — items #1, #6, #7 still open)
- `PARALLEL_AGENT_BLOCKERS.md` (Windows file-lock workaround you
  may need: `rm -f bin/nucleor.exe && sleep 2`)

## Suggested first move

Pick residual #6 (verify_parallel.sh fold-in). Pure tool work, zero
compiler overlap, smallest collision risk with whatever the main agent
is probing. The previous attempt at `spike/v04-verify-parallel-foldin-v2`
got close but never landed — re-derive on a fresh `-v3` branch from
current main. The user noted the missing-result-file issue appears
fixed; remaining gating problem was unrelated stale-base failures
that are no longer present at v0.4.155.
