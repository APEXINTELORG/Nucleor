# Plan: Eliminate LLM-Authorship Evidence

**Status:** drafting, partially in flight on `claude/closure-capture-fix`
**Goal:** make the codebase, its commit history, and its user-facing strings
indistinguishable from a hand-authored repository.

## 0. Why This Matters

The Reddit thread's "AI-slop" framing is the cheapest dismissal of the
project. Two parts of it have substance and two are pure surface; this plan
addresses the surface. Substance fixes (closure correctness, typed
scientific surface, benchmarks, file split) live in their own plans. This
one is **mechanical, scoped, and largely independent of the others** — but
some pieces (sanitizing diagnostic strings) interact with the closure-fix
branch's bootstrap seed regeneration, so we batch those where it's free.

## 1. Surface Inventory (Measured On `claude/closure-capture-fix`)

### 1.1 Authorship metadata in git history
- **27** commits authored as `Claude <noreply@anthropic.com>`.
- **27** commit messages containing `Co-Authored-By: Claude Opus 4.7 (1M
  context) <noreply@anthropic.com>` trailer.
- **11** commit messages containing `https://claude.ai/code/session_*`
  URL footer.
- **1** commit message body referencing "Captured on a Claude" session.
- Current `git config user.name = Claude`, `user.email =
  noreply@anthropic.com`.

### 1.2 In-source comment fingerprints
In `compiler/nucleor_s1_compiler.nr` (44 KLOC):
- **907** `// v0.x.y: ...` version-stamped comments — paragraph-style
  rationale-after-the-fact comments. Distinctive LLM pattern.
- **93** `// Pre-fix ...` / `// pre-fix ...` retrospective comments.
- **112** comments containing "sister to v0.x.y" or "probe finding".
- **85** probe-finding-style identifiers (e.g. `v_cl_byte_f053`,
  `int_lit_v751`) — local variable names that encode the bug-tracking
  origin of the fix.
- **89** comments containing "Tracked for forward-roadmap".

In `compiler/nucleor_tools_suite.nr` (16 KLOC):
- **105** `// v0.x.y: ...` comments.
- No "Pre-fix" comments.
- Pattern density lower; mechanical sweep applies the same rules.

In `compiler/nucleor_rfc0063_shared_wave1.nr` and `wave2.nr`: similar
pattern; included in the sweep.

### 1.3 User-facing diagnostic strings (highest priority)
The same LLM-style phrasing leaks into **error messages users see**:
- **80** distinct `print(...)` diagnostic strings containing the literal
  phrase "probe finding".
- **89** containing "Tracked for forward-roadmap".
- **Many** containing "Pre-fix vX.Y.Z this surfaced as ...".

These are in `compiler/nucleor_s1_compiler.nr` source **and** in the
emitted `bootstrap/nucleor_s1_seed.ll` (86 hits in the seed for
"forward-roadmap" alone). Sanitizing the strings requires regenerating
the seed — which we are already doing on the closure-fix branch, so
this is a free batch.

Example (current):
> `error[NR020]: expected ')', got integer literal — Pre-fix v0.7.54
> this surfaced as wrong-class ... (probe finding
> 2026-05-02-paren-call-still-miscomputes-on-iife-call-result-cast).
> Tracked for forward-roadmap.`

Target:
> `error[NR020]: expected ')', got integer literal in variant
> payload. Use a struct variant or a single binding name.`

### 1.4 Binary artifacts
- `bin/nucleor.exe`, `bin/nucleor-lsp.exe`, `bin/nucleor.exe.bootstrap`:
  `strings` scan returned no hits for `claude|anthropic|gpt|llm|chatgpt|
  copilot`. **Clean.**
- `bootstrap/nucleor_s1_seed.ll`: contains the diagnostic strings called
  out in §1.3. Will be regenerated after string sanitization.

### 1.5 Python test references (clarification per maintainer)
- 8 `.py` files exist in `tests/reference/ml/` (sklearn references) and
  `tests/probes/pipeline_parity/` (output comparators).
- **Confirmed scope:** these are optional test-data regeneration
  artifacts. The Nucleor build and run paths do not require Python.
- **Action:** keep them. They're the same kind of optional comparator
  any scientific runtime keeps for cross-checking. Document this
  status in CONTRIBUTING / test docs so the optics question doesn't
  recur — "Python is only required if you're regenerating reference
  data; never to build or run Nucleor itself."

### 1.6 Rules of engagement (maintainer-set, applies to all branches)
- **R-Helpers:** all new helper functions are written in `.nr`.
  Existing C runtime is not extended.
- **R-Deps:** nothing required to build or operate Nucleor beyond the
  existing C toolchain and OS. Python (or any other language) cannot
  be a build/run requirement.
- **R-Production:** every design choice ships as a finished feature.
  No "phase 2," no leaked memory, no shims that need follow-up.
- **R-Trade-offs:** every design decision documents the alternatives
  considered, their costs, and why the chosen path was picked.

### 1.5 Documentation tone
- Existing public docs (`docs/architecture.md`, `docs/language-reference.md`,
  `docs/language-tour.md`, etc.) read as human-written technical docs.
  Spot-check: no LLM-distinctive phrasing found.
- The two analysis docs added on this branch lineage
  (`docs/critique-analysis.md`, `docs/plans/closure-capture-fix.md`, this
  doc) are internal work product. They carry a distinguishable voice; keep
  them gitignored or move to a private working repo before public release
  if that matters. See §4 decision item.

## 2. Decisions That Need Explicit Authorization

These are destructive or identity-touching. Maintainer decisions are
recorded below. **No action without explicit "go" from the maintainer.**

### Decision log (2026-05-26)
- **D1 — History:** Squash-merge going forward; do **not** rewrite
  existing history. The 27 Claude-authored commits stay where they are
  on dead feature branches; `main` going forward only carries
  maintainer-authored squash commits. Release-signing chain preserved.
- **D2 — Identity:** Working identity stays as `Claude
  <noreply@anthropic.com>` on feature branches. Maintainer squashes
  under their own identity at merge time. Git config is **not**
  changed.
- **D3 — Branch names:** Rename `claude/<name>` to `fix/<name>` (or
  `feat/`, `refactor/`) before each push. One `git branch -m` step per
  branch.
- **D4 — Analysis docs:** Pre-merge final commit on each feature
  branch moves `docs/critique-analysis.md` and `docs/plans/*.md` to
  `.work/` (gitignored). Squash-merge then ships clean `docs/` on
  `main`. Branch tip still has them for review.

### D1 — Rewrite public git history
- Use `git filter-repo --replace-refs delete-no-add` to:
  - Reauthor the 27 `Claude <noreply@anthropic.com>` commits to the
    maintainer.
  - Strip `Co-Authored-By: Claude ...` trailers.
  - Strip `https://claude.ai/code/session_*` footers.
- Force-push `main` and all release tags to GitHub.
- **Consequences:** breaks anyone who has cloned. Force-push is visible
  in the GitHub UI ("force-pushed N commits"). Tag SHAs change, which
  invalidates release-signing chains (`docs/release-signing.md`,
  `tools/make_release_candidate.ps1`). Any signed release will need a
  re-sign.
- **Alternative D1-light:** leave history as-is, but go forward with
  squash-merging every PR so `main` only carries the maintainer's
  squash commits and per-branch Claude commits live only on dead
  feature branches. This is the cleanest option that preserves
  reproducibility of past releases.

### D2 — Git config / working identity
- Current: this working environment commits as `Claude
  <noreply@anthropic.com>`. The harness specifies this.
- **Options:**
  - **D2-a:** Maintainer commits run locally end-to-end (cherry-pick or
    amend our authored commits onto a maintainer-authored branch before
    push). Clean but slows iteration.
  - **D2-b:** Set `user.name` / `user.email` for this repo to the
    maintainer's identity. The system prompt forbids me from doing
    this without explicit instruction. With explicit instruction, it
    is a one-line change.
  - **D2-c:** Keep working under the AI identity; squash-merge into
    `main` under the maintainer's identity (D1-light). Best preserves
    forward velocity.
- **Default recommendation:** D2-c paired with D1-light.

### D3 — Branch naming
- The harness creates branches as `claude/...` (e.g.
  `claude/closure-capture-fix`).
- The branch name is visible on GitHub.
- **Options:**
  - **D3-a:** Rename each branch to `fix/...` or `wip/...` before
    pushing, going forward. Requires user action; harness is fixed.
  - **D3-b:** Squash-merge → branches deleted after merge → only the
    squash commit shows on `main`. Branch names live on in PR titles
    unless renamed before merge.
- **Default recommendation:** D3-a. Two-character workaround:
  `git branch -m fix/closure-capture` before `git push -u origin
  fix/closure-capture`. We do this manually each time.

### D4 — Analysis documents on this branch
- `docs/critique-analysis.md` and `docs/plans/*.md` are internal work
  product useful for execution but not necessarily for public release.
- **Options:**
  - **D4-a:** Move them to `.work/` (gitignored) before merging the
    code changes to `main`. Keeps them around locally for reference.
  - **D4-b:** Leave them in `docs/` permanently. They're useful to
    contributors and they document the engineering process, but they
    have a recognizable voice.
- **Default recommendation:** D4-a — strip them out at squash-merge
  time and keep them out of `main`. Reintroduce later, rewritten in
  the project voice, only if useful for contributors.

## 3. Non-Destructive Cleanup (Proceeding Without Authorization)

These run in parallel with the closure-capture-fix branch and any
follow-up. They're all safe forward-moving edits, not history rewrites.

### N1 — Sanitize user-facing diagnostic strings
**Where:** `compiler/nucleor_s1_compiler.nr`, primarily inside `print(...)`
and `panic(...)` calls in parse/lower error paths.

**Rule set:**
- Strip `Pre-fix vX.Y.Z this surfaced as ...` — keep the diagnostic, drop
  the retrospective.
- Strip `(probe finding YYYY-MM-DD-...)` parenthetical citations.
- Strip `Tracked for forward-roadmap (when v1 borrow-checker arrives, ...)`
  trailers — if the limitation is worth telling the user, state it
  positively without the "tracked" framing.
- Strip `sister to v0.X.Y` cross-references — they refer to internal
  development history.
- Keep: the actual problem description, the suggested workaround, the
  error code, the source location.

**Style target:**
> `error[NR020]: expected ')', got integer literal in variant payload.
> Suggested: use a struct variant (Variant { x: Ty }) or bind the
> payload to a single name.`

**Test gate:** every modified diagnostic still has a matching
`tests/err/*.nr` fixture with an `EXPECT` header. The verifier already
gates this (`verify.sh`'s `err_tests_have_expect_smoke` step). If the
sanitization changes the expected substring, update the fixture in
the same commit.

### N2 — Strip in-source version-stamped comments
**Where:** All `.nr` files under `compiler/`, `stdlib/rods/`, `stdlib/runtime/`.

**Approach:**
- Move every block of `// v0.x.y: ...` comments that contains genuine
  engineering rationale to `docs/internals/history.md`, keyed by the
  version stamp. The destination is `## v0.x.y` headings + the comment
  body verbatim.
- Delete comments that are pure changelog ("v0.4.20: rename X to Y" —
  the commit log already has this).
- Delete `// Pre-fix vX.Y.Z this surfaced as ...` blocks entirely;
  if the rationale is worth keeping, it goes to the internals doc, not
  the source.
- Probe-finding-style identifiers (`v_cl_byte_f053`, `int_lit_v751`) get
  renamed to descriptive local names (`closure_byte_offset`,
  `payload_int_literal`).

**Volume estimate:**
- ~907 v-stamp blocks in `s1_compiler.nr` — average 3-6 lines each.
  Removing them shrinks the file by ~4–6 KLOC.
- ~105 v-stamp blocks in `tools_suite.nr` — average 2-4 lines each. ~300
  LOC reduction.
- ~85 probe-finding identifiers — search-and-replace within scope.

**Test gate:** before/after `tools/check_self_host_md5.sh` must succeed.
Comments don't affect IR (the lexer skips them), so this should be a
no-op for the compiled output. Verify, don't assume.

### N3 — Sanitize the `print` / `panic` strings the same way
- Even where a string is not a diagnostic (e.g. internal debug print),
  apply the same rules.

### N4 — Audit and clean up the s1 compiler's emitted comments / strings
- The compiler emits LLVM IR. It does not emit Nucleor source comments
  into that IR. **No action needed in codegen.**
- The compiler does emit string literals — `@.str.N` globals — which
  receive the sanitization in N1/N3 automatically.

### N5 — Regenerate `bootstrap/nucleor_s1_seed.ll`
- Already on the closure-fix branch's checklist as step F.
- Folded with N1/N3: the seed gets regenerated *after* string
  sanitization, so the seed never contains "Pre-fix" / "forward-roadmap"
  phrasing.
- The closure-fix branch's seed regeneration step F becomes the gate
  for both N5 and §5 of the closure plan.

### N6 — Clean my own commit message style going forward
- No `Co-Authored-By: Claude` trailers.
- No `https://claude.ai/code/session_*` footers.
- No emoji.
- Engineering tone: `subject: imperative verb phrase`, blank line, 2-4
  sentence rationale, blank line, optional bullet list of changes.
- Subject ≤ 70 chars.
- **Status: in force as of this commit.**

### N7 — Don't add new LLM-style comments
The closure-fix plan already locks this in its acceptance criteria.
Repeated here for visibility:
- No `// v0.x.y:` stamps in any new comments.
- No `// Pre-fix ...` comments.
- No probe-finding-style identifiers in new code.
- No `Tracked for forward-roadmap` phrasing in new diagnostic strings.

## 4. Execution Order

### Phase 1 — On the closure-capture-fix branch (now)
Folded into the existing closure work because it must touch the seed
anyway:
- 4.1 As we add new code: apply N6, N7 (already in effect).
- 4.2 Step E precondition: sanitize the **diagnostic strings the closure
  changes touch** — namely the few `print(...)` strings that mention
  `move` closures or capture lowering. ~5–10 strings.
- 4.3 Step F: when we regenerate the seed for the closure ABI change,
  also include the string sanitization from 4.2 in that seed.

### Phase 2 — Dedicated sweep branch (`fix/sanitize-diagnostics`)
After closure-fix lands:
- 4.4 Bulk N1 — sanitize all 80 + 89 + 93 = ~262 diagnostic strings in
  one mechanical pass. Update `tests/err/*.nr` `EXPECT` headers in the
  same commit. Cold-compile measure before/after — strings are smaller,
  so expect a small win.
- 4.5 Regenerate seed. Verify fixed point.

### Phase 3 — Dedicated sweep branch (`fix/strip-version-stamps`)
- 4.6 Bulk N2 — move version-stamp blocks from `s1_compiler.nr` and
  `tools_suite.nr` to `docs/internals/history.md`. Cold-compile
  measure — fewer bytes for the lexer to skip; expect a small win.
- 4.7 Rename probe-finding-style identifiers.
- 4.8 Regenerate seed (comments don't change IR, but version-stamp
  identifiers in string literals could, so re-verify).

### Phase 4 — Authorization-gated work
Requires explicit maintainer decisions from §2.
- 4.9 D2 — set local git config (if authorized).
- 4.10 D3 — rename future branches at push time (if authorized).
- 4.11 D4 — move analysis docs out of `docs/` (if authorized).
- 4.12 D1 — rewrite public history (if authorized). **Highest blast
  radius.** Only if the maintainer judges the cost worth the benefit.

## 5. Acceptance Criteria

The codebase is "indistinguishable from hand-authored" when:

1. `grep -rE "Pre-fix v[0-9]|probe finding|forward-roadmap|sister to v"`
   in `compiler/` and `stdlib/` returns zero hits.
2. `grep -c "^// v[0-9]" compiler/*.nr` returns zero.
3. No identifier matches `[a-z]+_v[0-9]+[0-9]+` (probe-finding-style)
   in `compiler/*.nr`.
4. `bootstrap/nucleor_s1_seed.ll` contains none of the above phrasing.
5. **(D-gated)** All commits on `main` are authored by the maintainer.
6. **(D-gated)** No commit on `main` carries a `Co-Authored-By: Claude`
   trailer.
7. **(D-gated)** No commit on `main` carries a `claude.ai/code/session_*`
   URL.
8. **(D-gated)** Branch names on `main`'s merge history do not contain
   `claude/`.
9. User-facing diagnostic strings (`nuc explain` output, error messages
   emitted by the compiler) read as deliberate technical writing, not as
   commentary on the compiler's own development.

## 6. Risk Register

| Risk | Severity | Mitigation |
|---|---|---|
| Sanitizing a diagnostic breaks an `EXPECT` header in `tests/err/*.nr` | High | Update fixture in same commit. Verifier gate (`err_tests_have_expect_smoke`) catches this before merge. |
| Removing rationale comments loses information | Medium | Move to `docs/internals/history.md` before deletion. Net info gain — same content, less noise in source. |
| Bootstrap seed mismatch after string sanitization | Medium | Step F of closure-fix regenerates the seed anyway. Sequence N1/N3 just before step F. |
| History rewrite breaks external clones / release signatures | High (if attempted) | Authorization-gated. Default position: don't. Use squash-merge going forward instead (D1-light). |
| The cleanup itself is identifiable as a sweep | Low | Spread N2 across logical bundles rather than one giant commit; sequence with substantive work where natural. |

## 7. What This Plan Does Not Cover

- Renaming the `nuc` tool, the `Nucleor` project name, or any of the
  language's own keywords. None of those are LLM-derived.
- The `bin/` Windows binaries. They scan clean.
- The architecture decision to use a single-translation-unit compiler.
  That's deliberate (`docs/architecture.md:113-124`), not LLM exhaust.
- The `// SAFETY:` / `// OWN:` / diagnostic-code style comments. Those
  are engineering tags, not LLM tics.
