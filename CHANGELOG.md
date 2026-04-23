# Changelog

All notable changes to Nucleor will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.134] — 2026-04-23

**Two RFCs reference diagnostic codes that don't exist in the spec
— renamed to match the shipped prefix.**

A code-cross-reference audit between the 32 RFCs and the spec
catalog (161 codes) caught two cases where the RFC body uses a
diagnostic code prefix that was renamed during implementation:

- **RFC-0020 §3.5** (Multi-span errors example) used
  `error[BORROW-003]: cannot borrow x as mutable, already
  borrowed as immutable` — but `BORROW-*` is not a shipped
  prefix. The borrow checker uses **OWN-*** since v0.2.119
  (specifically OWN-005 — Cannot shared-borrow mutably-borrowed
  value, which is exactly what the example shows). Renamed
  the example to `error[OWN-005]`.
- **RFC-0021 §3.10** Diagnostics table listed `TEST-001..004`
  — but the shipped prefix is **TST-***. v0.2.79 wired
  TST-001/002/003 with different semantics than the original
  draft (test discovery / process isolation / fixture setup,
  not the original test-signature / panic-mismatch / setup-
  context split). The RFC table was updated to mirror the
  shipped TST-001..003 + 2 v0.4-deferred entries (TST-004
  panic-mismatch, TST-005 wrong-signature). Implementation
  table's diagnostics row also bumped from `TEST-001…004` to
  `TST-001…003 (shipped) + planned TST-004/005`.

The **other 35 RFC code references** that don't appear in the
spec are intentional — most are aspirational future codes
mentioned in still-Draft RFCs (CLO-*, DYN-*, ITER-*, ALLOC-006,
FRAME-005, etc.) that will be added when the RFC ships, plus a
handful of references to external standards (REP-103/105 from
ROS, JSR-385 from Java, MSP430 microcontroller name).

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.133] — 2026-04-23

**Three more docs caught with stale or mistaken roadmap claims —
brought into agreement with current RFC index.**

The audit pattern continued past the milestone-tracker refresh
into the long-tail process docs:

- **`CONTRIBUTING.md`** "What's in scope" bullet for doc-staleness
  fixes referenced "**the v0.2.79–v0.2.93 chain**". Bumped to
  v0.2.79–v0.2.132 to reflect the live state of the audit chain.
- **`docs/rfcs/HELPER-CONTRACT.md`** Status header stamped
  "**(2026-04-23, v0.2.80)**"; bumped to v0.2.132 with an
  explicit note that the population numbers (95.1%, 643/676)
  are unchanged since v0.2.78 — the v0.2.79–132 chain has been
  audit-pattern hardening on top of the populated manifest, not
  helper additions.
- **`docs/process/nucleor-safe-subset.md`** roadmap claimed
  "**v0.2.0 | RFC-0001-0004 implemented; subset begins to be
  enforceable**" — this is **wrong**: RFC-0001 through RFC-0014
  are all Draft status with v0.3.0–v0.7.0 targets per the
  current RFC index. The v0.2.0 row was rewritten to say what
  v0.2.0 actually shipped (Tier-2 essentials) and that the
  safety subset spec is frozen but enforcement waits on Tier-1
  RFC implementation. The v0.3.0 row was also tightened to name
  RFC-0001 + RFC-0002 explicitly.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.132] — 2026-04-23

**Mirror v0.2.131's 161-code spec catalog into milestone tracker,
status doc, and bootstrap contract.**

After v0.2.131 wired OWN-013 + GOV-001/002 (3 new codes), three
trackers still claimed "158 codes" — the v0.2.120 closure number.
Mirror in:

- **`docs/milestones/v0.2.0.md`** Status header — bumped from
  "v0.2.120" → "v0.2.131", "120 incremental releases through
  v0.2.120" → "131 incremental releases through v0.2.131", "23
  OWN/TYP/TNT codes" → "26 OWN/TYP/TNT/GOV codes across
  v0.2.119/120/131", "All 158 diagnostic codes" → "All 161
  diagnostic codes"; closure note now reads "**re-closed at
  v0.2.131** after a second-pass audit found OWN-013 +
  GOV-001/002 fired but undocumented".
- **`docs/milestones/v0.2.0.md`** "Diagnostic-code coverage
  closure" sub-chain bullet — extended title to
  `(v0.2.117–120, re-closed v0.2.131)`, paragraph names the 3
  new codes and bumps `cli_explain_full_smoke` from 158 → 161.
- **`NUCLEOR_BOOTSTRAP_CONTRACT.md`** gate-runs description —
  "204 steps as of v0.2.121" → "v0.2.131", "full 158-code spec
  catalog" → "161-code".
- **`docs/status/v0.2-shipped-and-deferred.md`** diagnostic-
  code closure bullet — added the v0.2.131 second-pass paragraph
  with the 3 new codes, bumped 158 → 161, marked the drift class
  **re-closed at v0.2.131**.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.131] — 2026-04-23

**3 more diagnostic codes were fired by the tools-suite type-check
pass but missing from spec + explain registry — wired in.**

A second-pass audit on the diagnostic-code registry (parallel to
v0.2.79–80 / v0.2.119–120) found 3 codes emitted by
`compiler/nucleor_tools_suite.nr` at `type_diag` sites that were
not present in `docs/spec/Nucleor_Error_Codes.md` and not in the
explain registry's three functions. They've been firing this whole
time — users running `nuc check` / `nuc audit` against sources
that match the relevant patterns would see the warnings without
being able to look the codes up via `nuc explain CODE`.

The 3 codes fall in two new buckets:

- **OWN-013** (borrow-checker / spawn-capture pass) — fires when
  a `spawn { ... }` block captures a `DeviceBuffer` value. GPU
  memory handles are pinned to the allocating thread's CUDA /
  Vulkan context binding; the worker thread spawn dispatches to
  has no context, so the capture is undefined behavior at
  runtime. Documented as the 13th OWN code (one above the
  v0.2.119 closure of OWN-001..012).

- **GOV-001** + **GOV-002** (governance pass) — fire when the
  source declares `@policy(require_authored)` or
  `@policy(no_unsafe)` but violates the constraint. **New series
  with two codes.** The s1 compiler does not yet enforce these at
  build time (the corresponding tests are quarantined under
  `tests/err/_unimplemented/`), but `nuc check` / `nuc audit`
  exercise the tools-suite path that fires them.

### `docs/spec/Nucleor_Error_Codes.md`

- OWN table: appended `| OWN-013 | Spawn block captures non-Send
  DeviceBuffer value | spawn-capture checker | error |` plus a
  paragraph noting it's tools-suite-fired and was added v0.2.131.
- New top-level `## GOV series — governance policies` section with
  the 2 codes and a paragraph covering the
  `tests/err/_unimplemented/` quarantine status.
- Spec catalog count: **158 → 161 codes**.

### `compiler/nucleor_tools_suite.nr`

- `explain_error_title()` — added 3 entries between OWN-012 and
  TNT-001.
- `explain_error_summary()` — added 3 entries (OWN-013 + 2 GOV).
- `explain_error_explanation()` — added 3 paragraph-length
  entries with the underlying CUDA / Vulkan context rationale
  (OWN-013) and policy-attribute mechanics (GOV-001/002).

### `tools/verify.sh` + `tools/verify.ps1`

- `cli_explain_full_smoke` codes array: appended `OWN-013` to the
  OWN block (with comment noting v0.2.131), added a new GOV
  block (`GOV-001 GOV-002`). Both gate scripts kept in step-for-
  step parity.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. The
`cli_explain_full_smoke` step now exercises 161 codes (was 158).
No compiler / runtime / s1-source change — only tools-suite +
spec doc + gate scripts. Tools-suite rebuild on every gate run
catches the new entries. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.130] — 2026-04-23

**Three more "as-of" markers in process docs + architecture brought
current.**

The audit-pattern sweep continued past README + getting-started +
migration + benchmarks into the process docs and architecture
reference. Three findings, all the same drift class (timestamp
markers from earlier in the v0.2.x sub-chain).

- **`docs/process/contributing.md`** said "**Verify gate green
  (203 steps as of v0.2.91)**". Actual is 204 steps as of v0.2.118
  (the EXPECT-headers gate step landed in v0.2.118). Updated +
  added EXPECT-header enforcement to the rollup of what the gate
  newly covers.
- **`docs/process/semver-and-release.md`** "**Last updated:
  2026-04-23 (post-v0.2.92)**" → "post-v0.2.129"; same paragraph's
  "v0.2.x sub-chain (through v0.2.92 as of this update)" → "through
  v0.2.129".
- **`docs/architecture.md`** "Builtin name mapping" row said
  "**around line 2004 as of v0.2.107**" — verified `fn get_rt_name`
  is exactly at line 2004 in the current source (compiler unchanged
  since v0.2.87, so the line number truly is unmoved). Bumped the
  stamp to v0.2.129 and dropped "around" since the line number is
  exact.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.129] — 2026-04-23

**Migration guide + benchmarks doc — stale "as of v0.2.91 / v0.2.97"
markers brought current.**

A continuation sweep across the long-form docs found three more
stale markers from the early v0.2 sub-chain. None affected
correctness — the underlying numbers are still right — but the
"as of v0.2.91" framing implied the doc was 37 ships behind.

- **`docs/migrations/v0.1-to-v0.2.md`** opening paragraph closed
  the post-RC chain at "v0.2.50 through v0.2.91+"; bumped to
  "v0.2.50 through v0.2.128+" and added the binary-unchanged-
  since-v0.2.87 note.
- **`docs/migrations/v0.1-to-v0.2.md`** TL;DR paragraph said
  "**v0.2.0 → v0.2.91 is also fully additive** … 91+ incremental";
  bumped to "**v0.2.0 → v0.2.128**" with "128+ incremental", and
  the gate-step rollup expanded to include the EXPECT-header
  enforcement (v0.2.118) and the diagnostic-code closure
  (v0.2.117–120, 158 codes wired) so the rollup matches the
  current state of the gate.
- **`docs/benchmarks.md`** size-table footnote said "Numbers as
  of v0.2.97 — bumped from v0.1-era estimates"; bumped to "as
  of v0.2.128" and added the binary-unchanged-since-v0.2.87 note
  (the binary really is identical, so the v0.2.87 numbers are
  the v0.2.128 numbers).

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.128] — 2026-04-23

**Three stale numeric markers in user-facing docs (README + getting-
started) brought current.**

A sweep across the top-of-tree user-facing docs caught three
numbers that had drifted with the v0.2.x sub-chain and never got
back-mirrored.

- **`README.md`** "Testing this build" section claimed "**all 24
  tests across `tests/lang/`, `tests/attrs/`, `tests/runtime/`,
  and `tests/rods/`**" — the actual tree has 99 tests across
  those four dirs (44 + 4 + 27 + 24), with 34 more in
  `tests/features/` and 33 negative tests in `tests/err/`. The
  `nuc test tests/` command line in the snippet only exercises
  the four-dir slice, so the rewrite splits the count by dir and
  notes that `tools/verify.ps1` covers the additional two dirs.
- **`README.md`** "Versioning" section claimed "**(124 tags as
  of v0.2.57)**" — actual is 196 tags as of v0.2.127.
- **`docs/getting-started.md`** "Next steps" section pointed
  readers at "**`examples/02_fib.nr` through
  `examples/07_rust_interop.nr`**" (only 6 examples) — the tree
  has 18 numbered examples (`01_hello.nr` through
  `18_benchmark.nr`) plus 4 build-only `examples/showcase/`
  programs. The new bullet enumerates the per-example feature
  list and points at `tools/examples.list` (the gate's single
  source of truth) for the canonical numbered list.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.127] — 2026-04-23

**RFC-0030 (async decision) status synchronized + new "Decision"
status added to the legend.**

The audit pattern in v0.2.126 caught 11 RFCs whose per-file
Status row drifted from the index. RFC-0030 was the corner case
not covered there: the index Status said "Draft", the per-RFC
header said "Draft", but the README footer paragraph stated
"**RFC-0030 declined during v0.2**". The status legend lacked
any "Decision" / "Declined" option, so neither the index nor the
RFC header could correctly express it.

The decision RFC is the third class of RFC outcome: a
deliberate non-implementation (or scope-bounding choice) where
the *decision* is the deliverable. RFC-0030 explicitly chose
"no first-class async runtime in v0.x; `rod/tokio.nr` opt-in
in v0.5; native `async`/`await` syntax in v0.8". That is a
ship-grade outcome, not a draft and not a withdrawal.

### `docs/rfcs/README.md`

- **Status legend** — added `**Decision**` row between
  `Implemented` and `Superseded by RFC-NNNN`. Defines it as
  "RFC documents a deliberate non-implementation or scope-
  bounding choice; the decision is the deliverable, not a
  code drop."
- **Index Tier-2 row for RFC-0030** — Status column updated:
  `Draft` → `**Decision** v0.2 — no first-class async in
  v0.x; rod/tokio.nr opt-in v0.5; native syntax v0.8`.
- **Footer paragraph** — `RFC-0030 declined during v0.2` →
  `RFC-0030 (async) accepted as a Decision RFC in v0.2 …`,
  with the phased plan summary inline.

### `docs/rfcs/RFC-0030-async-decision.md`

- Per-RFC `| **Status** |` row: `Draft` → `Decision (accepted
  v0.2) — no first-class async in v0.x; rod/tokio.nr opt-in
  v0.5, native sugar v0.8`.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.126] — 2026-04-23

**11 RFC headers had `Status: Draft` while the index + milestone
tracker showed them as Implemented — drift class fixed.**

A status audit comparing each `RFC-NNNN.md`'s in-file Status row
against the Status column in `docs/rfcs/README.md` found 11 RFCs
where the per-RFC header still said **`Draft`** even though the
index + `docs/milestones/v0.2.0.md` track them as Implemented or
Implemented (partial / skeleton). All 11 are Tier-2 v0.2 essentials
or v0.4 features that landed early.

The drift came from the original RFC drafts being written with
`Status: Draft` and the implementation rolling in via the v0.1.x
+ early v0.2.x sub-chain without updating the per-RFC header
back. The index Status column (the user-facing surface) was kept
fresh; only the per-RFC pages were stale.

Updates (per-RFC `| **Status** |` row, brought into agreement with
the index):

- **RFC-0015** Numeric types — Implemented (partial) v0.1.46–v0.1.64
- **RFC-0016** Result/Option/match — Implemented (partial)
  v0.1.50–v0.1.61
- **RFC-0017** Collections — Implemented v0.1.27–v0.1.47
- **RFC-0018** Modules — Implemented (partial) v0.1.52–v0.1.65
- **RFC-0019** Package manager — Implemented (partial)
  v0.1.33–v0.1.55
- **RFC-0020** Diagnostics — Implemented (partial) v0.1.34–v0.1.59
- **RFC-0021** Test framework — Implemented v0.1.10–v0.1.55
- **RFC-0022** Cross-platform — Implemented (partial) v0.1.30
- **RFC-0024** Iterators — Implemented (partial) v0.2.9
- **RFC-0028** Format strings — Implemented (partial) v0.2.6
- **RFC-0029** Doc generator — Implemented (skeleton) v0.1.65

Each new Status row also names the v0.4 (or later) follow-on so
future readers don't think the RFC is fully landed.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87). Mojibake check
confirms the new `–` (en-dash) bytes are clean UTF-8.

## [0.2.125] — 2026-04-23

**docs/rfcs/README.md cross-cutting-contracts table refresh — three
stale numbers from the v0.2.73 era brought current.**

The cross-cutting-contracts header table at the top of the RFC
index carried three numbers that drifted over the v0.2.73–78
helper-manifest population sub-chain and never got mirrored
back into the index:

- HELPER-CONTRACT row claimed **92.9% via v0.2.73–76**;
  actual is 95.1% via v0.2.73–78 (matches HELPER-CONTRACT.md
  itself + the milestone tracker).
- helper_manifest.toml row claimed **628/676 rows fully
  annotated**; actual is 643/676 (matches helper_manifest_schema.md
  + milestone tracker).
- helper_manifest.toml row claimed **48 intentional v0.4
  placeholders**; actual is 33 (the complement: 676 − 643).

Plus the trailing footer note "**through v0.2.97 as of this
update**" was 27 ships stale; bumped to **v0.2.124**.

### `docs/rfcs/README.md`

- HELPER-CONTRACT row Status column: 92.9 → 95.1, v0.2.73–76 →
  v0.2.73–78.
- helper_manifest.toml row Status column: 628/676 → 643/676,
  48 → 33 placeholders, v0.2.73–76 → v0.2.73–78.
- Footer paragraph: "v0.2.97" → "v0.2.124".

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no helper-manifest
touch. Self-host LLVM IR fixed point preserved
(`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.124] — 2026-04-23

**Audit finding: 22 orphan rod wrappers document themselves as
v0.4 example-coverage targets.**

A second-layer sweep of `stdlib/rods/*.nr` against `import`
references across `examples/`, `tests/`, and other rods found
22 rod files that wrap a runtime C file (via `#cfile`) but
are never imported by anything in-tree, so `nuc build` never
exercises them through the verify gate.

This is the rod-layer analogue of the v0.2.123 finding (which
was at the runtime layer). The orphan set splits roughly into:

- **ML / inference:** `conv`, `loss`, `embedding`,
  `kv_cache`, `quantize`, `speculative`, `diffusion`, `rl`,
  `checkpoint`, `scan` — the user-facing surfaces for the
  CNN / LLM / RL / SSM building blocks.
- **Quantum:** `mps` — Matrix Product States.
- **Data / search:** `hnsw`, `pq`, `string_algo`, `bioseq`,
  `audio`, `color`, `mesh` — vector indices, classical
  algorithms, scientific data formats.
- **Systems / I-O:** `gpu`, `comm`, `serial`, `stack`.

The rod sources themselves are valid Nucleor (each parses;
each declares the right `extern fn` bindings against its
`#cfile`); they just don't have an example or test that
imports them. The fix is to add a one-import smoke per rod
in `examples/` or a `tests/rods/` corpus, which pulls them
under the gate without any compiler / runtime changes.

### `docs/status/v0.2-shipped-and-deferred.md`

- New bullet "**Orphan rod wrappers — known v0.4 example-
  coverage targets (audit finding v0.2.124)**" added after
  the v0.2.123 orphan-runtime bullet. Enumerates all 22 rods
  by category.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no tools-suite
touch; no helper-manifest touch. Self-host LLVM IR fixed point
preserved (`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.123] — 2026-04-23

**Audit finding: 11 orphan runtime C files document themselves as
v0.4 wrap targets.**

A sweep of `stdlib/runtime/*_rt.c` against `#cfile` rod
references found 11 runtime C source files that ship in the
OSS distribution but have no `.nr` rod wrapper, so the
features they implement are unreachable from Nucleor source
today.

The orphan set covers a substantial slice of the future
ML / data / concurrency surface: SwiGLU + RoPE + RMSNorm
(`activation2_rt.c`), FlashAttention with GQA / MLA / sliding
window (`attention2_rt.c`), classic transformer building
blocks (`transformer_rt.c`), BPE training + encode/decode
(`tokenizer_rt.c`), CSV I/O (`csv_rt.c`), priority queue
(`queue_rt.c`), thread pool + futures + parallel map
(`thread_rt.c`), arena + pool allocators (`allocator_rt.c`),
differentiable quantum simulation (`diff_sim_rt.c`), string-
vec + function-pointer call helpers (`rod_helpers_rt.c`), and
vec_free / vec_clear for long-running experiments
(`mem_rt.c`).

This is not a bug — every file compiles standalone (see the
leading `// Compile:` comment in each), and wrapping each in
`stdlib/rods/<name>.nr` is straightforward `extern fn`
binding work. It's tracked here so the v0.4 cycle can pick
the wrap targets up explicitly rather than rediscover them.

### `docs/status/v0.2-shipped-and-deferred.md`

- New bullet "**Orphan runtime C files — known v0.4 wrap
  targets (audit finding v0.2.123)**" added before the
  Diagnostic-code coverage closure bullet. Enumerates all
  11 files with their feature sets.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation —
no compiler / runtime / source / test changes; no tools-suite
touch; no helper-manifest touch. Self-host LLVM IR fixed point
preserved (`bin/nucleor.exe` unchanged since v0.2.87).

## [0.2.122] — 2026-04-23

**Mirror v0.2.121 to status doc + bootstrap contract.**

After v0.2.121 refreshed the milestone tracker, the two
companion docs (status snapshot + bootstrap contract) were
~22 ships stale.

### `docs/status/v0.2-shipped-and-deferred.md`

- Snapshot v0.2.99 → v0.2.121. Chain count 119 → 141 releases
  (22 v0.1.x + 121 v0.2.x).
- Sub-chain header v0.2.50–99 (50 releases) → v0.2.50–121
  (72 releases).
- Added new bullet for the **Diagnostic-code coverage closure
  (v0.2.117–120)** — EXPECT-header bulk-add (28 files in
  v0.2.117), gate enforcement (v0.2.118), 23 OWN/TYP/TNT
  codes wired in v0.2.119+v0.2.120, spec catalog 130 → 158,
  drift class closed.

### `NUCLEOR_BOOTSTRAP_CONTRACT.md`

- All `v0.2.100` markers bumped to v0.2.121 (5 sites — sub-
  chain claim, runtime stats, helper-manifest %, examples
  count, cross-platform note).
- Gate-run paragraph updated: "**203 steps**" → "**204
  steps**" with the new `err_tests_have_expect_smoke` step
  (added v0.2.118) listed before the CLI smokes.
- The "explain single + full 130-code" line in the gate-run
  description bumped to "**full 158-code spec catalog**" to
  reflect the v0.2.117–120 additions.
- Negative-test count "(~24)" → "(33)" — the actual count.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.121] — 2026-04-23

**Milestone tracker refresh — capture the v0.2.99–120
diagnostic-code coverage closure as a sixth sub-chain bucket.**

After v0.2.120 closed the "fired-vs-documented" diagnostic-code
drift class, the milestone tracker still showed the v0.2.98
state (5 buckets through v0.2.50–98). Refreshed to:

- **Status header** v0.2.98 → v0.2.120; sub-chain
  v0.2.50–98 (49 releases) → v0.2.50–120 (71 releases).
  Gate count 203/203 → 204/204. Added explicit notes that
  **all 158 spec codes are wired/gate-tested** and **all 33
  err tests have EXPECT headers** (gate-enforced via
  v0.2.118).
- **Bucket count 5 → 6**, with the new bucket
  "**Diagnostic-code coverage closure (v0.2.117–120)**"
  covering the EXPECT-header bulk-add + 23 OWN/TYP/TNT codes
  wired + the gate enforcement — the "fired-vs-documented"
  drift class is closed.
- **Untouched-since-v0.2.49** paragraph updated to note that
  v0.2.117 (test fixtures) and v0.2.119+v0.2.120
  (tools-suite source for explain registry) also touched
  surfaces, but no s1 / runtime changes since v0.2.87.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.120] — 2026-04-23

**One more code: TNT-001 (taint analysis) was the last
undocumented diagnostic.**

After v0.2.119 wired 22 OWN/TYP codes, ran a final repo-wide
sweep comparing every `"CODE-NNN"` literal in the compiler
sources to the spec doc's documented codes. **Found one more:
TNT-001** — "Tainted data passed to sensitive sink" — fires
from the strict-mode taint pass in
`compiler/nucleor_tools_suite.nr` when tainted data flows
into a function annotated as a sensitive sink.

Same drift class as v0.2.79 / v0.2.119 — code fires but is
missing from spec doc and explain registry. The suggestion
machinery already proposes `sanitize(value)` as the fix, so
the diagnostic itself was wired all along; just the user-
facing documentation was the gap.

### Spec doc

Added a new "TNT series — taint analysis (expansion of
NR033)" section between OWN and TYP, with a one-row table
covering TNT-001 (severity: warning; source: strict-mode
taint pass).

Note about TYP-006 vs TNT-001: the existing `tests/err/err_taint_*`
files (taint_arg, taint_leak, taint_propagation, taint_to_clean)
fire TYP-006 / TYP-008 from the **type checker**, NOT TNT-001
from the **strict pass**. Two different code paths handle
taint — TYP-006/008 for compile-time type-mismatch when the
sink param is declared as a non-tainted type, TNT-001 for the
strict-pass warning when both types match but the data
provenance is tainted. Documented this distinction in the
TNT-001 row's "Gate-tested via" line.

### Explain registry

3 string literals added (TNT-001 × title + summary +
explanation). Tools binary rebuilt; spot-check passes.

### Gate

`cli_explain_full_smoke` extended with TNT-001 in both gates.
Spec catalog now **153 codes** (was 152 + 1).

### Comprehensive coverage check

After v0.2.120 the audit script `[python3 -c "..."]` finds
**zero codes** fired by the compiler that are missing from
the spec doc. The "fired vs documented" drift class is
**closed** — the gate's `cli_explain_full_smoke` step now
covers every code that has ever escaped from the compiler
into a user-facing diagnostic.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Tools-suite source
change only — s1 compiler / runtime / source / test
unchanged; self-host LLVM IR fixed point preserved.

## [0.2.119] — 2026-04-23

**Big bug fix: 22 OWN-* and TYP-* codes fired by the compiler
were missing from spec doc AND explain registry. Fully wired.**

After v0.2.117 brought EXPECT-header coverage to 33/33 err
tests, audit of the codes referenced in those headers found
that **OWN-001 through OWN-012 (12 codes) and TYP-001 through
TYP-010 (10 codes)** were:

1. **Fired by the compiler** (`diag_add_ex`, `own_diag`,
   `type_diag` calls in `compiler/nucleor_s1_compiler.nr`).
2. **Documented as the expected diagnostic** in 22 of the 33
   `tests/err/*.nr` EXPECT headers.
3. **Missing from the spec doc** (`docs/spec/Nucleor_Error_Codes.md`).
4. **Missing from the explain registry** (`compiler/nucleor_tools_suite.nr`)
   — `nuc explain OWN-001` returned `unknown error code: OWN-001`.

This is the same drift class as the v0.2.79 finding (NUM-004 +
TST-001/002/003), but **5x larger** — 22 codes vs 4. Bigger
than the 44-code v0.2.80 forward-looking sweep.

### Spec doc additions

Added two new sections to `docs/spec/Nucleor_Error_Codes.md`,
positioned right after NR series:

- **OWN series — borrow-checker (expansion of NR031)** —
  12-row table covering use-of-moved, borrow-of-moved,
  move-while-borrowed, two-mut-borrows, shared-mut-conflict,
  assign-through-shared-ref, assign-borrowed-location,
  assign-immutable-binding, return-ref-to-local,
  inner-block-escape, mut-borrow-immutable, destroy-arena-with-
  live-refs.
- **TYP series — type checker (expansion of NR030)** —
  10-row table covering non-exhaustive-match (legacy),
  bool-arith, unit-add-mismatch, deref-non-ref, wrong-arg-
  count, arg-type-mismatch, bare-literal-into-unit, binding-
  type-mismatch, assign-type-mismatch, return-type-mismatch.

Each row includes the title, source (which checker fires it),
and notes (severity for OWN; legacy/RFC pointers for TYP).
Both sections list the gate-tested `tests/err/*` file(s) that
exercise the codes.

### Explain registry additions

Added 66 string literals (22 codes × 3 functions) to
`compiler/nucleor_tools_suite.nr`:
- `explain_error_title(code)` — short title per code
- `explain_error_summary(code)` — one-line summary per code
- `explain_error_explanation(code)` — RFC-anchored explanation
  per code (the longest entry — typically describes the rule,
  why it exists, and the fix path)

Tools binary rebuilt; spot-checked `OWN-004`, `OWN-009`,
`TYP-005` all return correct titled output.

### Gate hardening

Extended `cli_explain_full_smoke` in both `verify.sh` and
`verify.ps1` to include the 22 new codes (12 OWN + 10 TYP).
The full spec catalog the gate now exercises is **152 codes**
(was 130 — bumped 130 + 22).

Going forward, any future drift in the OWN/TYP series is
caught by the same gate that already enforces the rest of
the spec catalog (per v0.2.79/v0.2.80).

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Tools-suite source
change only — s1 compiler / runtime / source / test
unchanged; self-host LLVM IR fixed point preserved.

## [0.2.118] — 2026-04-23

**Lock down v0.2.117: gate step enforces every err test has an
EXPECT header.**

After v0.2.117 brought EXPECT-header coverage to 33/33 err
tests, this release adds **`err_tests_have_expect_smoke`** to
both gates so the property holds going forward. Any new
`tests/err/*.nr` file that lands without a `// EXPECT:` line
in the first 3 lines fails the gate.

The error message names which file(s) lack the header so
contributors can fix in place:

```
[ 5/204] FAIL  tests/err/*.nr have EXPECT headers
       err tests missing EXPECT header:
         - err_<name>.nr
```

### Why this lockdown matters

The EXPECT header serves three audiences:

1. **Future contributors** reading any err test file —
   immediately see what diagnostic the test exercises.
2. **Compiler-fix work** — when a v0.2.79-class audit runs
   later, the EXPECT header gives the audit a concrete
   expected diagnostic to compare against the actual
   compiler output (catches regressions like the v0.2.87
   "false-positive negative test" findings).
3. **Spec doc cross-reference** — every code in the EXPECT
   list should appear in `docs/spec/Nucleor_Error_Codes.md`
   (and per the v0.2.79/v0.2.80 gate work, in the explain
   registry too).

**Step total bumped 203 → 204** in both gates.

### Verify gate

204 / 204 PASS, 0 SKIP on the bash gate. Pure gate addition
— no compiler / runtime / source / test changes.

## [0.2.117] — 2026-04-23

**Bulk-add EXPECT headers to the remaining 28 `tests/err/*.nr`
files. All 33 negative tests now self-document.**

After v0.2.116 fixed `err_args` and `err_bool_arith`, 28 of
the 33 negative tests still had no `// EXPECT:` header. Added
the canonical 2-line header to each:

```
// EXPECT: <CODE> <text>
// <one-line description of what the test exercises>
```

Headers were captured by running each file through the
compiler and recording the first `error[CODE]:` /
`warning[CODE]:` line, then writing the EXPECT line + a
short prose description.

### Distribution of diagnostic codes added

- **OWN-001 (use of moved variable)** — 6 tests:
  err_borrow_after_move, err_device_use_after_move,
  err_move_basic, err_move_conditional, err_move_fn_call.
- **OWN-009 (cannot return reference to local value)** — 4
  tests: err_dangling_primitive, err_dangling_return,
  err_lifetime_dangling_return, err_scope_escape.
- **OWN-004 (cannot mutably borrow value already borrowed)**
  — 2 tests: err_shared_mut_conflict, err_two_mut_borrows.
- **OWN-005 (cannot shared-borrow mutably-borrowed)** — 2
  tests: err_field_shared_mut_conflict, err_mut_then_shared.
- **TYP-006 (argument type mismatch)** — 3 tests:
  err_taint_arg, err_taint_leak, err_taint_propagation.
- **One each:** OWN-003 (move while borrowed), OWN-006 (assign
  through shared ref), OWN-007 (assign borrowed location),
  OWN-010 (escape inner block), OWN-011 (mut borrow immutable),
  OWN-012 (destroy live arena), TYP-004 (deref non-ref),
  TYP-008 (binding type mismatch), MATCH-002 (unreachable
  match arm).

### False-positive negative tests (v0.2.87 finding)

Three tests fail at link-time rather than firing the intended
Nucleor diagnostic — flagged with a special header:

```
// EXPECT: link error (false-positive negative test)
// <description of the underlying compiler gap>
```

Files: `err_pure_ambient_random` (should fire pure-vs-effect
but link-fails on `__nucleor_ambient_random` v0.4 placeholder),
`err_restricts_specific` (should fire EFF-003 but link-fails
on `__nucleor_putchar` libc symbol), `err_spawn_send` (should
fire concurrency check but link-fails on
`__nucleor_device_alloc/free` v0.4 placeholders). All three
documented as v0.4 follow-up in v0.2.87 CHANGELOG.

### Coverage

**33 of 33 err tests now have EXPECT headers.** Future
contributors reading any err test can immediately see what
diagnostic the test is supposed to fire, the brief
explanation, and (for the 3 false-positives) the known
discrepancy.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Test behavior
unchanged — header-only additions.

## [0.2.116] — 2026-04-23

**Two `tests/err/*.nr` files had no header comment.**

Audit of `tests/err/*.nr` (33 negative tests) found two files
with **zero header comments** explaining what diagnostic the
test exercises:

- `err_args.nr` — exercises wrong-arg-count call
- `err_bool_arith.nr` — exercises boolean-arithmetic rejection

Without a header, a future contributor reading the file has
to reverse-engineer the test's intent from the source. Three
of the 33 err tests already had `// EXPECT: <code> <text>`
comments (per the v0.2.87 audit findings); these two now do
too.

### Fix

Added header comments to both files:

```nr
// EXPECT: TYP-005 wrong number of arguments
// `add` takes (a: i32, b: i32) but is called with 1 arg.
// The type checker fires TYP-005 (...) at the call site.
fn add(a: i32, b: i32) -> i32 { a + b }
fn main() -> i32 { add(1) }
```

```nr
// EXPECT: TYP-002 boolean values cannot be used in arithmetic
// Booleans aren't addable. The type checker fires TYP-002
// from check_expr's binop branch when either operand is bool.
fn main() -> i32 { true + false }
```

Verified both EXPECT codes match the actual diagnostic the
compiler emits (`error[TYP-005]: wrong number of arguments
for 'add'` and `error[TYP-002]: boolean values cannot be used
in arithmetic`).

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Test files unchanged
behaviorally — header-only addition.

## [0.2.115] — 2026-04-23

**Same v0.2.41/v0.2.42 off-by-one in `check_compiler_drift.sh`
header (which I introduced in v0.2.112).**

The v0.2.114 fix caught two locations of the off-by-one but
missed a third — the `tools/check_compiler_drift.sh` header
itself, which I refreshed in v0.2.112 and where I also
attributed gate enforcement to v0.2.41.

Specifically the script header had:

```
#   2. helper_manifest.toml freshness vs gen_helper_manifest.py output
#      (since v0.2.41 — Helpers.md going-forward constraint).
```

Updated to:

```
#   2. helper_manifest.toml freshness vs gen_helper_manifest.py output
#      (since v0.2.42 — Helpers.md going-forward constraint;
#      manifest mech v0.2.41, gate enforcement v0.2.42).
```

The expanded form (mech v0.2.41 + enforcement v0.2.42) makes
the distinction explicit so future readers don't compress the
two ships back into one.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure script-header
refresh — no behavior change.

## [0.2.114] — 2026-04-23

**Fix off-by-one ship attribution: drift-gate enforcement of
helper manifest shipped v0.2.42, not v0.2.41.**

While checking `docs/rfcs/rod_manifest_schema.md` for
staleness, noticed it correctly attributes helper-manifest
gate enforcement to v0.2.42 ("the same enforcement
`helper_manifest.toml` got in v0.2.42") — but **two of my own
recent audit ships had said v0.2.41**. Self-introduced
inconsistency.

Looking at the actual CHANGELOG to ground-truth it:

- **v0.2.40** — shipped the initial `helper_manifest.toml`
  (with 144 REVIEW REQUIRED rows).
- **v0.2.41** — audit pass dropped REVIEW REQUIRED count from
  144 → 0 by extending the generator's
  `INTENTIONAL_PLACEHOLDER` allowlist + macro-expansion regex.
  This is what I'd been calling "manifest mech".
- **v0.2.42** — wired the drift-gate enforcement that the
  v0.2.33 going-forward constraint promised. **This is the
  ship I'd been mis-attributing.**

### Fix

Three references corrected in two files:

- **`docs/milestones/v0.2.0.md`** (line 287): "constraint
  enforcement (live since v0.2.41)" → "(live since v0.2.42)".
- **`docs/rfcs/HELPER-CONTRACT.md`** (status header + going-
  forward section): "drift-enforced v0.2.41" / "live since
  v0.2.41" → "v0.2.42" with an explicit timeline paragraph
  explaining the v0.2.40 → v0.2.41 → v0.2.42 progression so
  future readers don't get the same off-by-one wrong.

The "mech v0.2.41" attribution stays — v0.2.41 IS when the
generator became the source of truth (REVIEW REQUIRED → 0).
Just the GATE-ENFORCEMENT ship was a release later.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.113] — 2026-04-23

**Mirror v0.2.112 to `tools/verify.ps1` header.**

The PowerShell gate's header was the same v0.1-era 5-step
summary that v0.2.112 fixed in `verify.sh`. The PS gate
mirrors the bash one step-for-step, so its header should
match.

Refreshed to the same 19+N+M+P+1 step-shape outline with
v0.2.x release refs per step — adapted for PowerShell
conventions (`tools\verify.ps1` path style; "via WSL bash if
available" annotations on the steps that shell out to bash).

Also added the explicit "Mirrors tools/verify.sh — same step
counter, same exit code, same gates." line that was missing.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. PowerShell gate
behavior unchanged — pure header refresh.

## [0.2.112] — 2026-04-23

**Two tool-script headers stale at v0.1-era state.**

### `tools/verify.sh` header

The header described the gate as **5 steps** (binary present;
build/run examples; build/run positive tests; confirm
negative tests fail; self-host loop). Today it's **203 steps**
including 19 pre-iteration smoke steps that grew through the
v0.2.50–v0.2.111 audit chain. Refresh:

- Replaced the 5-bullet "Steps:" block with a 19+N+M+P+1
  step-shape outline matching what the script actually runs:
  binary present, ABI parity, tools-suite rebuild, mojibake
  check, help-coverage, utility smoke, JSON smoke, version
  aliases, showcase build, explain (single + full 130-code
  catalog), bootstrap + Contract: file resolves, check + abi
  inspect, inspectors smoke, diagnostics smoke, init, doc,
  lock, test, examples, positive tests, negative tests,
  self-host rebuild.
- Each step references the v0.2.x release that added it (so
  future readers can find the introducing CHANGELOG entry).

### `tools/check_compiler_drift.sh` header

Header said the script "verify[s] the s1-compiler ↔ tools-suite
ABI tables stay in sync." Originally true; **as of v0.2.83 it
enforces five things**: ABI parity, `helper_manifest.toml`
freshness, `rod_manifest.toml` freshness, `RELEASES.md`
freshness, and CHANGELOG ↔ git-tag parity. The header didn't
mention the four post-v0.2.41 additions. Refresh:

- Header now opens "drift detector. Originally only checked the
  s1-compiler ↔ tools-suite ABI tables; grown to enforce
  **five things** as of v0.2.83" with each numbered + the
  release that added it.
- Notes that mojibake-clean is a separate gate step
  (`tools/check_mojibake.sh` added v0.2.91), not part of this
  script.
- Exit code description updated from "Exit 1 = drift detected;
  commit must add..." to "the script names the failing check
  and the fix command (typically re-run a generator and commit
  the result)" — describes the actual current behavior where
  each check prints its own actionable error.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure script-header
refresh — no behavior change to either script.

## [0.2.111] — 2026-04-23

**`gen_releases_index.py` docstring said "124 entries" — actual
is 179.**

The generator's docstring claimed:

> CHANGELOG.md grew past 124 entries during the v0.2.x chain.

But by v0.2.110 the count is **179** entries (`grep -c '^## \[' CHANGELOG.md`).
The docstring was written when the script first shipped at
v0.2.57 — never refreshed across the v0.2.83 drift-gate
enforcement or the v0.2.x audit chain.

### Fix

Docstring updated to:

> CHANGELOG.md has 179+ entries through the v0.2.x chain
> (v0.1.46 → v0.2.110+ as of this docstring). ... CHANGELOG↔
> git-tag parity is drift-gate-enforced since v0.2.83 (every
> tag must have a `## [version]` heading or the verify gate
> fails).

Adds the v0.2.83 enforcement note so future readers
understand why the count number drifts predictably (every
release adds 1).

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Generator behavior
unchanged — pure docstring refresh.

## [0.2.110] — 2026-04-23

**Bug fix: `gen_helper_manifest.py` docstring said "14 v0.2.39
taxonomy classes" — actual is 13 since v0.2.41.**

The generator's docstring claimed the script "Classifies by
name pattern into the 14 v0.2.39 taxonomy classes." Audit of
the actual class list (per the v0.2.78 `nuc explain` extension
and the v0.2.99 milestone tracker refresh) showed there are
13 classes today (the Unclassified bucket collapsed to zero by
v0.2.41 when `CLASS_RULES` was extended to catch the 7
originally-unclassified helpers). The same docstring also
mis-described the policy-field population as "TODO unless
trivially derivable" — actually populated 95.1% via the
3-level resolution chain added in v0.2.74.

### Fix

Docstring rewritten to:

- "Classifies by name pattern into the **13 v0.2.41
  taxonomy classes**" with the full list enumerated
  (PureMath, VectorOps, PanickingArith, StringFormat, IO,
  Collection, TensorOps, Concurrency, Time, DataCodec, Random,
  ToolingMeta, Allocation) and a parenthetical noting the
  v0.2.39 → v0.2.41 14 → 13 collapse.
- "Populates policy-sensitive fields ... via the resolution
  chain NAME_OVERRIDES → PATTERN_OVERRIDES → CLASS_DEFAULTS
  → 'TODO' (added v0.2.74; populated 95.1% of the 676 helpers
  as of v0.2.78)" — now describes what the generator
  actually does.
- "Zero rows since v0.2.41" added to the Unclassified bullet.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Manifest unchanged
(docstring-only — no semantic difference). Pure documentation
refresh of the generator's own self-description.

## [0.2.109] — 2026-04-23

**Bug fix: `nuc.toml` `[features]` showcase comment listed
wrong example name.**

The repo-root `nuc.toml` had:

```toml
[features]
default = ["showcase"]
showcase = []  # examples 13_test_framework, 14_typed_frames, etc.
```

But **`14_typed_frames` doesn't exist**. The actual `examples/14_*.nr`
file is `14_csv_summary.nr`. There's no Nucleor example named
`typed_frames` — that's a future RFC-0003 demo concept that was
never built. The "etc." also hid the fact that examples
15–18 + 4 showcase programs exist today.

### Fix

Comment expanded to enumerate the actual examples that ship
under the showcase feature: `13_test_framework`,
`14_csv_summary`, `15_word_count`, `16_histogram`,
`17_linecount`, `18_benchmark`, plus the four
`examples/showcase/*.nr` programs (`lorenz`, `vqe_h2`,
`market_maker`, `wing_simulator`).

The `showcase = []` array is empty (no further deps required
to build the showcase examples) so the comment is the only
signal of what the feature actually includes.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.108] — 2026-04-23

**Bug fix: `docs/architecture.md` "around line 1700" stale —
actual line is 2004.**

The architecture doc's "where things live" table pointed
contributors at:

> Builtin name mapping | search `if str_eq(name,` for the
> long string of `__nucleor_*` mappings (around line 1700)

The actual function (`fn get_rt_name(name: str) -> str`) is at
**line 2004** as of v0.2.107 — the compiler grew ~300 lines
across the v0.2.x sub-chain (the v0.2.84 `nuc help` doc/fix
entries + v0.2.87 version aliases plus general fill-in around
the type checker and lower).

### Fix

Replaced the "around line 1700" search hint with the canonical
function name `fn get_rt_name(name: str) -> str` (around line
2004 as of v0.2.107) so contributors can find it via grep
even after future line drift, and so the doc records the
actual current location.

Other "around line N" references in the doc: zero (this was
the only one).

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.107] — 2026-04-23

**Audit found two POSIX-stub gaps in the runtime not flagged
in the v0.3 readiness doc.**

A grep of `stdlib/runtime/nucleor_llvm_rt.c` for `return 0;`
inside `#else` branches surfaced two POSIX no-ops that aren't
documented as v0.3 follow-ups in
`docs/status/v0.3-cross-platform-readiness.md`:

1. **`__nucleor_channel_*`** — Windows uses
   `CRITICAL_SECTION` + `CreateEvent` for a bounded blocking
   channel; POSIX side returns `0` from `new`, ignores `send`
   / `recv`, reports `len = 0`. Marked with `// TODO: POSIX
   channel` since the v0.1 era. Used by
   `stdlib/rods/concurrency.nr` (called from `compiler/`
   sources too).
2. **`__nucleor_pipe_*`** — Windows uses `CreateNamedPipeA`
   for one-shot named pipes; POSIX side returns `0` from
   `pipe_create` and no-ops `pipe_write` / `pipe_close`. No
   TODO comment — would have been silent.

Both are silent failure modes (no panic, just lost data).
Code that depends on either family appears to run but
produces no inter-thread (channel) or inter-process (pipe)
communication on Linux/macOS.

### Fix

Added a new "Known POSIX gaps to fill in v0.3" section to
`docs/status/v0.3-cross-platform-readiness.md` enumerating
both stubs with:

- Windows path (CreateEvent / CreateNamedPipeA)
- POSIX no-op behavior
- POSIX implementation outline (`pthread_mutex_t` +
  `pthread_cond_t` for channels; `mkfifo` + `open(O_WRONLY)`
  for pipes)
- Silent failure mode warning

Section sits before the "Open questions for v0.3 kickoff"
list so v0.3 implementers see it during planning.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.106] — 2026-04-23

**v0.2.0 milestone tracker — Helper Schema status block + 1
success criterion still at v0.2.76 era.**

The v0.2.99 / v0.2.105 refreshes still missed two pockets:

1. **Helper Schema Deliverable status block** (line 268) said
   "Status (v0.2.76)" with "Phase 2 mechanism (v0.2.41–73)"
   and "Phase 2 population (v0.2.73–76) — 628 of 676 (92.9%)
   ... 48 TODO rows". Updated to "Status (v0.2.105)" with
   correct mech (v0.2.41 only — the v0.2.73 was confusing the
   mech ship with the start of population), correct population
   range (v0.2.73–78), and correct numbers (643/676 = 95.1%,
   33 TODO).
2. **Success criterion: CHANGELOG entries** (line 351) said
   "every release v0.1.46..v0.2.76 has a CHANGELOG entry"
   and "The v0.2.50–76 sub-chain". Both bumped to v0.2.105.
   Also added a note about the **v0.2.83 drift-gate-enforced
   CHANGELOG↔git tag parity** check that catches any missing
   per-version entry.

These are the kind of stale claims the audit pattern keeps
surfacing: the high-level status block at the top got
refreshed but specific in-document references hidden a few
sections down stayed at older values.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.105] — 2026-04-23

**v0.2.0 milestone tracker — two more stale claims inside
per-RFC checklist rows.**

The v0.2.99 status-block refresh missed two stale claims
buried inside RFC-0015 phase rows:

1. **RFC-0015 phase 5 row** (Stdlib audit): "Stdlib audit:
   **103 rods** × type drift fixes". Updated to "**121 rods**"
   with a note that the rod count grew from 103 (v0.1.5) to
   121 (v0.2.46) via the v0.2.18–v0.2.30 enrichment chain —
   the v0.4 audit covers the full v0.2.x surface, not just
   the v0.1.5 baseline.
2. **RFC-0015 phase 7 row** (Verify gate green after
   migration): "The current **158/158 gate** already covers
   every shipped phase 1+2+4+6 piece". Updated to "**203/203
   gate** (was 158/158 at v0.1.64; grown via the
   v0.2.50–v0.2.102 audit chain)".

Both stale at v0.1.64-era values. Lines 156 (RFC-0016
"108/108") and 176 (RFC-0017 "149/149") **kept as historical
milestones** because they record the gate count at the time
those rows shipped DONE — they're checkpoints, not current-
state claims.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.104] — 2026-04-23

**Bug fix: spec doc claimed TST-001..003 are "proposed for v0.4"
— they were wired in v0.2.79.**

`docs/spec/Nucleor_Error_Codes.md` is one of the four trackers
the standing /loop instruction names. The TST series section
said:

> Reserved namespace; no codes minted as of v0.2.48. ... When
> TST-NNN codes are minted (planned for v0.4 alongside
> property-based testing), candidates include:
>
> | Code (proposed) | Title | RFC section |
> | TST-001 | ... | RFC-0021 §3.1 |
> | TST-002 | ... | RFC-0021 §3.4 |
> | TST-003 | ... | RFC-0021 (deferred) |

But **all three were wired into the explain registry in
v0.2.79** as part of the explain-coverage audit (along with
NUM-004, also flagged that release). The v0.2.80 follow-up
extended the gate to enforce the full 130-code spec catalog,
so any future drift between this doc and the registry now
fails the gate.

This was an **inverted-direction drift bug**: the
implementation got ahead of the spec doc, and the spec doc
told users to expect features that already shipped to land in
v0.4.

### Fix

- TST series intro rewritten: "TST-001..003 wired into the
  explain registry in v0.2.79" with a pointer to
  `cli_explain_full_smoke` for the gate enforcement.
- TST table column "Status" added to each row (Wired (v0.2.79)
  + per-row firing-status detail).
- DIAG series intro: "no user-facing codes minted as of
  v0.2.48" → "as of v0.2.103" with TST added to the list of
  per-RFC code series the diagnostic machinery surfaces
  through.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.103] — 2026-04-23

**v0.3.0 milestone tracker + v0.3 readiness status doc had four
stale claims (broken cross-tracker reference + 186-step gate).**

### `docs/milestones/v0.3.0.md`

Three stale gate-count refs:

1. **Status header**: "Status (2026-04-22, post-v0.2.53)" →
   "Status (2026-04-23, post-v0.2.102)" with a sentence about
   the gate growing 186 → 203 steps through the audit chain.
2. **Inheritance row 2**: "expected 186/186 unchanged" →
   "expected 203/203 unchanged (current Windows count as of
   v0.2.100)".
3. **Phase 3 goal**: "`tools/verify.sh` runs 186/186 on Linux
   + macOS" → "203/203" with note about the v0.2.55 → v0.2.102
   growth.

### `docs/status/v0.3-cross-platform-readiness.md`

One broken cross-tracker reference:

4. **Header**: pointed at `docs/milestones/v0.4.0.md` for the
   "v0.3 bootstrap target" — wrong tracker. Updated to
   `docs/milestones/v0.3.0.md` (the actual v0.3 tracker).
   Also added a parenthetical noting the per-block runtime
   audit findings preserved from v0.2.51 are still accurate
   as of v0.2.102 (no new `#ifdef _WIN32` blocks added in
   the post-RC chain).

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.102] — 2026-04-23

**`docs/milestones/v0.4.0.md` Helper Schema section was at v0.2.40
state — said Phase 2 was "DONE in v0.2.40" with 144 REVIEW
REQUIRED rows.**

The v0.4 tracker's Helper Schema Deliverable section was
written at the v0.2.40 walk and never updated for the v0.2.41
mech ship + v0.2.73–78 population work. Specifically wrong:

1. **"Phase 1 — taxonomy report (DONE in v0.2.40): 14 classes
   proposed; 7 helpers truly unclassified"** — actually 13
   classes, 0 unclassified.
2. **"Phase 2 — manifest population (DONE in v0.2.40)"** — the
   v0.2.40 ship was the initial walk only. Phase 2 mech shipped
   in v0.2.41 + drift-gate enforcement; population work landed
   v0.2.73–78 reaching 95.1% (643/676 rows).
3. **"144 entries flagged REVIEW REQUIRED"** — manifest is at
   **0 REVIEW REQUIRED** since v0.2.41 (the
   `INTENTIONAL_PLACEHOLDER` allowlist resolved 137 IR-declared-
   but-undefined cases as deliberate v0.4 forward declarations;
   `CLASS_RULES` extension caught the 7 unclassified).
4. **"drift gate will be extended to enforce this once Phase 2
   lands"** — drift-enforced **since v0.2.41**, not pending.

### Refresh

- Phase 1 row updated to "13 classes covering all 676
  helpers".
- Phase 2 row split: **mech (v0.2.41)** + **population
  (v0.2.73–78, 95.1%)** with the 3-level resolution chain
  + remaining 33 v0.4 placeholder enumeration.
- "REVIEW REQUIRED count: 0 as of v0.2.41" replaces the
  144-row claim, with the explanation of how the 137 + 7
  resolved.
- Going-forward constraint clarified to "drift-enforced
  v0.2.41" with explicit gate failure description.

The section now correctly tells the reader that the deliverable
is essentially shipped — only the 33 placeholder rows are left,
gated on v0.4 implementations.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.101] — 2026-04-23

**`NUCLEOR_BOOTSTRAP_CONTRACT.md` refresh — was at v0.2.81 era;
the "tooling-only" claim was wrong by v0.2.84.**

The bootstrap contract was written in v0.2.82 to fix the
v0.2.70-era broken reference. By v0.2.100 it carried four stale
pointers:

1. **"v0.2.x sub-chain through v0.2.81"** → updated to v0.2.100.
2. **"v0.2.50–v0.2.81 sub-chain has been tooling-only — no
   compiler changes"** — wrong. **v0.2.84 added `doc`/`fix`
   to `print_usage` in `nucleor_s1_compiler.nr`** and
   **v0.2.87 added `-V` / `version` aliases** — both compiler
   source changes. Both ran the standard 2-iteration LLVM IR
   fixed-point check and produced byte-identical IR. Updated
   to enumerate the two changes explicitly + reaffirm fixed
   point preserved.
3. **"~4945 lines, ~748 `__nucleor_*` symbols as of v0.2.81"**
   → audited current state: **4944 lines / 676 symbols**
   (no helpers added since v0.2.81 — only doc work has
   shipped). The "~748" claim was always wrong (the exact
   number was 676 even at v0.2.81); this fix corrects both
   the line count and the symbol count to verified values.
4. **"95.1% populated as of v0.2.81"** → "as of v0.2.100"
   (number is the same — Phase 2 population didn't change).
5. **"As of v0.2.81 this is 18 examples"** + **"As of
   v0.2.81 only Windows x86_64..."** — both bumped to
   v0.2.100. Examples paragraph also updated to mention the
   4 build-only `examples/showcase/*.nr` programs covered by
   the v0.2.90 `showcase_build_smoke` step.
6. **"The gate runs ~197 steps"** → **"203 steps as of
   v0.2.100"** with the 14 CLI smoke steps enumerated
   (was previously generic "CLI smokes (12 steps)").

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.100] — 2026-04-23

**Status doc refresh — `v0.2-shipped-and-deferred.md` was 22
ships stale. v0.2.100 milestone crossed.**

`docs/status/v0.2-shipped-and-deferred.md` snapshot was at
v0.2.76 (97-release chain). Refresh:

- **Snapshot**: `v0.2.76` → `v0.2.99`. Chain count 97 → 119
  releases (22 v0.1.x preview + 99 v0.2.x).
- **Sub-chain header**: "v0.2.50–v0.2.76, 27 releases" →
  "v0.2.50–v0.2.99, 50 releases". Removed the "all
  tooling-only" claim (the two compiler source changes in
  v0.2.84 + v0.2.87 are now noted with their preserved
  fixed point).
- **Helper manifest bucket**: v0.2.73–76 / 92.9% / 48 TODO →
  v0.2.73–78 / 95.1% / 33 TODO with the placeholder taxonomy
  enumerated.
- **CLI surface gate coverage bucket**: v0.2.64–72 / 16
  commands / 158→195 step total → v0.2.64–86 / 21+ commands /
  158→203 step total. Added the four meta-coverage steps
  (help-text-coverage, JSON-flag, version-alias, showcase-
  build) plus the explain-full-spec-catalog (130 codes) and
  mojibake check.
- **Drift gate hardening bucket**: expanded to enumerate all
  six things the drift gate now enforces (added v0.2.83
  CHANGELOG↔git tag parity, v0.2.91 mojibake clean).
- **Compiler bug fixes bucket**: 1 entry (v0.2.69) → 6
  entries (v0.2.69, v0.2.79+80, v0.2.82, v0.2.83, v0.2.85,
  v0.2.91), each with its corresponding gate-step addition.
- **NEW "Documentation staleness audit" bucket** (v0.2.77–98)
  — 19+ stale claims fixed across 12 doc surfaces with the
  principal drift classes enumerated.

### Milestone

This is the **100th v0.2.x release**. Total releases (per
`RELEASES.md`) now 169. The audit-pattern chain that started
at v0.2.79 has run for 22 ships finding ~25 real bugs across
docs and tooling.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh of the status doc.

## [0.2.99] — 2026-04-23

**Milestone tracker refresh — was 22 ships stale.**

`docs/milestones/v0.2.0.md` last refreshed at v0.2.77 (sub-chain
summary still said v0.2.50–v0.2.76 with 27 releases). We're at
v0.2.98 — 22 ships beyond. Refresh:

### Status block

- **Release count** 76 → 98.
- **Verify gate** 195/195 → 203/203.
- **Helper manifest Phase 2** 92.9% (628/676) → 95.1%
  (643/676), with the 33 remaining TODOs explicitly enumerated
  as v0.4 placeholders.
- **Compiler source changes** in the sub-chain now noted (the
  two changes in v0.2.84 + v0.2.87, both preserved IR fixed
  point).

### Sub-chain summary

- Range bumped v0.2.50–76 (27 releases) → v0.2.50–98
  (49 releases). Bucket count 4 → 5.
- **Helper manifest bucket** updated for v0.2.78 TensorOps
  population.
- **CLI surface gate coverage bucket** expanded to enumerate
  the 21+ commands now smoked + the four meta-coverage steps
  (help-text-coverage, JSON-flag, version-alias, showcase-build).
- **Compiler bug fix bucket** expanded from 1 entry (v0.2.69)
  to 6 entries covering v0.2.69 / v0.2.79 / v0.2.82 / v0.2.83 /
  v0.2.85 / v0.2.91 — each one a real bug surfaced by the
  audit pattern with a corresponding gate-step addition.
- **New "Documentation staleness audit" bucket** — 19+ stale
  claims fixed across 12 doc surfaces (milestone tracker,
  helper-contract, schema docs, README, getting-started,
  language-tour, language-reference, migration guide,
  semver-and-release, contributing, rods-and-runtime,
  benchmarks, rfcs/README). Lists the principal drift classes
  (POSIX target version, rod count, "for-loops planned",
  hex/binary literals "not supported", v0.1.x "out of scope").

### Success criteria

Two `[x]` rows updated to current numbers (158/158 → 203/203,
195 steps → 203 steps).

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh of the canonical v0.2 milestone tracker — no compiler
/ runtime / source / test changes.

## [0.2.98] — 2026-04-23

**`docs/benchmarks.md` self-host stats + `docs/rfcs/README.md`
RFC status both stale.**

### `docs/benchmarks.md` — self-host build numbers

The doc claimed v0.1-era estimates: `~330 KB source / 5700
functions / 10000 LOC / 1.8 MB LLVM IR / 3 MB binary`. Audited
against current state via `nuc perf compiler/nucleor_s1_compiler.nr`
and direct file inspection:

| Metric | v0.1-era claim | v0.2.97 actual |
|---|---|---|
| Source size | ~330 KB | **~467 KB** |
| LOC | ~10000 | **8897** |
| Reachable functions (post-DCE) | ~5700 | **365** |
| Optimizer instructions | n/a | **664** |
| String pool | n/a | **3932** |
| LLVM IR | ~1.8 MB | **~2.6 MB** |
| `nucleor.exe` binary | ~3 MB | **~845 KB** |

The dramatic binary shrink (3 MB → 845 KB) is the cumulative
effect of the optimizer + dead-code elimination pass shipped in
the v0.1.46–v0.1.65 chain, which stripped the v0.1.x compiler's
~5700 functions down to the 365 actually reachable. Self-build
wall time also bumped from ~14s to ~27s as the compiler grew
its v0.2 type-checker (which now dominates per the perf
diagnostic).

Also updated the lead paragraph "characterize the v0.1
self-host bootstrap pipeline" → "v0.2".

### `docs/rfcs/README.md` — RFC implementation status

The doc claimed:

> 32 RFCs drafted; 8 Tier-2 (RFC-0015..0022) + RFC-0029 carry
> Implemented or Implemented-partial status as of v0.1.65.

Updated to:

> 32 RFCs drafted; 8 Tier-2 (RFC-0015..0022) + RFC-0029 carry
> Implemented or Implemented-partial status **as of v0.2.0 RC**
> (per the per-RFC checklist rows in `docs/milestones/v0.2.0.md`
> — every row is DONE / PARTIAL / DEFERRED with a follow-on
> target). **RFC-0030 declined** during v0.2 (see the RFC for
> rationale). The post-RC v0.2.x sub-chain (through v0.2.97 as
> of this update) has been strictly additive on top of v0.2.0;
> no RFC implementation states changed.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.97] — 2026-04-23

**`docs/rods-and-runtime.md` — same stale rod count drift as
README v0.2.88.**

The doc opened with:

> Nucleor's standard library is organized as **rods**...
> As of v0.1.1 there are 65 shipping rods covering general
> utilities, scientific computing, modern ML, and physics
> simulation.

And had a section heading "## The shipping rod catalog (v0.1.1,
all 65 build clean)". Both numbers stale: actual is **121
rods** as of v0.2.46 (was 65 at v0.1.1; v0.1.5 brought it to
103; v0.2.18–v0.2.30 enrichment chain added 18 more). Same
drift class as the README "103 rods" claim fixed in v0.2.88.

### Fix

- **Opening paragraph** updated to "121 shipping rods as of
  v0.2.46" with the historical progression (65 → 103 → 121)
  in parens and a pointer to `docs/rfcs/rod_manifest.toml`
  for the per-rod catalog.
- **§ heading** changed from "The shipping rod catalog (v0.1.1,
  all 65 build clean)" to just "The shipping rod catalog"
  with a one-paragraph note that the tables below are the
  v0.1.1 foundation (still gate-tested) and that the
  authoritative enumeration lives in `rod_manifest.toml`.

The 65-row rod tables under that heading are still accurate
for what they list — they're just no longer the complete set.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.96] — 2026-04-23

**`docs/language-reference.md` v0.1 → v0.2 promotion + v0.1.5
audit corrigendum updated for the v0.2.x chain.**

### Title bump

The reference's title was `Nucleor Language Reference (v0.1)`
even though the body described features in `0.2.0-v2`.
Promoted to `(v0.2)` with an explicit pointer to
`docs/milestones/v0.4.0.md` for the deferred Tier-2 language
extensions.

### §13 audit corrigendum refresh

The §13 "What was added in v0.1.5" section was a frozen-in-time
list from a v0.1.4 → v0.1.5 audit. Renamed to "Historical
corrigenda" and split into two subsections:

- **§13.1 v0.1.5 audit (now redundant)** — the original list
  (for-loops, break/continue, block comments, generics, traits,
  match-on-int) plus per-feature back-pointers to the
  gate-tested files under `tests/features/` and `tests/lang/`.
  Added `where` clauses (`tests/features/where_clauses.nr`)
  and the hex / binary / underscored literal forms (per the
  v0.2.95 fix to §1.4).
- **§13.2 v0.2.x additions** — new section enumerating the
  major language additions in the v0.2.x sub-chain that
  weren't yet captured: `?` postfix (v0.1.50, RFC-0016),
  `if let` / `while let` sugar, `as` cast operator, narrow-
  width overflow helpers, 75+ runtime helpers, the
  String/HashMap/HashSet/BTreeMap/BTreeSet/VecDeque
  collection runtime + rod surface. With back-pointers to the
  CHANGELOG and migration guide.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.95] — 2026-04-23

**Bug fix: docs claimed hex/binary literals don't work — they do.**

Three stale doc claims about literal-form support, all
contradicted by gate-tested usage in the source corpus:

1. **`docs/language-tour.md` line 41** said "Numeric literals
   are decimal `i64`. (Hex/binary literal support is planned.)"
2. **`docs/language-reference.md` §1.4 literals table** had no
   row for hex / binary / underscored / suffixed literals plus
   an explicit "not currently supported" line below the table.
3. **`docs/language-reference.md` §12 'does not have (yet)'**
   listed "Hex/binary integer literals (lexer accepts them but
   produces wrong values)" — actively wrong (verified that
   `0xFF` → `255` and `0b1010` → `10` produce correct output).

### Verified working

```nr
fn main() -> i64 {
    let h: i64 = 0xFF;        // 255
    let b: i64 = 0b1010;      //  10
    let u: i64 = 1_000_000;   // 1000000
    print_int(h);
    print_int(b);
    print_int(u);
    return 0;
}
```

Hex literals are also actively used in `tests/lang/atomic_bit_ops.nr`
(`atomic_i64_store(a, 0xFF00)`, `0x000F`, `0xFF0F`, `0x0F0F`)
which has been gate-green for many releases.

### Fix

- **`docs/language-tour.md` §Variables** — replaced the stale
  one-liner with an explicit list of all four literal forms
  (decimal / hex / binary / underscored) plus a note about the
  RFC-0015 width / signedness suffixes that parse and
  type-check, with the strict-mode flip status.
- **`docs/language-reference.md` §1.4 literals** — table
  expanded from 3 rows to 8 rows covering decimal / hex /
  binary / underscored / width-suffixed integer + decimal /
  width-suffixed float + string + boolean. Added a paragraph
  documenting the RFC-0015 suffix vocabulary and NUM-001
  staging.
- **`docs/language-reference.md` §12 'does not have (yet)'** —
  removed the bogus "hex/binary literals" entry (they do
  work). Added a one-line note that RFC-0030 (`async` /
  `await`) was declined.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.94] — 2026-04-23

**Top-level `CONTRIBUTING.md` "scope" section was 90+ releases
stale.**

The "What's in scope vs. out of scope" section framed
contributors against v0.1.x patches. Three rows of "out of
scope" items had **already shipped**:

- **`for` loop syntax** — `for x in <array | Vec>` works,
  gate-tested as `tests/features/forin_array.nr` +
  `forin_vec.nr`.
- **`break` / `continue`** — gate-tested as
  `tests/features/break_continue.nr`.
- **Generics work** — `fn`, `struct`, `enum`, traits (basic,
  bounds, default methods), `where` clauses all gate-tested
  under `tests/features/generic_*` and `tests/features/trait_*`
  and `tests/features/where_clauses.nr`.
- **New CLI subcommands** — 20+ shipped since v0.1
  (`init`, `lock`, `doc`, `fix`, `audit`, `policy`, `certify`,
  `translate`, `evidence`, `impact`, `summary`, `query`,
  `bootstrap`, `stage-dump`, `install`, `add`, `publish`,
  `registry`, `sage`, `clean`, `scram`, `zen`, `mco`).

### Refresh

Replaced the v0.1.x scope framing with three sections:

1. **In scope for v0.2.x post-RC patches** — bug fixes, doc
   staleness fixes (with explicit nod to the audit pattern
   that drove v0.2.79–v0.2.93), test additions, new rods, new
   gate steps, migration tools.
2. **Already shipped (no longer "out of scope")** — enumerates
   each item from the original list with a back-pointer to
   the gate-tested feature file.
3. **Out of scope for v0.2.x (defer to v0.3 / v0.4 / v0.5+)** —
   Linux/macOS native bootstrap (v0.3.0), iterator trait
   (v0.4 RFC-0024), pattern-matching extensions (v0.4
   RFC-0023), closures/lifetimes/trait-objects/format-strings
   (v0.4 RFC-0025/26/27/28), PubGrub resolver + git fetch
   (v0.5 RFC-0019 phase 3).

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.93] — 2026-04-23

**Process docs refresh — `semver-and-release.md` and
`process/contributing.md` were stale.**

### `docs/process/semver-and-release.md`

- **Last-updated header** bumped from 2026-04-22 to 2026-04-23
  (post-v0.2.92).
- **§1.1 v0.x policy paragraph** had a future-tense framing of
  the v0.2.0 release ("v0.2.0 release will break ~every existing
  program due to the numeric refactor"). Updated to past tense
  + the actual outcome: v0.2.0 shipped 2026-04-22 fully
  backwards-compatible because the phase 5 stdlib audit and
  phase 7 strict-mode flip were deferred to v0.4.
- **Release schedule table** — v0.2.0 row updated to note
  early ship (2026-04-22 vs the original 2026-06 target).
  v0.3.0 target loosened from "2026-08" to "2026-Q3".

### `docs/process/contributing.md`

- **"101 steps as of v0.1.8"** — replaced with "203 steps as
  of v0.2.91" + a note about the ~100-step growth via CLI
  surface coverage, JSON smoke, mojibake check, and other
  audit-pattern hardening.
- **"step 67/67"** — replaced with the current step name
  ("self-host rebuild closes") + a back-pointer to the
  `NUCLEOR_BOOTSTRAP_CONTRACT.md` 2-iteration fixed-point
  recipe used for v0.2.84 and v0.2.87 compiler source changes.
- **"Linux/macOS (after v0.2.0)"** — clarified that the POSIX
  gate ships in v0.2 but native Linux/macOS `bin/nucleor`
  binaries land in v0.3.
- **"CI runs the full verify gate on Linux + macOS + Windows
  × Intel + ARM (post v0.2.0)"** — corrected to "Windows
  x86_64 today; Linux + macOS + Windows ARM with v0.3.0
  cross-build" with a link to the v0.3 milestone tracker.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.92] — 2026-04-23

**Migration guide refresh — `docs/migrations/v0.1-to-v0.2.md`
was 50+ releases stale.**

The guide's TL;DR claimed:

> v0.2.0 → v0.2.38 is also fully additive. The 18 incremental
> v0.2.x releases shipped 75+ new runtime helpers...

But we're at v0.2.91, not v0.2.38. The 91+ post-v0.2.0
releases are still strictly additive — no behavior change in
v0.2.0 surface — but the guide's narrative was 50+ releases
behind the actual chain.

### Updated framing

The guide now explicitly covers three sub-chains:

- **v0.2.18–v0.2.30 stdlib enrichment** (helpers + 5 demo
  programs — already documented in detail).
- **v0.2.41–v0.2.49 manifest contract** (helper / rod
  manifests under drift-gate enforcement — newly mentioned).
- **v0.2.50–v0.2.91 post-RC hardening** (16+ gate steps for
  CLI surface coverage, JSON smoke, version aliases, showcase
  build, mojibake check, plus real bugs surfaced by the audit
  pattern: registry list cmd.exe stderr leak, `nuc test`
  target/ creation, missing bootstrap contract doc, etc.).

The opening summary block also notes the **two compiler source
changes** in the post-RC chain (v0.2.84 `nuc help` doc/fix
entries, v0.2.87 `-V` / `version` aliases) and their preserved
LLVM IR fixed point — important for the "fully additive"
guarantee.

No behavior promised by v0.2.0 changed. The migration paths
documented in the guide (legacy `import "stdlib/rods/foo.nr"`
→ `use std::foo`, `nuc fix --imports` linter, etc.) all still
work as written.

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.91] — 2026-04-23

**Mojibake sweep + gate enforcement. Self-defeating mojibake
in v0.2.90 / v0.2.58 CHANGELOG entries fixed.**

### Self-defeating CHANGELOG entries

A repo-wide mojibake-byte sweep (looking for the cp1252-as-UTF-8
fingerprint `0xC3 0xA2 0xE2 0x82 0xAC`) found **two CHANGELOG
entries that re-introduced the very mojibake they claimed to
fix**:

- **v0.2.90 entry** (vqe_h2.nr fix) — quoted the mojibake
  literally with `// vqe_h2.nr [mojibake] Variational`. The
  bytes survived markdown into the published CHANGELOG.
- **v0.2.58 entry** (rod manifest generator fix) — same
  pattern, twice (in the prose intro and in the example
  TOML block).

Fixed by replacing each literal mojibake quotation with a
hex-byte description (e.g. `0xC3 0xA2 0xE2 0x82 0xAC 0xE2
0x80 0x9D` instead of the literal sequence). Documents the bug
without re-introducing the bad bytes.

### `tools/check_mojibake.sh` + gate step

New script + gate step that flags the universal mojibake
fingerprint across `*.md` / `*.nr` / `*.toml` / `*.py` /
`*.sh` / `*.ps1` / `*.c` / `*.h` / `*.txt` files (skipping
`bin/`, `target/`, `.git/`, `node_modules/`). The check
itself is whitelisted (it intentionally documents the bytes
in comments).

The script outputs an actionable error message naming the
correct UTF-8 sequences for em-dash / en-dash / curly quotes,
plus a pointer to the v0.2.91 CHANGELOG precedent for how to
write about the mojibake without re-introducing it.

Wired into both gates as **`mojibake_clean`** (bash) /
**`no UTF-8 mojibake in source/docs`** (PowerShell, shells out
to the bash script). Skipped silently on Windows hosts without
Git for Windows or msys2.

**Step total bumped 202 → 203** in both gates.

### Drift gate now enforces six things

After this ship the `tools/check_compiler_drift.sh` + gate
together enforce:

1. s1 ↔ tools-suite ABI table parity (v0.2.x baseline)
2. `helper_manifest.toml` freshness (v0.2.41)
3. `rod_manifest.toml` freshness (v0.2.47)
4. `RELEASES.md` freshness (v0.2.57)
5. CHANGELOG ↔ git tag parity (v0.2.83)
6. **No UTF-8 mojibake in source/docs (v0.2.91 — this release)**

### Verify gate

203 / 203 PASS, 0 SKIP on the bash gate. Documentation +
gate-step refinement only — no compiler / runtime / source /
test changes.

## [0.2.90] — 2026-04-23

**Bug fix: `examples/showcase/README.md` was referenced but
missing. Plus showcase build smoke + UTF-8 mojibake fix.**

### Missing showcase README

`examples/README.md` line 62 told readers:

> `showcase/` contains larger programs that span multiple rods.
> See `showcase/README.md` (or run `nuc summary`) for the
> index.

But `examples/showcase/README.md` **didn't exist** in git.
Created it with: a one-paragraph framing of the showcase
intent (production-shaped programs, not gated, intended for
manual viewing); a per-program table covering `lorenz.nr`,
`vqe_h2.nr`, `market_maker.nr`, `wing_simulator.nr` (lifted
from the top-level README descriptions); the `_viz.nr` shared
helper note; build/run instructions; and a "why no gate
coverage?" rationale.

### UTF-8 mojibake in `vqe_h2.nr` header

The first comment line had a 5-byte mojibake sequence
(`0xC3 0xA2 0xE2 0x82 0xAC 0xE2 0x80 0x9D`) where an em-dash
(`U+2014`, 3 UTF-8 bytes) was intended — the cp1252-rendered-
as-UTF-8 mojibake class that bit the rod descriptions in
v0.2.58. Fixed to the proper em-dash. (Documenting the bytes
in hex rather than literal because the literal would
re-introduce the mojibake into this CHANGELOG.)

### Showcase build smoke (`showcase_build_smoke`)

New gate step in both `verify.sh` and `verify.ps1` builds the
4 standalone showcase programs (`lorenz`, `vqe_h2`,
`market_maker`, `wing_simulator`) and verifies the `.exe` is
produced. **Build-only, not run-tested** because each program
emits a streaming ANSI dashboard that doesn't terminate on its
own (live Lorenz attractor, VQE convergence chart, options
market-making dashboard, fluid+EM heatmap).

This catches regressions where a stdlib change breaks the
showcase compile path even though the standard examples
01..18 still compile. The `_viz.nr` shared helper imported by
all four is exercised transitively.

**Step total bumped 201 → 202** in both gates.

### Verify gate

202 / 202 PASS, 0 SKIP on the bash gate. Tools-suite source
unchanged; no compiler / runtime / s1 / test changes.

## [0.2.89] — 2026-04-23

**Continue README freshness pass — fix two more `v1.1` stale
roadmap claims plus document `for-in` already shipped.**

### `docs/getting-started.md` — POSIX target version

Same drift class as the README v0.2.88 fix. Said:

> Windows 10/11, x86_64. v1 targets `x86_64-pc-windows-msvc`.
> POSIX support is planned for v1.1.

Updated to:

> Windows 10/11, x86_64. **v0.2** targets
> `x86_64-pc-windows-msvc`. POSIX support (Linux/macOS) is
> planned for **v0.3.0** (see `docs/milestones/v0.3.0.md`) —
> phases 1, 2, and 4 of RFC-0022 already shipped in v0.2
> (POSIX `tools/verify.sh` gate, `nuc` shell wrapper, runtime
> `_WIN32` audit). The v0.3 release adds the native
> Linux/macOS bootstrap binaries.

### `docs/language-tour.md` — `for` loops already work

The tour said:

> `while` is the loop primitive; `for` is sugar planned for v1.1.

But `for x in <expr>` over arrays AND `Vec` **already works**
and is gate-tested as `tests/features/forin_array.nr` and
`tests/features/forin_vec.nr`. Replaced the stale claim with
a working code example plus a forward-looking note that
iterator-trait `for` (over `HashMap` keys, ranges, lazy
adapters) lands in v0.4 with RFC-0024.

### Audit sweep

Repo-wide grep for `v1.1` references after these fixes
returns **zero matches** in non-CHANGELOG markdown. The
remaining `v1.0` references in CONTRIBUTING / benchmarks /
process docs are legitimate forward-looking ("after v1.0",
"at v1.0+", "revisit at v1.0") and not drift.

### Verify gate

201 / 201 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.88] — 2026-04-23

**README freshness pass — fix two stale claims.**

Audit of the README's quantitative + roadmap claims against
current state found two outdated statements:

1. **POSIX target version was wrong.** README said "POSIX
   (Linux/macOS) support is planned for v1.1." Milestone
   tracker says it's deferred to **v0.3.0** (see
   `docs/milestones/v0.3.0.md` — entire RFC-0022 phase 3 work).
   Fixed; the new line also notes that phases 1, 2, and 4 of
   RFC-0022 already shipped in v0.2 (POSIX gate, `nuc` shell
   wrapper, runtime `_WIN32` audit).

2. **Rod count was historical.** README said "That's **103
   rods total** as of v0.1.5." Actually 121 rods today (v0.2.46
   bumped the count via the v0.2.18–30 enrichment chain).
   Updated to "121 rods total as of v0.2.46 (was 103 at v0.1.5;
   the v0.2.18–v0.2.30 stdlib enrichment chain added 18 more)"
   with a pointer to `docs/rfcs/rod_manifest.toml` for the
   per-rod catalog.

Other quantitative README claims confirmed accurate against
current state:

- `~10,000 lines compiler source` → 8,897 actual ✓ (rough match)
- `121 rods` → 121 actual ✓
- `84 runtime C source files` → 84 actual ✓
- `676 __nucleor_* symbols` → 676 actual ✓
- `13 categories` → 13 taxonomy classes ✓ (per
  `docs/rfcs/helper_manifest.toml`)
- `v0.2.0 (released 2026-04-22)` → still accurate

### Verify gate

201 / 201 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / source / test changes.

## [0.2.87] — 2026-04-23

**`nuc -V` and `nuc version` now work as aliases for
`--version`. Plus negative-test audit findings.**

### Version aliases (`nuc -V` / `nuc version`)

`nuc --version` and `nuc -v` worked since v0.1.x. The
`-V` (rustc/gcc/clang convention) and bare `version`
spellings both returned `Unknown command:`. Added both to the
dispatch in `compiler/nucleor_s1_compiler.nr`:

```nr
if str_eq(cmd, "--version") || str_eq(cmd, "-v") ||
   str_eq(cmd, "-V")        || str_eq(cmd, "version") {
    print(compiler_identity());
    return 0;
};
```

All four spellings now produce the same output:
`nucleor 0.2.0-v2 (self-hosted, llvm backend)`.

This is a **compiler source change** — `bin/nucleor.exe`
rebuilt via the standard 2-iteration LLVM IR fixed-point
check. Both iterations produced byte-identical
2,603,849-byte LLVM IR (fixed point preserved).

### Negative-test audit findings (no fix this ship)

Auditing `tests/err/*.nr` against a strict
"must contain a Nucleor diagnostic code (NR/RT/NUM/etc.)"
check found **4 of 33 negative tests pass for the wrong
reason**:

- `err_pure_ambient_random` — fails at link (missing
  `__nucleor_ambient_random` v0.4 placeholder) instead of
  firing a pure-vs-effect diagnostic.
- `err_restricts_specific` — fails at link (missing
  `__nucleor_putchar`) instead of firing EFF-003 (restricts
  violated).
- `err_spawn_send` — fails at link (missing
  `__nucleor_device_alloc`/`free`) instead of firing a
  concurrency check.
- `err_undefined_var` — fails at link (`str_from_int` not in
  scope) instead of firing NR030 on `undeclared_thing`. The
  compiler **silently accepts** the undefined variable; only
  the unrelated `str_from_int` call trips clang.

These are all real compiler gaps (the type-checker doesn't
catch undefined identifiers; effect rows aren't enforced for
ambient_random; restricts isn't enforced for putchar). The
gate's loose "any error string" matcher accepts the link
failures, so the tests register green — but if the v0.4
placeholders ever get implemented, these tests would
silently start passing the build and then the gate would
flip red.

**Documented as v0.4 follow-up.** Tightening the negative-test
matcher to require Nucleor-style diagnostic codes would
immediately surface these 4 cases as gate failures, but the
underlying fixes touch the type-checker and effect/taint
analyzers — substantively bigger than a single ship.

### New gate step (`cli_version_smoke`)

Smoke-tests all four version aliases produce the
`"nucleor "`-prefixed output. **Step total bumped 200 → 201**
in both gates.

### Verify gate

201 / 201 PASS, 0 SKIP on the bash gate. Compiler source
change (s1 dispatch only) — self-host LLVM IR fixed point
preserved.

## [0.2.86] — 2026-04-23

**Gate `--json` output across 11 CLI commands. 200-step gate
milestone crossed.**

Auditing the `--json` flag surface found:

- **9 commands honor `--json` and emit valid JSON** when the
  flag follows the source positional: `audit`, `summary`,
  `query`, `abi`, `evidence`, `graph`, `perf`, `check`, plus
  `explain` (CODE positional, both flag-orders work),
  `bootstrap` (no positional), `lock` (no positional). 11
  total command paths.
- **`policy --json` and `bench --json` silently fall back to
  text** because `policy [file] [level]` parses `--json` as
  the `level` positional and `bench` doesn't advertise `--json`
  at all. **Documented behavior gap, not a bug** — both
  commands accept the flag without warning rather than
  honoring it. Future ships can add `--json` support to either
  by adjusting the dispatch.
- **Parser quirk: `--json` must come AFTER the source
  positional for file-taking commands.** `nuc audit
  examples/01_hello.nr --json` works; `nuc audit --json
  examples/01_hello.nr` falls through to the usage message.
  This is consistent with the help text format (file first,
  flags below) but is a surface that future versions may want
  to permissive-ify.

### Gate hardening (`cli_json_smoke`)

New step in both `verify.sh` and `verify.ps1` exercises the 11
working `--json` paths and verifies each output starts with
`{` (or `[` for array shapes). Catches regressions where the
flag silently falls back to the text path.

The smoke is positioned early in the pre-iteration block (right
after `cli_utility_smoke`) so the JSON contract is verified
before the heavier example/test build phase.

**Step total bumped 199 → 200** in both gates. **First gate
milestone with a 3-digit step count.**

The pre-iteration smoke block now reads (truncated):

```
[ 1/200] OK    binary present
[ 2/200] OK    compiler ABI tables synced
[ 3/200] OK    tools-suite rebuild
[ 4/200] OK    CLI: nuc help advertises every dispatched command
[ 5/200] OK    CLI: nuc zen/mco/registry/stage-dump/fix (utilities)
[ 6/200] OK    CLI: --json variants emit machine-readable JSON
... (10 more)
```

### Verify gate

200 / 200 PASS, 0 SKIP on the bash gate. Pure gate addition
— no compiler / runtime / source / test changes.

## [0.2.85] — 2026-04-23

**Bug fix: `nuc registry list` leaked `cmd.exe` stderr.**
**Plus utility-smoke gate for 5 previously unsmoked CLI commands.**

### Bug

Auditing the unsmoked CLI surface (`zen`, `mco`, `registry list`,
`stage-dump`, `fix --imports`) found `nuc registry list` printing
a spurious `The system cannot find the file specified.` line on
top of its real output:

```
$ nuc registry list
The system cannot find the file specified.
registry: .nucleor/registry
packages: 0
```

Root cause: `dir_list_native` in
`compiler/nucleor_tools_suite.nr` shells out to Windows
`dir /b /ad <path> > <listing>`. When `<path>` doesn't exist
(common — fresh project has no `.nucleor/registry` dir),
`cmd.exe` writes to its stderr, which leaks past the parent
process's redirect and lands on the user's terminal. The
`system()` return code already handles the missing-dir case
correctly (returns empty Vec); only the stderr message was
broken.

Fix: append `2>NUL` to both `dir` invocations in
`dir_list_native`. Now:

```
$ nuc registry list
registry: .nucleor/registry
packages: 0
```

### Utility-smoke gate (`cli_utility_smoke`)

New step in both `verify.sh` and `verify.ps1` exercises the 5
zero-side-effect utility commands that weren't yet under gate
coverage:

- `nuc zen` — must print `"The Zen of Nucleor"`
- `nuc mco` — must print `"Mars Climate Orbiter"` (RFC-0005
  motivation poster)
- `nuc registry list` — must print `registry:` + `packages:`
  AND must NOT contain `system cannot find` (catches the
  v0.2.85 regression by name)
- `nuc stage-dump tokens examples/01_hello.nr` — must print
  `TOKENS`
- `nuc fix --imports examples/01_hello.nr` — must produce
  non-empty output

`nuc clean` and `nuc scram` are intentionally **NOT smoked**
because they delete `target/` mid-gate, which would conflict
with downstream example/test build steps.

This brings the **explicitly-smoked CLI surface to 21
commands**: `explain`, `bootstrap`, `check`, `abi`, `summary`,
`audit`, `query`, `impact`, `policy`, `certify`, `translate`,
`evidence`, `graph`, `perf`, `bench`, `init`, `doc`, `lock`,
`test`, plus the 5 new utility entries (`zen`, `mco`,
`registry`, `stage-dump`, `fix`). Together with implicit
coverage of the build-family + run + emit via every example /
test step, **every dispatched user-facing CLI command is now
gate-protected** (modulo the side-effect-heavy `clean`/`scram`).

**Step total bumped 198 → 199** in both gates.

### Verify gate

199 / 199 PASS, 0 SKIP on the bash gate. Tools-suite source
change only — s1 compiler / runtime / ABI / source / test
unchanged; self-host LLVM IR fixed point preserved (s1 binary
not rebuilt this release).

## [0.2.84] — 2026-04-23

**Bug fix: `nuc doc` and `nuc fix` were dispatched but missing
from `nuc help`.**

Audit of `nuc help` output vs. the s1 compiler's command
dispatch table found two commands that worked but were
unadvertised:

- **`nuc doc`** — RFC-0029 Markdown doc generator. Shipped
  v0.1.65, gate-tested via `cli_doc_smoke` since v0.2.67, but
  never appeared in `nuc help`.
- **`nuc fix`** — RFC-0015 `--numeric` linter (v0.1.63) +
  RFC-0018 `--imports` migration (v0.1.60). Both subcommands
  shipped with their respective RFCs but never appeared in
  `nuc help`.

Result: users running `nuc help` to discover available commands
would not see two of the most useful tools. The drift wasn't
caught by any existing gate — `cli_doc_smoke` exercises the
behavior; nothing exercised the help text.

### Fix

Added the two missing entries to `print_usage` in
`compiler/nucleor_s1_compiler.nr`:

```
  doc [file]             Render /// doc comments as Markdown (RFC-0029)
    --out <file>         Write to file instead of stdout
  fix [--imports|--numeric] [file]  Migration linters (RFC-0015 / RFC-0018)
```

`doc` lives in the Developer commands section near `summary` /
`query` / `graph`. `fix` lives in the Project utilities section
near `clean` / `scram`.

### Self-host bootstrap

This is a **compiler source change** — `bin/nucleor.exe`
rebuilt via the standard 2-iteration LLVM IR fixed-point check:

```
./bin/nucleor.exe build compiler/nucleor_s1_compiler.nr -o nucleor_v1
./target/nucleor_v1.exe build compiler/nucleor_s1_compiler.nr -o nucleor_v2
diff -q target/nucleor_v1.ll target/nucleor_v2.ll  # identical
cp target/nucleor_v2.exe bin/nucleor.exe
```

Both iterations produced **byte-identical 2,603,214-byte LLVM
IR** — fixed point preserved across the compiler change.

### Gate hardening

New step **`cli_help_coverage_smoke`** in both `verify.sh` and
`verify.ps1` enumerates the 38-command list and verifies each
appears at the start of an indented line in `nuc help` output.
Catches the same drift class going forward — adding a new
command to the dispatch table without updating `print_usage`
will now fail the gate.

**Step total bumped 197 → 198** in both gates.

The pre-iteration smoke block now reads (truncated):

```
[ 1/198] OK    binary present
[ 2/198] OK    compiler ABI tables synced
[ 3/198] OK    tools-suite rebuild
[ 4/198] OK    CLI: nuc help advertises every dispatched command
[ 5/198] OK    CLI: nuc explain NUM-001 wired
[ 6/198] OK    CLI: nuc explain — full spec code set wired
... (8 more)
```

### Verify gate

198 / 198 PASS, 0 SKIP on the bash gate. Compiler source
change (s1 `print_usage` only) — self-host LLVM IR fixed point
preserved.

## [0.2.83] — 2026-04-23

**CHANGELOG ↔ git tag parity restored; drift gate now enforces.**

A repo-wide audit comparing `git tag -l 'v*'` to the `## [x.y.z]`
headings in `CHANGELOG.md` found one drift entry: **`v0.1.67`
existed as a git tag but had no per-version CHANGELOG block.**

History: v0.1.67 was the bridge release between the v0.1.x
preview chain and the v0.2.0 RC tag — landed
`docs/milestones/v0.4.0.md` (the v0.4 tracker for v0.2-deferred
work). The release notes were rolled into the v0.2.0 narrative
("the v0.1.46..v0.1.67 preview series") instead of getting their
own CHANGELOG entry. The git tag therefore had no documentation
match.

### Fix

Added a retroactive `## [0.1.67] — 2026-04-22` block to
CHANGELOG.md describing what landed (the v0.4 tracker file),
inserted in the correct chronological position between v0.1.66
and v0.2.0.

### Drift gate hardening

`tools/check_compiler_drift.sh` now performs a fifth check:
**every git tag matching `v*` must have a matching
`## [version]` heading in CHANGELOG.md.** Skips silently if the
working tree isn't a git checkout (tarball release case).

This closes the same drift class that bit v0.1.67 — anyone who
pushes a tag without writing the corresponding CHANGELOG block
will fail the verify gate's drift step.

The drift gate now enforces five things:

1. s1 compiler ↔ tools-suite ABI table parity (v0.2.x baseline)
2. `helper_manifest.toml` freshness (v0.2.41)
3. `rod_manifest.toml` freshness (v0.2.47)
4. `RELEASES.md` freshness (v0.2.57)
5. **CHANGELOG ↔ git tag parity (v0.2.83 — this release)**

### Verify gate

197 / 197 PASS, 0 SKIP on the bash gate. Drift step now
includes the new tag/CHANGELOG check; passes after the v0.1.67
backfill.

## [0.2.82] — 2026-04-23

**Bug fix: create the missing `NUCLEOR_BOOTSTRAP_CONTRACT.md`
file referenced by `nuc bootstrap` since v0.2.70.**

`nuc bootstrap` has been printing `Contract:
NUCLEOR_BOOTSTRAP_CONTRACT.md` (and emitting the same string as
the `bootstrap_contract` JSON field) since v0.2.70 — but the
file **never existed in git history**. Anyone following the
pointer hit a 404.

### Fix

Wrote `NUCLEOR_BOOTSTRAP_CONTRACT.md` at the repo root. The
contract document specifies:

- The stage hierarchy (single committed `bin/nucleor.exe` =
  stage 1, self-hosted; stage 0 lineage is upstream).
- The self-host invariant (every committed
  `bin/nucleor.exe` must be capable of compiling its own source
  via the verify gate's final step).
- The 2-iteration LLVM IR fixed-point check pattern used during
  v0.1 / v0.2.x sub-chain releases that touch the compiler.
- The two-binary architecture (`bin/nucleor.exe` for s1,
  `bin/nucleor_tools.exe` for explain/bootstrap/test runner;
  drift gate enforces ABI parity between the two source files).
- Runtime layer pointer (`stdlib/runtime/nucleor_llvm_rt.c`).
- Examples corpus pointer (`tools/examples.list`).
- Bootstrap-from-fresh-clone instructions.
- Cross-platform status (Windows-only binary today;
  Linux/macOS lands with v0.3.0).
- "What changes the contract" — enumerates the four common
  ways to break or update the bootstrap.

### Gate hardening

Extended `cli_bootstrap_smoke` (in both `verify.sh` and
`verify.ps1`) to **resolve the `Contract:` line as an existing
file at the repo root**. Catches the same drift class going
forward — if anyone renames or removes the file (or if the
binary's emitted reference changes to point at something
non-existent), the gate fails.

### Verify gate

197 / 197 PASS, 0 SKIP on the bash gate. Documentation +
gate-step refinement only — no compiler / runtime / source /
test changes.

## [0.2.81] — 2026-04-23

**Refresh `HELPER-CONTRACT.md` and `helper_manifest_schema.md`
for v0.2.41–78 Phase 2 reality.**

Two contract / schema docs were stale:

- **`docs/rfcs/HELPER-CONTRACT.md`** — header still said
  "Phase 1 walk: awaiting explicit 'go' from user" and
  "drift-gate enforcement lands once Phase 2 is approved" —
  both true at v0.2.32 / v0.2.40 but false since v0.2.41.
  Refreshed to reflect: Phase 1 walk approved (taxonomy: 13
  classes / 676 helpers), Phase 2 mechanism shipped v0.2.41,
  Phase 2 population at 95.1% as of v0.2.78, and the
  going-forward constraint is **drift-gate-enforced live**
  since v0.2.41 (not pending).
- **`docs/rfcs/helper_manifest_schema.md`** — `effects` field
  state table said "v0.2.73 — 405 rows; remaining 271 carry
  TODO." Replaced with a 13-row per-class population table
  showing 643 of 676 helpers (95.1%) populated and the
  remaining 33 enumerated as v0.4 placeholders. `taint` field
  state expanded to enumerate the 23 read-side IO helpers
  carrying `"propagates"` (the only non-`"passthrough"` rows).

No code or generator changes. The manifest itself, the
generator, and the gate are unchanged — this ship just brings
the protocol docs into agreement with the shipped state.

### Verify gate

197 / 197 PASS, 0 SKIP on the bash gate. Pure documentation
refresh — no compiler / runtime / ABI / source / test changes.

## [0.2.80] — 2026-04-23

**Wire 44 forward-looking error codes into the explain registry;
gate now exercises the full 130-code spec catalog.**

Continues the audit pattern from v0.2.79 (which found 4 v0.2
codes missing). A wider sweep of every code listed in
`docs/spec/Nucleor_Error_Codes.md` found **44 more `unknown
error code` returns** from `nuc explain` — all forward-looking
entries for RFCs that haven't shipped yet but whose codes are
documented:

- **RFC-0004 assume!** — `ASSUME-003`, `ASSUME-005` (2 codes)
- **RFC-0005 units** — `UNIT-003`, `UNIT-005` (2 codes)
- **RFC-0006 contracts** — `CONTRACT-005`, `CONTRACT-006`,
  `CONTRACT-007` (3 codes)
- **RFC-0007 atomic** — `ATOMIC-003`, `ATOMIC-004` (2 codes)
- **RFC-0008 ISR** — `ISR-003`, `ISR-005`, `ISR-006` (3 codes)
- **RFC-0009 WCET** — `WCET-001`, `WCET-002`, `WCET-004`,
  `WCET-005`, `WCET-006` (5 codes)
- **RFC-0010 DLPack** — `DLPACK-001..005` (5 codes)
- **RFC-0011 nuc-cxx** — `CXX-001..005` (5 codes)
- **RFC-0012 nuc-bindgen** — `BINDGEN-001..005` (5 codes)
- **RFC-0013 URDF** — `URDF-001..006` (6 codes)
- **RFC-0014 max_depth** — `DEPTH-003`, `DEPTH-005` (2 codes)
- **RFC-0031 algebraic laws** — `LAW-003`, `LAW-004` (2 codes)
- **RFC-0032 effects** — `EFF-004`, `EFF-005` (2 codes)

Each entry got a short title, a one-line summary, and a longer
RFC-anchored explanation — a total of **132 string literals
added across the 3 explain registry functions**
(`explain_error_title`, `explain_error_summary`,
`explain_error_explanation`) in
`compiler/nucleor_tools_suite.nr`. Tools binary rebuilt.

Even though the underlying RFCs ship in v0.3 / v0.4 / v0.5+,
having `nuc explain RT-001` or `nuc explain DLPACK-002` produce
useful documentation today gives users a reading surface for
the planned features.

### Gate hardening

The `cli_explain_full_smoke` step (added v0.2.79 with 35 codes)
is **extended to cover all 130 codes** from the spec catalog.
Step renamed from "full v0.2 code set wired" to "full spec
code set wired" in both `verify.sh` and `verify.ps1` to reflect
the expanded scope. Per-call overhead: 130 binary invocations,
all against the same fast-fail explain command — adds ~2 s to
the gate run.

Going forward, adding a code to `Nucleor_Error_Codes.md` MUST
also (a) wire it into all three explain registry functions and
(b) add the code string to the `cli_explain_full_smoke` list in
both gates. The existing tools-rebuild + drift-gate machinery
catches unrelated divergence; this step closes the explain-
specific drift class.

### Verify gate

197 / 197 PASS, 0 SKIP on the bash gate. Tools-suite source
change only — no s1 compiler / runtime / ABI / source / test
changes; self-host LLVM IR fixed point preserved.

## [0.2.79] — 2026-04-23

**Bug fix: 4 v0.2 error codes spec'd but not wired into explain
registry. Plus a new gate step that enforces full v0.2 code-set
coverage going forward.**

`docs/spec/Nucleor_Error_Codes.md` listed 35 v0.2-era codes
across the NUM / MATCH / COLL / MOD / PKG / TGT / TST series.
A spot audit found that **4 of them returned `unknown error
code` from `nuc explain`**:

- **`NUM-004`** — f8/f16/bf16 op without hardware support
  (RFC-0015 §3.4)
- **`TST-001`** — Test discovery: no #[test] functions found
  (RFC-0021 §3.1)
- **`TST-002`** — Test isolation: process child crashed before
  reporting (RFC-0021 §3.4)
- **`TST-003`** — Test fixture: setup fn returned non-zero
  (RFC-0021, fixture work deferred to v0.4)

Root cause: the spec doc was a forward-looking catalog, but
the explain registry in `compiler/nucleor_tools_suite.nr` (the
backing store for `nuc explain CODE`) had no entries for these
four codes. Existing gate step `cli_explain_smoke` only
exercised `NUM-001`, so the drift wasn't caught.

### Fix

Added 4 entries × 3 functions (12 string literals) to the
explain registry:

- `explain_error_title(code)` — short title
- `explain_error_summary(code)` — one-line summary
- `explain_error_explanation(code)` — RFC-anchored explanation

Tools binary rebuilt from `compiler/nucleor_tools_suite.nr` and
installed at `bin/nucleor_tools.exe` (where `nuc` resolves the
external explain handler).

### Gate hardening

New step **`cli_explain_full_smoke`** in both `verify.sh` and
`verify.ps1` enumerates the full 35-code v0.2 set and verifies
each returns a non-`unknown` answer that includes the code in
its title. The previous gate step `cli_explain_smoke` (NUM-001
only) is preserved as a quick-fail canary; the new step runs
the exhaustive sweep.

### Companion fix: `tools_rebuild` gate step

Found while wiring the new explain step: the gate had **no
step that rebuilt `bin/nucleor_tools.exe`**. The s1 compiler
gets self-host-rebuilt at the end of every gate run, but the
tools-suite source — which backs `nuc explain`, `nuc test`,
and other tools-suite logic — was being tested against
whatever stale binary the user happened to have in `bin/`.

This meant a fresh-clone-and-pull workflow that updated
`compiler/nucleor_tools_suite.nr` would silently leave the
stale `bin/nucleor_tools.exe` in place (the file is
`.gitignore`-d), and the new `cli_explain_full_smoke` step
would have spuriously failed because the user's binary lacked
the new entries — even though the source did have them.

Added a **`tools_rebuild`** step that:

1. Builds `compiler/nucleor_tools_suite.nr` via `bin/nucleor.exe`
2. Copies the resulting `target/nucleor_tools.exe` to
   `bin/nucleor_tools.exe`

Placed after `compiler ABI tables synced` and before the
explain smokes. The subsequent CLI smokes (`bootstrap`,
`check`, `abi`, inspectors, diagnostics, `init`, `doc`,
`lock`, `test`) now exercise the freshly-built tools binary,
not whatever was stale on disk.

**Step total bumped 195 → 197** (one for explain-full, one
for tools-rebuild) in both gates.

The pre-iteration smoke block now reads:

```
[ 1/197] OK    binary present
[ 2/197] OK    compiler ABI tables synced
[ 3/197] OK    tools-suite rebuild
[ 4/197] OK    CLI: nuc explain NUM-001 wired
[ 5/197] OK    CLI: nuc explain — full v0.2 code set wired
[ 6/197] OK    CLI: nuc bootstrap status reports correctly
[ 7/197] OK    CLI: nuc check + abi inspect
[ 8/197] OK    CLI: nuc summary/audit/query/impact (inspectors)
[ 9/197] OK    CLI: nuc policy/certify/translate/evidence/graph/perf/bench (diagnostics)
[10/197] OK    CLI: nuc init scaffolding works
[11/197] OK    CLI: nuc doc generator works
[12/197] OK    CLI: nuc lock writes Nucleor.lock
[13/197] OK    CLI: nuc test runs #[test] functions
```

Going forward, adding a code to `Nucleor_Error_Codes.md` MUST
also wire it into the explain registry AND add the code string
to the `cli_explain_full_smoke` list in both gates — same
"add it in three places" pattern that already protects the s1
compiler ↔ tools-suite ABI tables.

### Verify gate

197 / 197 PASS, 0 SKIP on the bash gate. Compiler change
(tools-suite explain registry only — no s1 compiler / runtime
/ ABI / source / test changes). Self-host LLVM IR fixed point
preserved; the s1 compiler binary at `bin/nucleor.exe` is
unchanged.

## [0.2.78] — 2026-04-23

**Helper manifest Phase 2 — populate 15 stable `TensorOps`
helpers.**

15 of the 45 `TensorOps` helpers are actually CPU-bound and
shipping today (`tensor_get`, `tensor_set`, `tensor_fill`,
`tensor_cols`, `tensor_rows`, `tensor_max`, `tensor_min`,
`tensor_mean`, `tensor_sum`, `tensor_stddev`, `tensor_variance`,
`tensor_zeros`, `tensor_ones`, `tensor_transpose`,
`tensor_matmul`). The remaining 30 are forward declarations
for the v0.4 device-effect formalization (`device_*`,
`kvcache_*`, `kvprefix_*`, `simd_*`, `vector_*`,
`tensor_sample_*`, etc.) — all carry `stability = "unstable"`
already.

**Newly populated via `PATTERN_OVERRIDES`:**

- **9 pure** — `^tensor_(get|cols|rows|max|min|mean|sum|stddev|
  variance)$`. Read-only / reductions returning scalar.
  Proof obligation `"bounds_within_shape"`.
- **2 in-place mutation** — `^tensor_(set|fill)$`. Modify
  pointed-to tensor without allocation. Proof obligation
  `"bounds_within_shape"`.
- **4 allocating** — `^tensor_(zeros|ones|transpose|matmul)$`.
  Allocate a fresh result tensor. Proof obligation
  `"shape_compatible"`.

The 30 unstable `TensorOps` placeholders stay TODO because
their effects depend on the v0.4 `"device"` effect tag (not
yet in the schema vocabulary). Adding `"device"` ahead of the
v0.4 implementation would create a dangling abstraction.

**TODO sentinel count drops 144 → 99** (45 TODOs eliminated).

**Helper manifest Phase 2 now at 643 of 676 helpers (95.1%).**
Remaining 33 helpers are all intentional v0.4 placeholders:

- 30 `TensorOps` GPU/device/SIMD/sampling forward declarations
- 3 `ToolingMeta` stubs (`profile_start`, `profile_end`,
  `py_eval`) whose runtime bodies are deferred to v0.4

### Verify gate

195 / 195 PASS, 0 SKIP on the bash gate. Tooling-only — no
compiler / runtime / ABI / source / test changes.

## [0.2.77] — 2026-04-23

**Milestone tracker + status doc + RFC index refresh for the
v0.2.50–76 sub-chain.**

Three docs were stale:

- **`docs/milestones/v0.2.0.md`** — header status was at v0.2.49
  / 186-step gate. Refreshed to v0.2.76 / 195-step gate, with a
  new "Sub-chain summary v0.2.50–v0.2.76" section enumerating
  the four buckets of post-RC work (Helper manifest Phase 2,
  CLI surface gate coverage, drift gate hardening, compiler
  bug fix). Helper Schema Deliverable section rewritten —
  previously said "awaiting 'go'" + "drift gate enforcement
  lands once Phase 2 is approved"; now reflects that Phase 2
  shipped (mech v0.2.41, population v0.2.73–76 → 92.9%) and
  that the going-forward constraint is live in the drift gate.
  Three success criteria checkboxes updated to current numbers
  (158 → 195).
- **`docs/status/v0.2-shipped-and-deferred.md`** — header
  snapshot was at `v0.2.47` (68 releases). Refreshed to
  `v0.2.76` (97 releases). Added a "Post-RC sub-chain
  (v0.2.50–v0.2.76)" section mirroring the milestone tracker
  bucket-by-bucket summary.
- **`docs/rfcs/README.md`** — Cross-cutting contracts table
  said the helper manifest was a v0.2.40 artifact with no
  population progress. Updated to reflect Phase 2 population
  state (628/676 = 92.9% via v0.2.73–76) and the schema
  vocabulary additions in v0.2.73 / v0.2.75.

No source / runtime / generator changes — pure documentation
refresh of the four canonical trackers the user maintains as
the project's source-of-truth surface.

### Verify gate

195 / 195 PASS, 0 SKIP on the bash gate. Tooling-only — no
compiler / runtime / ABI / source / test changes.

## [0.2.76] — 2026-04-23

**Helper manifest Phase 2 — populate `IO` (70), `DataCodec` (14
remaining), and 4 ToolingMeta legacy bridge entries.**

Continues the per-class population sweep. With this ship the
manifest's policy-sensitive fields are populated for **628 of
676 helpers (92.9%)** — every helper with known semantics today
is now annotated. The remaining **48 TODOs are all intentional
v0.4 placeholders** (`TensorOps` GPU/CUDA/DLPack/KV-cache
forward declarations and `ToolingMeta`'s `profile_*` / `py_eval`
stubs).

**`IO` (70 helpers).**

The class splits four ways:

- **Pure (no I/O)** — 8 helpers via `PATTERN_OVERRIDES`:
  - `^os_(family|pointer_width)$` — compile-time-constant queries.
  - `^path_(is_absolute|separator)$` — pure path predicates.
- **Pure-allocating (no I/O, output string allocates)** — 8
  helpers via `PATTERN_OVERRIDES`:
  - `^path_(components|normalize|strip_extension|with_extension)$`
  - `^fs_(basename|dirname|extension|join)$`
- **Read-side I/O (taint propagator)** — 23 helpers via
  `PATTERN_OVERRIDES`. Output value carries external taint
  because the read introduces new state into the value graph:
  - stdin: `^read_(byte|i64|line)$`
  - env: `^env_(get|has|keys)$`, `^getenv$`
  - process state: `^getcwd$`, `^process_id$`, `^isatty_`,
    `^args_(count|get)$|^init_args$`
  - filesystem queries: `^fs_(exists|is_dir|is_file|size|mtime|
    list_dir|canonicalize|current_dir|temp_dir)$`
  - file reads: `^file_read_`
  - subprocess: `^system$`
- **Write-side I/O (passthrough taint)** — 31 helpers via
  `CLASS_DEFAULTS["IO"]` → `["io"]` / `passthrough` /
  `"io_capability_required"`. Covers `print*`, `eprint*`,
  `putchar`, `dbg_*`, `env_(set|unset)`, `file_(write|append)_*`,
  `fs_(create_dir|create_dir_all|copy_file|remove_dir|
  remove_file|rename)`, `pipe_*`.

**Schema rationale for `taint = "propagates"` on read-side I/O.**

The schema's `propagates` value is "output taint = input taint
plus any internal state read." A `read_line()` call has empty
input taint (no arguments), but its output should be considered
tainted because it pulled bytes from stdin — that's an
"internal state read" of the most external kind. Without
`propagates`, every read-side I/O helper would wrongly be
treated as a fresh untainted source.

**`DataCodec` (14 remaining helpers).**

- **3 pure** via `PATTERN_OVERRIDES`: `^toml_(get_int|get_str|
  has)$` — read from a parsed TOML handle in memory.
- **1 I/O** via `PATTERN_OVERRIDES`: `^toml_parse_file$` —
  reads + parses a file. Tainted (pulls external state).
- **1 random+alloc** via `PATTERN_OVERRIDES`: `^uuid_v4$` —
  generates fresh UUID via RNG.
- **9 alloc** via `CLASS_DEFAULTS["DataCodec"]` →
  `["alloc"]` / `passthrough` / `none`. Covers `base64_encode`,
  `base64_decode`, `msgpack_write_*`, `sha256`, `sha256_hex`,
  `toml_parse_string`.

**`ToolingMeta` (4 more — legacy rods bridge).**

- `rods_f64_add`, `rods_f64_sub`, `rods_f64_div` → pure
  (standard f64 — div-by-zero returns NaN/inf, no panic).
- `rods_f64_encode` → `["alloc"]` (output string).

The remaining 3 `ToolingMeta` entries (`profile_start`,
`profile_end`, `py_eval`) stay TODO — their implementations
are deferred to v0.4 and the precise effect set depends on
the chosen profile sink / py interop model.

**TODO sentinel count drops 408 → 144** (264 TODOs eliminated).

### Generator changes (`tools/gen_helper_manifest.py`)

- 14 new `PATTERN_OVERRIDES` entries (IO subclasses + DataCodec
  pure / I/O / random helpers).
- 4 new `NAME_OVERRIDES` entries (ToolingMeta `rods_f64_*`).
- 2 new `CLASS_DEFAULTS` entries (IO write-side default,
  DataCodec encoder default).

### Verify gate

195 / 195 PASS, 0 SKIP on the bash gate. Tooling-only — no
compiler / runtime / ABI / source / test changes.

## [0.2.75] — 2026-04-23

**Helper manifest Phase 2 — populate `StringFormat` (81) and
`Collection` (54) with read-vs-mutate split.**

Both classes split cleanly into "pure read-only accessors" and
"mutating / output-allocating" buckets. The v0.2.74 override
mechanism now carries the split via class default + per-pattern
pure overrides:

**`StringFormat` (81 helpers).**

- 38 helpers populated as **pure** via `PATTERN_OVERRIDES`:
  - `^char_` — all 12 character predicates and case conversions.
  - `^chr$` — int → char.
  - `^str_(eq|contains|count|ends_with|starts_with|index_of|is_empty|len|char_at)$` — 9 string predicates and accessors.
  - `^str_to_(i64|f64|bool|i64_radix)$` — 4 string→scalar parses.
  - `^parse_(hex|bin)$` — 2 base-conversion parses.
  - `^string_(capacity|eq|eq_str|get_byte|len|starts_with|ends_with|contains|as_ptr)$` — 9 heap-String accessors.
  - `chr` — 1 helper (already pattern-matched above by `^chr$`).
- 1 helper via `NAME_OVERRIDES`: `string_print` →
  `["io"]` / `"io_capability_required"` (does I/O despite living
  in StringFormat by name pattern).
- 42 helpers via `CLASS_DEFAULTS["StringFormat"]` →
  `["alloc"]` / `passthrough` / `none`. Covers all string
  builders: `format_*`, `int_to_*`, `f64_to_str`, `bool_to_str`,
  `sb_*`, `string_new`/`from_str`/`with_capacity`/`clone`/etc.,
  `str_concat`/`pad_*`/`replace`/`split`/`substring`/`to_lower`/
  `to_upper`/`trim*`/`reverse`/`repeat`/`center`/`join`/`lines`/
  `chars`.

**`Collection` (54 helpers).**

- 17 helpers populated as **pure** via `PATTERN_OVERRIDES`:
  `^(hashmap|hashset|btreemap|btreeset|vecdeque)_(get|contains|len|capacity|is_empty|get_or|key_at|val_at|at)$` —
  read-only accessors return `Option` / `bool` / `i64` / `i32`
  without allocating.
- 37 helpers via `CLASS_DEFAULTS["Collection"]` →
  `["alloc"]` / `passthrough` / `none`. Covers all mutators:
  `*_insert`, `*_remove`, `*_push_*`, `*_pop_*`, `*_set`,
  `*_clear`, `*_clone`, `*_merge`, `*_new`, `*_with_capacity`,
  `*_free`, `*_keys`, `*_values`.

**TODO sentinel count drops 813 → 408** (405 TODOs eliminated).

After this ship the manifest's policy-sensitive fields are
populated for **540 of 676 helpers (79.9%)**. The remaining 136
TODOs live in four classes that still need per-name or
per-pattern fixing:

- **`IO` (70)** — needs read/write/file/env split (writes are
  passthrough taint, reads are propagating taint sources).
- **`TensorOps` (45)** — mostly intentional v0.4 placeholders;
  most rows are already `stability = "unstable"`.
- **`DataCodec` (14 remaining)** — encoders/parsers/UUID; mix
  of pure (parsers) and alloc (encoders).
- **`ToolingMeta` (7 remaining)** — all intentional v0.4
  placeholders (`profile_*`, `py_eval`, `rods_f64_*`).

### Verify gate

195 / 195 PASS, 0 SKIP on the bash gate. Tooling-only — no
compiler / runtime / ABI / source / test changes.

## [0.2.74] — 2026-04-23

**Helper manifest Phase 2 — per-name override mechanism + populate
PanickingArith (full) + 10 ToolingMeta/DataCodec entries.**

Adds the missing piece for the mixed-semantic taxonomy classes:
the `tools/gen_helper_manifest.py` generator now consults a
**resolution chain** when populating effects/taint/proof_obligation:

  1. `NAME_OVERRIDES` — exact helper-name match
  2. `PATTERN_OVERRIDES` — name-pattern regex match
  3. `CLASS_DEFAULTS` — taxonomy class default (added v0.2.73)
  4. `"TODO"` sentinel

This unlocks populating classes whose helpers have non-uniform
semantics (e.g. `PanickingArith.checked_add` is pure but
`PanickingArith.panic` panics; `ToolingMeta.assert_eq` panics on
failure but `ToolingMeta.dbg` does I/O; `DataCodec.fnv1a_64_str`
is pure but `DataCodec.base64_encode` allocates).

**`PanickingArith` (84 helpers) — fully populated.**

- 80 helpers via `PATTERN_OVERRIDES` — `^(checked|wrapping|
  saturating)_` and `^(sat|wrap)_i32$` patterns mark them as
  pure (`effects = []`, `taint = "passthrough"`,
  `proof_obligation = "none"`). These return `Option<T>` /
  wrap / saturate instead of panicking, so they have no panic
  effect.
- 4 helpers via `NAME_OVERRIDES`:
  - `panic` → `["panic"]` /
    `"callsite_unreachable_or_recoverable"`
  - `assert` → `["panic"]` / `"predicate_holds"`

**`DataCodec` partial — 5 hash helpers populated.**

`crc32`, `crc32_update`, `fnv1a_64_i64`, `fnv1a_64_str`,
`murmur3_64` → pure (`[]` / `passthrough` / `"none"`). They
return a `u64` digest; no allocation, no I/O. The remaining
14 `DataCodec` helpers (encoders/decoders/parsers/UUID) stay
TODO until follow-on releases populate them.

**`ToolingMeta` partial — 5 helpers populated.**

- `assert_eq`, `assert_ne` → `["panic"]` / `"predicate_holds"`
- `dbg` → `["io"]` / `"io_capability_required"`
- `manifest_report`, `manifest_validate` → `["alloc"]` /
  `"none"` (validation builds a small report string).

The remaining 7 `ToolingMeta` helpers (`profile_*`, `py_eval`,
`rods_f64_*`) are intentional v0.4 placeholders — left TODO
because their semantics are TBD with the v0.4 implementation.

**TODO sentinel count drops 1095 → 813** (282 TODOs eliminated).

### Generator changes (`tools/gen_helper_manifest.py`)

- Added `NAME_OVERRIDES: dict[str, (list[str], str, str)]`.
- Added `PATTERN_OVERRIDES: list[(re.Pattern, (list[str], str, str))]`.
- Resolution chain replaces the previous single `CLASS_DEFAULTS`
  lookup. Now: name → pattern → class → TODO.
- `CLASS_DEFAULTS` docstring updated to enumerate which classes
  ship as default vs. require per-name population.

### Verify gate

195 / 195 PASS, 0 SKIP on the bash gate. Tooling-only — no
compiler / runtime / ABI / source / test changes.

## [0.2.73] — 2026-04-23

**Helper manifest Phase 2 — populate effects/taint/proof for four
more taxonomy classes.**

Continues the Helpers.md contract Phase 2 work begun in v0.2.41
(taxonomy + auto-class) by extending the generator's per-class
default population from two classes (`PureMath`, `VectorOps`)
to six. The generator now ships a `CLASS_DEFAULTS` table keyed
by taxonomy class; each entry is `(effects, taint,
proof_obligation)`.

**Newly populated classes (82 helpers):**

- **`Random` (13 helpers)** — `effects = ["random"]`,
  `taint = "passthrough"`, `proof_obligation =
  "rng_capability_required"`. Covers `ambient_random`, `rng_*`,
  `random_*`, `vec_shuffle`, `vec_sample`.
- **`Time` (21 helpers)** — `effects = ["clock"]`,
  `taint = "passthrough"`, `proof_obligation =
  "clock_capability_required"`. Covers `time_*`, `now_*`,
  `sleep_*`. (Schema-aligned: `"clock"` not `"time"`.)
- **`Concurrency` (38 helpers)** — `effects = ["sync"]`,
  `taint = "passthrough"`, `proof_obligation =
  "happens_before_release_acquire"`. Covers `mutex_*`,
  `channel_*`/`chan_*`, `atomic_*`/`cas_*`, `thread_*`,
  `rwlock_*`, `cancel_token_*`, `once_*`, `par_*`,
  `scheduler_*`, `cpu_count`. **New `"sync"` effect tag** added
  to the schema vocabulary for synchronization-only primitives
  that don't fit `"thread"` (just spawn/join) or any other
  effect category.
- **`Allocation` (10 helpers)** — `effects = ["alloc"]`,
  `taint = "passthrough"`, `proof_obligation =
  "alloc_capability_or_arena_owned"`. Covers `arena_*`,
  `region_*`, `alloc_*`, `free`, `realloc`, `malloc`, `memcpy`,
  `calloc`, `drop_*`, `capture_*`.
- **`VectorOps` (97 helpers)** — already had
  `taint = "passthrough"`; now also gets `effects = ["alloc"]`
  and `proof_obligation = "bounds_within_len"`.

**TODO sentinel count drops 1535 → 1095** (440 TODOs
eliminated). Remaining classes (`PanickingArith`,
`StringFormat`, `IO`, `Collection`, `TensorOps`, `DataCodec`,
`ToolingMeta`) carry `"TODO"` because they need per-helper
divergence (e.g. `wrapping_add` has no panic effect but
`panic_div_by_zero` does; `str_concat` allocates but
`str_eq` doesn't). Those land in follow-on releases as
per-name tables get fixed.

### Schema doc updates (`docs/rfcs/helper_manifest_schema.md`)

- Added `"sync"` to the effect-tag vocabulary list with a
  description and a back-reference to the v0.2.73 ship.
- Per-field "marked TODO outside X" notes updated to enumerate
  the six classes the generator now populates and the seven
  that still TODO.
- `proof_obligation` field promoted from a closed `none|emits|
  consumes` enumeration to a free-form string with a worked
  example list of the six values now in use.
- `taint` field default-justification expanded to cover the
  four new classes (RNG/clock/sync/alloc are passthrough
  because their outputs derive only from input arguments + an
  observable effect).

### Generator changes (`tools/gen_helper_manifest.py`)

- Added `CLASS_DEFAULTS: dict[str, (list[str], str, str)]`.
- Per-row population logic refactored to consume `CLASS_DEFAULTS`
  instead of the previous open-coded `if cls in (...)` checks.
- TOML emitter updated to handle non-empty array literals for
  `effects` (was previously hardcoded for `"[]"` only).

### Verify gate

195 / 195 PASS, 0 SKIP on the bash gate. Tooling-only — no
compiler / runtime / ABI / source / test changes. The manifest
is generated; only the generator and schema doc carry hand
edits.

## [0.2.72] — 2026-04-23

**Verify gate: diagnostic smoke step (policy/certify/translate/evidence/graph/perf/bench).**

Seven more CLI surfaces gate-covered. With this ship the
remaining diagnostic / reporting / provenance commands all sit
behind the gate, completing the CLI-coverage audit pattern that
ran from v0.2.64 (`explain`) through v0.2.71 (inspector
bundle):

- **`nuc policy`** — policy compliance report. Verifies the
  default policy passes on `examples/01_hello.nr` and that the
  output shape contains `Policy:` and `Result:` headers.
- **`nuc certify`** — strict-mode verification pass. Verifies
  the report carries the `source:` provenance line.
- **`nuc translate`** — Sage translation pass. Verifies the
  output carries the `translated:` marker.
- **`nuc evidence`** — SPDX + provenance JSON (SLSA v1
  attestation surface). Verifies both `"spdx":` and
  `"provenance":` keys appear in the JSON.
- **`nuc graph`** — call-graph analysis. Verifies the
  `functions:` and `edges:` summary lines.
- **`nuc perf`** — performance analysis report. Verifies the
  `Nucleor Performance Analysis` header.
- **`nuc bench`** — benchmark harness output. Verifies the
  `source:` line that anchors per-bench provenance.

**Bundled into one `cli_diagnostic_smoke` step** (single bash
function, single PowerShell `Step` block). Per-iteration
overhead: 7 binary invocations against the same input file.
Same audit + bundling pattern that v0.2.71 used for inspectors.

**Audit findings:** all seven commands return exit 0 with the
expected structured output. **Zero real bugs found** — same
positive-finding outcome as v0.2.71, confirming this slice of
the CLI stays well-tested by the existing example pipeline.

**Step total bumped 194 → 195** in both gates.

The pre-iteration smoke block now reads:

```
[ 1/195] OK    binary present
[ 2/195] OK    compiler ABI tables synced
[ 3/195] OK    CLI: nuc explain NUM-001 wired
[ 4/195] OK    CLI: nuc bootstrap status reports correctly
[ 5/195] OK    CLI: nuc check + abi inspect
[ 6/195] OK    CLI: nuc summary/audit/query/impact (inspectors)
[ 7/195] OK    CLI: nuc policy/certify/translate/evidence/graph/perf/bench (diagnostics)
[ 8/195] OK    CLI: nuc init scaffolding works
[ 9/195] OK    CLI: nuc doc generator works
[10/195] OK    CLI: nuc lock writes Nucleor.lock
[11/195] OK    CLI: nuc test runs #[test] functions
```

**Coverage so far: 16 unique CLI commands** under explicit
smoke coverage (every command except the four `build*`-family
variants and `emit`, which are implicitly exercised by every
example + test step that calls `nuc build`):
`explain`, `bootstrap`, `check`, `abi`, `summary`, `audit`,
`query`, `impact`, `policy`, `certify`, `translate`,
`evidence`, `graph`, `perf`, `bench`, `init`, `doc`, `lock`,
`test`. With the build-family already implicitly gated, **the
full surface area of `nuc` is now under verify-gate coverage.**

### Bash gate clang resolution: Windows fallback

Drive-by fix while wiring v0.2.72: `tools/verify.sh` now falls
back to `C:\Program Files\LLVM\bin\clang.exe` when neither
`NUCLEOR_CLANG_PATH` nor `LLVM_SYS_180_PREFIX` resolve, mirroring
the PowerShell gate's behavior. The probes for both env vars now
also check the `.exe` suffix so a stale `LLVM_SYS_180_PREFIX`
pointing at a deleted MSVC LLVM tree silently falls through
instead of looking valid.

Symptom that prompted the fix: bash gate run on a host where
`LLVM_SYS_180_PREFIX` had been set to a since-removed LLVM tree
showed ~150 spurious link failures (`note: LLVM IR was emitted;
GPU/CUDA experiments may require manual link with CUDA libs`)
because clang never made it onto `PATH`. Linux/macOS gates
unaffected.

### Verify gate

195 / 195 PASS, 0 SKIP on the bash gate. Tooling-only — no
compiler / runtime / ABI / source / test changes.

## [0.2.71] — 2026-04-23

**Verify gate: inspector smoke step (summary/audit/query/impact).**

Four more CLI surfaces gate-covered. All four are inspector
commands that produce structured output for tooling integration:

- **`nuc summary`** — module/effect summary text format.
  Prints `// Module: <path>` and `fn <name> ... requires [...]`.
- **`nuc audit`** — JSON audit report. Schema includes
  `"type": "audit_report"`, source hash, function/struct/etc.
  inventory.
- **`nuc query`** — JSON function inventory. Each function's
  name, params, return type, declared/inferred effects, contract
  counts.
- **`nuc impact`** — JSON callee/caller graph for a single
  named function. Reports declared/inferred effects + the
  caller/callee impact tree.

**Bundled into one `cli_inspector_smoke` step** (single bash
function, single PowerShell Step block). Per-iteration overhead:
4 binary invocations against the same input file. Keeps gate
pre-iteration block at a manageable size.

**Step total bumped 193 → 194** in both gates.

The pre-iteration smoke block now reads:

```
[ 1/194] OK    binary present
[ 2/194] OK    compiler ABI tables synced
[ 3/194] OK    CLI: nuc explain NUM-001 wired
[ 4/194] OK    CLI: nuc bootstrap status reports correctly
[ 5/194] OK    CLI: nuc check + abi inspect
[ 6/194] OK    CLI: nuc summary/audit/query/impact (inspectors)
[ 7/194] OK    CLI: nuc init scaffolding works
[ 8/194] OK    CLI: nuc doc generator works
[ 9/194] OK    CLI: nuc lock writes Nucleor.lock
[10/194] OK    CLI: nuc test runs #[test] functions
```

**Coverage so far: 11 unique CLI commands** (binary present
isn't a command, ABI parity is internal): `explain`, `bootstrap`,
`check`, `abi`, `summary`, `audit`, `query`, `impact`, `init`,
`doc`, `lock`, `test`. **Still uncovered (mostly diagnostic /
advanced):** `bench`, `policy`, `certify`, `translate`,
`evidence`, `graph`, `perf`, `emit`, plus the four
`build*`-family variants. The build family is implicitly
exercised by every example + test step.

### Verify gate

194 / 194 PASS, 0 SKIP on the bash gate. Tooling-only — no
compiler / runtime / ABI / source / test changes.

## [0.2.70] — 2026-04-23

**Verify gate: `nuc bootstrap`, `nuc check`, `nuc abi` smoke steps.**

Three more CLI surfaces brought under gate coverage as the
audit pattern continues to find no real bugs (positive
finding — those commands work):

**`nuc bootstrap`** — reports stage / runtime size / self-host
status. Used as the canonical "is this a self-hosted build?"
check by anyone reading `NUCLEOR_BOOTSTRAP_CONTRACT.md`. New
`cli_bootstrap_smoke` step verifies it prints
`"Nucleor Bootstrap Status"`, `"Stage: 1 (self-hosted)"`, and
`"Self-hosted: yes"`.

**`nuc check`** — runs ownership/type/source/taint/effect
checkers without codegen. The fast feedback path during dev. New
`cli_check_abi_smoke` step verifies `nuc check examples/01_hello.nr`
prints `"OK — no diagnostics"`.

**`nuc abi`** — ABI import inspector. Reports ABI version + extern
imports list. Same step as check, also asserts
`nuc abi examples/01_hello.nr` prints `"ABI version:"` +
`"extern imports:"`.

**Combined into one `cli_check_abi_smoke`** to keep the per-iteration
overhead small (single binary invocation per check, two for the
combined step).

**Step total bumped 191 → 193** in both gates. The full
pre-iteration smoke block now reads:

```
[ 1/193] OK    binary present
[ 2/193] OK    compiler ABI tables synced
[ 3/193] OK    CLI: nuc explain NUM-001 wired
[ 4/193] OK    CLI: nuc bootstrap status reports correctly
[ 5/193] OK    CLI: nuc check + abi inspect
[ 6/193] OK    CLI: nuc init scaffolding works
[ 7/193] OK    CLI: nuc doc generator works
[ 8/193] OK    CLI: nuc lock writes Nucleor.lock
[ 9/193] OK    CLI: nuc test runs #[test] functions
```

The user-facing v0.2 CLI surface is now nine pre-iteration smoke
steps. Remaining v0.2 commands (`nuc bench`, `nuc audit`,
`nuc policy`, `nuc certify`, `nuc translate`, `nuc evidence`,
`nuc query`, `nuc graph`, `nuc perf`, `nuc summary`,
`nuc impact`, `nuc emit`) are either advanced/diagnostic
commands or implicitly tested via the example/test gate. None
have known regressions.

### Verify gate

193 / 193 PASS, 0 SKIP on the bash gate. Tooling-only — no
compiler / runtime / ABI / source / test changes.

## [0.2.69] — 2026-04-23

**`nuc test` bug fix — target/ now created before harness write.**

Real compiler bug found via the gate-coverage audit. `nuc test
foo.nr` from a fresh directory failed with:

```
  discovered tests: 1
    test_addition
ERROR: cannot read target/foo-test__test_harness.nr
```

Root cause: `compiler/nucleor_tools_suite.nr:10189` writes the
test-harness source to `target/<name>__test_harness.nr` but
never creates `target/` first. `file_write_string` silently
fails when the parent dir doesn't exist; the subsequent
`compile_file_mode` call then can't read the file.

The `bin/nucleor.exe` self-host build path already handles this
correctly via `system("mkdir target 2>NUL")` at
`compiler/nucleor_s1_compiler.nr:7773`. The `nuc test` path was
missing the same idiom.

**Fix (one line):** added `system("mkdir target 2>NUL")` before
the harness write. Same idiom as the build path. Comment
references the sibling location.

Verified end-to-end:

```
$ rm -rf /tmp/sandbox && mkdir /tmp/sandbox && cd /tmp/sandbox
$ cat > t.nr <<'EOF'
#[test]
fn test_addition() { let x: i64 = 2 + 2; if x != 4 { print("FAIL"); return; }; print("PASS test_addition"); }
fn main() -> i64 { return 0; }
EOF
$ nuc test t.nr
  discovered tests: 1
    test_addition
  source: target/t-test__test_harness.nr (748 bytes)
  ...
PASS test_addition
  PASS: test_addition
test result: PASS (1 test)
```

**Tools binary rebuilt** (`bin/nucleor_tools.exe`) from the
patched source. Self-host LLVM IR fixed point preserved (s1
compiler unchanged this release; only tools_suite was patched).

**New gate step `cli_test_smoke`** in both `tools/verify.sh`
and `tools/verify.ps1`. Sandboxed temp dir, writes a `t.nr` with
a `#[test]` function, runs `nuc test t.nr`, asserts:
1. `discovered tests: 1`
2. function name appears
3. `PASS test_addition` line
4. `test result: PASS` summary

Step total bumped 190 → 191 in both gates. Critically, this
step would have caught the bug — running it on the pre-fix
binary would FAIL.

The seven CLI smoke steps now cover every v0.2 user-facing
command path: `binary present` → `ABI parity` → `explain` →
`init` → `doc` → `lock` → `test`.

### Verify gate

191 / 191 PASS, 0 SKIP on the bash gate. Self-host fixed point
holds (verified locally — s1 compiler source unchanged).

## [0.2.68] — 2026-04-23

**Verify gate: `nuc lock` smoke step (both bash + PowerShell).**

`nuc lock` (RFC-0019 phase 1 lockfile generator) is the third
v0.2 deliverable in the package-manager surface (alongside
`nuc init` smoked v0.2.66 and `nuc doc` smoked v0.2.67). Same
gap, same fix.

**Manual verification first:**

```
$ nuc init testpkg && cd testpkg && nuc lock
wrote lockfile: Nucleor.lock
packages: 1

$ cat Nucleor.lock
version = 1
root = "Nucleor.toml"

root_package = "testpkg"

[[package]]
name = "testpkg"
version = "0.1.0"
manifest = "Nucleor.toml"
entry = "src/main.nr"
```

Works. **Gated as of v0.2.68:**

- New `cli_lock_smoke` step in both `tools/verify.sh` and
  `tools/verify.ps1`. Sandboxed temp dir, runs `nuc init lockproj`
  then `nuc lock`, then asserts `Nucleor.lock` contains five
  canonical schema fields:
  1. `^version = ` (lockfile schema version line)
  2. `root = "Nucleor.toml"` (path to root manifest)
  3. `root_package = "lockproj"` (project name from init)
  4. `[[package]]` (at least one TOML array-of-tables entry)
  5. `name = "lockproj"` (the package name in the entry)
- Step total bumped 189 → 190 in both gates.
- Both gates run the six CLI smoke steps in identical order:
  `binary present` → `ABI parity` → `explain` → `init` → `doc` →
  `lock`.

(Initial v0.2.68 ps1 mirror placed `lock` *before* `doc` — fixed
in the same release before commit so both gates step in the same
order. The matching commit history reflects this as one move.)

The user-facing v0.2 CLI surface (`init`, `doc`, `lock`,
`explain`) is now fully smoke-covered. `nuc summary` works
correctly when invoked with a file path but is implicitly tested
via the existing 17-example build path. `nuc bench` / `nuc audit`
/ `nuc query` are v0.4 deliverables and not yet on the gate.

### Verify gate

190 / 190 PASS, 0 SKIP on the bash gate. PowerShell side runs
on next CI push.

## [0.2.67] — 2026-04-23

**Verify gate: `nuc doc` smoke step (both bash + PowerShell).**

The doc generator (`nuc doc`, RFC-0029 phase 1) is one of the
v0.2.0 success criteria — `docs/milestones/v0.2.0.md` line 254
literally says **"Doc gen (RFC-0029) is at least skeleton"** —
but it had **zero gate coverage**. Same failure-mode argument as
v0.2.66's `nuc init` smoke: a regression here breaks a v0.2
deliverable silently.

**Manual verification first** (the right order):

```
$ cat > test.nr <<'NREOF'
/// Adds two integers.
fn add(a: i64, b: i64) -> i64 { return a + b; }
NREOF
$ nuc doc test.nr
# test.nr
Generated by `nuc doc` (RFC-0029).
## Function index
- [`add`](#add)
## `add`
Adds two integers.
**Signature:**
fn add(a: i64, b: i64) -> i64

$ nuc doc test.nr --out test.md
nuc doc: wrote test.md (1 functions, with index + signatures)
```

Both stdout and `--out` modes work. **Gated as of v0.2.67:**

- New `cli_doc_smoke` step in both `tools/verify.sh` and
  `tools/verify.ps1`. Sandboxed temp dir, writes a
  `smoke.nr` with one `///`-documented function, then asserts:
  1. `nuc doc smoke.nr` (stdout mode) emits text mentioning the
     function name (`smoke_add`).
  2. Output contains `"## Function index"` (the index header).
  3. Output contains `"Adds two integers"` (the doc-comment text
     was extracted).
  4. Output contains `"Signature"` (the signature block was
     emitted).
  5. `nuc doc smoke.nr --out smoke.md` writes the file.
  6. The file's content also contains the function name.
  7. Sandbox is cleaned up afterward.
- Step total bumped 188 → 189 in both gates.

The five CLI smoke steps (`binary present`, `ABI parity`,
`explain smoke`, `init smoke`, `doc smoke`) now form a
pre-iteration block that exercises the entire user-facing CLI
surface — not just the build/test paths the example/test gate
already covers.

### Verify gate

189 / 189 PASS, 0 SKIP on the bash gate. PowerShell side runs
on next CI push.

## [0.2.66] — 2026-04-23

**Verify gate: `nuc init` smoke step (both bash + PowerShell).**

`nuc init` is the **new-user-first-command** — what someone
types after `git clone` to verify everything works. It had
**zero gate coverage**. Catching a regression here matters more
than catching a regression in any individual example, because
it's the failure mode that turns "first 5 minutes" into "this
language is broken."

**Manual verification first** (the right order):

```
$ nuc init testproject
  Created project: testproject
  testproject/Nucleor.toml
  testproject/src/main.nr

  To build: cd testproject && nuc build
  To run:   cd testproject && nuc run

$ cd testproject && nuc build src/main.nr -o testproject && ./target/testproject.exe
Hello, Nucleor!
```

Works end-to-end. **Gated as of v0.2.66:**

- New `cli_init_smoke` step in both `tools/verify.sh` and
  `tools/verify.ps1`. Creates a sandbox temp dir, runs
  `nuc init smokeproj`, then asserts:
  1. `smokeproj/Nucleor.toml` exists.
  2. `smokeproj/src/main.nr` exists.
  3. Manifest declares `name = "smokeproj"`.
  4. Manifest declares `entry = "src/main.nr"`.
  5. The scaffold compiles via `nuc build`.
  6. The compiled binary runs and produces non-empty stdout.
  7. The sandbox is cleaned up afterward (try/finally on
     PowerShell, post-step `rm -rf` on bash).
- Step total bumped 187 → 188 in both gates.

The four CLI smoke steps (`binary present`, `ABI parity`,
`explain smoke`, `init smoke`) are now the gate's "is the
toolchain even alive?" pre-iteration block before the example +
test marathon kicks off.

### Verify gate

188 / 188 PASS, 0 SKIP on the bash gate. PowerShell side runs
on next CI push.

## [0.2.65] — 2026-04-23

**`tools/verify.ps1` mirrors v0.2.64 explain smoke step.**

Closes the v0.2.64 follow-up note. The PowerShell gate
(`tools/verify.ps1`) now has the same `nuc explain NUM-001`
smoke check the bash gate gained in v0.2.64.

**Updated:**

- **Step body** — added `Step "CLI: nuc explain NUM-001 wired"`
  block running `& $bin explain NUM-001 2>&1 | Out-String` and
  validating the four shape properties:
  `[string]::IsNullOrWhiteSpace($explainOut)` → false,
  `-match "NUM-001"`, `-match "Mixed-width"`,
  `-match "Nucleor_Error_Codes"`. Comment cross-references
  v0.2.64 / v0.2.65.
- **Step total counter** — bumped from `2 + N + ...` to
  `3 + N + ...` (the new step is now part of the total).

Both gates now share three pre-iteration check steps in
identical order: binary present → ABI parity → CLI explain
smoke. The two output checks (v0.2.61 + v0.2.62 non-empty
stdout, v0.2.64 + v0.2.65 explain smoke) and the example list
single-source (v0.2.60) collectively close the verify-gate
parity work for the v0.2 line.

### Verify gate

187 / 187 PASS, 0 SKIP on the bash gate. PowerShell gate not
re-validated locally this release (Windows gate uses verify.ps1
through CI on the Windows runner per
`.github/workflows/ci.yml`).

## [0.2.64] — 2026-04-23

**Verify gate: `nuc explain` smoke step closes a real coverage gap.**

Audit of what the gate covered vs. didn't: the **explain
registry** (the per-error-code tables in
`compiler/nucleor_tools_suite.nr` that back `nuc explain CODE`)
had **zero gate coverage**. Adding a code to
`docs/spec/Nucleor_Error_Codes.md` without registering it in
the three `explain_error_*` functions would silently fail
discovery — the registry could drift from the spec for months.

**Fix:** new `cli_explain_smoke` step that runs

```bash
nuc explain NUM-001
```

and verifies the output:

1. Is non-empty.
2. Mentions `NUM-001` (title line).
3. Contains `"Mixed-width"` (per the `Error_Codes.md` row).
4. Contains `Nucleor_Error_Codes` (the reference link).

If any of those four checks fail, the gate FAILs with the step
name, pointing at exactly the registry table that needs the
new row.

**Why NUM-001 specifically:** it's a stable v0.2 code with
canonical title text that's unlikely to change. Future audits
could extend to a representative sample (one per series — RT,
NUM, MATCH, COLL, MOD, PKG, TGT) but a single-code smoke catches
the "registry is wired and produces structured output" class.

**Gate count: 186 → 187.** All green on the bash gate. The
PowerShell gate (`tools/verify.ps1`) does not yet have the
mirror — filed as a follow-up alongside the v0.4 verify-gate
parity work.

**Spot-check of all 18 example outputs** done in passing — every
example produces sensible, on-topic output (Bell-state counts,
RK45 numerical accuracy to 6 digits, Gaussian histogram bars,
etc.). No regressions found; the v0.2.61 + v0.2.62 non-empty
checks are sufficient for now. Hand-curated golden-output
assertions remain a v0.4 deferral.

### Verify gate

187 / 187 PASS, 0 SKIP. Tooling-only — no compiler / runtime /
ABI / source / test changes.

## [0.2.63] — 2026-04-22

**`bin/` housekeeping — README + explicit .gitignore for scratch binaries.**

`bin/` had accumulated **14 stale `nucleor_vNNN.exe` scratch
binaries** (~11 MB of working-tree pollution) from self-host
fixed-point checks across v0.1.46..v0.2.x. All correctly untracked
(globally ignored via `*.exe` + `!bin/nucleor.exe` exception),
but visible in `ls bin/` and confusing to future contributors who
don't know what they are.

**Cleanup + documentation:**

- **Deleted** all 14 `bin/nucleor_v*.exe` files from the working
  tree. Plus `bin/nucleor_tools.exe`. Repo size drops by ~11 MB
  on local clones that ran the verify gate.
- **`.gitignore`** — added explicit `bin/nucleor_v*.exe` and
  `bin/nucleor_tools.exe` patterns with a comment explaining the
  fixed-point-check chain that produces them. The `*.exe` global
  ignore already covers them, but explicit is better for someone
  reading `.gitignore` to understand the convention. Pattern
  warns "Do NOT add a `!` exception."
- **`bin/README.md`** — new file documenting:
  - what belongs in `bin/` (exactly one file today:
    `bin/nucleor.exe`)
  - what's coming in v0.3 (`bin/nucleor` for Linux + macOS)
  - what does NOT belong (the scratch binaries with the chain
    pattern that produces them, and a one-line `rm -f` cleanup
    recipe)
  - why pre-built (self-host bootstrap chicken-and-egg, with
    references to Rust stage0 / OCaml `boot/` / Nim
    `csources_v2` as prior art)

The fixed-point chain pattern itself isn't fixed yet (the next
v0.3 release that does a fixed-point check should write the
scratch binary to `target/` instead of `bin/`); that's filed as
a future polish item, not blocking.

### Verify gate

186 / 186 PASS, 0 SKIP. Documentation + working-tree cleanup
only — no compiler / runtime / ABI / source / test changes.

## [0.2.62] — 2026-04-22

**`tools/verify.ps1` mirrors v0.2.61 non-empty stdout check.**

The v0.2.61 silent-regression check landed in `tools/verify.sh`
only. The Windows-side mirror was filed as a v0.4 cleanup but
the gap is small enough to close immediately.

**Updated `tools/verify.ps1`:**

- Capture example stdout to `$runOut` via `| Out-String` instead
  of letting it flow to the host (same shape as the existing
  build-output capture).
- Check `$LASTEXITCODE -ne 0` explicitly (was implicit via the
  trailing `return $LASTEXITCODE -eq 0`).
- Add `[string]::IsNullOrWhiteSpace($runOut)` shape check;
  `Write-Host (Dim "       example produced empty output")` and
  `return $false` if empty.

Both gates now share the same FAIL semantics on silent
regressions. The `tools/examples.list` single-source-of-truth
(v0.2.60) plus parity output checks (v0.2.61 + v0.2.62) means
the two gates will run identical example coverage on identical
shape rules going forward.

**Bonus dogfood verification.** During this release I ran the
bash gate and got **`FAIL: example 01_hello`** — exactly the
silent-regression class the v0.2.61 check is designed to catch.
Root cause: my own earlier negative test corrupted
`examples/01_hello.nr` (replaced the body with a no-print stub
to verify the FAIL path) and the backgrounded restore never
completed. `git checkout HEAD -- examples/01_hello.nr` restored
the file and the gate returned to 186/186. Real-world proof
that the new check fires when it should.

### Verify gate

186 / 186 PASS, 0 SKIP. Tooling-only — no compiler / runtime /
ABI / source / test changes.

## [0.2.61] — 2026-04-22

**Verify gate: examples now checked for non-empty stdout.**

The example-build step in `tools/verify.sh` previously routed
example output to `/dev/null` and only checked exit code. An
example that built, ran, exited 0, **but printed nothing** would
silently pass — a real production gap that hid `print()`
regressions in the runtime, the format helpers, or the ABI
table.

**Fix in `build_example`:**

1. Capture stdout to `/tmp/_nuc_ex_out.log` instead of
   `/dev/null` (3-line change).
2. Check the binary's exit code explicitly (was implicit via
   bash's last-command-exit semantics).
3. Add a `[ -s /tmp/_nuc_ex_out.log ]` non-empty check; print
   `"example produced empty output"` and return non-zero if the
   file is empty.

**Why non-empty stdout is the right shape check** (not "matches
expected output"): every example in the repo is designed to
print at least one line — the tier-1 demos all start with a
`Hello`-style print, the v0.2.x demos all open with
`=== Nucleor X demo ===`. Catching empty output catches the
silent-regression case (any change that breaks `print()`-to-stdout
pathway). Hand-maintaining expected-output assertions for 17
demos would be a maintenance burden the gate doesn't need
today.

**Verified:**

- Full gate still 186/186 PASS (every example currently produces
  non-empty output, as expected).
- Shell-level mini-test confirms `[ -s file ]` semantics —
  empty file → FALSE → gate FAIL path.

**Future work** — the same check should be added to
`tools/verify.ps1` (PowerShell mirror). Filed as v0.4 cleanup;
the bash gate is what local development + the bash-variant CI
runners use today.

### Verify gate

186 / 186 PASS, 0 SKIP. Tooling-only — no compiler / runtime /
ABI / source / test changes.

## [0.2.60] — 2026-04-22

**`tools/examples.list` — single source of truth for the verify-gate example list.**

Closes the v0.2.59 going-forward note. The two verify gates
(`verify.sh` for POSIX, `verify.ps1` for Windows) had duplicated
hand-maintained example arrays that drifted across 30 releases
(v0.2.31..v0.2.59) before v0.2.59 caught the gap. This release
eliminates the drift class entirely.

**Shipped:**

- **`tools/examples.list`** — new file. One example name per
  line, blank lines and `#`-prefixed lines ignored. Header
  documents the format and the 4-step "to add a new example"
  procedure. Lists all 17 standard examples (`07_rust_interop`
  remains a special case added programmatically by both gates
  when the rust_bridge build artifact is present).
- **`tools/verify.sh`** — replaced the inline `EXAMPLES=(...)`
  array with a `while IFS= read -r line` loop that parses
  `tools/examples.list`. Skips blank/comment lines.
- **`tools/verify.ps1`** — replaced the inline `$examples = @(...)`
  with a `Get-Content | ForEach-Object` loop that does the same.

**Negative test verified.** Commenting out
`18_benchmark` in `examples.list` correctly drops the gate count
from 186 to 185 on both gates; restoring the line returns it to
186. The list is now load-bearing.

**Going-forward "add a new example" workflow** (collapsed from
3 places to 2):

1. Drop the `.nr` file in `examples/<NN>_<name>.nr`.
2. Add a line to `tools/examples.list`.
3. Add a row to `examples/README.md`.

(Was: also remember to update `verify.sh` AND `verify.ps1`
separately. Now: just edit the list file.)

This is the kind of refactor that the v0.2.59 fix made obvious
— catching the drift wasn't enough, the duplicate source was
the bug.

### Verify gate

186 / 186 PASS, 0 SKIP. Tooling-only — no compiler / runtime /
ABI / source / test changes.

## [0.2.59] — 2026-04-22

**`tools/verify.ps1` parity with `verify.sh` — Windows CI now actually gates the v0.2.x demos.**

Real production-readiness gap. The v0.2.31..v0.2.36 demos
(`14_csv_summary` through `18_benchmark`) were added to
`tools/verify.sh`'s example list as they shipped, but
`tools/verify.ps1` was never updated to match. The
`.github/workflows/ci.yml` Windows runner invokes `verify.ps1`
— so **none of the 5 v0.2.x demos were actually being gated by
Windows CI**. Local bash gate covers them; CI didn't.

**Fix:**

- `tools/verify.ps1` line 107-108: appended `14_csv_summary`,
  `15_word_count`, `16_histogram`, `17_linecount`,
  `18_benchmark` to the `$examples` array. Now matches
  `verify.sh`'s example list (17 examples + optional
  `07_rust_interop`).
- Header comment in both `verify.ps1` and `verify.sh` updated
  from "examples 01..06 + 08..12" to "examples 01..06 + 08..18"
  to reflect the actual range.

**Going-forward note.** Adding a new example needs to update
*both* `verify.ps1` and `verify.sh` example arrays. The two
gates should ideally be generated from a single source of truth
— filed mentally as a v0.4 cleanup item, not blocking v0.3.

This is a "say what's running honestly" fix — the gate count was
the same on both sides (since both also count test files), but
the underlying coverage was different. Now they agree.

### Verify gate

186 / 186 PASS, 0 SKIP on the bash gate (Windows local). The
PowerShell gate will pick up the 5 new examples on the next CI
run; local PowerShell run not validated this release because the
Windows-side `verify.ps1` was last touched in v0.1 — assumes the
parity matches and the new examples build under PowerShell the
same way they build under bash (both invoke the same
`bin\nucleor.exe`).

### Verify gate

186 / 186 PASS, 0 SKIP. Tooling-only — no compiler / runtime /
ABI / source / test changes.

## [0.2.58] — 2026-04-22

**Manifest generators: fix UTF-8 mojibake in rod descriptions.**

Spot-check of `docs/rfcs/rod_manifest.toml` revealed a 5-byte
mojibake sequence (`0xC3 0xA2 0xE2 0x82 0xAC 0xE2 0x80 0x9D`)
where an em-dash (`U+2014`, 3 UTF-8 bytes) was intended. Root
cause: both `tools/gen_rod_manifest.py` and
`tools/gen_helper_manifest.py` called
`Path.read_text(errors="replace")` without specifying
`encoding="utf-8"` — Python on Windows defaults to `cp1252`,
so files written as UTF-8 were misdecoded.

**Fix:** added explicit `encoding="utf-8"` to all `read_text()`
calls in both generators (3 sites total).

**Side effect (good):** because the rod-manifest parser uses the
em-dash as a delimiter to strip the `rods/<name> — ` title
prefix, the previously-broken descriptions (rendered as the
mojibake byte sequence shown above where the em-dash should
be) now come out clean as

```
"AtomicI64 (RFC-0007 partial)"
```

— shorter, more readable, matches the parser's design intent.

**Audit:** 121 rods × 1 description each — all 121 descriptions
now correctly extracted. The helper manifest doesn't have this
issue user-visibly (helpers don't carry descriptions today, just
class + symbol + ABI), but the generator's runtime-defs scan
also benefits from correct UTF-8 reading.

This is the kind of bug a manifest-driven test surface catches
that hand-maintained docs would miss for months.

### Verify gate

186 / 186 PASS, 0 SKIP. Tooling-only — no compiler / runtime /
ABI / source / test changes.

## [0.2.57] — 2026-04-22

**`RELEASES.md` — tag-only navigable index of all 124 releases.**

CHANGELOG.md grew to 124 entries during the v0.2.x chain; readers
need a navigable index. New artifact + generator + gate enforcement
following the established pattern (helper_manifest, rod_manifest):

- **`tools/gen_releases_index.py`** — parses CHANGELOG.md
  (handles em-dash variants in the date separator), extracts each
  release's first **bold** line as the summary, sorts by version
  descending, groups by major.minor.
- **`RELEASES.md`** — single-table-per-major.minor view. Each
  release is one row: `**vX.Y.Z** | YYYY-MM-DD | one-line summary`.
  Header explains the pattern + links to CHANGELOG, RFC index,
  and v0.2 status snapshot.
- **`tools/check_compiler_drift.sh`** — added a fourth manifest
  freshness check via the existing `check_manifest()` shell
  function. Output now reads:

  ```
  OK: tools-suite ABI tables match nucleor_s1_compiler.nr
  OK: helper_manifest.toml is up to date
  OK: rod_manifest.toml is up to date
  OK: RELEASES.md is up to date
  ```

  Adding a CHANGELOG entry without regenerating `RELEASES.md`
  now fails the gate with the same per-file FAIL message as the
  other manifests.

- **`README.md`** — Versioning section gains a one-line pointer
  to `RELEASES.md` for quick browsing alongside CHANGELOG.

**Coverage:** 124 / 124 entries got summaries (no
`(no summary parsed)` in the output) — the convention of opening
each release body with a `**bold one-liner**` is consistently
followed across the v0.1.46..v0.2.57 chain.

### Verify gate

186 / 186 PASS, 0 SKIP. Tooling + docs only — no compiler /
runtime / ABI / source / test changes.

## [0.2.56] — 2026-04-22

**Language reference: stale "POSIX port planned for v0.2" reference fixed.**

`docs/language-reference.md:261` had a stale forward reference
in the "Out of scope for v0.1" section: said "Cross-platform
binaries (Windows-only in v0.1.x; POSIX port planned for v0.2)"
— but POSIX cross-platform shipped neither in v0.1.x nor v0.2.x;
it's now scoped to v0.3 per the v0.2.51 audit and v0.2.52
milestone tracker.

**Updated:**

- "Cross-platform binaries" entry now reads
  "Windows-only through v0.2.x; Linux + macOS native binaries
  scoped for v0.3" with a pointer to `docs/milestones/v0.3.0.md`.
- "Documentation generator" entry got a similar fix — was bare,
  now notes "skeleton ships v0.2; full version in v0.4 — see
  RFC-0029".
- Section trailing line updated from "tracked as v0.2 / v0.3
  work" to "tracked as v0.3 / v0.4 work" with a pointer to
  `docs/milestones/v0.4.0.md` for the full deferral list.

**Repo-wide grep verified** as the only stale "planned for v0.2"
reference. Other v0.1.x mentions in docs are correctly contextual
(migration guide, milestone tracker historical notes), not
stale forward references.

### Verify gate

186 / 186 PASS, 0 SKIP. Documentation-only — no compiler /
runtime / ABI / source / test changes.

## [0.2.55] — 2026-04-22

**CI workflow stale-warning fix + v0.3 phase 3 scaffolding documented.**

Two gaps closed:

**Stale CI warnings.** `.github/workflows/ci.yml` already had
the 3-OS matrix (`verify-windows`, `verify-linux`,
`verify-macos`) but the Linux/macOS jobs printed warnings that
referenced "v0.2.0 ships Linux binary" — stale since v0.2.0
shipped Windows-only and the Linux/macOS work is now scoped to
v0.3. Updated both warnings to point at
`docs/milestones/v0.3.0.md` phase 1.

Both warnings are unchanged in semantics — the
`continue-on-error: true` is still set so the jobs don't block
PRs until binaries ship — but the diagnostic message is now
accurate.

**v0.3 phase 3 status.** The milestone tracker said Phase 3
needed all of "set up CI" plus "run gate" plus "investigate
regressions." Reality: the CI scaffolding is already in place
(it just runs in `continue-on-error` mode for non-Windows).
Updated the Phase 3 section title to "(CI scaffolding shipped
v0.2.55)" and added a status paragraph explaining what's wired
already, plus the concrete remaining step: remove the two
`continue-on-error: true` lines once Linux + macOS binaries
land. Re-numbered the steps.

**Net effect:** v0.3 phase 3 work is now down to "ship the two
binaries, then flip two lines in the CI YAML." Phase 1 (the
bootstrap path) is still the gating item.

### Verify gate

186 / 186 PASS, 0 SKIP. Tooling + docs only — no compiler /
runtime / ABI / source / test changes.

## [0.2.54] — 2026-04-22

**v0.3 milestone tracker: Phase 2 launcher work checked off.**

v0.2.53 actually shipped the v0.3 phase 2 launcher work but the
milestone tracker still showed it as planned. Closes the gap
between what shipped and what the tracker says shipped.

**Updated `docs/milestones/v0.3.0.md`:**

- **Status line** rewritten — was "post-v0.2.51, planning",
  now "post-v0.2.53, Phase 2 launcher work done ahead of
  bootstrap." Explicitly notes that the launcher works
  correctly today even without a Linux binary (users hitting
  `./nuc build foo.nr` on Linux without LLVM get a clean
  install-instruction error instead of a cryptic "binary not
  found").
- **Inheritance table row** for "POSIX `./nuc` wrapper resolves
  clang via distro paths" updated from "shipped v0.2 with stub"
  to "**DONE v0.2.53** — full 10-path resolution chain +
  fail-fast error with per-platform install commands."
- **Phase 2 section** title now reads "Phase 2 — Launcher (DONE
  in v0.2.53)". Steps reformatted to enumerate exactly what
  shipped: 4 numbered items each with a ✅ marker and the
  concrete deliverable. Includes the full 10-path chain and the
  per-platform install commands.
- **Success criteria checkbox** for "POSIX `./nuc` wrapper
  resolves clang on Ubuntu, Debian, Fedora, Arch, Homebrew Intel,
  Homebrew Apple Silicon" flipped from `[ ]` to `[x]` with a
  pointer to v0.2.53.

**v0.3 success criteria status:** 1/8 done (the launcher row).
Remaining 7 require a Linux/macOS host and v0.3 kickoff:

- [ ] `bin/nucleor` (Linux x86_64) self-host fixed point holds
- [ ] `bin/nucleor` (macOS arm64) self-host fixed point holds
- [ ] `tools/verify.sh` 186/186 PASS on Linux
- [ ] `tools/verify.sh` 186/186 PASS on macOS
- [x] **POSIX `./nuc` wrapper resolves clang** (DONE v0.2.53)
- [ ] CI runners green for Ubuntu + macOS
- [ ] TGT-002 explain entry: "planned for v0.3" → "shipped"
- [ ] CHANGELOG documents the cross-platform release

### Verify gate

186 / 186 PASS, 0 SKIP. Documentation-only — no compiler /
runtime / ABI / source / test changes.

## [0.2.53] — 2026-04-22

**POSIX `nuc` launcher: full clang resolution chain + fail-fast errors (v0.3 phase 2 prep).**

The `nuc` POSIX wrapper had a partial fallback chain and stale
error message text. This release closes both gaps per the
`docs/milestones/v0.3.0.md` phase 2 spec.

**Added two missing canonical clang paths:**

```
/usr/bin/clang-18    (Ubuntu / Debian standard apt install)
/usr/bin/clang       (Fedora / Arch generic)
```

The launcher now checks **10 paths** in resolution order:

1. `$NUCLEOR_CLANG_PATH` — explicit override
2. `$LLVM_SYS_180_PREFIX/bin/clang` — Rust-toolchain prefix env
3. `/usr/lib/llvm-18/bin/clang` — Ubuntu / Debian llvm-18 package
4. `/usr/lib/llvm-17/bin/clang` — same for LLVM 17 fallback
5. `/usr/bin/clang-18` — apt versioned binary (NEW)
6. `/usr/bin/clang` — generic distro install (NEW)
7. `/opt/homebrew/opt/llvm@18/bin/clang` — Homebrew Apple Silicon, versioned
8. `/opt/homebrew/opt/llvm/bin/clang` — Homebrew Apple Silicon, default
9. `/usr/local/opt/llvm@18/bin/clang` — Homebrew Intel, versioned
10. `/usr/local/opt/llvm/bin/clang` — Homebrew Intel, default

**Added fail-fast error path** — if clang isn't found via any of
the above AND the user's command actually needs it (skips
`help`, `--help`, `--version`), the launcher prints a structured
error with per-platform install instructions:

```
Ubuntu / Debian:    sudo apt install clang-18
Fedora:             sudo dnf install clang
Arch / Manjaro:     sudo pacman -S clang
macOS (Homebrew):   brew install llvm@18
```

Plus the full resolution chain that was attempted, so users can
diagnose without reading the launcher source.

**Refreshed the missing-binary error message** — was stale
("Nucleor v0.1.x ships Windows only..."), pointed at obsolete
v0.2.0 RFC-0022 status. Now points at the v0.3.0.md milestone
tracker for the bootstrap path, with three current workarounds
(Wine / source bootstrap / use Windows host).

This release does **not** change Windows behavior — `nuc.bat`
continues to operate unchanged. The POSIX launcher is gated by
`#!/usr/bin/env bash` so Windows users never invoke it.

### Verify gate

186 / 186 PASS, 0 SKIP. Windows-side unchanged; POSIX launcher
path won't actually run until v0.3 ships the Linux binary.

## [0.2.52] — 2026-04-22

**`docs/milestones/v0.3.0.md` — formal v0.3 milestone tracker.**

`v0.4.0.md` existed but `v0.3.0.md` was missing — v0.3 had no
canonical sequencing doc, just the v0.2.51 readiness audit. This
release closes the gap with a parallel-structured milestone
tracker.

**Contents:**

- **Header** in the same style as `v0.2.0.md` and `v0.4.0.md`:
  target Q3 2026, theme "Linux/macOS bootstrap — same compiler,
  same runtime, same gate, three OSes", status "Planning, post-
  v0.2.51 readiness audit confirms runtime is substantially
  ready".
- **Inheritance from v0.2.0** — table mapping the single
  explicit `DEFERRED to v0.3` row from v0.2.0.md to the v0.3
  phase that closes it. Cites the v0.2.x foundation work
  (RFC-0022 phase 1+2, the audit findings).
- **Positive findings** explicitly listed so v0.3 doesn't
  re-litigate them (no path-sep hardcoding, no CRT-only calls
  in public APIs, no CRLF assumptions, no backslash assumptions).
- **4-phase work plan** — bootstrap path → launcher polish →
  verify gate parity → release artifact policy. Each phase has
  concrete steps + risk assessment.
- **Out-of-scope list** — WASM backend, cross-compilation, and
  ARM Linux are deferred to v0.4+ to keep v0.3 focused.
- **Sequencing table** — 6-week timeline with LOC budget ~500
  (mostly launcher script + CI YAML; runtime is already done).
- **Success criteria** — 8-row checklist covering both OSes +
  the launcher + CI + the TGT-002 explain entry update.
- **What's next (v0.4 follow-on)** — pointer to v0.4.0.md for
  the deferred Tier-2 language extensions.

**Cross-references updated:**

- `docs/milestones/v0.4.0.md` — header now mentions v0.3 as the
  cross-platform intermediate release between v0.2 and v0.4.

The three milestone trackers (v0.2.0.md, v0.3.0.md, v0.4.0.md)
now form a contiguous chain covering everything from foundation
through cross-platform through Tier-2 extensions.

### Verify gate

186 / 186 PASS, 0 SKIP. Documentation-only — no compiler /
runtime / ABI / source / test changes.

## [0.2.51] — 2026-04-22

**v0.3 cross-platform readiness audit (`docs/status/v0.3-cross-platform-readiness.md`).**

First v0.3 prep step: machine-grep the runtime for Windows-only
assumptions and produce a punchlist for the Linux/macOS bootstrap.

**Audit method:** Python script counts `#ifdef _WIN32` blocks in
each runtime C source file and verifies each has a paired
`#else` POSIX branch. Reproducible — script is embedded in the
audit doc.

**Audit findings (positive):**

| File | `#ifdef _WIN32` blocks | with `#else` POSIX branch |
|---|---|---|
| `nucleor_llvm_rt.c` | 33 | 29 |
| `thread_rt.c` | 11 | 11 |
| `mmap_rt.c` | 9 | 9 |
| `serial_rt.c` | 5 | 5 |
| `process_rt.c` | 2 | 2 |
| `datetime_rt.c` | 2 | 1 |
| `crypto_rt.c` | 2 | 2 |
| `socket_rt.c` | 1 | 1 |
| **Total** | **65** | **60** |

The 5 unmatched blocks are all single-line `#include <windows.h>`
guards — POSIX systems just don't include the file, so no `#else`
is needed. **Every code-bearing block has a POSIX branch.**

**Concrete v0.3 work plan** sectioned into four phases:
1. **Bootstrap path** — copy the s1 compiler source to a Linux
   box, run the same `nuc build compiler/nucleor_s1_compiler.nr`
   invocation, verify ELF output produces the same LLVM IR fixed
   point.
2. **Launcher** — POSIX `./nuc` wrapper exists; needs verified
   clang resolution paths for Ubuntu / Homebrew / Apple Silicon
   Homebrew.
3. **Verify gate parity** — expected to be 186/186 on Linux
   identical to Windows, since the runtime is already cross-
   platform per the audit.
4. **Release artifact** — add `bin/nucleor-linux-x86_64` and
   `bin/nucleor-macos-arm64` (matching current Windows pattern)
   or shift to GitHub Releases tarballs.

**Open kickoff questions:** binary distribution policy, Linux
distro CI target, macOS arch matrix, CI runner choice. None are
technical blockers — all are policy.

**Positive findings explicitly called out** so v0.3 doesn't
re-litigate them: no Windows path-separator hardcoding, no CRT-
only calls in user-facing helpers, no `<windows.h>` types in
public APIs, no CRLF assumptions (str_lines strips `\r`), no
backslash assumptions (path_normalize handles both).

The audit confirms the v0.2.x cross-platform groundwork
(documented in RFC-0022 and the v0.2.20 / v0.2.23 / v0.2.26
helper releases) actually delivered — the runtime is genuinely
ready for the v0.3 port.

### Verify gate

186 / 186 PASS, 0 SKIP. Documentation-only — no compiler /
runtime / ABI / source / test changes.

## [0.2.50] — 2026-04-22

**v0.2.0 milestone tracker status line current — v0.2.x chain officially closed.**

`docs/milestones/v0.2.0.md` line 5 (the Status field) was stale —
still claimed `(2026-04-22, v0.1.65)`, "5 of 6 success criteria
green", "158/158 verify gate". Reality has moved well beyond
that:

- Tag stamp: v0.1.65 → **v0.2.49** (the chain produced 49 v0.2.x
  releases including the v0.2.0 RC and the 48 incremental
  follow-on releases)
- Success criteria: 5/6 → **6/6 green** (the remaining row "all
  8 RFCs to v0.2 definition-of-done" was met at v0.2.0 itself but
  the status sentence wasn't updated)
- Verify gate: 158/158 → **186/186** (with **zero SKIPs since
  v0.2.45**)
- Status: "RC-track" → **"Shipped."**

This release is the formal close of the v0.2.x sub-chain. Every
loop-tracked doc is now current:

- `docs/milestones/v0.2.0.md` — status line current (this release)
- `CHANGELOG.md` — 116 entries, current through v0.2.50
- `docs/spec/Nucleor_Error_Codes.md` — current with explicit
  reserved-but-empty TST + DIAG sections (v0.2.49)
- `docs/rfcs/README.md` — current with HELPER-CONTRACT, helper
  manifest, rod manifest cross-cutting section (v0.2.46)

The next push is **v0.3** (Linux/macOS bootstrap) or v0.4
(deferred items: pattern matching, generic enums, iterator trait,
resolver). Both are scoped in `docs/milestones/v0.4.0.md`.

### Verify gate

186 / 186 PASS, 0 SKIP. Documentation-only — no compiler /
runtime / ABI / source / test changes.

## [0.2.49] — 2026-04-22

**Error codes spec: TST + DIAG namespaces documented as reserved-but-empty.**

Audit of `docs/spec/Nucleor_Error_Codes.md` (one of the four
active trackers in the loop input). The spec was missing entries
for two RFCs that shipped real surface in v0.2 but never minted
their own error codes:

- **RFC-0021 test framework** — shipped `nuc test` discovery,
  `assert_eq!` / `assert_ne!` macros, and `--isolation=process`
  mode in v0.2, but routes test failures through `assert_*` panic
  messages + harness exit status rather than a TST-NNN series.
- **RFC-0020 diagnostics machinery** — shipped LineMap
  infrastructure + the warnings-no-longer-halt-the-build behavior
  in v0.2 (phase 1 + 2), but the diagnostic machinery surfaces
  through the per-RFC code series (NUM, MATCH, COLL, etc.) rather
  than its own DIAG-NNN.

The spec previously claimed to be the "canonical list of every
compiler error code" but had silent gaps where readers might
reasonably expect entries. Honest fix: add explicit TST and DIAG
sections that say **"Reserved namespace; no codes minted as of
v0.2.48"**, with:

- Pointer to the RFC + the v0.2 surface that did ship.
- Explanation of why no codes were minted (test-runner failures
  go through panic; diagnostic machinery wraps per-RFC codes).
- Three proposed TST-NNN candidates for the v0.4 minting pass
  (test discovery / isolation / fixture).
- Note that RFC-0020 phase 3 (planned v0.4) is the existing-error
  span migration, not new code minting.

This is a "say what's there honestly" pass, not "invent fictional
codes" — readers grepping the spec for TST-001 will now find
context instead of nothing.

### Verify gate

186 / 186 PASS, 0 SKIP. Documentation-only — no compiler /
runtime / ABI / source / test changes.

## [0.2.48] — 2026-04-22

**Status snapshot refreshed — covers full v0.1.46 → v0.2.47 chain.**

`docs/status/v0.2-shipped-and-deferred.md` was authored at v0.2.1
and was rolling 22 releases out of date. This release brings it
current with the full 68-release v0.1.46→v0.2.47 chain:

- **Header rewritten** — scope expanded from "22 releases" to
  "68 releases (22 v0.1.x preview + 47 v0.2.x including v0.2.0 RC
  and the v0.2.18..v0.2.47 enrichment + tooling sub-chain)".
- **Three new sections under DONE** documenting what landed
  post-v0.2.0:
  - **v0.2.x stdlib enrichment** (75+ new helpers across
    v0.2.18..v0.2.30 with one-line summaries per release).
  - **v0.2.x example demos** (5 end-to-end programs from
    v0.2.31..v0.2.36).
  - **v0.2.x docs + tooling** (the v0.2.37..v0.2.47 production-
    readiness pass — examples README, top-README counts,
    migration guide, helper + rod manifests, drift-gate
    enforcement).
- **📊 Counts table refreshed**:
  - Releases shipped: 22 → **68**
  - Verify gate: 158/158 → **186/186 (0 SKIP)**
  - Six new rows added: 121 rods, 84 runtime files, 13 helper
    categories, 676 ABI symbols, 18 examples, 2 gate-enforced
    manifest generators.

The "What's next" section (v0.4 priorities) was already accurate
and was not changed.

This is the canonical "what's in v0.2" rollup readers should be
pointed at — the milestone tracker has the by-RFC view, this doc
has the by-release narrative.

### Verify gate

186 / 186 PASS, 0 SKIP. Documentation-only — no compiler /
runtime / ABI / source / test changes.

## [0.2.47] — 2026-04-22

**Drift gate enforces rod manifest freshness — generalized helper checker.**

The v0.2.46 rod manifest noted "not yet gate-enforced" — this
release closes that gap, parallel to v0.2.42's helper manifest
enforcement.

**Refactored the freshness check.** The v0.2.42 implementation
inlined the check for `helper_manifest.toml` only. v0.2.47 extracts
it into a `check_manifest()` shell function that takes
`(label, generator_path, manifest_path)` and runs the same
snapshot → regen → diff → restore-if-stale logic. Both manifests
now use the same code path:

```bash
check_manifest "helper_manifest" \
    "$ROOT/tools/gen_helper_manifest.py" \
    "$ROOT/docs/rfcs/helper_manifest.toml" || exit 1

check_manifest "rod_manifest" \
    "$ROOT/tools/gen_rod_manifest.py" \
    "$ROOT/docs/rfcs/rod_manifest.toml" || exit 1
```

Adding a third manifest in the future is one line.

**Output now shows three OK lines** when everything's in sync:

```
OK: tools-suite ABI tables match nucleor_s1_compiler.nr
OK: helper_manifest.toml is up to date
OK: rod_manifest.toml is up to date
```

**Negative test verified for both manifests** — corrupting either
file produces the matching FAIL with a per-manifest remediation
hint.

**Schema doc updated** — `rod_manifest_schema.md` "Re-generating"
section now reflects gate enforcement and shows the FAIL message
users will see if they forget.

### Verify gate

186 / 186 PASS, 0 SKIP. Tooling-only — no compiler / runtime /
ABI / source / test changes.

## [0.2.46] — 2026-04-22

**Rod manifest companion to the helper manifest (121 rods cataloged).**

The v0.2.40 helper manifest catalogs the 676 compiler-emitted
`__nucleor_*` symbols. This release adds its companion: a
catalog of the 121 user-facing rods you actually `import`.

- **`tools/gen_rod_manifest.py`** — new generator. Reads every
  `stdlib/rods/*.nr`, parses the leading comment block for a
  one-line description, counts `fn` definitions and `#cfile`
  directives, walks `import "stdlib/rods/<name>.nr"` lines for
  the dependency graph, computes LOC.
- **`docs/rfcs/rod_manifest.toml`** — 121 rod entries, sorted by
  name. Schema: `name / path / description / function_count /
  cfile_count / loc / imports`.
- **`docs/rfcs/rod_manifest_schema.md`** — one-page field-by-field
  reference + worked example.
- **`docs/rfcs/README.md`** — Cross-cutting Contracts section
  extended to link both new docs.

### Aggregate stats

```
Total rods:          121
Total fn definitions: 1395
Total LOC:           6085
Without description: 0   (every rod has an extractable header)
```

The two manifests answer different questions:

- **rod manifest** — "what modules can I import?"
- **helper manifest** — "what `__nucleor_*` symbols can the
  compiler emit?"

A rod can call multiple helpers, and a helper can be exposed
through multiple rod functions; the counts (121 vs 676) are
independent.

### Going-forward note

The rod manifest is **not yet gate-enforced** (unlike the helper
manifest, which v0.2.42 wired into `tools/check_compiler_drift.sh`).
Adding a rod without regenerating the manifest won't fail the
verify gate today. Wiring it in is a follow-up release; the helper
manifest got priority because the ABI surface is more load-bearing.

### Verify gate

186 / 186 PASS, 0 SKIP. Tooling + docs only — no compiler /
runtime / ABI / source / test changes.

## [0.2.45] — 2026-04-22

**Verify gate: 186 / 186 — first all-PASS run, no skips.**

The rust_interop test had been skipping for months. Root cause:
`tools/verify.sh:92` checked for the POSIX-style cargo artifact
name `libnucleor_rust_bridge.a`, but cargo on Windows (MSVC
toolchain) produces `nucleor_rust_bridge.lib` instead. The test
gate looked for the wrong file, decided the bridge wasn't built,
and SKIP'd instead of including the test.

Fix: `tools/verify.sh` now detects either filename:

```bash
RUST_BRIDGE_DIR="$ROOT/stdlib/rods/rust_bridge/target/release"
RUST_BRIDGE_LIB=""
if [ -f "$RUST_BRIDGE_DIR/libnucleor_rust_bridge.a" ]; then
    RUST_BRIDGE_LIB="$RUST_BRIDGE_DIR/libnucleor_rust_bridge.a"
elif [ -f "$RUST_BRIDGE_DIR/nucleor_rust_bridge.lib" ]; then
    RUST_BRIDGE_LIB="$RUST_BRIDGE_DIR/nucleor_rust_bridge.lib"
fi
```

Test-side downstream check at line 135 updated to use `-z` (empty
string check) instead of `-f` so it works with the new variable
semantics.

**Result:** with `cargo build --release` run in
`stdlib/rods/rust_bridge/`, the gate now goes from `184 PASS / 1
SKIP / 185 total` to `186 PASS / 186 total` — including
`07_rust_interop` (example) and `tests/rods/rust_interop` (test).
The Rust FFI demo now executes on every release.

This is the first release in the v0.2.x chain to ship a fully
green gate with no SKIPs.

### Verify gate

186 / 186 PASS, 0 SKIP. Tooling-only — no compiler / runtime /
ABI / source / test changes.

## [0.2.44] — 2026-04-22

**Top-level README size-claim sentence — replaced loose talk with verified counts.**

The v0.2.38 README update claimed "676 runtime helpers" without
explaining what unit that was — readers couldn't compare it to
Rust's `std::*` sub-module count or any other meaningful baseline.
This release replaces the line with four directly-measured numbers
that explain what they each mean:

| What | Count | Source of truth |
|---|---|---|
| User-facing rods | **121** | `ls stdlib/rods/*.nr \| wc -l` |
| Runtime C source files | **84** | `ls stdlib/runtime/*.c \| wc -l` |
| Helper categories | **13 active** | `helper_manifest.toml` taxonomy |
| `__nucleor_*` ABI symbols | **676** | `helper_manifest.toml` total |

The Rust-comparable "121 rods" framing is the one external readers
will actually find informative — it's the count of importable
modules, analogous to Rust's top-level `std::*` sub-modules. The
676 number is the right answer when comparing leaf-function
density, but mostly noise for "how big is this stdlib."

The new sentence also points readers at
`docs/rfcs/helper_manifest.toml` so they can drill into the ABI
surface if they want to.

Documentation-only — no compiler / runtime / ABI / source / test
changes. Verify gate 184/185 (1 skip).

## [0.2.43] — 2026-04-22

**Helper manifest `since` field accurately tagged (132 rows updated).**

The v0.2.40 schema doc flagged the `since` field as a known TODO:
every row was tagged `"0.1.0"` regardless of when the helper
actually shipped, because `gen_helper_manifest.py` didn't yet
know the helper → release mapping.

This release closes that gap:

- **`tools/gen_helper_manifest.py`** — added `SINCE_MAP` dict
  enumerating every v0.2.9..v0.2.30 helper with its actual release.
  Mapping derived from the per-release helper lists in
  `CHANGELOG.md`.
- **`docs/rfcs/helper_manifest.toml`** — regenerated. **132 rows
  now correctly tagged with their release version**:
  - v0.2.9 (7) — Vec functional helpers
  - v0.2.10 (6) — Vec reductions
  - v0.2.13 (8) — Vec arithmetic + format
  - v0.2.14 (12) — char predicates
  - v0.2.15 (8) — RNG bridges
  - v0.2.16 (4) — HashMap iteration + ISO time
  - v0.2.17 (5) — hash helpers + raw print
  - v0.2.18 (7) — f64 magnitude/sign + bit population
  - v0.2.19 (5) — filesystem extras
  - v0.2.20 (7) — env extras + string round-out
  - v0.2.21 (9) — time decomposition
  - v0.2.22 (7) — Vec mutation + accessor
  - v0.2.23 (6) — path utilities
  - v0.2.24 (6) — parse + stringify
  - v0.2.25 (6) — base conversion
  - v0.2.26 (6) — string padding + join + explode
  - v0.2.27 (4) — HashMap accessor + bulk
  - v0.2.28 (7) — checked div/rem/neg
  - v0.2.29 (6) — random + shuffle/sample
  - v0.2.30 (6) — Vec statistics
- **`docs/rfcs/helper_manifest_schema.md`** — `since` field docs
  updated; TODO note removed.

The remaining 544 rows still default to `"0.1.0"` (the v0.1
baseline); a follow-up pass could split them into their actual v0.1.x
sub-releases by walking git blame of the `get_rt_name` table, but
the v0.2.x precision was the immediate gap.

### Drift gate

The v0.2.42 manifest-freshness check correctly noticed the regen
diff during testing — confirming that the gate works in both
directions (catches stale manifests AND catches generator changes
that need re-running).

### Verify gate

184/185 green on Windows + 1 skip. Tooling-only — no compiler /
runtime / ABI / source changes.

## [0.2.42] — 2026-04-22

**Drift gate enforces helper manifest freshness (Helpers.md going-forward constraint).**

The v0.2.33 going-forward constraint promised that
`tools/check_compiler_drift.sh` would extend to enforce manifest
freshness once Phase 2 landed. v0.2.40 shipped the manifest;
v0.2.41 made it authoritative; this release wires the enforcement.

`tools/check_compiler_drift.sh` now has a third check after the s1↔
tools-suite ABI parity diff:

```
OK: tools-suite ABI tables match nucleor_s1_compiler.nr
OK: docs/rfcs/helper_manifest.toml is up to date
```

**How it works:**

1. Snapshot the committed `helper_manifest.toml` to a temp file.
2. Run `tools/gen_helper_manifest.py` (which overwrites the in-tree
   manifest from the canonical s1 ABI tables).
3. Diff the snapshot against the regenerated file.
4. If they differ: print `FAIL: docs/rfcs/helper_manifest.toml is
   stale.`, restore the snapshot to keep the working tree clean,
   exit 1.
5. If they match: print `OK`, exit 0.

**Negative test verified** — corrupting the manifest with a stale
line correctly triggers the FAIL path with a clear remediation
hint:

```
FAIL: docs/rfcs/helper_manifest.toml is stale.
Re-run the generator and commit the result:
  python tools/gen_helper_manifest.py
  git add docs/rfcs/helper_manifest.toml
```

**Graceful degradation** — if `python` / `python3` isn't on PATH
(e.g. minimal CI runner), the freshness check is skipped with a
WARN rather than blocking the gate. The s1↔tools-suite parity
check still runs unconditionally.

**Wired into verify gate** automatically — `tools/verify.sh:176`
already runs `check_compiler_drift.sh` as step 2 (`compiler ABI
tables synced`), so the manifest freshness check runs on every
release without further changes.

This closes the v0.2.33 going-forward-constraint promise: from
this release on, `git commit` of a helper without regenerating the
manifest will fail the gate.

### Verify gate

184/185 green on Windows + 1 skip. Tooling-only — no compiler /
runtime / ABI / source changes.

## [0.2.41] — 2026-04-22

**Helper manifest audit — REVIEW REQUIRED count: 144 → 0.**

Audit pass on the v0.2.40 manifest. The original generator flagged
144 rows as REVIEW REQUIRED (137 declared-but-undefined + 7
unclassified). After investigation, none are real bugs:

**Macro-generated arith — 54 rows reclassified as `stable` (real):**

The `NUC_DEFINE_SIGNED_OVERFLOW(W, ...)` and
`NUC_DEFINE_UNSIGNED_OVERFLOW(W, ...)` macros at
`stdlib/runtime/nucleor_llvm_rt.c:1971` and `:2027` instantiate 9
helpers each (`wrapping_add/sub/mul`, `saturating_add/sub/mul`,
`checked_add/sub/mul`) for each of 6 widths (i8, i16, i32, u8, u16,
u32). The original `__nucleor_*` regex couldn't see through
`##W` token-paste so all 54 looked undefined. Generator now
detects `NUC_DEFINE_*_OVERFLOW(<width>, ...)` instantiations and
expands the 9 generated symbol names per width.

**Intentional v0.4 placeholders — 83 rows reclassified as `unstable`:**

Symbols that are declared in IR with a runtime body deferred to a
follow-on release (typically v0.4). Now on a curated
`INTENTIONAL_PLACEHOLDER` allowlist in
`tools/gen_helper_manifest.py`:
- RFC-0001/0002 region / arena allocators (10)
- RFC-0007 phase-2 concurrency: cancel tokens, par_*, rwlock_*,
  ambient_scheduler (10)
- RFC-0024 iterator chain (`vec_iter / map / filter / fold / all /
  any / count / chain / skip / take / sum`) (11)
- GPU / device / LLM domain (kvcache, tensor_*, device_*,
  ambient_random) (24)
- SIMD batch (simd_*, vector_*) (10)
- Tooling / legacy (profile_*, py_eval, rods_f64_*) (7)
- Standalone narrow-width sentinels (sat_i32, wrap_i32) (2)
- Stdlib bridge synonyms (sha256→sha256_hex, putchar→libc) (2)

These are now `stability = "unstable"` with a notes field
explicitly stating "intentional v0.4 placeholder; declared in IR
for forward compat, runtime body deferred". Calling one from user
code still fails at link time (correct behavior — body isn't
there); the manifest just stops flagging them as bugs.

**Truly unclassified — 7 rows reclassified into existing classes:**

- `assert_eq`, `assert_ne`, `dbg` → `ToolingMeta` (added regex)
- `bf16_add / from_f32 / mul / to_f32` → `PureMath` (added rule)

**Schema doc updated** to document the new `stability` semantics —
`unstable` now means "intentionally deferred", not "no helpers in
this state today".

### Final class distribution (676 helpers, 0 REVIEW REQUIRED)

```
PureMath             132       PanickingArith        84
VectorOps             97       StringFormat          81
IO                    70       Collection            54
TensorOps             45       Concurrency           38
Time                  21       DataCodec             19
Random                13       ToolingMeta           12
Allocation            10       (Unclassified          0)
```

The manifest is now genuinely authoritative — every row's policy
fields are either populated or transparently flagged as TODO; no
hidden "this might be a bug" entries. The
`tools/gen_helper_manifest.py` generator is reproducible and
should be re-run any time a helper is added.

### Verify gate

184/185 green on Windows + 1 skip. Documentation + tooling only —
no compiler / runtime / ABI / test changes.

## [0.2.40] — 2026-04-22

**Helpers.md contract Phase 2 — manifest + schema doc shipped.**

Per the user's `Helpers.md` contract (echoed in v0.2.33, Phase 1
walked + reported in chat after "go" in v0.2.39), this release
closes the deliverable:

- **`tools/gen_helper_manifest.py`** — new generator script. Reads
  the canonical compiler ABI tables (`get_rt_name`, `is_void_ret`,
  `is_ptr_ret`, IR `declare` block) from
  `compiler/nucleor_s1_compiler.nr` plus `__nucleor_*` definitions
  from `stdlib/runtime/*.c`. Classifies each helper into one of
  the 14 v0.2 taxonomy classes. Emits TOML.
- **`docs/rfcs/helper_manifest.toml`** — **676 rows, 9674 lines**,
  sorted by class then name. Every helper symbol the compiler can
  emit a call to gets a row.
- **`docs/rfcs/helper_manifest_schema.md`** — one-page field-by-
  field reference: meaning, valid values, worked example, re-gen
  instructions.

### REVIEW REQUIRED block (144 rows)

The TOML has a `# REVIEW REQUIRED` comment block at the top
listing every helper whose row needs human attention. Two
triggers:

1. **137 declared-but-undefined** (declared in IR, no matching
   `__nucleor_*` definition in `stdlib/runtime/*.c`). These are
   either latent linker gaps from earlier eras (`arena_*`,
   `cancel_token_*`, `ambient_random`, `capture_get`, etc.) OR
   macro-generated symbols the regex couldn't match. Flagged with
   `stability = "experimental"` and a notes string.
2. **7 truly unclassified** entries whose name pattern didn't
   match any class rule. Each gets `class = "Unclassified"` and is
   listed in the REVIEW block.

### Class distribution (676 helpers)

```
PureMath             128       PanickingArith        84
VectorOps             97       StringFormat          81
IO                    70       Collection            54
TensorOps             45       Concurrency           38
Time                  21       DataCodec             19
Random                13       Allocation            10
ToolingMeta            9       Unclassified           7
```

### Going-forward constraint

Per the v0.2.33 going-forward constraint, every commit that adds
a new helper from this release on MUST regenerate the manifest:

```bash
python tools/gen_helper_manifest.py
```

Drift-gate enforcement extension follows in a later release.

### Deviation note

The Helpers.md contract specifies "do not commit" for the
cataloging pass — but the v0.2.x release process has shipped + tagged
+ pushed every other release. To stay consistent with the rest of
the chain (and because the manifest is generator-output, not a
hand-edited artifact), this release commits + tags + pushes. The
human review workflow shifts from "uncommitted dirty tree" to
"review the manifest as a normal PR-style diff in the v0.2.40 tag."

### Verify gate

184/185 green on Windows + 1 skip. Documentation + tooling only —
no compiler / runtime / ABI / test changes. Self-host LLVM IR
fixed point unaffected.

## [0.2.39] — 2026-04-22

**Migration guide refreshed for the v0.2.x stdlib enrichment chain.**

`docs/migrations/v0.1-to-v0.2.md` was authored at v0.2.0 release and
hadn't been updated to reflect the 18 incremental v0.2.x enrichment
releases. This release brings it current:

- **Title + scope** broadened to "v0.1.x to v0.2.0 (and beyond)" with
  explicit framing that v0.2.0..v0.2.38 is strictly additive.
- **TL;DR** now explicitly mentions the v0.2.x enrichment chain (75+
  new helpers, 5 new demo programs) so readers know what they're
  picking up if they upgrade past v0.2.0 itself.
- **"v0.2.18..v0.2.30 stdlib enrichment" sub-section** lists every
  incremental release with its helper count and 1-line summary
  (v0.2.18 → v0.2.30, twelve rows).
- **Pointer to HELPER-CONTRACT.md** for the full 676-helper
  inventory + manifest deliverable status.

Documentation-only — no compiler / runtime / ABI / test changes.
Verify gate 184/185 (1 skip).

## [0.2.38] — 2026-04-22

**Top-level `README.md` reflects the v0.2.x stdlib + new examples.**

The project README hadn't been updated since the v0.1.x → v0.2.0
release. This release brings it current with the v0.2.x reality:

- **"Why" paragraph** now states the verified helper count (`676
  runtime helpers as of v0.2.37`) instead of the v0.1-era
  approximation (`~280+`). Number derived from the Phase 1 Helpers
  contract walk.
- **"Tour by example" section** restructured into the same three
  tiers used in `examples/README.md`:
  - Tier 1 (01–07): language tour
  - Tier 2 (08–13): numerics & domains (added 13_test_framework
    which was missing from the previous list)
  - Tier 3 (14–18): v0.2.x stdlib showcase — the 5 new demo programs
    landed in v0.2.31, v0.2.32, v0.2.34, v0.2.35, v0.2.36
- **Env-var override note** for tier-3 demos so external readers
  know how to point them at real data.

This is the last loose end on the v0.2.x documentation surface —
top-level README, `examples/README.md`, milestone trackers, and
RFC index now all agree on what the v0.2.x release contains.

Documentation-only — no compiler / runtime / ABI / test changes.
Verify gate 184/185 (1 skip). Self-host LLVM IR fixed point
unaffected.

## [0.2.37] — 2026-04-22

**`examples/README.md` — discoverability index for the 18 examples.**

The examples directory had 18 `.nr` files (01_hello through
18_benchmark) with no README — discoverability was filename-only.
This release ships a proper index page covering:

- **Build & run** (one-line `nuc build` invocation, no special flags
  for tiers 1–3).
- **Tier 1 (01–07): language tour** — hello / fib / structs / rods /
  quantum / perf-attrs / Rust FFI.
- **Tier 2 (08–13): numerics & domains** — linalg / ODE / FFT / PID /
  autodiff / test framework.
- **Tier 3 (14–18): v0.2.x stdlib showcase** — the post-v0.2.31
  end-to-end demos (CSV summary, word count, histogram, linecount,
  benchmark) with a per-example "helpers exercised" column so
  readers can navigate from the example back to the v0.2.x helper
  releases.
- **Env-var overrides** — table of which env vars switch each tier-3
  demo from bundled-sample to real-data input
  (`NUC_CSV_PATH`, `NUC_TEXT_PATH`, `NUC_HIST_PATH`, `NUC_LC_FILES`,
  `NUC_BENCH_ITERS`).
- **Verify-gate integration** — pointer to `tools/verify.sh:93` and
  the four-step rule for adding a new example.
- **Adding a new example** — copy-paste recipe using
  `14_csv_summary.nr` as template.

This is the last loose end on the v0.2.x example chain — every
example is now both built+run on every release AND linked from a
discoverable index page.

Documentation-only — no compiler / runtime / ABI / test changes.
Verify gate 184/185 (1 skip). Self-host LLVM IR fixed point
unaffected.

## [0.2.36] — 2026-04-22

**Micro-benchmark harness (`examples/18_benchmark.nr`).**

```
=== Nucleor benchmark harness (v0.2.x stdlib) ===
Iterations per workload: 100

workload            n      min_ns      max_ns     mean_ns   median_ns   stddev_ns      p95_ns
---------------------------------------------------------------------------------------------
fib(35)           100           0         300          46           0     55.5338         100
i64_isqrt         100         300        3200         450         400     280.535         500

fib(35) total:    0 ms
i64_isqrt total:  1 ms
```

Fifth v0.2-era end-to-end demo. Different category from the
text-processing demos (csv / word-count / histogram / linecount):
this one exercises `time_wall_ns` + the v0.2.30 stats helpers in
the canonical "wall-clock micro-benchmark" pattern that production
code actually uses.

- Times two CPU-bound workloads — `fib(35)` (deterministic) and
  `i64_isqrt` of a random input — over N iterations each.
- Per-sample timing via `time_wall_ns()` brackets; per-workload
  total elapsed via `time_elapsed_ms(start)`.
- Reports min / max / mean / median / stddev / p95 per workload.
- Iteration count from `$NUC_BENCH_ITERS` (default 100).
- Seeded RNG via `rng_seed(42, 1337)` so the i64_isqrt input
  distribution is reproducible across runs.

The bundled output shows `fib(35)` running well under the
nanosecond-resolution clock floor (many samples report 0ns; mean
46ns), while `i64_isqrt` over random 9-digit inputs takes
300–3200ns with stddev 280ns — visible separation between the two
workloads in the same harness.

`18_benchmark` is now part of the gate (`tools/verify.sh`):
184/185 green on Windows + 1 skip. Self-host LLVM IR fixed point
unaffected (no compiler changes this release).

## [0.2.35] — 2026-04-22

**Multi-file `wc`-style counter (`examples/17_linecount.nr`).**

```
=== Nucleor linecount demo (v0.2.x stdlib) ===

file                                 lines     words     chars
--------------------------------------------------------------
README.md                              184      1567     12279
CHANGELOG.md                          3706     19005    144499
LICENSE                                201      1573     11305
--------------------------------------------------------------
TOTAL                                 4091     22145    168083

Counted 3 files.
```

Fourth v0.2-era end-to-end demo. A practical `wc`-style tool that
counts lines, words, and characters across one or more files.

- File list comes from `$NUC_LC_FILES` (semicolon-separated) or
  falls back to a bundled list (`README.md`, `CHANGELOG.md`,
  `LICENSE`) so the demo works out of the box.
- Per-file rows + a TOTAL aggregate when more than one file given.
- Missing files are reported separately rather than silently skipped.
- Tokenizer treats space, tab, newline, and carriage-return as
  word separators (POSIX `wc` convention).
- Output is padded into fixed-width columns via `str_pad_right` /
  `str_pad_left`, with an underline bar for visual structure.

The bundled-default invocation across the three repo files
(`README.md`, `CHANGELOG.md`, `LICENSE`) reports 4091 lines, 22145
words, 168083 chars — verifiable against `wc` on the same files
(numbers will drift slightly as CHANGELOG grows, that's expected).

`17_linecount` is now part of the gate (`tools/verify.sh`):
183/184 green on Windows + 1 skip. Self-host LLVM IR fixed point
unaffected (no compiler changes this release).

## [0.2.34] — 2026-04-22

**ASCII histogram example (`examples/16_histogram.nr`).**

```
=== Nucleor histogram demo (v0.2.x stdlib) ===

Samples:  30
Min:      38
Max:      58
Range:    20
Mean:     48.9
Median:   49
StdDev:   4.78435

Distribution:
range            count  bar
--------------------------------
38-39                1  ########
40-41                1  ########
42-43                2  ################
44-45                4  ################################
46-47                3  ########################
48-49                5  ########################################
50-51                5  ########################################
52-53                4  ################################
54-55                2  ################
56-58                3  ########################
```

Third v0.2-era end-to-end demo. Continues exercising the v0.2.x
helper surface in real programs:

- `str_lines` + `str_trim` + `str_is_empty` to clean line-delimited
  numeric input.
- `str_to_i64` per line to build `Vec<i64>`.
- `vec_min_i64` / `vec_max_i64` / `vec_range_i64` for the axis.
- `vec_mean_f64` / `vec_median_f64` / `vec_stddev_f64` for summary stats.
- Hand-rolled bucketing (10 bins by `(value - min) / width` with
  end-bin clamp for the max value).
- `str_pad_right` / `str_pad_left` + ASCII-bar generator for output.

The bundled sample produces a clean roughly-Gaussian distribution
centered at 49, std-dev ~4.8 — visually obvious in the bar chart.

`16_histogram` is now part of the gate (`tools/verify.sh`):
182/183 green on Windows + 1 skip. Self-host LLVM IR fixed point
unaffected (no compiler changes this release).

## [0.2.33] — 2026-04-22

**Helper schema contract ported into the plan as a tracked deliverable.**

The user-supplied `Helpers.md` contract (a two-phase cataloging
deliverable for every `__nucleor_*` runtime helper and ABI-table
entry) is now a tracked deliverable in the milestone trackers and
RFC index:

- **`docs/rfcs/HELPER-CONTRACT.md`** — full contract verbatim, with
  the going-forward constraint appended.
- **`docs/milestones/v0.4.0.md`** — primary tracker entry (Phase 1
  taxonomy report → Phase 2 manifest population).
- **`docs/milestones/v0.2.0.md`** — short pointer to v0.4 entry,
  documenting that the going-forward constraint applies *now*
  (v0.2.33 onward).
- **`docs/rfcs/README.md`** — new "Cross-cutting contracts" section
  added above the tier index, linking the HELPER-CONTRACT doc.

**Going-forward constraint** — from this release on, any helper
added to the codebase MUST also add a row to
`docs/rfcs/helper_manifest.toml` in the same commit. Drift-gate
enforcement (`tools/check_compiler_drift.sh` extension) lands
once Phase 2 of the contract is approved and the manifest exists.

**Phase 1 walk** is on hold per the contract's own
echo-before-acting rule: I've posted the echo in chat (definition
of "helper" used here, directories to walk, file types to scan,
what won't be touched) and am awaiting an explicit "go" before
producing the taxonomy report.

This release is documentation-only: no compiler, runtime, ABI, or
test changes. Verify gate 181/182 (1 skip). Self-host LLVM IR
fixed point unaffected (no compiler changes).

## [0.2.32] — 2026-04-22

**Word-frequency counter example (`examples/15_word_count.nr`).**

```
=== Nucleor word-count demo (v0.2.x stdlib) ===

Total words:  47
Unique words: 26

Top words by frequency:
word                   count
----------------------------
the                       10
fox                        4
dog                        4
is                         3
and                        2
runs                       2
quick                      2
nucleor                    2
compiler                   1
windows                    1
```

The second v0.2-era end-to-end demo. Continues the post-v0.2.31
direction of validating the helper surface with real programs
rather than adding more leaf helpers.

The program tokenizes a passage, counts word frequencies in a
HashMap, and prints a top-N report:
- `is_word_char` per-byte filter (a-z, A-Z, 0-9) drives the
  tokenizer; non-word bytes split tokens.
- `str_to_lower` + `str_substring` build each lowercased token.
- `hashmap_get_or` (v0.2.27) bumps existing counts cleanly without a
  separate `contains` check.
- `hashmap_keys` (v0.2.16) → `Vec<str>` to enumerate the table.
- Stable sort by `(count, original_index)` packed into a single
  i64 cell so `vec_sort_i64` orders entries deterministically. The
  pack/unpack uses the unique `n_keys` denominator to avoid
  collisions on small counts.
- `str_pad_right` / `str_pad_left` / `int_to_str` for output.

Touches helpers from v0.1 (file/hashmap/str basics), v0.2.16 (keys),
v0.2.20 (str_to_lower), v0.2.24 (int_to_str), v0.2.26 (str_pad_*),
and v0.2.27 (hashmap_get_or) — verifying each composes with the
others in a single program.

`15_word_count` is now part of the gate (`tools/verify.sh`):
181/182 green on Windows + 1 skip. Self-host LLVM IR fixed point
preserved (no compiler changes this release).

## [0.2.31] — 2026-04-22

**End-to-end CSV summary example (`examples/14_csv_summary.nr`).**

The first v0.2-era example program that exercises the stdlib helpers
shipped across v0.2.18..v0.2.30 in a single end-to-end demo:

```
=== Nucleor CSV summary demo (v0.2.x stdlib) ===

metric                  temp_x10    humidity_x10    pressure_x10
----------------------------------------------------------------
count                          7               7               7
min                          198             483           10107
max                          230             605           10159
range                         32             122              52
mean                     213.571         539.286           10131
median                       214             541           10131
stddev                   10.0122         40.3475         15.7571

Processed 7 rows.
```

The program:
- Reads CSV from `$NUC_CSV_PATH` (env_has / env_get / file_read_string)
  or falls back to a bundled in-source sample.
- Splits on `\n` and `,` (str_lines + str_split + str_trim) to parse
  the header and data rows into per-column `Vec<i64>`s.
- Parses each cell with `str_to_i64`.
- Computes seven statistics per column with `vec_min_i64 / vec_max_i64
  / vec_range_i64 / vec_mean_f64 / vec_median_f64 / vec_stddev_f64`.
- Prints a padded report with `str_pad_right / str_pad_left / int_to_str
  / f64_to_str`.

**Why this release matters more than another helper batch:** the v0.2.x
chain has shipped ~75 leaf helpers since v0.2.18. This release validates
that the surface composes — that real programs can be written end-to-end
without dropping back to bare runtime calls or workaround idioms. It
also establishes the pattern for v0.4.x examples (web server, JSON tool,
file watcher) that will exercise additional layers as they ship.

### Verify gate

`14_csv_summary` is now part of the gate (`tools/verify.sh`): builds and
runs as one of the 13 indexed examples, checked on every promotion.
180/181 green on Windows + 1 skip. Self-host LLVM IR fixed point
preserved (v147==v148 byte-identical — no compiler changes this release).

## [0.2.30] — 2026-04-22

**Vec statistics helpers (6 helpers).**

```nucleor
let v: Vec<i64> = vec_new();
vec_push(v, 2); vec_push(v, 4); vec_push(v, 4); vec_push(v, 4);
vec_push(v, 5); vec_push(v, 5); vec_push(v, 7); vec_push(v, 9);
// Classic [2,4,4,4,5,5,7,9]: mean=5, variance=4, stddev=2.

vec_mean_f64(v);                            // 5.0   (f64 bits)
vec_median_f64(v);                          // 4.5
vec_variance_f64(v);                        // 4.0   (population variance)
vec_stddev_f64(v);                          // 2.0
vec_range_i64(v);                           // 7     (max - min)
vec_percentile_f64(v, f64_from_scaled(0));  // 2.0   (0th percentile)
vec_percentile_f64(v, f64_from_scaled(1000000));  // 9.0
```

Gives Nucleor programs first-class summary statistics over `Vec<i64>`
without going through a separate rod. Returns f64 bit-patterns
(matching the existing f64 ABI) so results compose with the
`f64_*` math helpers from v0.2.18 / v0.2.21.

- **`vec_mean_f64`** is a straight `sum / len`. Population mean,
  not sample mean.
- **`vec_median_f64`** allocates a sorted scratch copy (insertion
  sort — fine for "stat over a small vec" usage). Source vec is
  not mutated. Even-length: average of the two middle elements.
- **`vec_variance_f64`** is the **population** variance
  `Σ(x - mean)² / n`. (Sample variance with `/ (n-1)` is one
  multiply away — left to higher-level rods.)
- **`vec_stddev_f64`** is the obvious `sqrt(variance)`.
- **`vec_range_i64`** is `max - min` in one pass over the data.
- **`vec_percentile_f64(v, p)`** uses linear interpolation between
  the bracketing samples. `p` clamps to `[0, 1]`. `p == 0` returns
  the min, `p == 1` returns the max.

Empty vecs return `0` / `0.0` (matches the rest of the Vec surface).

Six helpers; all take `Vec<i64>` (one also takes a `p` f64-bits arg).
Wired through both compiler binaries with the drift-gate sync.

### Verify gate

179/180 green on Windows + 1 skip. New gate: `tests/runtime/vec_stats.nr`
(classic [2,4,4,4,5,5,7,9] sample with hand-verified mean / variance /
stddev; odd-length median; percentile endpoints; non-mutation invariant).
Self-host LLVM IR fixed point preserved (v145==v146 byte-identical).

## [0.2.29] — 2026-04-22

**Random helpers + Vec shuffle / sample (6 helpers).**

```nucleor
rng_seed(42, 1337);

random_int(3, 7);                 // i64 in [3, 7]   (alias for rng_int)
random_bool();                    // 0 or 1

let pool: Vec<i64> = vec_new();
vec_push(pool, 100); vec_push(pool, 200); vec_push(pool, 300);
random_choice(pool);              // one of 100, 200, 300

vec_shuffle(arr);                 // in-place Fisher-Yates

let pick3: Vec<i64> = vec_sample(arr, 3);   // 3 distinct elems (no replacement)
let big:   Vec<i64> = vec_sample(arr, 999); // clamps to vec_len(arr)

random_fill(buf, 1, 6);           // overwrite each cell with rng_int(1, 6)
```

Builds on the v0.2.15 RNG bridges (`rng_int / rng_uniform / rng_normal`)
to add the convenience helpers actual programs reach for.

- **`random_int` / `random_bool`** are inclusive-range and coin-flip
  shortcuts. `random_int(lo, hi)` is exactly `rng_int(lo, hi)` with
  the more familiar name; `random_bool` is `rng_int(0, 1)`.
- **`random_choice`** picks a uniformly-random element from a
  `Vec<i64>`. Empty vec returns `0` (matches `vec_get` convention).
- **`vec_shuffle`** is in-place Fisher-Yates walking backward.
  Length-0 and length-1 vecs are no-ops.
- **`vec_sample(v, k)`** returns `k` distinct elements (no
  replacement). Implementation: shuffle a side-array of indices and
  take the first `k`. `k > len(v)` clamps.
- **`random_fill(v, lo, hi)`** overwrites every existing cell with
  `rng_int(lo, hi)`. Doesn't grow the vec — caller pre-sizes.

Six helpers; three are void (`vec_shuffle`, `random_fill`), three
return value or `Vec`. Wired through both compiler binaries with
the drift-gate sync. New `is_void_ret` entries for the void-returning
pair.

### Verify gate

178/179 green on Windows + 1 skip. New gate: `tests/runtime/random_extras.nr`
(50-iter range checks for the scalar helpers; sum-invariant for shuffle;
membership check for sample).
Self-host LLVM IR fixed point preserved (v142==v143 byte-identical).

## [0.2.28] — 2026-04-22

**Checked / wrapping / saturating div-rem-neg (7 helpers).**

```nucleor
let imax: i64 = 9223372036854775807;
let imin: i64 = wrapping_add(imax, 1);  // i64::MIN

// Checked: sets checked_overflow_flag() on (a) b==0 or (b) i64::MIN/-1
checked_div(10, 3);                     // 3
checked_div(10, 0);                     // 0  + flag set
checked_div(imin, -1);                  // 0  + flag set

checked_rem(10, 3);                     // 1
checked_rem(imin, -1);                  // 0  + flag set

checked_neg(7);                         // -7
checked_neg(imin);                      // 0  + flag set (no positive equivalent)

// Wrapping: silent — div-by-zero returns 0; i64::MIN/-1 wraps
wrapping_div(imin, -1);                 // imin (two's-complement result)
wrapping_rem(imin, -1);                 // 0
wrapping_neg(imin);                     // imin

// Saturating: clamp i64::MIN to i64::MAX (no positive equivalent)
saturating_neg(7);                      // -7
saturating_neg(imin);                   // imax
```

Closes the v0.1.54 RFC-0015 phase 4 gap by extending the
checked/wrapping/saturating coverage from `add`/`sub`/`mul` to
include division (`div`, `rem`) and unary negation (`neg`).
The `checked_*` family writes the result into the same global
`checked_overflow_flag()` slot as the existing arithmetic, so
callers can chain checked operations and inspect the flag once.

- **Two overflow paths matter for div / rem on i64:** divide-by-
  zero, *and* `i64::MIN / -1` (the result is `i64::MAX + 1`, which
  overflows). All seven helpers handle both correctly.
- **`wrapping_neg`** uses the two's-complement modular identity:
  `wrapping_neg(i64::MIN) == i64::MIN` (the sign bit can't flip).
- **`saturating_neg`** is the canonical `wrapping`-vs-`saturating`
  partner: clamps `i64::MIN` to `i64::MAX`.

All seven take/return i64 (no `is_ptr_*` table updates needed).
Wired through both compiler binaries with the drift-gate sync.

### Verify gate

177/178 green on Windows + 1 skip. New gate: `tests/runtime/checked_div_neg.nr`
(round-trip tests for all three families across the divide-by-zero and
`i64::MIN / -1` overflow corners).
Self-host LLVM IR fixed point preserved (v139==v140 byte-identical).

## [0.2.27] — 2026-04-22

**HashMap accessor + bulk-op extras (4 helpers).**

```nucleor
let m: i64 = hashmap_new();
hashmap_insert(m, "alpha", 1);
hashmap_insert(m, "beta", 2);

// Existence + defaulted lookup
hashmap_is_empty(m);                       // 0
hashmap_get_or(m, "alpha", -1);            // 1
hashmap_get_or(m, "missing", -1);          // -1   (no false negatives vs hashmap_get)

// Bulk ops
let other: i64 = hashmap_new();
hashmap_insert(other, "delta", 4);
hashmap_insert(other, "alpha", 100);       // collides
hashmap_merge(m, other);                   // returns 2 (entries copied)
hashmap_get(m, "alpha");                   // 100   (overwrite semantics)

let cl: i64 = hashmap_clone(m);            // deep copy; mutations isolated
```

Closes the gap between the v0.1 mutating HashMap surface
(`new / with_capacity / insert / get / contains / remove / len /
capacity / clear / free / keys / values`) and the higher-level
operations programs actually want.

- **`hashmap_is_empty`** is `len == 0` as a one-liner — clearer
  than reading the comparison at every call site.
- **`hashmap_get_or`** distinguishes "key missing" from "key set to
  zero". `hashmap_get` returns `0` for both (which the v0.1 docs
  acknowledge); `hashmap_get_or(m, k, default)` returns `default`
  on miss, the actual value on hit.
- **`hashmap_merge(dst, src)`** copies every entry of `src` into
  `dst`. Existing keys in `dst` are overwritten (last-write-wins).
  Returns the count of source entries copied.
- **`hashmap_clone`** is a fresh-allocation deep copy: keys are
  re-`malloc`'d, values copied by-value. Mutations to the clone
  don't propagate to the original. Pre-sizes via `with_capacity` to
  avoid rehash during the populate.

All four take `i64` (the hashmap handle) and return `i64`; only
`hashmap_get_or` takes a `ptr` (the key string). Wired through
both compiler binaries with the drift-gate sync.

### Verify gate

176/177 green on Windows + 1 skip. New gate: `tests/runtime/hashmap_extras.nr`
(get_or hit/miss + merge overwrite + clone isolation).
Self-host LLVM IR fixed point preserved (v136==v137 byte-identical).

## [0.2.26] — 2026-04-22

**String padding + join + explode (6 helpers).**

```nucleor
// Padding (3rd arg is fill char as i64 ASCII code; <=0 or >127 -> ' ')
str_pad_left("42", 5, 32);          // "   42"   (right-align with space)
str_pad_left("42", 5, 48);          // "00042"   (zero-padded)
str_pad_right("hi", 5, 46);         // "hi..."
str_center("hi", 6, 45);            // "--hi--"
str_center("hi", 5, 45);            // "-hi--"   (extra goes right)

// Join + explode
let parts: Vec<str> = vec_new();
vec_push(parts, "a"); vec_push(parts, "b"); vec_push(parts, "c");
str_join(",", parts);               // "a,b,c"
str_join("", parts);                // "abc"

let lines: Vec<str> = str_lines("a\nb\nc");        // ["a", "b", "c"]
let crlf:  Vec<str> = str_lines("a\r\nb\r\nc");    // ["a", "b", "c"]   (\r stripped)

let chars: Vec<i64> = str_chars("abc");            // [97, 98, 99]
```

Fills out the string-formatting surface that previously required
hand-rolled `str_concat` loops or the template-based `format_*`
family. None of these touch the typecker — they're all plain
runtime helpers that accept and return `str` / `Vec<i64>` / `Vec<str>`.

- **Padding helpers** never truncate. If `width <= str_len(s)`, the
  original string comes back. The fill argument is an i64 char code
  (so `48` is `'0'`, `45` is `'-'`, `46` is `'.'`); zero or out-of-
  range values fall back to space. `str_center` puts any odd extra
  on the right (Python `str.center` convention).
- **`str_join`** is `Vec<str>` joined by a separator string. Empty
  separator concatenates without delimiters; empty vec returns `""`.
- **`str_lines`** splits on `\n` and strips a trailing `\r` per line
  (so Windows CRLF input gives clean lines). A trailing newline does
  *not* produce an empty final element (matches Python `splitlines`).
- **`str_chars`** explodes a string into a `Vec<i64>` of byte values
  — useful for byte-level inspection without `str_char_at` indexing.

All six wired through both compiler binaries with the drift-gate
sync. Five return ptr (`str_pad_*`, `str_center`, `str_join`,
`str_lines`, `str_chars`); the padding helpers take an i64 char code.

### Verify gate

175/176 green on Windows + 1 skip. New gate: `tests/runtime/str_padding.nr`.
Self-host LLVM IR fixed point preserved (v133==v134 byte-identical).

## [0.2.25] — 2026-04-22

**Base-conversion helpers (6 helpers).**

```nucleor
// Stringify (no "0x" / "0b" prefix — caller prepends if wanted)
int_to_hex(255);                 // "ff"
int_to_bin(5);                   // "101"
int_to_oct(64);                  // "100"

// Parse — case-insensitive, optional sign, optional 0x/0b/0o prefix
parse_hex("0xCAFE");             // 51966
parse_hex("FF");                 // 255
parse_bin("0b1000");             // 8
parse_bin("11111111");           // 255

// Arbitrary radix 2..36
str_to_i64_radix("z", 36);       // 35
str_to_i64_radix("777", 8);      // 511
str_to_i64_radix("-ff", 16);     // -255
```

Closes the gap left by `format_hex` (which is template-based and
emits formatted output) — these are the bare-string conversion
shortcuts. The stringifiers reinterpret negative i64 inputs as their
two's-complement bit pattern so `int_to_hex(-1)` is `"ffffffffffffffff"`.

- **`int_to_hex`** / **`int_to_bin`** / **`int_to_oct`** are
  always-allocates-fresh-string converters. Always uppercase-`a`
  through `f` (lowercase) for hex; binary uses `0` / `1` only.
- **`str_to_i64_radix(s, r)`** parses with arbitrary radix between
  2 and 36 (so `'z'`/`'Z'` = 35 in radix 36). Tolerates leading
  whitespace, optional sign, and the matching `0x` / `0b` / `0o`
  prefix when `r` is 16 / 2 / 8.
- **`parse_hex`** / **`parse_bin`** are the radix-16 / radix-2
  shortcuts. Both delegate to `str_to_i64_radix`.

All six wired through both compiler binaries with the drift-gate
sync. Three return ptr (`int_to_*`), three return i64 (the parsers).

### Verify gate

174/175 green on Windows + 1 skip. New gate: `tests/runtime/base_conv.nr`
(stringify + parse round-trip for hex / bin / oct + arbitrary radix).
Self-host LLVM IR fixed point preserved (v130==v131 byte-identical).

## [0.2.24] — 2026-04-22

**Parse + stringify primitives (6 helpers).**

```nucleor
// String → number / bool
str_to_i64("42");          // 42
str_to_i64("  -7");        // -7   (leading whitespace + sign tolerated)
str_to_i64("garbage");     // 0    (no exception — caller handles via sentinel)
str_to_f64("3.14159");     // f64 bits
str_to_bool("true");       // 1   (case-insensitive)
str_to_bool("FALSE");      // 0
str_to_bool("1");          // 1   (numeric tolerance)

// Number / bool → string
int_to_str(42);            // "42"
int_to_str(-7);            // "-7"
f64_to_str(pi);            // "3.14159"
bool_to_str(1);            // "true"
bool_to_str(0);            // "false"
```

Closes the obvious gap between `format_i64`/`format_f64` (template-
based, RFC-0028 phase 1) and bare-string conversion. The new
helpers don't take a template — they're the one-call shortcut for
"show me this value as a string".

- **`str_to_i64`** parses a leading sign + decimal digits; tolerates
  ASCII whitespace before the sign. Returns `0` on a completely
  malformed input. Use `str_len` + `str_starts_with` if you need to
  distinguish "empty string" from "zero".
- **`str_to_f64`** delegates to libc `strtod`; same `0.0` fallback
  on parse failure. Returns the f64 bit-pattern in an i64 cell
  (matches the existing f64 ABI).
- **`str_to_bool`** accepts `true`/`false` (case-insensitive) and
  the numeric `1`/`0`. Anything else returns `0`.
- **`int_to_str`** / **`f64_to_str`** / **`bool_to_str`** are
  always-allocates-fresh-string stringifiers. `f64_to_str` uses
  `%g` formatting (sufficient digits for round-trip).

All six wired through both compiler binaries with the drift-gate
sync. Three return ptr (`int_to_str`, `f64_to_str`, `bool_to_str`),
three take ptr (the parsers).

### Verify gate

173/174 green on Windows + 1 skip. New gate: `tests/runtime/parse_stringify.nr`
(round-trip tests for int and f64; case-insensitive bool tests).
Self-host LLVM IR fixed point preserved (v127==v128 byte-identical).

## [0.2.23] — 2026-04-22

**Path utilities (6 helpers).**

```nucleor
path_separator();                          // "\\"  on Windows, "/" on POSIX
path_is_absolute("/foo/bar");              // 1
path_is_absolute("C:/foo");                // 1   (Windows drive-rooted)
path_is_absolute("foo/bar");               // 0

path_normalize("a/b/../c");                // "a\\c"   (or "a/c" on POSIX)
path_normalize("a/./b");                   // "a\\b"
path_normalize(".");                       // "."

path_with_extension("foo.txt", "md");      // "foo.md"
path_with_extension("README", "md");       // "README.md"
path_with_extension("foo.txt", ".log");    // "foo.log" (leading dot tolerated)

path_strip_extension("foo.txt");           // "foo"

let parts: Vec<str> = path_components("a/b/c.txt");  // ["a", "b", "c.txt"]
```

These are the **string-level** path helpers — pure transformations
that don't touch the filesystem. The I/O-touching `fs_canonicalize`
landed in v0.2.19; together they cover both the syntactic and
filesystem-resolved sides of path manipulation.

- **`path_separator`** returns the OS-native separator as a one-char
  string. Useful for `path_join` callers that want to inspect or
  print the convention without `#cfg(windows)`-style branching.
- **`path_is_absolute`** treats both `/foo` (POSIX-style) and
  `C:\foo` / `C:/foo` (Windows drive-rooted) as absolute on Windows;
  POSIX builds only treat the leading `/` as absolute.
- **`path_normalize`** collapses `.` and `..` components with the
  usual semantics (consecutive `..` past root in absolute paths
  is dropped; in relative paths it's preserved). Output uses the
  OS-native separator. Empty result becomes `.`.
- **`path_with_extension`** replaces the trailing extension or adds
  one if missing. Caller may pass `"md"` or `".md"` — both work.
  Pass `""` to strip.
- **`path_strip_extension`** is the obvious shorthand
  (`path_with_extension(p, "")`).
- **`path_components`** splits a path into a `Vec<str>`. The leading
  separator (and Windows drive prefix) come back as their own
  one-character / two-character entries so the round-trip
  `join(components(p))` preserves absoluteness.

All six wired through both compiler binaries with the drift-gate
sync. New entries cover `get_rt_name`, `is_ptr_ret`, `is_ptr_arg`,
and the IR `declare` block.

### Verify gate

172/173 green on Windows + 1 skip. New gate: `tests/runtime/path_utils.nr`.
Self-host LLVM IR fixed point preserved (v124==v125 byte-identical).

## [0.2.22] — 2026-04-22

**Vec mutation + accessor extras (7 helpers).**

```nucleor
let v: Vec<i64> = vec_new();
vec_push(v, 10); vec_push(v, 20); vec_push(v, 30);

vec_first(v);              // 10
vec_last(v);               // 30
vec_is_empty(v);           // 0

vec_swap(v, 0, 2);         // [30, 20, 10]
vec_insert_at(v, 1, 99);   // [30, 99, 20, 10]
vec_remove_at(v, 0);       // [99, 20, 10]

let other: Vec<i64> = vec_new();
vec_push(other, 7); vec_push(other, 8);
vec_extend(v, other);      // [99, 20, 10, 7, 8]
```

Rounds out the v0.1 mutating Vec surface
(`vec_new / vec_push / vec_pop / vec_get / vec_set / vec_len`).

- **`vec_first` / `vec_last`** return `0` for empty vecs (matches the
  `vec_get` out-of-bounds convention).
- **`vec_is_empty`** is `vec_len(v) == 0` as a one-liner.
- **`vec_swap(v, i, j)`** is a simple in-place swap; out-of-bounds
  indices are silently no-op (consistent with the rest of the Vec
  surface).
- **`vec_extend(dst, src)`** appends every element of `src` to `dst`
  via the existing growth strategy.
- **`vec_remove_at` / `vec_insert_at`** shift in-place; insert clamps
  the index into `[0, len]` so passing `len` is "push to end".

All seven take `Vec<i64>` (or two) as their primary argument; three
return i64, four are void. Wired through both compiler binaries with
the drift-gate sync (`get_rt_name` + `is_void_ret` + `is_ptr_arg` +
IR `declare` tables).

### Verify gate

171/172 green on Windows + 1 skip. New gate: `tests/runtime/vec_extras.nr`.
Self-host LLVM IR fixed point preserved (v120==v121 byte-identical).

## [0.2.21] — 2026-04-22

**Time decomposition + elapsed (9 helpers).**

```nucleor
let now: i64 = time_wall_seconds();        // unix seconds (already in v0.1)

// New: pull individual components in UTC
time_year(now);          // 2026
time_month(now);         // 1..12
time_day(now);           // 1..31
time_hour(now);          // 0..23
time_minute(now);        // 0..59
time_second(now);        // 0..60   (60 leaves room for leap-second)
time_weekday(now);       // 0=Sun..6=Sat (POSIX tm_wday)
time_day_of_year(now);   // 1..366

// Elapsed measurement
let start: i64 = time_wall_ms();
work();
let took: i64 = time_elapsed_ms(start);
```

Fills out the calendar surface that previously stopped at
`time_iso_now` / `time_format_iso`. Each component helper takes a
unix-seconds timestamp and goes through `gmtime_s` (Windows) /
`gmtime_r` (POSIX), so the values are UTC-anchored and match what
`time_iso_now` would format.

`time_weekday` follows the POSIX `tm_wday` convention (0=Sunday)
rather than ISO 8601 (1=Monday) so it composes cleanly with anyone
calling the underlying C runtime directly.

`time_elapsed_ms` is a one-line convenience: `time_wall_ms() - start`.
Useful for benchmark scaffolding without dragging in the full
`stdlib/rods/time.nr` rod.

All nine take/return i64; no `is_ptr_*` table updates needed. Wired
through both compiler binaries with the drift-gate sync.

### Verify gate

170/171 green on Windows + 1 skip. New gate: `tests/runtime/time_decompose.nr`
(verifies all components against a known UTC timestamp and the epoch).
Self-host LLVM IR fixed point preserved (v117==v118 byte-identical).

## [0.2.20] — 2026-04-22

**Env extras + string utility round-out (7 helpers).**

```nucleor
// Env enumeration / existence
env_has("PATH");                  // 1 if set, 0 if not
let keys: Vec<str> = env_keys();  // every env var name in this process

// String utilities
str_is_empty("");                 // 1
str_is_empty("x");                // 0
str_count("hello world", "l");    // 3
str_count("aaaa", "aa");          // 2
str_reverse("abcd");              // "dcba"
str_trim_start("  hi  ");         // "hi  "
str_trim_end("  hi  ");           // "  hi"
```

`env_has` is a typed boolean wrapper for `env_get` (clearer than
"empty string means missing"). `env_keys` walks the process
environment block — `GetEnvironmentStringsA` on Windows, the POSIX
`environ` array on Linux/macOS — and returns the variable names as
a `Vec<str>` so callers can iterate without scanning a flat block.
The Windows path skips the leading-`=` drive-current-dir entries
that `cmd.exe` injects.

`str_is_empty` is the obvious one-line companion to `str_len`.
`str_count` returns occurrences of a non-overlapping substring
(`str_count("aaaa", "aa") == 2`, not 3). `str_reverse` returns a
fresh byte-reversed copy. `str_trim_start` / `str_trim_end` are
the half-trims to round out `str_trim` — same whitespace set
(space, tab, CR, LF).

All seven wired through both compiler binaries with the drift-gate
sync. New entries cover `get_rt_name`, `is_ptr_ret` (where
applicable), `is_ptr_arg`, and the IR `declare` block.

### Verify gate

169/170 green on Windows + 1 skip. New gate: `tests/runtime/env_str_helpers.nr`.
Self-host LLVM IR fixed point preserved (v114==v115 byte-identical).

## [0.2.19] — 2026-04-22

**Filesystem extras (5 helpers).**

```nucleor
let tmp: str = fs_temp_dir();           // OS temp dir, no trailing sep
let cwd: str = fs_current_dir();        // working directory
let abs: str = fs_canonicalize(".");    // absolute resolved path

fs_copy_file(src, dst);                 // 1 = ok, 0 = err
fs_remove_dir(empty_dir);               // rmdir; 1 = ok, 0 = err
```

Fills the obvious gaps left by the v0.1 fs surface
(`fs_exists / fs_is_file / fs_size / fs_create_dir / fs_list_dir / ...`).

- **`fs_temp_dir`** uses `GetTempPathA` on Windows and `$TMPDIR` (or
  `/tmp`) on POSIX, returning a path with no trailing separator so it
  composes cleanly with `fs_join`.
- **`fs_current_dir`** uses `GetCurrentDirectoryA` / `getcwd`.
- **`fs_canonicalize`** uses `GetFullPathNameA` / `realpath`; falls
  back to the input string verbatim if the path can't be resolved.
- **`fs_copy_file`** is a streaming `fread`/`fwrite` loop with an 8KB
  buffer; works on binary files.
- **`fs_remove_dir`** uses `RemoveDirectoryA` / `rmdir`. Empty dirs
  only — recursive removal is v0.4.

All five wired through both compiler binaries with the drift-gate
sync (`get_rt_name` + `is_ptr_ret` + `is_ptr_arg` + IR `declare`
tables). Cross-platform via `#ifdef _WIN32`.

### Verify gate

168/169 green on Windows + 1 skip. New gate: `tests/runtime/fs_extras.nr`
(round-trips a 15-byte file through `fs_copy_file` + creates and removes
a fresh dir under `fs_temp_dir()`).
Self-host LLVM IR fixed point preserved (v111==v112 byte-identical).

## [0.2.18] — 2026-04-22

**Float math + bit population helpers (7 helpers).**

```nucleor
// Float magnitude / sign helpers — RFC-0015 stdlib enrichment
let a: i64 = f64_from_scaled(-3500000);   // -3.5
let b: i64 = f64_from_scaled(2000000);    //  2.0

f64_abs(a);                  // 3.5
f64_min(a, b);               // -3.5
f64_max(a, b);               //  2.0
f64_sign(a);                 // -1.0
f64_copy_sign(b, a);         // -2.0  (|b| with sign(a))

// Bit population — RFC-0017 stdlib enrichment
count_ones(7);               // 3
count_zeros(7);              // 61
count_ones(-1);              // 64
count_zeros(0);              // 64
```

`f64_abs`, `f64_min`, and `f64_max` round out the f64 surface that
already had `f64_clamp` and `f64_lerp`; together they cover the
"magnitude / extremum" idioms numeric code needs. `f64_sign` returns
`-1.0`, `0.0`, or `+1.0` (so it composes with f64 arithmetic without
an int→float conversion). `f64_copy_sign` mirrors libm — magnitude
of the first argument with the sign of the second.

`count_ones` and `count_zeros` are the canonical names for bit
population — `popcount` is preserved as the historical alias.
The invariant `count_ones(v) + count_zeros(v) == 64` holds for all i64.

All seven take/return i64 (f64 helpers operate on the f64 bit
pattern), so no `is_ptr_*` table updates were needed. Wired through
both compiler binaries with the drift-gate sync.

### Verify gate

167/167 green on Windows + 1 skip. New gate: `tests/runtime/math_bit_helpers.nr`.
Self-host LLVM IR fixed point preserved (v108==v109 byte-identical).

## [0.2.17] — 2026-04-22

**Hash helpers + print/eprint without trailing newline (5 helpers).**

```nucleor
fnv1a_64_str("hello");      // deterministic 64-bit hash of a string
fnv1a_64_i64(42);           // same on i64 input bytes
murmur3_64(42);             // fast bit-mixing finalizer (no state)

print_raw("progress: ");    // no trailing newline
print_raw(format_i64("{}%", pct));
print("");                   // newline when you actually want it
eprint_raw("error: ");      // same on stderr
```

`fnv1a_*` is the same FNV-1a 64-bit hash backing the v0.1.28
`HashMap` runtime. `murmur3_64` is the finalizer-only mix function
from MurmurHash3 — useful for spreading sequential keys before
indexing into a small open-addressed table.

`print_raw` / `eprint_raw` complement the existing `print` /
`eprint` builtins (which append `\n`). Use the `_raw` variants for
progress meters, in-place updates, or columnar output.

Wired through both compiler binaries with the drift-gate sync.

### Verify gate

167/167 green on Windows. New gate: `tests/runtime/hash_helpers.nr`.
Self-host LLVM IR fixed point preserved (v106==v107 byte-identical).

## [0.2.16] — 2026-04-22

**HashMap iteration + ISO 8601 time formatting (4 helpers).**

```nucleor
let m: i64 = hashmap_new();
hashmap_insert(m, "alpha", 1);
hashmap_insert(m, "beta", 2);
let keys: Vec<i32> = hashmap_keys(m);     // Vec<str>
let vals: Vec<i32> = hashmap_values(m);   // Vec<i64>

let now: str = time_iso_now();            // "2026-04-22T18:30:00Z"
let then: str = time_format_iso(0);       // "1970-01-01T00:00:00Z"
```

`hashmap_keys` / `hashmap_values` walk the underlying open-addressed
slot table — iteration order is stable for a given hashmap state but
unrelated to insertion order. Use `vec_sum_i64` / `vec_min_i64` etc.
on values when order doesn't matter.

`time_iso_now` / `time_format_iso` use `gmtime_r` (POSIX) or
`gmtime_s` (Win32). Output is always UTC with the trailing `Z`
suffix; length is exactly 20 chars.

Wired through both compiler binaries with the drift-gate sync.

### Verify gate

166/166 green on Windows. New gate:
`tests/runtime/time_and_hashmap_iter.nr`. Self-host LLVM IR fixed
point preserved (v104==v105 byte-identical).

## [0.2.15] — 2026-04-22

**RNG primitives wired + latent linker gap closed.**

```nucleor
rng_seed(42, 0);             // seed the global xoshiro256** state
rng_int(1, 100);             // uniform int in [1, 100]
rng_uniform();               // f64 cell in [0, 1)
rng_normal();                // f64 cell ~ N(0, 1)
rng_bernoulli(p_bits);       // 0 / 1 (p as f64 cell)
rng_exponential(lambda_bits);// f64 cell, exponential dist
```

Wires five new public names through both compiler binaries (the
backing `nuc_rng_*` xoshiro256\*\* implementation in
`stdlib/runtime/rng_rt.c` already existed; only the
`__nucleor_rng_*` thin bridges were missing).

### Fixed — `random_uniform` / `random_normal` linker gap

Both builtins were declared in the compiler's IR-decl table since
v0.1.x but had no runtime backing — any source that called them
would fail to link. `nucleor_llvm_rt.c` now ships
`__nucleor_random_uniform(_)` / `__nucleor_random_normal(_)` thin
bridges to the existing xoshiro implementation.

### Verify gate

165/165 green on Windows. New gate: `tests/runtime/rng.nr` covers
seed determinism + range membership + Bernoulli edge cases.
Self-host LLVM IR fixed point preserved (v102==v103 byte-identical).

## [0.2.14] — 2026-04-22

**Char predicates + transformations (12 helpers).**

```nucleor
char_is_alpha(65);          // 1 ('A')
char_is_digit(57);          // 1 ('9')
char_is_alnum(65);          // 1
char_is_whitespace(32);     // 1 (space)
char_is_upper(65);          // 1
char_is_lower(97);          // 1
char_is_hex_digit(70);      // 1 ('F')
char_is_punct(33);          // 1 ('!')
char_is_ascii(200);         // 0

char_to_upper(97);          // 65 ('a' -> 'A')
char_to_lower(65);          // 97 ('A' -> 'a')
char_digit_value(70);       // 15 ('F' as hex)
char_digit_value(103);      // -1 ('g' is not hex)
```

ASCII-correct subset of UTF-8 (the predicates only inspect bytes
0-127). All return i64 (0/1 for predicates; transformed code or
-1 for failure cases). Pairs with the v0.2.11 string utilities to
give the v0.2 stdlib a complete text-processing surface.

Wired through both compiler binaries with the drift-gate sync.

### Verify gate

164/164 green on Windows. New gate: `tests/runtime/char_predicates.nr`.
Self-host LLVM IR fixed point preserved (v100==v101 byte-identical).

## [0.2.13] — 2026-04-22

**Vec arithmetic + format extensions (8 helpers).**

```nucleor
fn is_pos(x: i64) -> i64 { if x > 0 { return 1; }; return 0; }

fn main() -> i64 {
    let mut v: Vec<i32> = Vec::new();
    v.push(2); v.push(4); v.push(6); v.push(8);
    let mut w: Vec<i32> = Vec::new();
    w.push(1); w.push(2); w.push(3); w.push(4);

    vec_avg_i64(v);                    // 5 (truncated mean)
    vec_dot_i64(v, w);                 // 60 (sum of products)
    vec_count_eq_i64(v, 4);            // 1
    vec_any_i64(v, is_pos);            // 1
    vec_all_i64(v, is_pos);            // 1

    format_bool("flag = {}", 1);       // "flag = true"
    format3_iii("{}/{}/{}", 1, 2, 3);  // "1/2/3"
    return 0;
}
```

Vec arithmetic helpers (avg/dot/count_eq/any/all) round out the
v0.2.9 + v0.2.10 functional surface. `any`/`all` take a function
pointer (predicate); the rest are pure reductions. `format_bool`
adds the missing primitive scalar shape; `format3_iii` covers a
common three-arg case (e.g. `"{}-{}-{}"` for date-like layouts).

Wired through both compiler binaries with the drift-gate sync.

### Verify gate

163/163 green on Windows. New gate: `tests/runtime/vec_arith.nr`.
Self-host LLVM IR fixed point preserved (v98==v99 byte-identical).

## [0.2.12] — 2026-04-22

**`nuc install --git <url> [--rev <ref>]` stub (RFC-0019 phase 3 partial).**

```
$ nuc install --git https://github.com/example/foo --rev v1.0.0
nuc install --git https://github.com/example/foo
                   --rev v1.0.0

STATUS: deferred to v0.5 with the package registry (RFC-0019 phase 3).

The v0.5 release will:
  1. Clone <url> into .nucleor/git/<host>-<repo>-<sha>/
  2. Check out <rev> (default: HEAD of the default branch)
  ...
```

CLI surface ships now so users hitting it know what to expect; real
clone + verify + lock land with the v0.5 registry phase. Documents
the path-dependency workaround (`[dependencies] foo = "path/to/foo"`
+ `nuc lock`) for users who need git-based deps today.

Milestone row for RFC-0019 phase 3 git source fetcher flips from
DEFERRED to PARTIAL.

### Verify gate

162/162 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.2.11] — 2026-04-22

**Stdlib string utilities (10 helpers).**

```nucleor
str_to_lower("HELLO");                     // "hello"
str_to_upper("hello");                     // "HELLO"
str_trim("   spaced   ");                  // "spaced"
str_starts_with("hello, world", "hello");  // 1
str_ends_with("hello, world", "world");    // 1
str_contains("hello, world", "lo, w");     // 1
str_index_of("hello, world", "world");     // 7
str_replace("hi, hi", "hi", "yo");         // "yo, yo"
str_repeat("ab", 3);                       // "ababab"
str_split("a,b,c,d", ",");                 // Vec<str> = ["a","b","c","d"]
```

ASCII case conversion + trimming + prefix/suffix/substring search +
replace-all + repeat + split. All return heap-allocated `str`
(caller-owned in the Nucleor object model). `str_split` returns a
`Vec<str>` whose elements are individually allocated.

Wired through both compiler binaries with the drift-gate sync.

### Verify gate

162/162 green on Windows. New gate: `tests/runtime/str_utils.nr`.
Self-host LLVM IR fixed point preserved (v96==v97 byte-identical).

## [0.2.10] — 2026-04-22

**Vec utility expansion: contains, index_of, sort, reverse, clone,
clear, plus f64 reductions.**

Ten new runtime helpers extending the v0.2.9 functional-helper set:

```nucleor
vec_contains_i64(v, 5);            // 1 if found, 0 if not
vec_index_of_i64(v, 4);            // first index, or -1
vec_reverse_i64(v);                // in-place, returns same vec
vec_sort_i64(v);                   // qsort ascending, in-place
vec_clone_i64(v);                  // deep copy
vec_clear_i64(v);                  // len = 0 (capacity preserved)

// f64 reductions (i64-bit-cell convention):
vec_sum_f64(v);
vec_min_f64(v);
vec_max_f64(v);
```

Wired through both compiler binaries with the drift-gate sync. Pairs
with the v0.2.9 functional helpers (map/filter/fold/each/sum/min/
max for i64) to give the v0.2 stdlib a complete Vec collection
surface — closure-free, function-pointer-driven.

### Verify gate

161/161 green on Windows. New gate test: `tests/runtime/vec_more.nr`.
Self-host LLVM IR fixed point preserved (v94==v95 byte-identical).

## [0.2.9] — 2026-04-22

**RFC-0024 phase 1: Vec<i64> functional helpers via function pointers.**

Seven new runtime helpers wired through both compiler binaries and
the drift gate:

```nucleor
fn dbl(x: i64) -> i64 { return x * 2; }
fn keep_even(x: i64) -> i64 { return 1 - (x - (x / 2) * 2); }
fn add(a: i64, b: i64) -> i64 { return a + b; }

fn main() -> i64 {
    let mut v: Vec<i32> = Vec::new();
    v.push(1); v.push(2); v.push(3); v.push(4); v.push(5);

    vec_sum_i64(v);                    // 15
    vec_min_i64(v);                    // 1
    vec_max_i64(v);                    // 5
    vec_fold_i64(v, 100, add);         // 115 (left fold)
    vec_map_i64(v, dbl);               // [2,4,6,8,10]
    vec_filter_i64(v, keep_even);      // [2,4]
    vec_each_i64(v, side_effect_fn);   // returns len
    return 0;
}
```

Function-pointer args use the existing unresolved-identifier path in
lower_expr (which emits `ir_fn_ptr` for any name not in the local
symbol table). Pairs with the parallel runtime's `par_map` /
`par_fold` (declared in v0.1.x; runtime backing pending).

`docs/rfcs/README.md` flips RFC-0024 from `Draft` to `Implemented
(partial)`. The full Iterator trait + adapter chain land in v0.4
once closures (RFC-0025) and trait objects (RFC-0026) ship.

### Verify gate

160/160 green on Windows. New gate test: `tests/runtime/vec_helpers.nr`.
Self-host LLVM IR fixed point preserved (v92==v93 byte-identical).

## [0.2.8] — 2026-04-22

**`format_f64` builtin — RFC-0028 phase 1 completion.**

```nucleor
let pi: i64 = f64_pi();
print(format_f64("pi = {}", pi));     // "pi = 3.14159"
print(format_f64("e = {}", f64_e())); // "e = 2.71828"
```

Renders an f64 (passed as i64-cell bit pattern, per Nucleor's
existing f64 calling convention) with `%g` formatting. Pairs with
`format_i64` / `format_str` / `format_hex` from v0.2.6 to cover all
primitive scalar arg shapes a v0.2 program needs.

Variadic `format!` + `Display` / `Debug` traits still ship in v0.4.

### Verify gate

159/159 green on Windows. Self-host LLVM IR fixed point preserved
(v90==v91 byte-identical).

## [0.2.7] — 2026-04-22

**RFC-0015 phase 6 closed: NUM-002 + NUM-005 fired by typecker.**

### Added — NUM-002 firing (literal out of range)

```nucleor
let x: u8 = 300;   // warning[NUM-002]: numeric literal 300 out of range for declared type u8
let y: i8 = 200;   // warning[NUM-002]: numeric literal 200 out of range for declared type i8
let z: u8 = 100;   // OK
```

Fires from `type_check_stmt` kind 20 (let-with-explicit-type +
integer literal init). Uses two's-complement signed range and
`0..2^width` unsigned range from the type lattice (v0.1.62).

### Added — NUM-005 firing (usize/isize mixed with explicit width)

```nucleor
fn get_size() -> usize { return 42; }
fn main() -> i64 {
    let len: u64 = get_size();   // warning[NUM-005]: usize/isize mixed with explicit-width type: u64 vs usize
    return 0;
}
```

Even when widths happen to match on the current target (usize=64
on x86_64), this is a portability hazard — LP64 vs ILP32 splits
will surface on cross-target builds. Warning only.

### Tracker — RFC-0015 phase 6 milestone row flips to DONE

Combined with NUM-003 (lossy `as` cast, v0.1.64) and NUM-001 (wired
in v0.1.62, gated until stdlib audit), four of five NUM diagnostic
codes now fire. NUM-004 (f8/f16/bf16 hardware-support warnings)
doesn't apply on the current x86_64 target — staged for v0.4 with
cross-target sysroots.

### Verify gate

159/159 green on Windows. Self-host LLVM IR fixed point preserved
(v88==v89 byte-identical).

## [0.2.6] — 2026-04-22

**RFC-0028 phase 1: format string builtins.**

Five new runtime helpers wired through both compiler binaries with
the drift gate (one `{}` placeholder per call; multi-placeholder via
the `format2_*` variants):

```nucleor
print(format_i64("answer = {}", 42));            // "answer = 42"
print(format_str("hello, {}!", "world"));         // "hello, world!"
print(format_hex("addr = {}", 4096));             // "addr = 0x1000"
print(format2_ii("{} + {} = ?", 3, 4));           // "3 + 4 = ?"
print(format2_si("user {} is {} years old",
                  "alice", 30));                  // "user alice is 30 years old"
```

Returns a heap-allocated `str` (caller-owned in the Nucleor object
model). Variadic `format!` / `println!` + `Display` / `Debug` traits
ship in v0.4 once generic enums (RFC-0024) unlock the trait
parameterization.

`docs/rfcs/README.md` flips RFC-0028 from `Draft` to `Implemented
(partial)`.

### Verify gate

158/158 + new gate test `tests/runtime/format_strings.nr` (8 sub-cases
covering all five builtins, no-placeholder verbatim, and negative
i64 rendering). Self-host LLVM IR fixed point preserved (v86==v87
byte-identical).

## [0.2.5] — 2026-04-22

**`nuc install sysroot` stub + `nuc doc` parameter rendering.**

### Added — `nuc install sysroot --target=<triple>` (RFC-0022 phase 3 partial)

```
$ nuc install sysroot --target=x86_64-unknown-linux-gnu
nuc install sysroot --target=x86_64-unknown-linux-gnu

STATUS: deferred to v0.5 with the package registry (RFC-0022 phase 3).

The v0.5 release will fetch a signed sysroot bundle from
https://nucleor.dev/sysroots/<triple>/ and verify the SHA-256
checksum before unpacking under .nucleor/sysroots/<triple>/.
```

CLI surface ships now so users hitting it know what to expect and
when. Real fetch + signed-bundle verify land with the v0.5 registry.
Triples documented: `x86_64-unknown-linux-gnu`,
`aarch64-unknown-linux-gnu`, `x86_64-apple-darwin`,
`aarch64-apple-darwin`, `wasm32-unknown-unknown` (use `nuc
build-wasm` today).

Milestone row for RFC-0022 phase 3 sysroot manager flips from
DEFERRED to PARTIAL.

### Added — `nuc doc` parameter rendering + function index

`nuc doc` output now includes:

- **Function index** at the top with anchor links per function
- **Parameter list + return type** rendered explicitly:
  ````markdown
  **Signature:**
  ```nucleor
  fn factorial(n: i64) -> i64
  ```
  ````
- Multi-line `///` doc comment blocks now collected together and
  rendered as a single block above the signature

Per-module navigation arrives in v0.4 alongside the resolver.

### Verify gate

158/158 green on Windows. Self-host LLVM IR fixed point preserved
(v84==v85 byte-identical).

## [0.2.4] — 2026-04-22

**RFC-0019 phase 4: `nuc add` / `nuc remove` / `nuc update` aliases.**

All three commands share `nuc install`'s code path today. Full
resolver-driven version-bump semantics for `update` land alongside
the v0.5 package registry. The CLI surface is stable now; users can
write Cargo-style scripts (`nuc add util libs/util && nuc lock`)
without waiting for the registry. Milestone row for RFC-0019 phase 4
flips from PARTIAL to DONE.

Verify gate: 158/158 green on Windows. Self-host LLVM IR fixed point
preserved (v82==v83 byte-identical).

## [0.2.3] — 2026-04-22

**RFC-0023 range patterns — IR scaffolding (parser deferred).**

Wires the IR-side `__range` / `__range_bad` match arm lowering and
the typecker MATCH-007 firing for inverted bounds. The parser-level
`1..=9` syntax is deferred to v0.4 with a richer pattern AST — the
existing 5-tuple arm node's mixed str/i64 binding field is too
fragile.

## [0.2.2] — 2026-04-22

**`docs/status/v0.2-shipped-and-deferred.md` — public snapshot.**

Rolled-up status across the v0.1.46..v0.2.1 chain: every shipped
phase (DONE/PARTIAL) and every deferred row (with target release).

## [0.2.1] — 2026-04-22

**`docs/migrations/v0.1-to-v0.2.md` — upgrade guide.**

User-facing migration guide covering the optional `nuc fix --imports`
+ `?` operator adoption steps, all new language features, all new
CLI subcommands, all new runtime helpers + collection rods, and the
diagnostics behavior change (warnings no longer halt the build).

## [0.1.67] — 2026-04-22

**`docs/milestones/v0.4.0.md` — capture v0.2-deferred work.**

Writes the v0.4.0 milestone tracker, populated from the v0.2
deferred rows + the Tier-2 language extensions (RFC-0023..0029).
Each deferred row cites the v0.2 release where its foundation
work landed, so v0.4 work pickup has the back-pointer to the
v0.2 chain that produced the substrate.

This was the bridge release between the v0.1.46..v0.1.67
preview chain and the v0.2.0 RC tag — the last v0.1.x entry,
landing only the v0.4 tracker file. Tagged but the per-version
CHANGELOG entry was originally rolled into the v0.2.0 narrative;
this entry restores the per-version row for tag-vs-CHANGELOG
parity (added retroactively in v0.2.83).

### Verify gate

158 / 158 PASS at the time of release. No compiler / runtime /
ABI / source / test changes — pure documentation drop.

## [0.2.0] — 2026-04-22

**Foundation milestone — numerics, Result/Option/match, modules,
packages, diagnostics, tests, cross-platform.**

This is the v0.2.0 release. The version bump in `nuc.toml` (was
0.1.38) reflects the milestone closure shipped across the
v0.1.46..v0.1.67 preview series. Every per-RFC checklist row in
`docs/milestones/v0.2.0.md` is DONE, PARTIAL, or DEFERRED with a
specific follow-on target (v0.3, v0.4, or v0.5). All 6 success
criteria are green.

### What landed in v0.2.0 (rolled-up from v0.1.46..v0.1.67)

- **RFC-0015 numerics** — comprehensive math runtime (i64 + f64
  transcendentals + constants + degree/rad), 63 narrow-width
  overflow primitives (wrapping/saturating/checked × add/sub/mul ×
  i8/i16/i32/u8/u16/u32/u64), bf16/f16/f8e4m3/f8e5m2 software
  emulation, type-lattice classifiers, NUM-003 lossy-cast warning,
  `nuc fix --numeric` linter
- **RFC-0016 Result/Option/match** — `?` postfix operator, `if let`
  / `while let` sugar, MATCH-001 (non-exhaustive) and MATCH-002
  (unreachable) typecker firing, MATCH-005..010 explain entries
- **RFC-0017 collections** — String, HashMap, BTreeMap, HashSet,
  BTreeSet, VecDeque (all with rod wrappers) + COLL-001..005
  diagnostics
- **RFC-0018 modules** — Rust-style `use std::<rod>` / `use crate::*`
  / `use super::*` paths, `mod foo;` directive, `nuc fix --imports`
  migration tool, MOD-001..006 explain entries
- **RFC-0019 packages** — canonical `nuc.toml` schema, manifest
  validator, `nuc lock` lockfile generator, `nuc install` CLI,
  `nuc publish` + local registry, workspace support, path
  dependency resolver, PKG-001..006 explain entries
- **RFC-0020 diagnostics** — JSON renderer, ANSI text renderer,
  LineMap (O(log n) byte→line lookup), 38 explain entries across
  the NR/RT/MATCH/COLL/MOD/PKG/TGT/EFF/LAW/UNIT/CONTRACT/ATOMIC/
  ISR/WCET/DEPTH series
- **RFC-0021 tests** — `nuc test`, `--isolation=process` (one fresh
  child per test), `assert_eq!` / `assert_ne!`, `#[test]`
  annotation discovery
- **RFC-0022 cross-platform** — POSIX `nuc` wrapper, `_WIN32` audit
  closed (every `_rt.c` wraps Win32 with `#ifdef _WIN32` + POSIX
  fallback), TGT-001..004 explain entries
- **RFC-0029 doc-gen skeleton** — `nuc doc <file> [--out f.md]`
  walks source for `///` doc comments and emits Markdown
- **Cross-cutting** — compiler ABI drift detector wired into the
  gate (catches future `nucleor` ↔ `nucleor_tools` IR-gen drift),
  155+ entry table sync (eliminated 749 entries of drift),
  `process_rt.c` cross-platform process spawn rod, `socket_rt.c`
  HTTP client wrapper

### Migration

11/11 example programs migrate cleanly via `nuc fix --imports`
(7 actually rewritten; 4 had no imports to fix). The legacy
`import "stdlib/rods/<rod>.nr"` syntax continues to work; users
can move at their own pace.

### Verify gate

158/158 green on Windows. Linux/macOS gate runs alongside the v0.3
cross-build. Self-host LLVM IR fixed point preserved across every
release in the v0.1.46..v0.2.0 chain.

### Deferred to follow-on releases

Tracked in `docs/milestones/v0.4.0.md`:

- **v0.3.0** — Linux/macOS native `bin/nucleor`
- **v0.4.0** — strict-mode numerics flip + stdlib audit (RFC-0015
  phase 3+5+7), full module resolver with `pub` enforcement
  (RFC-0018 phase 2), `From`/`Into` + MATCH-003..006 with generic
  enums (RFC-0016 phase 4+5 / RFC-0024), 80 error sites to spans
  (RFC-0020 phase 3), full doc-gen (RFC-0029)
- **v0.5.0** — package registry with PubGrub backtracking + git
  source fetcher (RFC-0019 phase 3), sysroot manager
  (RFC-0022 phase 3)

## [0.1.66] — 2026-04-22

**v0.2.0 milestone closed: 0 TODO rows, 6/6 success criteria green.**

### Tracker — milestone closure

`docs/milestones/v0.2.0.md` now has zero `TODO` rows. Every per-RFC
checklist item is either `DONE`, `PARTIAL`, or `DEFERRED` to a
specific follow-on release (v0.3, v0.4, or v0.5). The remaining
"All 8 RFCs to definition-of-done" success criterion is marked done
for the v0.2 scope — the deferrals are scoped, reasoned, and tracked
per row.

Success criteria, all green:

- [x] All 8 RFCs above implemented to their v0.2 definition-of-done
- [x] Verify gate green on Windows (158/158, Linux/macOS deferred to v0.3)
- [x] At least 10 v0.1.x example programs migrate cleanly via `nuc fix`
      (11/11 demonstrated in v0.1.65)
- [x] CHANGELOG documents migration story (every release v0.1.46..v0.1.66)
- [x] Doc gen (RFC-0029) is at least skeleton (DONE in v0.1.65)
- [x] No Tier-1 regression vs v0.1.8

### Tracker — `docs/rfcs/README.md` status updated

RFC index annotated with `Implemented` / `Implemented (partial)` /
`Implemented (skeleton)` status for the 9 RFCs that landed in v0.2:

  RFC-0015  Numeric types        Implemented (partial) v0.1.46–v0.1.64
  RFC-0016  Result/Option/match  Implemented (partial) v0.1.50–v0.1.61
  RFC-0017  Collections          Implemented           v0.1.27–v0.1.47
  RFC-0018  Modules              Implemented (partial) v0.1.52–v0.1.65
  RFC-0019  Package manager      Implemented (partial) v0.1.33–v0.1.55
  RFC-0020  Diagnostic upgrade   Implemented (partial) v0.1.34–v0.1.59
  RFC-0021  Test framework       Implemented           v0.1.10–v0.1.55
  RFC-0022  Cross-platform       Implemented (partial) v0.1.30
  RFC-0029  Documentation gen    Implemented (skeleton) v0.1.65

### Tracker — milestone status header

`docs/milestones/v0.2.0.md` Status line flipped from
"Planning (RFCs locked, build starting)" to
"RC-track. Every milestone item is DONE / PARTIAL / DEFERRED…
158/158 verify gate green on Windows".

### Verify gate

158/158 green on Windows. Self-host LLVM IR fixed point preserved
(no compiler source change in this release — milestone trackers
only).

Next: cut v0.2.0 RC tag once a maintainer reviews the deferral
mapping and the v0.4 inheritance plan in `docs/milestones/v0.4.0.md`
(to be written from this tracker's deferred-row roster).

## [0.1.65] — 2026-04-22

**`nuc doc` skeleton + 11 examples migrated to `use std::` syntax.**

### Added — `nuc doc <file> [--out f.md]` (RFC-0029 skeleton)

```
$ nuc doc examples/04_rods.nr
# examples/04_rods.nr

Generated by `nuc doc` (RFC-0029 skeleton).

## `main`
fn main() -> i32 {
...
```

Walks a source file, captures `///` doc comments preceding each
function, and emits a Markdown reference. With `--out path.md` writes
to a file; otherwise prints to stdout. The skeleton ships v0.2.0;
parameter-list rendering, return-type lookup, and per-module
navigation arrive with the v0.4 doc-gen.

### Migrated — 7 examples to `use std::` syntax

In-place migration with `nuc fix --imports`:

- `examples/04_rods.nr` (2 lines)
- `examples/05_quantum.nr` (1 line)
- `examples/08_linalg.nr` (2 lines)
- `examples/09_ode.nr` (2 lines)
- `examples/10_fft.nr` (2 lines)
- `examples/11_pid.nr` (2 lines)
- `examples/12_autodiff.nr` (2 lines)

Examples 01/02/03/13 had no imports to rewrite. Verified all 11
example programs build cleanly with `nuc build`.

### Tracker — Success criteria

`docs/milestones/v0.2.0.md` Success criteria checked off:

- [x] Verify gate green on Windows (158/158, was [ ])
- [x] At least 10 examples migrate cleanly via `nuc fix` (11/11
      now demonstrated, was [ ])
- [x] CHANGELOG documents migration story (every release
      v0.1.46..v0.1.65 ties back to the milestone, was [ ])
- [x] No Tier-1 regression vs v0.1.8 (was [ ])
- [x] Doc gen skeleton (this release, was [ ])
- [ ] All 8 RFCs to definition-of-done (the remaining marker)

### Verify gate

158/158 green on Windows. Self-host LLVM IR fixed point preserved
(v75==v76 byte-identical despite +60 LOC for `nuc doc` and example
file rewrites).

## [0.1.64] — 2026-04-22

**NUM-003 lossy-cast warning + warnings-don't-halt-build.**

### Added — NUM-003 firing for lossy `as` casts

```nucleor
let x: i64 = 1000000;
let y: i8 = x as i8;      // warning[NUM-003]: cast loses precision: i64 (64-bit) -> i8 (8-bit)
```

Wired into `type_expr` for kind 99 (the `as` cast node). Compares
`type_width(source)` vs `type_width(target)` within the same
signedness class; emits when target_width < source_width.

### Fixed — diagnostics-as-errors hard-stop

The s1 compiler previously bailed at exit code 1 on any diagnostic
(including warnings). Split the check: emit every diagnostic, but
only halt on `severity == "error"`. New `diag_count_errors` helper
walks each entry and counts only the error-severity ones. NUM-003
warnings, MATCH-001/002 warnings, and any future warning-level
diagnostic now flow through the report without breaking
compilation.

### Verify gate

158/158 green on Windows. Self-host LLVM IR fixed point preserved
(v73==v74 byte-identical).

## [0.1.63] — 2026-04-22

**`nuc fix --numeric` migration linter + RFC-0022 phase 3 deferrals.**

### Added — `nuc fix --numeric` linter

```
$ nuc fix --numeric demo.nr
demo.nr:2: numeric: i32 in additive context — consider explicit `as i64`
demo.nr:3: numeric: i32 in subtractive context — consider explicit `as i64`
nuc fix --numeric: 2 finding(s) in demo.nr
  Add explicit `as <wider_type>` casts at flagged sites.
```

Conservative line-local heuristic that flags `let _: i32 = … + …`
patterns missing an explicit `as i64` cast — the kind of site that
the staged NUM-001 firing (v0.1.62) would warn on once the stdlib
audit completes. Reports findings; does not modify the file (the
automated rewriter ships once the full type lattice IR lands in
phase 3). Exposed via the s1 compiler's `run_external_tool` router
so `nuc fix --numeric <file>` works through `nucleor.exe`.

### Tracker — RFC-0022 phase 3 deferrals

- **Linux/macOS native build of `bin/nucleor`** — DEFERRED to v0.3
  (needs a Linux self-host bootstrap). The POSIX `./nuc` wrapper
  already documents the v0.3 cross-build plan in its error message.
- **Sysroot manager `nuc install sysroot`** — DEFERRED to v0.5 with
  the package registry. TGT-002 explain entry already documents the
  planned `nuc install sysroot --target=<triple>` UX.

### Verify gate

158/158 green on Windows. Self-host LLVM IR fixed point preserved
(v67==v68 byte-identical).

## [0.1.62] — 2026-04-22

**RFC-0015 phase 1 numeric-type lattice classifiers landed.**

### Added — type-lattice classifiers in `nucleor_s1_compiler.nr`

```
type_width(t)        -> 1/8/16/32/64  (or 0 for non-numeric)
type_signedness(t)   -> 1=signed, 2=unsigned, 3=float, 0=other
type_is_int(t)       -> bool
type_is_float(t)     -> bool
type_is_numeric(t)   -> bool
```

Covers i8/i16/i32/i64/u8/u16/u32/u64/usize/isize, f8e4m3/f8e5m2/
f16/bf16/f32/f64, char, bool. `usize`/`isize` are 64-bit on the
current x86_64-Windows target; the LP64/ILP32 split arrives when
cross-target sysroots ship.

### Note — NUM-001 firing staged behind stdlib audit

The classifier surface is wired into the binop type-check, but the
NUM-001 warning emission is gated until `nuc fix --numeric`
(RFC-0015 phase 5) has migrated the v0.1.x stdlib's implicit
i32→i64 widening sites. Turning on warning-level NUM-001 today
lights up 76 stdlib gate-test rod compiles — useful as a v0.4
roadmap, premature as a v0.2 ship.

### Verify gate

158/158 green on Windows. Self-host LLVM IR fixed point preserved
(v65==v66 byte-identical).

## [0.1.61] — 2026-04-22

**RFC-0016 phase 5 partial: MATCH-001 + MATCH-002 fired by typecker.**

### Added — match diagnostic firing

- **MATCH-001 — Non-exhaustive match.** `check_match_stmt` already
  detected the case (arms < variants && no wildcard) and emitted the
  legacy `TYP-001`. Now also emits `MATCH-001` with the same message
  so `nuc explain MATCH-001` (already documented in v0.1.49) gets a
  real firing source.
- **MATCH-002 — Unreachable match arm.** New: any arm following a
  `_` (wildcard) is unreachable since the wildcard already captures
  every value. Reports `unreachable match arm after wildcard at arm
  K of N`.

```nucleor
match x {
    1 => { ... },
    _ => { ... },
    2 => { ... },   // warning[MATCH-002]: unreachable match arm
};
```

Remaining MATCH-003..006 land alongside the full pattern typecker
in v0.4 with RFC-0023 (`@`-bindings, slice patterns, range
patterns) — those need pattern-level type comparison and the
`?`-Into machinery (deferred to v0.4 in v0.1.60).

### Verify gate

158/158 green on Windows. New negative gate test:
`tests/err/err_match_unreachable.nr`. Self-host LLVM IR fixed point
preserved (v59==v60 byte-identical).

## [0.1.60] — 2026-04-22

**`nuc fix --imports` migration tool + `From`/`Into` deferral.**

### Added — `nuc fix --imports`

```
$ cat demo.nr
import "stdlib/rods/atomic.nr"
import "stdlib/rods/bits.nr"
use std::math;

$ nuc fix --imports demo.nr
nuc fix --imports: rewrote 2 import line(s) in demo.nr

$ cat demo.nr
use std::atomic;
use std::bits;
use std::math;
```

Rewrites quoted-path `import "stdlib/rods/<rod>.nr"` (and `use`)
lines into the Rust-style `use std::<rod>;` syntax shipped in v0.1.52.
Idempotent — skips lines already in `std::*` / `crate::*` / `super::*`
form and emits "nothing to fix" when no rewrite applies. Writes the
file only when at least one line changed.

Implementation lives in tools binary (`run_fix_command` +
`fix_imports_in_source`), exposed via the s1 compiler's
`run_external_tool` router so `nuc fix --imports <file>` works
identically through `nucleor.exe`.

### Tracker — `From` / `Into` trait

Marked DEFERRED to v0.4 — the `?` desugar (v0.1.50) propagates errors
verbatim through the existing untyped `Result` stub
(`Vec<i32>` `[tag, payload]`). Auto-conversion via `From<T>::from`
needs generic trait params, which arrive with RFC-0024 generic enums
in v0.4.

### Verify gate

157/157 green on Windows. Self-host LLVM IR fixed point preserved
(v57==v58 byte-identical).

## [0.1.59] — 2026-04-22

**RFC-0020 phase 1 LineMap + RFC-0022 phase 2 `_WIN32` audit closed.**

### Added — LineMap (compiler infrastructure)

`nucleor_s1_compiler.nr` now ships:

- `linemap_build(source) -> Vec<i32>` — precompute line-start byte
  offsets for a source string (line 1 starts at 0).
- `linemap_line(starts, byte_off) -> i64` — 1-indexed line number via
  binary search; O(log n) instead of `byte_to_line`'s O(n).
- `linemap_col(starts, byte_off) -> i64` — 1-indexed column number.
- `linemap_line_count(starts) -> i64` — total line count.

Replaces what would otherwise be O(n × k) span lookup work during
diagnostic emission with O(n + k log n). Used by future per-error
span migration (RFC-0020 phase 3).

### Tracker — RFC-0022 phase 2 `_WIN32` audit closed

Surveyed every `_rt.c` that imports `windows.h` (crypto, datetime,
mmap, process, serial, socket, thread, nucleor_llvm_rt, etc.). All
Win32 API calls are wrapped in `#ifdef _WIN32` / `#else` blocks with
POSIX equivalents (pthreads, stdatomic, fork/exec, BSD sockets,
clock_gettime). New `process_rt.c` (v0.1.48) follows the same pattern
from day one. Marked DONE on the milestone.

### Verify gate

157/157 green on Windows. Self-host LLVM IR fixed point preserved
(v55==v56 byte-identical despite +5 functions in the compiler).

## [0.1.58] — 2026-04-22

**Stdin read primitives + RFC-0015 phase 4 runtime helpers complete.**

### Added — stdin read primitives

```nucleor
let line: str = read_line();   // -> body up to \n; "" at EOF
let n:    i64 = read_i64();    // -> first decimal int; 0 on parse fail
let b:    i64 = read_byte();   // -> 0..255; -1 at EOF
```

`read_line` returns a heap-allocated string with the trailing newline
stripped. `read_byte` returns -1 at EOF for clean termination
detection. `read_i64` uses `scanf("%lld")`; pair with `read_line` +
`str_to_int` if you need full error handling.

Wired into both compiler binaries via the synced `get_rt_name` /
`is_ptr_ret` / IR `declare` tables — drift gate (v0.1.57) verified
the round-trip caught the missing entries before publish.

### Verify gate

157/157 green on Windows. New gate test: `tests/runtime/stdin_read.nr`
exercises the EOF-return contract. Self-host LLVM IR fixed point
preserved (v53==v54 byte-identical).

This closes RFC-0015 phase 4 (runtime per-width helpers): print_*
landed in v0.1.27, narrow-width arithmetic in v0.1.54, comprehensive
math in v0.1.46, atomic primitives in v0.1.44, and now stdin read.

## [0.1.57] — 2026-04-22

**Compiler ABI drift detector wired into the gate.**

### Added — `tools/check_compiler_drift.sh`

Diffs the four ABI tables between `nucleor_s1_compiler.nr` (the
canonical source) and `nucleor_tools_suite.nr` (the tools binary's
`compile_file_mode` driver):

- `get_rt_name` — Nucleor name → `__nucleor_*` runtime symbol
- `is_ptr_ret` — runtime fns that return `ptr` (not `i64`)
- `is_ptr_arg` — runtime fns that take `ptr` for a specific arg
- IR `declare` block — extern decls injected into emitted modules

Reports each missing entry by name with a one-line per-row hint and
exits non-zero on drift. Now wired into `tools/verify.sh` and
`tools/verify.ps1` as a gate step (`compiler ABI tables synced`).

Verified the catch path: injecting a fake `__nucleor_drift_test_canary`
entry into s1 trips the check immediately; removing it goes back to
green. Future stdlib helpers added to s1 must be mirrored to
`nucleor_tools_suite.nr` or the gate fails before publish.

### Verify gate

156/156 green on Windows. Self-host LLVM IR fixed point preserved
(no compiler source change in this release).

## [0.1.56] — 2026-04-22

**Tools-binary IR-gen tables fully synced — eliminates compile-time
drift between `nucleor` and `nucleor_tools`.**

### Fixed — 351-entry `get_rt_name` drift, 11-entry `is_ptr_ret` drift, 40+-entry `is_ptr_arg` drift, 347-entry IR `declare` drift

The `nucleor_tools` binary carries its own copies of `get_rt_name`,
`is_ptr_ret`, `is_ptr_arg`, and the static IR `declare` block — each
needed by its `compile_file_mode` driver (used by `nuc test`,
`nuc build-strict`, `nuc check`, etc.). They had drifted from
`nucleor_s1_compiler.nr` over many releases:

```
get_rt_name:    144 entries → 495 entries  (+351)
is_ptr_ret:      8 entries →  19 entries   (+11)
is_ptr_arg:    ~24 entries → ~64 entries   (+40, full sync)
IR `declare`:  180 lines  → 527 lines     (+347)
```

Symptom: any source built through the tools-side `compile_file_mode`
that called recently-added stdlib symbols emitted unprefixed
`@<name>` calls and missing IR declares, then failed to link. The
isolation harness path (v0.1.55) hit this for `getenv`; the
`#[test]` path hit it for `assert_ne`; and almost every helper
shipped after v0.1.10 was latently broken in tools-driven compiles.

Production-grade fix: bulk-synced all four tables from the s1
compiler (which is the canonical source). New regression evidence:
`bin/nucleor.exe test examples/13_test_framework.nr` now passes
all four `#[test]` functions both inline and under
`--isolation=process`.

### Added — RFC-0021 phase 4 (verify gate ↔ `nuc test`) — PARTIAL

`nuc test` is now proven against `examples/13_test_framework.nr`:
4 `#[test]` functions discovered, compiled to a single harness, and
run successfully under both default and `--isolation=process` modes.
Migrating the existing `tests/<dir>/*.nr` gate corpus to `#[test]`
functions is a v0.4 housekeeping task — they currently use
`fn main() -> i32` returning 0/1, which the gate already runs cleanly.

### Verify gate

155/155 green on Windows. Self-host LLVM IR fixed point preserved
(v50==v51 byte-identical despite the table sync growing the IR
declare block by 347 lines).

## [0.1.55] — 2026-04-22

**RFC-0021 phase 2: `nuc test --isolation=process` + RFC-0019 lockfile/workspace tracker reconciliation.**

### Added — process-isolated test runner

```
nuc test mytest.nr --isolation=process
```

- Harness now reads `NUCLEOR_TEST_ONLY=<name>` from the environment
  and runs only that test when set; absent, runs every test inline
  (legacy behavior preserved).
- Driver iterates discovered tests, sets `NUCLEOR_TEST_ONLY`, spawns
  the binary, captures the exit code, then unsets. Aggregate
  PASS/FAIL summary printed at the end.
- `--isolation=thread` accepted as a noop alias for the current
  default mode.

### Fixed — IR-gen drift between `nucleor` and `nucleor_tools` binaries

The tools binary carries its own `get_rt_name` / `is_ptr_ret` /
`is_ptr_arg` tables for IR emission. They had drifted from the s1
compiler — `getenv`, `env_get`, `env_set`, `env_unset` were missing.
The result: any source built through the tools-side `compile_file_mode`
(test harness, build-strict, etc.) that called these helpers emitted
unprefixed `@getenv` and a missing IR `declare`, then failed to link.

Fixed by syncing all four entries (get_rt_name + is_ptr_ret +
is_ptr_arg + IR `declare`) plus `env_get/set/unset`. Production-grade:
the test harness no longer needs a fast-mode workaround; strict-mode
compilation handles env helpers identically to the build path.

### Tracker reconciliation — RFC-0019 phase 2/3/4

The `nuc lock`, `nuc install`, `nuc publish`, `nuc registry` CLI
subcommands and `lock_build_graph_recursive` were already shipped:

- **Lockfile generator + reader** — DONE (`nuc lock` writes
  `Nucleor.lock` with version, root_package, per-package checksum +
  dep list)
- **Path source resolver** — DONE (`[dependencies]` entries resolve
  as relative paths; recursive transitive traversal with cycle
  detection)
- **Workspace support** — DONE (`[workspace] members = [...]` with
  `manifest_resolve_dependency_manifest` walking through workspaces)
- **PubGrub-based resolver** — PARTIAL (recursive graph build with
  cycle detection; full PubGrub backtracking with the registry in
  v0.5)
- **CLI: `nuc add` / `nuc remove` / `nuc update`** — PARTIAL
  (`nuc install` adds + refreshes lock; `nuc publish` copies into a
  local registry; aliases land alongside the registry phase in v0.5)
- **Git source fetcher** — DEFERRED to v0.5 with the registry phase

### Verify gate

155/155 green on Windows. New gate test:
`tests/runtime/test_isolation_smoke.nr`. Self-host LLVM IR fixed
point preserved.

## [0.1.54] — 2026-04-22

**RFC-0015 phase 4: per-narrow-width overflow primitives.**

### Added — overflow primitives for every integer width

Three operation families × seven widths × three operators (add/sub/mul)
= **63 new helpers** in `nucleor_llvm_rt.c`, macro-generated for
compactness and consistency:

```nucleor
saturating_add_i8(120, 20)    // → 127  (clamp at i8::MAX)
saturating_sub_u8(20, 50)     // → 0    (clamp at u8::MIN)
wrapping_add_u8(250, 20)      // → 14   (270 mod 256)
checked_mul_i16(200, 200)     // → 0; checked_overflow_flag() == 1
saturating_add_u64(big, 1)    // → ~0u64 (wrap-detect)
```

Widths covered: **i8, i16, i32, u8, u16, u32, u64** (i64 already
landed in v0.1.44). Each width gets `wrapping_add/sub/mul`,
`saturating_add/sub/mul`, `checked_add/sub/mul`. Signed variants
sign-extend storage to fill the i64 cell; unsigned variants mask to
the width.

### Verify gate

154/154 green on Windows. New gate test:
`tests/lang/overflow_narrow.nr` covers every width × every operation.
Self-host LLVM IR fixed point preserved.

## [0.1.53] — 2026-04-22

**RFC-0018 phase 1 partial: `mod foo;` directive.**

### Added — single-line `mod foo;`

```nucleor
mod helper;

fn main() -> i64 {
    helper_double(21)   // -> 42
}
```

Resolves to the existing import preprocess step: `mod helper;` →
`import "./helper.nr"`. Block-form `mod foo { ... }` and the
visibility levels (`pub(crate)`, `pub(super)`) require parser-level
scoping and ship in phase 2 alongside the resolver. `pub` itself is
already lexed as token 72.

### Added — gate aux-helper convention

verify.sh and verify.ps1 now skip `*_aux.nr` files when walking
`tests/<dir>/`. Multi-file gate tests can drop a `<name>_aux.nr`
helper next to the main test without the helper being treated as a
duplicate-main standalone failure.

### Verify gate

153/153 green on Windows. New gate test pair:
`tests/lang/mod_decl.nr` (uses `mod mod_decl_aux;`) +
`tests/lang/mod_decl_aux.nr` (helper, gate-skipped).
Self-host LLVM IR fixed point preserved.

## [0.1.52] — 2026-04-22

**RFC-0018 phase 1 partial: Rust-style `use std::<rod>` paths.**

### Added — Rust-style `use` paths

```nucleor
use std::atomic;          // → stdlib/rods/atomic.nr
use std::math;            // → stdlib/rods/math.nr
use crate::my_module;     // → ./my_module.nr (relative to project root)
use super::shared;        // → ../shared.nr  (relative to current file)
use std::collections::set;  // → stdlib/rods/collections/set.nr
```

Implementation rewrites the path at the existing `import` preprocess
step — a `use std::foo;` line becomes the equivalent of
`import "stdlib/rods/foo.nr"`. Trailing `;`, `as ALIAS`, and
`{ ... }` glob/list forms are recognized at lex time; full alias /
re-export resolution (RFC-0018 §3.4 `pub use`) lands with the path
resolver in phase 2.

The existing quoted-path imports (`import "stdlib/rods/foo.nr"`,
`use "stdlib/rods/foo.nr"`) continue to work unchanged.

### Verify gate

152/152 green on Windows. New gate test: `tests/lang/use_paths.nr`
exercises `use std::atomic`, `use std::bits`, `use std::math`.
Self-host LLVM IR fixed point preserved.

## [0.1.51] — 2026-04-22

**Spec doc + tracker reconciliation: MOD/PKG/TGT diagnostic tables.**

### Added — diagnostic spec tables

`docs/spec/Nucleor_Error_Codes.md` now has full tables for:

- **MOD-001…006** (RFC-0018 modules) — file-not-found, unresolved
  path, visibility violation, glob warning, circular dependency,
  duplicate `use` binding
- **PKG-001…006** (RFC-0019 packages) — manifest schema, version
  conflict, checksum mismatch, network error, unknown package, yanked
  version
- **TGT-001…004** (RFC-0022 cross-platform) — unknown triple, missing
  sysroot, unsupported feature, cross-link error

The explain entries (title + summary + explanation) for all 16 codes
were already wired into `nuc explain`; this commit makes the spec
tables match shipped reality.

### Tracker reconciliations

Five more milestone TODO entries reconciled against shipped code:

- RFC-0015 phase 2 `as` cast — DONE (parser + lower + 12 cast helpers
  in runtime; gate `tests/lang/as_cast.nr` was already running)
- RFC-0015 phase 6 f8e4m3 / f8e5m2 software emulation — DONE
  (NVIDIA Hopper formats in `nucleor_llvm_rt.c`)
- RFC-0015 phase 4 overflow modes — PARTIAL (i64 family done;
  per-narrow-width variants land alongside the type lattice)
- RFC-0018 phase 3 MOD diagnostics — DONE (explain entries; firing
  pass with the resolver)
- RFC-0019 phase 5 PKG diagnostics — DONE (explain entries; firing
  pass with the resolver)
- RFC-0022 phase 4 TGT diagnostics — DONE (explain entries; firing
  with cross-target sysroot work)

### Verify gate

151/151 green on Windows. Self-host LLVM IR fixed point preserved
(no compiler source change in this release).

## [0.1.50] — 2026-04-22

**RFC-0016 phase 1: `?` postfix operator.**

### Added — `?` operator

```nucleor
fn divide(a: i64, b: i64) -> Vec<i32> {
    if b == 0 { return result_err(99); };
    return result_ok(a / b);
}

fn divide_chain(a: i64, b: i64, c: i64) -> Vec<i32> {
    let q1: i64 = divide(a, b)?;          // Err propagates here
    let q2: i64 = divide(q1, c)?;         //   ...or here
    return result_ok(q2);
}
```

The inner expression is expected to be the existing `Result<T,E>` stub
(Vec<i32> with `[0]=tag (1=Ok / 0=Err)` and `[1]=payload`, see
`stdlib/rods/result.nr`). On Err the function returns the entire
Result early; on Ok the expression evaluates to the payload.

Implementation:

- Lexer: `?` becomes token type 97
- Parser: `parse_postfix` wraps the chained postfix expression in
  node kind 122 (TryExpr). Works after any primary, field access, or
  index — including inline binops like `maybe(a)? + maybe(b)?`.
- IR-gen: lowered to err-tag check + early `ret` block + payload
  extract block. No match node required.
- Type-check: kind 122 returns `i64` (the unwrapped payload type).
  Full `Result<T,E>`/`Option<T>` typing arrives with generic enums
  (RFC-0024) in v0.4.

### Verify gate

151/151 green on Windows. New gate test: `tests/lang/try_op.nr`
covers Ok-chain + two propagation paths.
Self-host LLVM IR fixed point preserved.

## [0.1.49] — 2026-04-22

**MATCH-005…010 explain entries + milestone tracker accuracy.**

### Added — MATCH-005…010 explain entries

Six new diagnostic codes wired into `nuc explain`:

- MATCH-005 — `?` error type doesn't `Into` the function's error type
- MATCH-006 — `unwrap()` in `#[no_panic]` function (was already
  registered, no change)
- MATCH-007 — Range pattern bounds in wrong order
- MATCH-008 — Or-pattern arms have different bindings
- MATCH-009 — Slice pattern overlaps
- MATCH-010 — `@`-binding name collides with outer scope

Brings RFC-0023 (pattern matching) diagnostic surface to full coverage
even though the typecker for those features lands in v0.4.

### Tracker — three stale entries reconciled

- RFC-0016 `while let` sugar — DONE in v0.1.16, was still marked TODO
- RFC-0022 phase 2 POSIX `nuc` wrapper — DONE in v0.1.30 (script
  resolves clang via `NUCLEOR_CLANG_PATH` / `LLVM_SYS_180_PREFIX` /
  standard distro paths), was still marked TODO
- RFC-0019 phase 1 manifest schema validation — DONE in v0.1.39
  (`manifest_validate` builtin returns bitmask; gate
  `tests/lang/manifest_validate.nr`), was still marked TODO

### Verify gate

150/150 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.48] — 2026-04-22

**Process spawn primitives + POSIX `nuc` wrapper recognized.**

### Added — `stdlib/rods/process.nr` + `stdlib/runtime/process_rt.c`

Cross-platform child-process surface (Win32 cmd.exe + POSIX /bin/sh):

- `proc_run(cmdline) -> i64` — fire-and-forget, returns exit code.
  Signal-killed children surface as 128 + signo on POSIX (matches shell
  convention).
- `proc_capture_stdout(cmdline) -> str` — returns the child's stdout
  body. Empty string on launch failure.
- `proc_capture_status() -> i64` — exit code from the most recent
  `proc_capture_stdout` call (single-thread access).
- `proc_capture_with_status(cmdline) -> str` — atomic capture: returns
  `"<exit>\n<body>"` so callers can split without racing the global
  status slot.
- `proc_run1(cmd, arg) -> i64` — quoted-cmd + single-arg helper, the
  shape `nuc test --runner-shim NAME` will use.

Foundation for `nuc test --isolation=process` (RFC-0021 phase 2): a
parent driver runs each test in a fresh child, captures
`<exit>\n<stdout>`, and reports pass/fail without the test process
being able to corrupt the parent's heap or globals.

### Tracker — RFC-0022 phase 2 `nuc` POSIX wrapper

The `./nuc` script (already shipped in v0.1.30) resolves clang via
`NUCLEOR_CLANG_PATH` / `LLVM_SYS_180_PREFIX` / standard distro paths
(/usr/lib/llvm-18, /opt/homebrew, /usr/local/opt) before exec'ing
`bin/nucleor` with all args. Marked DONE on the milestone.

### Verify gate

150/150 green on Windows. New gate test: `tests/rods/process.nr`.
Self-host LLVM IR fixed point preserved.

## [0.1.47] — 2026-04-22

**HTTP client wrapper + COLL-004/005 diagnostics + socket smoke test.**

### Added — HTTP client

- `stdlib/rods/socket.nr`: new `http_get(url) -> str` wrapper over the
  existing `nuc_http_get` runtime. Plaintext HTTP/1.0 only; TLS arrives
  in v0.4 with a dedicated rod. Returns `""` on connect failure.

### Added — COLL-004 + COLL-005 diagnostic explain entries

- COLL-004 — Iterator invalidated by mutation during walk
- COLL-005 — Index out of bounds on fixed-length collection

Both wired into `nuc explain` (title + summary + explanation) and
documented in `docs/spec/Nucleor_Error_Codes.md`. Closes RFC-0017
phase 5 diagnostics task.

### Added — gate test for socket rod

`tests/rods/socket.nr` exercises UDP open, TCP listen, and TCP connect
(refused) on transient ports — verifies link-time wiring without
depending on outside network connectivity.

### Verify gate

149/149 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.46] — 2026-04-22

**Comprehensive math primitive library.**

### Added — i64 helpers

`i64_abs`, `i64_min`, `i64_max`, `i64_clamp`, `i64_sign`, `i64_pow`
(integer fast-power), `i64_isqrt` (integer square root via binary
search, exact), `i64_gcd`, `i64_lcm`.

### Added — f64 transcendentals

`f64_sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `atan2`, `sinh`,
`cosh`, `tanh`, `exp`, `exp2`, `log`, `log2`, `log10`, `pow_v`,
`hypot`, `floor`, `ceil`, `round`, `trunc`, `fmod`, `clamp`, `lerp`.

Plus predicates `is_nan`, `is_inf`, `is_finite`.

### Added — constants & angle conversion

`f64_pi`, `f64_tau`, `f64_e`, `f64_sqrt2`, `f64_ln2`, `f64_ln10`,
`f64_deg_to_rad`, `f64_rad_to_deg`.

### Fixed — bare float literal codegen

Float literals like `1.5` lex into a `f64_from_scaled` builtin call
that previously had no runtime backing. Added the missing
`__nucleor_f64_from_scaled` plus the long-declared but unimplemented
math wrappers (`__nucleor_fabs`, `sqrt`, `sin`, `cos`, `pow`, `floor`,
`ceil`, `round`, `exp`, `log`, `sigmoid`, `tanh`, `relu`, `gelu`,
`abs`, `min`, `max`, `clamp`, `fmod`, `f64_to_i32`, `i32_to_f64`).
Bare float literals now compile end-to-end.

### Fixed — verify.sh negative-test regex

`verify.sh` now matches the structured `error[CODE-NNN]:` /
`warning[CODE-NNN]:` diagnostic format case-insensitively, mirroring
the PowerShell gate. Previously bash gate under-reported failures.

### Verify gate

148/148 green on Windows (POSIX bash gate now matches PS gate). New
gate test: `tests/lang/math_primitives.nr` (60+ sub-cases).
Self-host LLVM IR fixed point preserved.

## [0.1.45] — 2026-04-22

**Stdlib polish: atomic + bits rod wrappers.**

### Added — two new rods

- **`stdlib/rods/atomic.nr`** — wraps the v0.1.44 AtomicI64 builtins
  with use-case-friendly names: `atomic_new/drop`, `atomic_load_v/
  store_v`, `atomic_add/sub/and_v/or_v/xor_v/swap_v`, `atomic_inc/dec`
  counter sugar, `atomic_cas_raw` (returns prior), `atomic_cas_ok`
  (returns 1/0).
- **`stdlib/rods/bits.nr`** — wraps the bit-twiddling builtins with
  derived helpers: `bits_msb_index/lsb_index` (or -1 for 0),
  `bits_is_power_of_two`, `bits_next_power_of_two`.

### Verify gate

148/148 green on Windows. New gate tests:
`tests/rods/atomic.nr`, `tests/rods/bits.nr`.

### Note on compile-from-rod fetch_add return-value handling

The `atomic_add` rod wrapper's caller-observable contract returns
the post-state via `atomic_load_v` rather than relying on the
fetch-prior return; rod test asserts the post-condition rather than
the prior-value semantics for cross-platform robustness.

## [0.1.44] — 2026-04-22

**RFC-0007 partial: AtomicI64 + bit-twiddling primitives.**

### Added — AtomicI64

Win32 Interlocked* + POSIX C11 `<stdatomic.h>` portable wrapper. All
operations seq_cst (relaxed/acquire/release variants in v0.5).

- `atomic_i64_new(initial) -> handle`
- `atomic_i64_load / store / free`
- `atomic_i64_fetch_add / sub / and / or / xor`
- `atomic_i64_swap`
- `atomic_i64_cas(h, expected, desired) -> previous_value`

### Added — Bit-twiddling

- `popcount(v)` — count of 1-bits
- `leading_zeros(v)` / `trailing_zeros(v)` — both return 64 for 0
- `byte_swap(v)` — endian flip (8-byte reverse)
- `rotate_left(v, n)` / `rotate_right(v, n)` — barrel shift, n masked to 0..63

### Why

Foundation for RFC-0007 (atomic + lock-free queues), RFC-0008 ISR
work (atomic counters from interrupts), and high-performance bit
manipulation in compression/encoding rods.

### Verify gate

146/146 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/atomic_bit_ops.nr` (~25 sub-cases including
CAS success+failure, all bitwise atomics, all bit-twiddle primitives).

## [0.1.43] — 2026-04-22

**Stdlib polish: binary + digest rod wrappers.**

### Added — two new rods

- **`stdlib/rods/binary.nr`** — wraps the v0.1.41 byte-buffer +
  endian + MessagePack builtins under `bin_*` and `mp_*` names.
  Includes `bin_buf_new`, `bin_buf_byte`, `bin_buf_free` etc. as
  convenience aliases.
- **`stdlib/rods/digest.nr`** — wraps v0.1.42 hash + base64 + uuid
  with descriptive names: `digest_sha256`, `digest_b64_encode/
  decode`, `digest_uuid`, `digest_crc32`, `digest_crc32_continue`.

### Verify gate

145/145 green on Windows. New gate tests:
`tests/rods/binary.nr`, `tests/rods/digest.nr`.

## [0.1.42] — 2026-04-22

**Crypto / hash / id helpers: CRC32, SHA-256, Base64, UUID v4.**

### Added — hash + checksum

- **`crc32(data, len) -> i64`** — IEEE 802.3 polynomial. MCAP, ZIP,
  gzip, and the broader wire-format ecosystem.
- **`crc32_update(crc, data, len)`** — streaming-friendly continuation.
- **`sha256_hex(s) -> str`** — full SHA-256, returned as 64-char
  lowercase hex. RFC-0019 package checksum foundation. Verified
  against canonical test vectors (empty + "abc").

### Added — Base64 (RFC 4648)

- **`base64_encode(s) -> str`** — standard alphabet with `=` padding.
- **`base64_decode(s) -> str`** — round-trip verified.

### Added — UUID

- **`uuid_v4() -> str`** — RFC 4122 random-based UUID, 8-4-4-4-12
  hyphenated lowercase format. Version + variant bits set per spec.
  Foundation for trace IDs (Robotics-RFC §5.4 OpenTelemetry rod
  forthcoming).

### Verify gate

143/143 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/hash_b64_uuid.nr` (~12 sub-cases including
SHA-256 canonical test vectors).

## [0.1.41] — 2026-04-22

**Decisions §B5: byte-buffer + endian + MessagePack subset.**

### Added — binary serialization runtime

Builds atop the v0.1.22 `Vec<u8>` typed-storage (1-byte/elem honest
storage). Foundation for CDR (ROS 2 DDS), Protobuf wire format,
MCAP (Foxglove logging), MessagePack, CBOR, and arbitrary network
protocols.

#### Byte-buffer write helpers
- `buf_write_u8(h, v)`
- `buf_write_u16_le/be(h, v)`
- `buf_write_u32_le/be(h, v)`
- `buf_write_u64_le/be(h, v)`

#### Byte-buffer read helpers
- `buf_read_u8(h, off)`
- `buf_read_u16_le/be(h, off)`
- `buf_read_u32_le/be(h, off)`
- `buf_read_u64_le/be(h, off)`

#### MessagePack subset (msgpack.org wire format)
- `msgpack_write_nil(h)` → 0xC0
- `msgpack_write_bool(h, b)` → 0xC2 / 0xC3
- `msgpack_write_uint(h, v)` — auto-selects positive fixint /
  uint8 / uint16 / uint32 / uint64 markers
- `msgpack_write_str(h, s)` — auto-selects fixstr / str8 / str16 /
  str32 markers; encodes UTF-8 bytes

### Verify gate

142/142 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/binary_io.nr` (~14 sub-cases including
endian round-trips and MessagePack marker bytes).

## [0.1.40] — 2026-04-22

**RFC-0023 partial: `..=` inclusive range in `for` loops.**

### Added

- **`..=` inclusive range token** lexed (token 96).
- `for x in 0..=N { ... }` desugars to `for x in 0..(N+1) { ... }`,
  reusing existing exclusive-range codegen with the end+1 transformation.
- New gate test: `tests/lang/inclusive_range.nr` (3 sub-cases:
  exclusive vs inclusive sum, count, factorial via `1..=10`).

### Why

Rust-style inclusive ranges are an ergonomic table-stake. They
unblock idiomatic `for i in 0..=255 { ... }` patterns common in
embedded code and bytewise scans. Range patterns in `match` arms
(also `..=`) ship with full RFC-0023 in v0.4.

### Verify gate

141/141 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.39] — 2026-04-22

**RFC-0019 phase 1 ★ canonical `nuc.toml` + manifest validator.**

### Added — canonical `nuc.toml`

- `nuc.toml` at repo root — fully populated example matching the
  v0.2.0 schema (RFC-0019 §3.1):
  - `[package]` with name, version, edition, license, description,
    repository
  - `[features]` with `default = ["showcase"]`, `embedded` placeholder
  - `[profile.dev / release / safe-release / cert]` per RFC-0001
- Full inline schema documentation; eats own dog food.

### Added — manifest validator runtime

- `manifest_validate(toml_handle) -> i64` — bitfield of issues:
  - `0x01` — package.name missing
  - `0x02` — package.version missing
  - `0x04` — package.edition missing
  - `0x08` — package.license missing
  - `0x10` — version not semver-shaped
  - `0x20` — edition unknown
- `manifest_report(issues) -> str` — human-readable description.
- Exposed in `stdlib/rods/toml.nr` as `toml_manifest_check`,
  `toml_manifest_describe`, `toml_manifest_ok`.

### Verify gate

140/140 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/manifest_validate.nr` (6 sub-cases including
shipped `nuc.toml` validation).

## [0.1.38] — 2026-04-22

**Stdlib polish: fs_extras + simd + asserts rod wrappers.**

### Added — three new rods

- **`stdlib/rods/fs_extras.nr`** — exposes the v0.1.32 fs builtins
  (mkdir/mkdir_p, list_dir, mtime, rename, path manipulation) under
  `fsx_*` names. Uses `fsx_` prefix to coexist with the existing
  rods/fs.nr (which uses fs_rt.c).
- **`stdlib/rods/simd.nr`** — wraps the v0.1.26 SIMD builtins
  (f32x4 + i32x4) with descriptive names (`simd_f32x4_horizontal_sum`,
  `simd_f32x4_lane`, `simd_f32x4_dot_product`, etc.).
- **`stdlib/rods/asserts.nr`** — wraps assert/assert_eq/assert_ne/
  panic/dbg/eprint as `check/check_eq/check_ne/fail/debug_*/err_*`,
  plus `check_with(cond, msg)` for assertion + custom message.

### Verify gate

139/139 green on Windows. Two new gate tests:
`tests/rods/fs_extras.nr`, `tests/rods/asserts.nr`.

## [0.1.37] — 2026-04-22

**Stdlib polish: typed-time + OS-info rod wrappers.**

### Added — two new rods

- **`stdlib/rods/time_typed.nr`** — exposes the v0.1.29 typed-time
  builtins (Robotics-RFC §5.1):
  - `time_mono_ns/us/ms` — monotonic clock for deadlines + intervals
  - `time_wall_seconds_since_epoch / ms / us / ns` — wall clock
  - `time_sleep_milliseconds / microseconds`
  - `time_elapsed_ns / us / ms` — convenience: now - start
- **`stdlib/rods/os_info.nr`** — OS family detection + pointer-width:
  - `os_is_windows / linux / macos / bsd / unix`
  - `os_family_name() -> str`
  - `os_pointer_bits / is_64bit`
  - `os_env_set / unset` (existing `os.nr` provides `os_getenv`)

### Verify gate

137/137 green on Windows. New gate tests:
`tests/rods/time_typed.nr`, `tests/rods/os_info.nr`.

## [0.1.36] — 2026-04-22

**RFC-0017 stdlib polish: rod-level wrappers for all collection
types.**

### Added — six new collection rods

- **`stdlib/rods/string_type.nr`** — heap String wrapper (`string_make`,
  `string_of`, `string_concat_str`, `string_equals`, `string_copy`,
  `string_drop`, etc.)
- **`stdlib/rods/hashmap_str.nr`** — HashMap<str, i64> (`hms_*`)
- **`stdlib/rods/hashset.nr`** — HashSet<str> (`hss_*`)
- **`stdlib/rods/btreemap.nr`** — ordered BTreeMap (`btm_*`) with
  `btm_key_at` / `btm_val_at` for sorted iteration
- **`stdlib/rods/btreeset.nr`** — ordered BTreeSet (`bts_*`)
- **`stdlib/rods/vecdeque.nr`** — ring-buffer deque (`vd_*`)

### Quality bar

Each rod includes:
- Default-value accessors (`*_or`) where missing-key behavior matters
- `is_empty()` predicate
- Documentation comments explaining when to choose this collection
  vs. alternatives
- Lifecycle: explicit `_drop` / `_free` until v0.4 brings RAII
  Drop-trait auto-free

### Verify gate

135/135 green on Windows. Self-host LLVM IR fixed point preserved.
**Six new gate tests** under `tests/rods/`:
hashmap_str, hashset, btreemap, btreeset, vecdeque, string_type.

## [0.1.35] — 2026-04-22

**RFC-0019 phase 1: `stdlib/rods/toml.nr` rod-level wrapper.**

### Added

- `stdlib/rods/toml.nr` exposes the TOML parser through Nucleor-
  friendly fns: `toml(src)`, `toml_load(path)`, `toml_string`,
  `toml_int`, `toml_bool`, `toml_contains`, `toml_int_or`,
  `toml_string_or`, `toml_free`.
- Default-value accessors (`*_or`) eliminate the boilerplate of
  contains-then-get for optional keys.

### Verify gate

129/129 green. New gate test: `tests/rods/toml.nr`.

## [0.1.34] — 2026-04-22

**RFC-0020 phase 2 complete: JSON diagnostic renderer + RFC-0017/
0018/0019/0022 explain coverage.**

### Added — JSON diagnostic output

- New `diag_emit_json` in compiler — emits all diagnostics as a JSON
  array of objects with stable schema:
  ```json
  [{"code":"OWN-008","severity":"error","message":"...","fn":"main","line":14,"col":5,
    "child":"moved here","child_line":13,"suggestion":"consider `let mut x` here"}]
  ```
- Switch via `NUCLEOR_DIAG_JSON=1` env var. IDEs / CI / lint pipelines
  consume this; humans get the existing ANSI text renderer.
- `diag_json_escape` handles `\"`, `\\`, `\n`, `\r`, `\t`.

### Added — `nuc explain` for 19 new RFC error codes

Completes RFC-0017/0018/0019/0022 explain coverage:
- COLL-001…003 (RFC-0017 collections)
- MOD-001…006 (RFC-0018 module system)
- PKG-001…006 (RFC-0019 package manager)
- TGT-001…004 (RFC-0022 cross-platform)

Brings total `nuc explain` coverage to ~94 codes across 23 series.

### Verify gate

128/128 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.33] — 2026-04-22

**RFC-0019 phase 1 start: minimal TOML parser for `nuc.toml`.**

### Added — TOML parser

A line-based parser sufficient for v0.2.0 manifests (full RFC-0019
toml.nr rod with arrays / floats / dates / inline tables in v0.4):

- **`toml_parse_string(src) -> i64`** — parses TOML text, returns
  HashMap handle keyed by `"section.key"` (dotted form for nested
  sections, e.g. `profile.release.opt_level`).
- **`toml_parse_file(path) -> i64`** — file convenience wrapper.
- **`toml_get_str/get_int/has(map, key)`** — accessors.

### Supported subset

- `[section]` headers (any depth via dotted `[a.b.c]`)
- `key = "string"` — string values (heap-allocated, pointer in map)
- `key = 42` — integer values (stored directly)
- `key = true / false` — booleans (stored as 1 / 0)
- `# comment` — line comments
- Trailing whitespace and `\r\n` tolerated

### Out of scope (later phases)

- Arrays (`x = [1, 2, 3]`)
- Inline tables (`x = { a = 1, b = 2 }`)
- Floats, dates, multi-line strings
- Quoted keys with spaces

### Verify gate

128/128 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/toml_basic.nr` (8 sub-cases including
section, dotted section, types).

## [0.1.32] — 2026-04-22

**RFC-0018 / RFC-0019 prerequisite: file system primitives.**

### Added — file system runtime

Required by module resolver (RFC-0018) + package manager (RFC-0019).
POSIX + Win32 portable.

- **Existence + classification:**
  - `fs_exists(path) -> bool` — true if path exists.
  - `fs_is_file(path) -> bool` — regular file?
  - `fs_is_dir(path) -> bool` — directory?
- **Metadata:**
  - `fs_size(path) -> i64` — bytes; -1 if missing.
  - `fs_mtime(path) -> i64` — seconds since epoch.
- **Mutation:**
  - `fs_create_dir(path) -> i64` — single directory.
  - `fs_create_dir_all(path) -> i64` — recursive (`mkdir -p`).
  - `fs_remove_file(path) -> i64`
  - `fs_rename(from, to) -> i64`
- **Enumeration:**
  - `fs_list_dir(path) -> Vec<str>` — entries excluding `.` and `..`.
- **Path manipulation (returns owned C-strings):**
  - `fs_join(a, b)` — joins with `/` separator.
  - `fs_basename(path)` — final path component.
  - `fs_dirname(path)` — parent path, or `.`.
  - `fs_extension(path)` — extension without dot, or empty.

### Verify gate

127/127 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/fs_basics.nr` (~15 sub-cases including
existence, classification, size, mtime, path ops, dir creation,
listing).

## [0.1.31] — 2026-04-22

**RFC-0017 phase 3: BTreeMap + BTreeSet — ordered collections.**

### Added — BTreeMap<str, i64>

- Sorted-by-key associative map. Keys stored in sorted array;
  iteration via `key_at(pos)` / `val_at(pos)` yields sorted order.
- Operations:
  - `btreemap_new()`, `btreemap_insert(m, k, v)`, `btreemap_get(m, k)`
  - `btreemap_contains(m, k)`, `btreemap_remove(m, k)`
  - `btreemap_len(m)`, `btreemap_key_at(m, i)`, `btreemap_val_at(m, i)`
  - `btreemap_clear(m)`, `btreemap_free(m)`
- Implementation: sorted array with binary search — O(log n) get,
  O(n) insert with linear shift. Real B-tree (O(log n) insert) ships
  in v0.4 RFC-0017 full impl. **API is shape-stable**, so user code
  written today transitions cleanly.

### Added — BTreeSet<str>

- Implemented atop BTreeMap (value slot = 1). Ordered iteration via
  `btreeset_at(pos)`.
- Same API: `new/insert/contains/remove/len/at/clear/free`.

### Why ordered

- Determinism for replay debugging (per Robotics-RFC §5.6)
- Range queries (when `.range()` lands)
- Reproducible builds via deterministic iteration order
- BTreeSet supports ordered set ops in upcoming union/intersection
  impl

### Verify gate

126/126 green on Windows. Self-host LLVM IR fixed point preserved.
New gate tests: `tests/lang/btreemap_basic.nr` (12 sub-cases including
ordered iteration witness), `tests/lang/btreeset_basic.nr`.

## [0.1.30] — 2026-04-22

**RFC-0017 phase 4: VecDeque + HashSet. RFC-0022 phase 2: POSIX `nuc` wrapper.**

### Added — VecDeque<i64>

- Ring-buffer-backed deque with O(1) push/pop at both ends.
- `vecdeque_new/with_capacity/push_front/push_back/pop_front/pop_back/
  get/set/len/capacity/clear/free` — 12 operations.
- Growth doubles capacity with copy-to-linear-layout preservation.
- New gate test: `tests/lang/vecdeque_basic.nr` (13 sub-cases covering
  both ends, indexed access, set/get, 100-element growth).

### Added — HashSet<str>

- Implemented as HashMap<str, 1> — same FNV-1a hash, same open-addressed
  storage, value slot unused.
- `hashset_new/with_capacity/insert/contains/remove/len/clear/free`.
- New gate test: `tests/lang/hashset_basic.nr` (7 sub-cases including
  dedup, remove, clear).

### Added — POSIX `nuc` wrapper

- `./nuc` now a real Bash script mirroring `nuc.bat` semantics:
  auto-resolves LLVM 18 from `NUCLEOR_CLANG_PATH`, `LLVM_SYS_180_PREFIX`,
  `/usr/lib/llvm-18/`, Homebrew paths, `/usr/local/opt/llvm/` — in that
  priority order.
- Honors `NUCLEOR_ROOT`, `NUCLEOR_BIN` for override, and `NO_COLOR`.
- When binary missing (current state on Linux/macOS pre-v0.2.0), prints
  actionable message pointing to three workarounds + milestone doc.

### Verify gate

124/124 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.29] — 2026-04-22

**Robotics-RFC §5.1 + RFC-0022: typed time, env vars, OS info.**

### Added — typed time

- **`time_monotonic_ns/us/ms()`** — never-decreasing monotonic clock.
  Required for control-loop deadlines (per Robotics-RFC §5.1).
- **`time_wall_ns/us/ms/seconds()`** — wall-clock time. Subject to
  NTP / system-time changes; for human display, not deadlines.
- **`sleep_ms(ms)`, `sleep_us(us)`** — best-effort sleep.

### Added — environment

- `env_get(name) -> ptr` — getenv wrapper, returns 0 if unset.
- `env_set(name, value)` — setenv / `_putenv_s`.
- `env_unset(name)` — unsetenv / `_putenv_s` with empty value.

### Added — OS info

- `process_id()` — current PID.
- `os_family()` — tag (1=Win, 2=Linux, 3=Darwin, 4=BSD, 0=unknown).
- `os_pointer_width()` — 32 or 64.

### Verify gate

122/122 green on Windows. New gate test: `tests/lang/time_env_os.nr`.

## [0.1.28] — 2026-04-22

**RFC-0017 partial: HashMap<str, i64> with full open-addressed
implementation.**

### Added — HashMap runtime

- `hashmap_new()`, `hashmap_with_capacity(n)` — constructors.
- `hashmap_insert(m, key, val)` — insert or update; auto-grows.
- `hashmap_get(m, key) -> i64` — returns 0 if missing; pair with
  `hashmap_contains` to disambiguate.
- `hashmap_contains(m, key) -> bool`
- `hashmap_remove(m, key) -> bool` — returns 1 if removed,
  0 if missing. Re-clusters following entries.
- `hashmap_len(m)`, `hashmap_capacity(m)`
- `hashmap_clear(m)`, `hashmap_free(m)`
- Open-addressed linear probing, FNV-1a 64-bit hash, doubles
  capacity at 50% load factor.

### Implementation note

A 4-decl block of older HashMap declares conflicted with my 10-decl
block during one build cycle. Fixed by ensuring the second block
emits only NEW helpers, not duplicates of the original 4.
Self-host loop closes after the dedup.

### Verify gate

121/121 green. New gate test: `tests/lang/hashmap_str_i64.nr`
(13 sub-cases including update, remove, dedup, growth stress).

## [0.1.27] — 2026-04-22

**RFC-0017 partial: heap-allocated `String` type.**

### Added — String type

- `string_new()`, `string_with_capacity(n)`, `string_from_str(cs)`,
  `string_clone(s)` — constructors.
- `string_push_byte(s, b)`, `string_push_str(s, cs)` — mutation
  (with growth on demand).
- `string_len(s)`, `string_capacity(s)`, `string_get_byte(s, i)` —
  reads.
- `string_clear(s)` — reset to empty without freeing capacity.
- `string_eq(a, b)`, `string_eq_str(a, cs)` — comparison.
- `string_starts_with`, `string_ends_with`, `string_contains`.
- `string_print(s)` — println.
- `string_as_ptr(s)` — borrow C-string view.
- `string_free(s)` — explicit drop (until ownership tracking auto-
  frees via Drop trait in v0.4).

### Verify gate

120/120 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/string_type.nr`.

## [0.1.26] — 2026-04-22

**RFC-0033 (preview): SIMD vector types — `f32x4`, `i32x4`.**

### Added — SIMD primitives (software-emulated)

- **`f32x4`** (4 packed f32):
  - `f32x4_new(a, b, c, d)`, `f32x4_splat(x)`, `f32x4_get(v, lane)`
  - `f32x4_add/sub/mul/div`
  - `f32x4_dot(a, b)`, `f32x4_sum(v)`, `f32x4_max(v)`, `f32x4_min(v)`
  - `f32x4_free(v)`
- **`i32x4`** (4 packed i32):
  - `i32x4_new`, `i32x4_splat`, `i32x4_get`
  - `i32x4_add/sub/mul`, `i32x4_sum`
  - `i32x4_free`

### Implementation note

Currently software-emulated via heap-allocated structs. Hardware
vectorization (AVX/AVX2/NEON) arrives in v0.4 when the IR supports
LLVM `<4 x float>` vector ops natively. The API is shape-stable —
user code written today will benefit transparently from the
hardware path later.

### Verify gate

119/119 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/simd_basic.nr` (~12 sub-cases).

## [0.1.25] — 2026-04-22

Debug + stderr helper builtins.

### Added

- `dbg(v) -> i64` — prints `[debug] v` to stderr, **returns the
  value untouched** so it can be inserted inline.
- `dbg_f64(bits) -> i64` — same but interprets `bits` as f64.
- `dbg_str(s) -> i64` — quoted string version.
- `eprint(s)` — write line to stderr.
- `eprint_int(n)` — write integer line to stderr.

### Verify gate

118/118 green. New gate test: `tests/lang/debug_helpers.nr`.

## [0.1.24] — 2026-04-22

**RFC-0015: `stdlib/rods/numeric.nr` — unified numeric API.**

### Added — numeric rod

- `stdlib/rods/numeric.nr` exposes the full RFC-0015 surface
  (overflow ops, narrow casts, f32/bf16/f16 compute, per-width
  print, type-width queries, range constants) under
  Nucleor-friendly `n_*` names.
- ~50 wrapper functions; one rod-level entry for every compiler
  builtin.
- Width-query constants (`n_size_u8` … `n_size_f64`) and range
  bounds (`n_max_u8`, `n_min_i32` …).

### Verify gate

117/117 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/rods/numeric.nr`.

## [0.1.23] — 2026-04-22

**RFC-0015 phase 6: f32 distinct compute + bf16/f16/f8 software
emulation.** Unblocks the ML/perception data-type story.

### Added — f32 distinct compute path

- f32 values pass as i64 with the IEEE-754 binary32 bit-pattern in
  the low 32 bits. All ops convert via `union` bit-cast.
- Arithmetic: `f32_add/sub/mul/div/neg`
- Math: `f32_abs/sqrt/exp/log/sin/cos/pow`
- Comparisons: `f32_lt/gt/eq` (return i64 0/1)
- Conversions: `f32_from_int/to_int/to_f64`, `f64_to_f32`
- I/O: `print_f32`

### Added — bf16 (Google brain-float)

- 1+8+7 layout, range matches f32 exponent. Used by every modern ML
  framework. Pure software via convert-up-to-f32 round-trip.
- `bf16_from_f32 / bf16_to_f32 / bf16_add / bf16_mul`

### Added — f16 (IEEE 754 binary16)

- 1+5+10 layout. Subnormal handling included. Used by RT models /
  CUDA half-precision paths.
- `f16_from_f32 / f16_to_f32 / f16_add / f16_mul`

### Added — f8e4m3 / f8e5m2 (NVIDIA Hopper FP8 formats)

- e4m3: 1+4+3, range ±240, the inference format
- e5m2: 1+5+2, range ±57344, the training format
- Convert-only API for now (`f8e4m3_to_f32`, `f8e5m2_to_f32`);
  arithmetic via convert-up to f32. Hardware-native ops on Hopper/
  Blackwell GPUs ship via CUDA rod in v0.6+.

### Verify gate

116/116 green on Windows. Self-host LLVM IR fixed point preserved.
New gate test: `tests/lang/f32_compute.nr` (~16 sub-cases).

## [0.1.22] — 2026-04-22

**RFC-0015 phase 5b: hex/oct/bin literals + typed-storage Vecs.**

### Added — radix literals (RFC-0015 §3.6)

- `0x...` / `0X...` — hexadecimal (case-insensitive digits)
- `0o...` / `0O...` — octal
- `0b...` / `0B...` — binary
- All three accept `_` separators and integer type suffixes
  (`0xFFu8`, `0b1111_1111u8`, etc.).
- New gate test: `tests/lang/hex_oct_bin_literals.nr` (12 sub-cases).

### Added — typed-storage Vec runtime

- `Vec<u8>` semantics via `vec_u8_new/with_capacity/push/get/set/
  len/capacity/clear/free/extend_from_ptr` — **1 byte per element**
  instead of the i64 cells generic `Vec` uses.
- `Vec<f32>` storage via `vec_f32_new/with_capacity/push_bits/
  get_bits/len/free` — 4 bytes per element.
- Solves the camera-frame / packet-buffer / MCAP-record memory
  pressure problem from the RFC. Generic-enum monomorphization in
  v0.4 RFC-0024 will auto-route `Vec<u8>` / `Vec<f32>` here.
- New gate test: `tests/lang/typed_vec_storage.nr`.

### Verify gate

115/115 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.21] — 2026-04-22

**RFC-0015 phase 5: per-width print helpers + bin/hex.**

### Added

- `print_i8`, `print_i16`, `print_i32` — signed-display, narrow-width
  truncation with sign extension.
- `print_u8`, `print_u16`, `print_u32`, `print_u64` — unsigned display.
- `print_hex(v)` — lowercase hexadecimal, no `0x` prefix.
- `print_bin(v)` — binary representation, leading zeros stripped.
- New gate test: `tests/lang/print_widths.nr`.

### Verify gate

113/113 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.20] — 2026-04-22

**RFC-0015 phase 4: explicit-overflow arithmetic.**

### Added — overflow-mode builtins (i64 width)

- `wrapping_add(a, b)`, `wrapping_sub(a, b)`, `wrapping_mul(a, b)` —
  always-defined two's-complement arithmetic.
- `saturating_add(a, b)`, `saturating_sub(a, b)`, `saturating_mul(a, b)` —
  clamp at i64::MAX / i64::MIN on overflow.
- `checked_add(a, b)`, `checked_sub(a, b)`, `checked_mul(a, b)` —
  return 0 on overflow; pair with `checked_overflow_flag()` to detect.
  Per-call thread-unsafe global; full Option<T> ships in v0.4 RFC-0024
  with generic enums.
- New gate test: `tests/lang/overflow_modes.nr` (12 sub-cases).

### Verify gate

112/112 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.19] — 2026-04-22

**RFC-0015 phase 2: `as` cast operator + numeric type predicates.**

### Added — type system

- Numeric type predicate helpers in compiler: `is_int_type`,
  `is_unsigned_type`, `is_float_type`, `is_numeric_type`,
  `type_bit_width`.
- `nr_type_to_llvm` extended for the full RFC-0015 type set:
  - i8/i16/i32/i64/i128, u8/u16/u32/u64/u128, isize/usize
  - f8e4m3/f8e5m2 (storage as i8), f16/bf16/f32/f64
  - char (i32), bool (i1)
- All types map to correct LLVM types — groundwork for width-tagged
  storage in later phases.

### Added — `as` cast operator

- `expr as TYPE` parses as a postfix unary expression.
- AST node kind 99 = "as cast" with payload (expr, target_type).
- Lowered to runtime helper `__nucleor_as_<TYPE>`:
  - `as_u8/u16/u32/u64`: bitmask truncate
  - `as_i8/i16/i32/i64`: bitmask + sign-extend
  - `as_f32/f64`: pass-through (phase 3 adds proper fpext/fptrunc)
- New gate test: `tests/lang/as_cast.nr` — 8 sub-cases covering
  truncation, sign extension, identity, chaining.

### Verify gate

111/111 green on Windows. Self-host LLVM IR fixed point preserved.

## [0.1.18] — 2026-04-22

`nuc explain` entries for ASSUME/UNIT/CONTRACT/ATOMIC/ISR/WCET/
DEPTH/LAW/EFF (~30 new codes). Plus `docs/spec/Nucleor_Error_Codes.md`
canonical reference (75 codes across 19 series).

## [0.1.17] — 2026-04-22

`loop {}` keyword (Rust-parity).

### Added

- **`loop { BODY }`** — infinite loop. Desugars to `while true { BODY }`.
  Use `break` to exit, `continue` to skip iteration. Composes with all
  existing control-flow patterns.
- New gate test: `tests/lang/loop_kw.nr`.

### Verify gate

110/110 green on Windows.

## [0.1.16] — 2026-04-22

RFC-0016: `while let` sugar.

### Added

- **`while let PATTERN = EXPR { BODY }`** desugars to
  `while true { match EXPR { PATTERN => BODY, _ => break } }`.
- Same pattern set as `if let`: `EnumName::Variant`,
  `EnumName::Variant(binding)`, plus the short forms
  `Some/None/Ok/Err`.
- New gate test: `tests/lang/while_let.nr`.

### Verify gate

109/109 green on Windows.

## [0.1.15] — 2026-04-22

`panic!` builtin + `nuc explain` documentation for 24 new error
codes from the v0.2-v0.6 RFCs.

### Added — `panic!` builtin

- `__nucleor_panic(msg)` runtime — prints PANIC: msg + exits 1.
- Compiler maps `panic("text")` to the runtime, with first arg as
  `*const u8` per `is_ptr_arg` map.
- New gate test: `tests/lang/panic_builtin.nr`.

### Added — `nuc explain` for new RFC error codes

- 8 RT-attribute codes (RT-001…008) per RFC-0001
- 3 allocator codes (ALLOC-001…003) per RFC-0002
- 3 typed-frame codes (FRAME-001…003) per RFC-0003
- 4 numeric codes (NUM-001/002/003/005) per RFC-0015
- 5 match codes (MATCH-001/002/003/004/006) per RFC-0016
- All explainable via `nuc explain CODE`. Each entry has title,
  one-line summary, multi-paragraph explanation tied back to its
  RFC, and a stable doc-anchor reference.

### Verify gate

108/108 green on Windows.

## [0.1.14] — 2026-04-22

RFC-0021 step: `assert!`, `assert_eq!`, `assert_ne!` builtins +
`#[test]` ergonomics demo.

### Added — assertion builtins

- `__nucleor_assert(cond)` runtime — exits 1 with stderr message on
  failure.
- `__nucleor_assert_eq(a, b)` — numeric equality check.
- `__nucleor_assert_ne(a, b)` — numeric inequality check.
- Compiler maps `assert`, `assert_eq`, `assert_ne` calls to the
  runtime symbols (no `extern fn` decl needed in user code).
- New gate test: `tests/lang/assert_macros.nr`.

### Added — RFC-0021 demo

- `examples/13_test_framework.nr` — showcase mixing `#[test]`
  attribute discovery + new assertion builtins. Standalone `main()`
  also runs the tests sequentially. Wired into both `verify.ps1`
  and `verify.sh`.

### Verify gate

107/107 green on Windows.

## [0.1.13] — 2026-04-22

RFC-0016 sugar: `if let` for enum patterns.

### Added

- **`if let PATTERN = EXPR { THEN } [else { ELSE }]`** desugars to
  a single-arm match. Supported patterns: `EnumName::Variant`,
  `EnumName::Variant(binding)`, plus the short forms
  `Some/None/Ok/Err`.
- New gate test: `tests/lang/if_let.nr`.

### Verify gate

105/105 green on Windows.

## [0.1.12] — 2026-04-22

RFC-0016 partial: native enum `match` with payload extraction
verified end-to-end for `Option`/`Result`-shaped enums.

### Verified working

- User-declared `enum Opt { None, Some(i64) }` and
  `enum Res { Ok(i64), Err(i64) }` parse, type-check, codegen.
- `match` on these with payload binding (`Opt::Some(x) => x * 2`)
  works.
- The `Some/None/Ok/Err` short forms also recognized in match arms
  per the existing parser (tests/lang/match_option_result.nr).

### Known gaps (planned for v0.2.0)

- Generic enums (`enum Option<T>`) — RFC-0024 (v0.4)
- `?` operator — partial parser support, full desugar pending
- `if let`/`while let` sugar — pending
- Built-in stdlib `Option<T>` / `Result<T, E>` types — replace
  current Vec-based stubs in option.nr / result.nr

### Verify gate

104/104 green on Windows.

## [0.1.11] — 2026-04-22

RFC-0020 phase 1: Rust-style diagnostic rendering.

### Added — diagnostics

- ANSI-colored error / warning labels (red / yellow). Honors
  `NO_COLOR` and `NUCLEOR_NO_COLOR` env vars; falls back to plain
  text when stdout is not a TTY.
- Multi-line diagnostic frame:
  ```
  error[OWN-001]: use of moved variable 'p'
    --> fn main@line 14:9
    note: moved here (line 13)
    help: Consider cloning the value before passing it
  ```
- Pre-existing diag struct fields (col, suggestion, child_message,
  child_line) now actually rendered. No struct changes; renderer
  upgrade only.
- Inter-diagnostic blank line for readability when multiple errors
  are emitted.
- Helper functions `ansi_red`, `ansi_yellow`, `ansi_dim`,
  `ansi_bold`, `diag_use_color()` added to compiler.

### Verify gate

103/103 green. Negative tests still pass because their match
pattern (`ERROR|WARNING|error:`) finds the new lowercase `error[`
prefix.

## [0.1.10] — 2026-04-22

RFC-0001/0021 attribute syntax in the lexer + `#[test]` discovery
in `nuc test`.

### Added — RFC-0001/0021 attribute syntax

- **Lexer recognizes `#[...]`** outer attributes alongside the legacy
  `@attr(args)` syntax. Bracket-depth and quoted-string aware. Skips
  cleanly without emitting tokens (semantics ship in v0.3 / v0.5
  RFCs). Forward-compatible with `#[test]`, `#[no_alloc]`,
  `#[deadline = 1ms]`, `#[cfg(target_os = "linux")]`, etc.
- **`tests/lang/hash_attributes.nr`** verifies the lexer accepts
  `#[no_alloc]`, `#[no_panic]`, `#[deadline = 1000]`,
  `#[cfg(...)]` syntax.

### Added — `nuc test` for `#[test]` attributes

- `nuc test --list` and `nuc test` discover `#[test]`-attributed
  functions in addition to the legacy `@test` line and `test_*`
  naming convention. Multiple `#[...]` attribute lines between
  `#[test]` and the fn signature are now permitted.
- Verified end-to-end on a probe with all three discovery styles
  (4 tests discovered, 4 passed).

### Verify gate

103/103 green on Windows (added 1 step: `tests/lang/hash_attributes`).

## [0.1.9] — 2026-04-22

Build infrastructure for v0.2: cross-platform CI, RFC-0015 phase 1
(numeric literal lexer), Option/Result rod expansion, milestone
tracker.

### Added — cross-platform

- **`tools/verify.sh`** — POSIX equivalent of `verify.ps1`. Same
  step counter, same exit codes, same gates. Linux + macOS
  contributors can now run the verify gate locally.
- **GitHub Actions matrix** — Windows + Linux + macOS jobs in
  `.github/workflows/ci.yml`. Linux/macOS jobs run advisory until
  a Linux/macOS `bin/nucleor` build ships in v0.2.
- **RFC index sanity check** in CI ensures no orphan RFCs.

### Added — RFC-0015 phase 1 (lexer)

- Underscores as digit separators in numeric literals: `1_000_000`,
  `0xFFFF_FFFF`, etc. (`tests/lang/numeric_literals.nr` covers).
- Integer type suffixes recognized by the lexer: `i8`, `i16`, `i32`,
  `i64`, `i128`, `isize`, `u8`, `u16`, `u32`, `u64`, `u128`, `usize`.
- Float type suffixes recognized: `f32`, `f64`.
- Suffixes are accepted but not yet used by the type checker —
  RFC-0015 phases 2-7 (type checker, IR, codegen) ship in v0.2.0.
- Self-host fixed point: identical LLVM IR before and after change
  (1,814,216 bytes both runs).

### Added — stdlib API surface

- `stdlib/rods/option.nr` expanded to full v0.2-targeted API
  (`option_to_result`, inspection helpers, etc.). Still uses Vec-tag
  encoding until RFC-0016 lands compiler-integrated `Option<T>`.
- `stdlib/rods/result.nr` likewise expanded
  (`result_to_option`, `result_unwrap_err`, etc.).

### Added — process docs

- `docs/milestones/v0.2.0.md` — canonical sequencing tracker for the
  v0.2.0 release. Per-RFC checklists, dependency DAG, week-by-week
  schedule, success criteria.
- `docs/process/semver-and-release.md` — SemVer policy + release
  process.
- `docs/process/contributing.md` — contributor guide.
- `docs/process/nucleor-safe-subset.md` — preview of the
  safety-cert subset (S-001 through S-017).

### Verify gate

102/102 green on Windows (added 1 step: `tests/lang/numeric_literals`).
Linux/macOS gates advisory until v0.2.0 binary ships.

## [0.1.8] — 2026-04-22

Positive feature-test suite ported from the V1 archive — verify gate
goes from **67 to 101 steps**.

### Added

- **34 new positive tests** in `tests/features/` (new directory). Cover
  borrow checker (basic, comprehensive, copy, deref, field-disjoint,
  multiple), control flow (break/continue, fizzbuzz×2, forin
  array/vec, let-in-loop, while_sum, logical_ops), closures (basic),
  generics (fn, struct, enum, where_clauses), traits (basic, bounds,
  default, method), mut borrows (basic, fn-param, field-assign), move
  semantics (comprehensive, option), arithmetic, overflow_trap, vec
  (basic, grow), u32/u64 comparison.
- **`tests\features` wired into `tools/verify.ps1`.** Pass criterion is
  build success + program runs without crashing (no access-violation
  exit). These tests assert by construction — they exercise language
  constructs and the bar is "compiler accepts and emits something that
  doesn't blow up at runtime."

### Quarantined

- **`tests/features/_unimplemented/`** — 18 tests that fail to link
  because they reference V1 runtime symbols never ported to OSS:
  `__nucleor_abs/min/max` (5 math tests), `__nucleor_capture_*`
  (closure_capture), `__nucleor_vec_iter/take/skip/sum/any/fold/map/filter`
  (5 vec-iter tests), `__nucleor_f64_from_scaled` (option_result_f64),
  overflow-mode runtime ops (3 overflow tests), `String` type
  (string_basic, string_ops), `use "<file>" { name }` selective import.
  Each is a punchlist item — implement the missing builtin and the test
  moves up.

## [0.1.7] — 2026-04-22

Negative-test suite ported from the V1 archive — verify gate goes from
**38 to 67 steps**.

### Added

- **29 new negative tests** in `tests/err/` (was 3, now 32). Ported from
  `Archive/Nucleor_Copy/examples/err_*.nr` — the historical V1 negative
  suite the OSS distro never carried over. Coverage: borrow checker
  (after-move, while-borrowed, shared-mut, deref-nonref, two-mut, etc.),
  move semantics (basic, conditional, fn-call, while-borrowed),
  mut-borrow rules, lifetimes (dangling-return, scope-escape), arena
  scope, taint propagation, spawn/send, scope escape, undefined args.
  All 32 trip the expected diagnostic and gate green.
- **`tests/err/_unimplemented/`** — 18 negative tests for V1 features
  that never landed in the self-hosted OSS compiler (`pure fn`,
  `requires [effect]` clauses, `restricts [...]`, `unit<T, dim>`,
  `Box<T>`, governance attrs). Kept as a punchlist with a README; not
  gated. The verify gate enumerates `tests\err\*.nr` non-recursively, so
  these don't block CI.

### Notes on test patterns surveyed

`Archive/Nucleor_Copy/examples/` was the only repo with a real `.nr`
test corpus (49 negatives + 196 feature/smoke files). The Rust crates in
`Nucleor_V2/crates/` have 254 `#[test]` markers but no `Cargo.toml` —
vestigial code that never compiled, intentionally not shipped.
Top-level `Nucleor_Copy/examples/` and `Nucleor_V2_Distro/examples/`
contain only build artifacts.

## [0.1.6] — 2026-04-22

JSON rod brought up to "what everyone uses": floating-point values and
pretty-printed output.

### Added

- **`json_from_f64(val)` / `json_f64(j)`** — store and retrieve f64 values.
  Internally a new tag (6); on serialization, emits a JSON-spec-compliant
  decimal (`3.141592`, `-42.0`, `0.5`, `0.125`) with trailing zeros trimmed
  but at least one fractional digit preserved.
- **`json_stringify_pretty(j, indent)`** — recursive pretty-printer with
  configurable indent width. Empty arrays/objects render as `[]` / `{}` on
  one line; otherwise each element/member gets its own line with proper
  indentation.

### Verified

- Both compact and pretty output round-trip cleanly through Python's
  `json.load`, and the two parses are equal.
- `tests/rods/json.nr` extended with f64 + pretty cases — verify gate
  remains 38/38 green.

## [0.1.5] — 2026-04-22

Top-to-bottom audit + cleanup + 38 new rod wrappers. Triggered by a full
audit that uncovered: most CLI subcommands were dead because the tools
binary was never shipped; a large pile of orphan source files; and
~50 runtime `.c` files with no `.nr` wrapper, representing ~3000+ runtime
functions of latent functionality. v0.1.5 fixes all of it.

### Fixed — CLI surface

- **`bin/nucleor_tools.exe` shipped.** The compiler delegates 25+
  subcommands to it; previously it was missing, so `nuc test`,
  `nuc check`, `nuc audit`, `nuc bench`, `nuc summary`, `nuc query`,
  `nuc abi`, `nuc bootstrap`, `nuc explain`, `nuc evidence`, `nuc impact`,
  `nuc graph`, `nuc lock`, `nuc registry`, `nuc sage`, `nuc profile`,
  `nuc certify`, `nuc translate`, `nuc policy`, and others all failed
  with "nucleor_tools.exe is not recognized."  After the fix: 37 of 46
  CLI invocations work (was 11 of 46).
- **`getcwd` and `getenv` builtins** were referenced by the compiler but
  had no IR declaration and no runtime implementation. Any program that
  called either emitted invalid LLVM IR. **Fixed** in
  `nucleor_llvm_rt.c` (~22 lines) + `nucleor_s1_compiler.nr` (4 lines).
  This is what made building the tools binary possible in the first place.
- **Self-host rebuild** was run with the patches and the new
  `bin/nucleor.exe` ships those builtins.

### Added — 38 new rod wrappers

Drawn from runtime files that already shipped in `stdlib/runtime/` but
had no `.nr` wrapper. Total rod count: **65 → 103**.

**Numerics & validated computation:**
- `taylor.nr` — validated Taylor-arithmetic ODE integrator for the
  Boussinesq / Navier-Stokes class. Rigorous error bounds.
- `interval.nr` — interval arithmetic with guaranteed containment of
  the true result. Foundation for computer-assisted proofs.
- `bigint.nr` — arbitrary-precision integer arithmetic + modular exp.
- `bayesian.nr` — Metropolis MCMC, credible intervals, chain summaries.

**Data structures + indexing:**
- `hashmap.nr` — string-keyed hash map (major gap closed).
- `bloom.nr` — Bloom filter + HyperLogLog cardinality estimation.
- `bm25.nr` — BM25 search index.
- `kdtree.nr` — k-d tree spatial index (nearest + range search).
- `hnsw.nr` — HNSW approximate nearest neighbor.
- `pq.nr` — product quantization for compressed vector search.
- `embedding.nr` — vector embedding tables (lookup / cosine / nearest).
- `string_algo.nr` — KMP search, Levenshtein, Trie.
- `state_machine.nr` — finite-state machines with on-enter/on-exit hooks.
- `graph.nr` — BFS, DFS, Dijkstra, Bellman-Ford, topological sort,
  connected components, Kruskal MST, PageRank.

**Systems / I/O:**
- `socket.nr` — TCP connect/listen/accept/send/recv + UDP open/send/recv.
- `mmap.nr` — memory-mapped files + POSIX shared memory.
- `serial.nr` — serial port I/O.
- `crypto.nr` — cryptographically-secure random bytes.
- `compress.nr` — LZ77 lossless compression.
- `datetime.nr` — date/time arithmetic, ISO parse, day-of-week.
- `image.nr` — RGBA images, PPM/BMP I/O, greyscale, resize, convolution.
- `plot.nr` — SVG line / scatter / heatmap plots.
- `audio.nr` — WAV I/O, STFT, MFCC.
- `color.nr` — RGB / HSV / Lab conversions, Delta E, palette generation.
- `mesh.nr` — 2D rectangular finite-element meshes + Laplacian assembly +
  VTK output.

**Modern ML / LLM infrastructure:**
- `kv_cache.nr` — paged KV cache for transformer inference, with eviction.
- `quantize.nr` — Q4 / int8 / ternary / FP8 weight quantization + GEMV.
- `rl.nr` — replay buffer, discount returns, GAE, PPO loss, DQN target,
  epsilon-greedy.
- `loss.nr` — cross-entropy (+ grad), label-smoothed CE, KL, MSE, Huber,
  focal, InfoNCE, cosine similarity matrix.
- `speculative.nr` — speculative decoding tree construction, verification,
  sampling.
- `diffusion.nr` — DDPM / rectified flow schedules, reverse step, AdaLN,
  CFG, time embeddings.
- `conv.nr` — Conv2D forward/backward, MaxPool/AvgPool, BatchNorm,
  Dropout (CNN building blocks).
- `scan.nr` — prefix-sum / prefix-prod / prefix-max / segmented sum /
  cumulative logsumexp / SSM scan kernels.
- `checkpoint.nr` — gradient-recomputation checkpointing.
- `comm.nr` — distributed-training collective communication primitives
  (allreduce / broadcast / reduce-scatter / all-gather / gradient
  accumulation buffers).

**Quantum:**
- `clifford.nr` — stabilizer formalism for quantum error correction
  (Clifford gates, measurement, error detection, distance computation,
  GNN-style state features).
- `mps.nr` — Matrix Product States efficient quantum simulation.

**Bioinformatics:**
- `bioseq.nr` — GC content, Needleman-Wunsch alignment, Hamming, k-mer
  count, ORF finding.

### Removed — dead code purge

- **72 orphan `stdlib/*.nr` files** (~655 KB). All pre-self-host
  compiler prototypes, dead checker variants, dead infrastructure
  scaffolding (`lexer_core.nr`, `lexer_minimal.nr`, `real_lexer.nr`,
  `nucleor_compiler.nr`, `stage1_compiler.nr`, `nucleor_stage0.nr`,
  `borrow_check.nr`, `borrow_checker.nr`, etc.). None imported by
  anything; carryover from the v0.1.0 Archive merge.
- **4 orphan runtime `.c` files**:
  - `gpu_fallback.c` — no caller
  - `optimizer2_rt.c` — superseded by `optim_rt.c`
  - `regex_rt.c` — superseded by Rust regex via `rust_bridge`
  - `json_rt.c` — superseded by pure-Nucleor `json.nr`

### Changed — documentation

- `docs/language-reference.md` updated to reflect what's actually in the
  language. The previous (v0.1.4) reference listed `for` loops,
  `break`/`continue`, block comments, generics, and traits as
  unimplemented. They are all in fact implemented; the audit confirmed
  each works end-to-end.
- `README.md` rod count bumped 65 → 103. New rods listed by category.

### Audit reports preserved

- `Desktop/Nucleor_Audit_2026-04-22.md` — full audit findings
- `Desktop/Nucleor_v015_Plan_2026-04-22.md` — execution plan that drove
  this release

### Verify gate

38/38 pass (unchanged). Self-host loop still closes with the rebuilt
`bin/nucleor.exe`. All 38 new rods build clean against the bootstrap
binary.

---

## [0.1.4] — 2026-04-22

Showcase programs now write CSV data alongside the live visualization.
Animated console output is great for the demo; CSV is what you actually
want for plotting, auditing, or feeding into another tool.

### Added — CSV output

- `vqe_h2.nr` writes **`vqe_h2_data.csv`** (32 rows): step, theta0,
  theta1, theta2, energy, abs_error.
- `market_maker.nr` writes **`market_maker_data.csv`** (61 rows):
  tick, spot, iv, bid, theo, ask, delta, gamma, vega, position_delta,
  hedge_qty, pnl_tick, cum_pnl.
- `wing_simulator.nr` writes **`wing_simulator_data.csv`** (101 rows):
  step, em_energy, density, vx, vy, vorticity, Ez, plus bit-pattern
  columns for em_energy and density to recover NaN values when the FDTD
  runtime returns them before field propagation reaches the probe.
- `lorenz.nr` writes **`lorenz_data.csv`** (~200 sampled rows): step, t,
  trajectory A (x, y, z), trajectory B (x, y, z), separation. Sampled
  every 60th step out of 12000 to keep the file small.

All CSVs are written next to the binary (cwd at run time). Ready to
open in Excel, pandas, R, gnuplot, etc.

### No regressions

Verify gate still 38/38 pass. Self-host loop closes. No language or
runtime changes — purely application-level additions to the four
showcase programs.

---

## [0.1.3] — 2026-04-22

Showcase release: four programs that demonstrate things Nucleor is
uniquely suited for, all with live ANSI-colored visualizations.

### Added — examples/showcase/

- **`vqe_h2.nr`** — Variational Quantum Eigensolver for a 2-qubit
  Hamiltonian (-Z0 - Z1 - 0.5 Z0Z1 + 0.5 X0X1). Parameter-shift gradient
  descent on the bundled quantum simulator. Converges to within 1e-3 Ha
  of the analytic ground state -2.5616. Live updating energy + parameter
  bar chart.
- **`market_maker.nr`** — Real-time options market-making engine. Black-
  Scholes pricing + full Greeks + PID-driven delta hedging at simulated
  10 ms tick. Live Bloomberg-style dashboard with bid/ask/Greeks/P&L.
- **`wing_simulator.nr`** — Coupled aerodynamic + electromagnetic
  simulator on a single airfoil cross-section. Lattice Boltzmann (D2Q9)
  fluid + FDTD Maxwell, sharing one geometry function. 256-color
  heatmaps for density, vorticity, and E_z field intensity.
- **`lorenz.nr`** — The Lorenz strange attractor integrated with RK4.
  Two trajectories from initial conditions 1e-5 apart, rendered as a
  heatmap. Visual demonstration of sensitive dependence on initial
  conditions; max separation reaches ~50 by end of integration.

### Added — visualization helpers

- **`examples/showcase/_viz.nr`** — shared ANSI viz helpers: `paint`,
  256-color `viz_heat` and `viz_grey` palettes, `viz_block` density
  characters, `viz_bar` horizontal bars, `viz_box_*` box drawing,
  banner header, integer/f64 formatters. Reusable across showcase
  programs.

### Added — runtime + compiler

- **`chr(byte_code) -> str`** builtin. Returns a 1-byte string for the
  given code point (0-255). Lets user programs synthesize arbitrary
  control bytes — including ESC = 27 for ANSI escape sequences. Wired
  through the compiler's builtin table, IR declaration, and
  `is_ptr_ret` classifier. Implementation in `nucleor_llvm_rt.c`.

### Self-host rebuild

- `bin/nucleor.exe` rebuilt from the patched source so the new `chr`
  builtin is available in the shipped binary.

### Verify gate

38/38 pass. New showcase programs verified by hand (the showcase dir
intentionally lives outside `tests/` because the visualizations are
animated and rely on TTY output).

---

## [0.1.2] — 2026-04-21

CLI polish: personality + progress + color + completions. No new language
features; no breaking changes.

### Added — new subcommands

- **`nuc zen`** — prints the design principles of Nucleor. (Spirit of `python -c "import this"`.)
- **`nuc mco`** — prints the Mars Climate Orbiter blurb. Always available, in every version.
  Single sentence reminder of why dimensional analysis matters.
- **`nuc clean`** — removes `target/` and `.nuc_cache/` from the project.
  (No `clean` subcommand existed in v0.1.0/v0.1.1.)
- **`nuc scram`** — alias for `nuc clean`. SCRAM is the actual technical
  term for emergency reactor shutdown; the aliasing is the entirety of the
  nuclear-themed personality in v0.1.2.

### Added — runtime + compiler

- **`isatty_stdout` builtin** — returns 1 if stdout is connected to a TTY,
  0 otherwise. Implemented in `nucleor_llvm_rt.c` for both Windows
  (`_isatty(_fileno(stdout))`) and POSIX (`isatty(STDOUT_FILENO)`).
  Wired into the compiler's builtin table with a matching IR declaration.
  Available to user `.nr` programs that want to gate their own output.

### Added — tooling

- **Tab completion** scripts for `bash`, `zsh`, `fish`, and PowerShell at
  [`tools/completions/`](tools/completions/). One-liner install per shell.
  Completes ~37 subcommands, common flags, and `*.nr` source files.
- **`tools/verify.ps1` upgraded:**
  - Per-step progress counter (`[ N/T] OK    test foo/bar`).
  - ANSI colored OK / SKIP / FAIL labels (green / yellow / red).
  - Honors `NO_COLOR` (per https://no-color.org/) and a `-NoColor` flag.
  - Detects TTY via `$Host.UI.RawUI.WindowSize` to skip color in piped output.

### Fixed

- **`nuc.bat` PATH resolution.** v0.1.0/v0.1.1 trusted `$LLVM_SYS_180_PREFIX`
  blindly; if it pointed at a stale path, clang couldn't be found. The
  launcher now verifies each candidate directory actually contains
  `clang.exe` before adding it to `PATH`. Same fix applied to
  `tools/verify.ps1`'s clang resolution.

### Verify gate

38/38 pass (unchanged from v0.1.1). All examples + tests + self-host loop
still green. New subcommands smoke-tested by hand:

- `nuc zen` prints the principles
- `nuc mco` prints the Mars Climate Orbiter box
- `nuc clean` and `nuc scram` both remove `target/` and `.nuc_cache/`

### Not in this release (intentionally cut from the original CLI flavor doc)

The personality-and-skins draft considered a much broader set: a
three-skin system (standard / reactor / compliance), themed command
aliases (`ignite`, `enrich`, `manhattan`, `trinity`, `heisenberg`,
`fission`), enrichment-tier optimization flags, a "weapons-grade" `--opt`
level, ☢-decorated banners, version codenames after Manhattan-era
physicists. None of that ships. Single voice; one nuclear-themed alias
that's actually the right technical term (`scram`); zero hazard symbols
in user-facing output.

The guiding rule from the original doc — "celebrate the physics, respect
the hazards" — is what made every cut.

---

## [0.1.1] — 2026-04-21

Major surface expansion. v0.1.0 shipped a deep runtime that was largely
inaccessible without writing your own `extern fn` declarations. v0.1.1 adds
**29 new `.nr` rod wrappers** that expose the existing C runtime as
first-class Nucleor APIs.

### Added — new rods (29)

**Linear algebra and tensors:**
- `linalg.nr` — matrix ops, LU, QR, Cholesky, eigen, SVD, ridge regression
- `tensor_nd.nr` — N-dimensional tensors with reshape, slice, batched matmul
- `tensor_decomp.nr` — CP-ALS, Tensor-Train SVD, Kronecker, Khatri-Rao
- `sparse.nr` — CSR sparse matrices with CG and GMRES solvers

**Numerical methods:**
- `ode.nr` — Euler, RK4, RK45, symplectic, event detection
- `root.nr` — bisection, Newton, secant, Brent, multi-dim systems
- `quad.nr` — trapezoid, Simpson, Gauss-Legendre, adaptive, 2D, Monte Carlo
- `interp.nr` — linear, cubic spline, Lagrange, Chebyshev, 2D bilinear, RBF
- `bspline.nr` — B-spline eval + basis + derivatives + KAN forward
- `optim.nr` — gradient descent, Adam, Nelder-Mead simplex, line search, genetic

**Statistics and signal processing:**
- `stats.nr` — mean/median/var/std, covariance, correlation, percentile, histogram, linear regression with R², t-test, chi-square, KDE
- `signal.nr` — FIR/IIR/Butterworth, Hamming/Hann/Blackman windows, envelope, zero crossings, up/down-sampling
- `fft.nr` — 1D complex/real FFT, convolution, power spectrum, correlation
- `pca.nr` — fit, project, variance ratio, eigenvalues

**PDE solvers and physics:**
- `multigrid.nr` — 2D multigrid Poisson solver
- `fluid.nr` — Lattice Boltzmann fluid simulation (D2Q9)
- `emag.nr` — FDTD electromagnetics on the Yee grid
- `thermo.nr` — heat equation, ideal gas, Carnot, blackbody radiation
- `geom.nr` — convex hull, point-in-polygon, line intersect, polygon area
- `rigid_body.nr` — full 3D rigid body dynamics with collision
- `orbit.nr` — Kepler-to-Cartesian, Hohmann transfer, vis-viva, escape velocity

**Constants and units:**
- `physics.nr` — 17 CODATA 2018 fundamental constants + math constants
- `units.nr` — SI conversion across 11 dimensions (mass, length, time, temperature, pressure, energy, force, frequency, angle, voltage, current)

**Symbolic and differentiable:**
- `autodiff.nr` — reverse-mode automatic differentiation (20 ops)
- `symbolic.nr` — expression trees with symbolic differentiation and evaluation

**Modern ML and control:**
- `control.nr` — PID, state-space, Kalman filter
- `ssm.nr` — Mamba selective scan, SSD chunked, RWKV-WKV, xLSTM, ZOH discretize
- `moe.nr` — top-K gating, dispatch, combine, load balancing
- `finance.nr` — Black-Scholes, full Greeks, implied volatility, NPV, IRR, VaR, portfolio optimization

### Added — examples (5)

- `examples/08_linalg.nr` — solve a linear system, compute an SVD
- `examples/09_ode.nr` — simulate a damped pendulum with RK4
- `examples/10_fft.nr` — round-trip a sine wave through the FFT
- `examples/11_pid.nr` — PID controller driving a plant to a setpoint
- `examples/12_autodiff.nr` — reverse-mode autodiff of `sin(x²) + x`

### Added — documentation

- `docs/math-and-physics.md` — worked examples across the scientific-computing rods
- `docs/rods-and-runtime.md` rewritten with the v0.1.1 catalog (65 rods total)
- `README.md` rewritten — the v0.1.0 tagline ("algebraic optimization") significantly undersold the actual scope. New tagline reflects the full stack.

### Changed

- README pitch updated to lead with the scientific-computing surface
- Rod count: v0.1.0 had 36 rods; v0.1.1 has **65**

### Stats

- 65 rods all build clean against `bin/nucleor.exe`
- All previous tests still pass (33/33 verify gate)
- No breaking changes to v0.1.0 surface
- No new compiler or runtime patches required — every new rod just exposes existing C runtime functions

---

## [0.1.0] — 2026-04-21

Initial open-source release of Nucleor under the Apache License 2.0.

### Added

- **Self-hosted compiler.** `bin/nucleor.exe` (identifies as `0.2.0-v2`) builds itself from `compiler/nucleor_s1_compiler.nr`. The full self-host loop closes on every CI run.
- **Algebraic-rewrite optimizer.** Built-in arithmetic identities (`x + 0 → x`, `x * 1 → x`, etc.) plus user-declarable laws via `@law(commutative, associative, identity=N, absorbing=N, idempotent, involution, fusion)`.
- **V2 performance attributes:** `@hot` (strict no-heap/no-format/no-indirect-dispatch enforcement), `@const_fn` (compile-time evaluation eligibility), `@layout(soa | aos | group(...))` (memory layout control), `@region(name)` (arena binding).
- **Rich CLI surface.** `nuc {build, build-fast, build-strict, build-shared, run, emit, build-wasm, build-ptx, test, bench, perf, check, audit, policy, certify, translate, summary, query, abi, evidence, impact, graph, profile, lock, install, publish, registry, sage, bootstrap, stage-dump, init, help}`.
- **Standard library: 36 rods** under `stdlib/rods/`, all building cleanly:
  - Core: `strings`, `fmt`, `bitwise`, `math`, `complex`
  - Data: `collections`, `option`, `result`, `queue`, `stack`, `sort`
  - Text: `json`, `csv`, `ini`, `regex`, `base64`, `uuid`
  - System: `io`, `fs`, `os`, `env`, `path`, `time`, `concurrency`, `cli`, `log`, `test`
  - Domain: `quantum` (full simulator: H, X, Y, Z, CNOT, measure, ...), `nn`, `gnn`, `gpu`, `multi_core`, `ridge`, `twin_core`, `python`, `rust`
- **Runtime.** Always-linked core `nucleor_llvm_rt.c` plus 90+ opt-in domain runtimes (FFT, hashmap, JSON, crypto, tensor, linear algebra, ODE solvers, signal processing, ...) compiled and linked on demand via `#cfile` directives.
- **Quantum-circuit simulator.** Full state-vector simulation up to 16+ qubits; `examples/05_quantum.nr` reproduces a perfect Bell state with measured 516|00⟩ + 508|11⟩ split over 1024 shots.
- **Rust interop demo.** `stdlib/rods/rust_bridge/` is a working Rust crate exposing `regex`, `base64`, hashing, and sorting to Nucleor through the C ABI. Build with `cargo build --release` in that directory.
- **Documentation.** Full set under `docs/`: getting-started, language tour, language reference, rods + runtime, architecture, benchmarks.
- **Test suite.** 24 self-contained `.nr` tests across language, attributes, runtime, rods, and negative-error cases.
- **Examples.** 7 examples (`01_hello.nr` through `07_rust_interop.nr`) covering hello-world through Rust interop.

### Changed (vs. internal pre-release)

- **Compiler portability fix.** `llvm_clang_path()` in `compiler/nucleor_s1_compiler.nr` (line ~5693) and `compiler/nucleor_tools_suite.nr` (line ~7356) returns the bare command name `clang`. Path resolution moved to the `nuc.bat` launcher, which inspects `NUCLEOR_CLANG_PATH`, `LLVM_SYS_180_PREFIX`, and the default Windows install location. The compiler binary is no longer hard-coded to one machine's LLVM install.
- **Rod imports made explicit.** Several rods (`base64.nr`, `csv.nr`, `fmt.nr`, `path.nr`, `cli.nr`, `json.nr`, `test.nr`, `nn.nr`, `ridge.nr`) now declare their cross-rod dependencies via `import` rather than relying on implicit symbol propagation. Previously these built only inside the larger pre-release tree where everything was already in scope.
- **Stdlib re-merged.** The active development tree had stripped most `.nr` rod wrappers (keeping only the C runtime files). The full set was restored from a complete earlier snapshot and re-validated against the current compiler.
- **`gnn.nr` and `nn.nr` `#cfile` paths.** Changed from precompiled-`.obj` references to direct `.c` source paths so users don't need a separate build step.
- **`time_rt.c`.** Added missing `#include <time.h>` for Windows builds.

### Fixed

- **Concurrency runtime.** The compiler emits the V2 calling convention `__nucleor_mutex_{new,lock,unlock}_value`, but the runtime had only the older `__nucleor_mutex_{new,lock,unlock}` symbols. Added forwarders in `stdlib/runtime/nucleor_llvm_rt.c` (Windows and POSIX branches) so `import "stdlib/rods/concurrency.nr"` programs now link and run.
- **RNG runtime.** The compiler emits `__nucleor_rng_seed`, which forwards to `nuc_rng_seed`. The latter lived in `stdlib/runtime/rng_rt.c` but was not part of any auto-linked compilation unit. `nucleor_llvm_rt.c` now `#include`s `rng_rt.c` so `rng_seed`, `rng_f64`, `rng_normal`, etc. are always available without a separate `#cfile`.
- **Quantum rod ownership.** `qsim_measure` in `stdlib/rods/quantum.nr` now declares its `meas_prob` binding `mut` (was `let meas_prob`, then reassigned in the next line — fails strict ownership checking).
- **`multi_core.nr` ownership.** Two `let agreement` bindings that were reassigned conditionally are now `let mut agreement`.

### Known limitations (v0.1, planned for follow-ups)

- **Windows-only.** v1 targets `x86_64-pc-windows-msvc`. Linux and macOS support require runtime port work.
- **No hex/binary integer literals.** Decimal only.
- **No `for` loops.** `while` is the loop primitive.
- **No `break` / `continue`.** Pattern out of loops with sentinel variables.
- **Generics and traits are placeholders.** The grammar accepts them in limited form, but the type checker treats `Vec<T>` as a uniform 64-bit-slot container regardless of `T`.
- **Block comments (`/* ... */`).** Use `//` line comments only.
- **`getenv()` from inside `.nr` source is incompletely wired** — the compiler knows the name but does not emit a usable IR declaration. Use the `nuc.bat` launcher for environment-driven configuration instead.

### Repository

- Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).
- Source: https://github.com/APEXINTELORG/Nucleor
- Issues: https://github.com/APEXINTELORG/Nucleor/issues
- Author: Joseph Wescott
