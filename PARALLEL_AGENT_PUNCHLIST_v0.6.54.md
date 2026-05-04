# Parallel Agent Punchlist (post-v0.6.54, updated post-v0.6.61)

> Drafted 2026-05-03 by main agent. Split of the forward-roadmap
> items parked in finding promotions during the v0.6.48–v0.6.54
> closure stream. Probe inbox is at **0 unmatched** as of v0.6.54.
> The work below is what's left for the helper agent to grind on
> while the main agent handles new probe findings + integration.
>
> **Update post-v0.6.61:** main agent shipped v0.6.55–v0.6.61
> closing 8 of 11 rust-syntax-translation-fidelity audit rows
> (const-fn, unreachable!, break-with-value, raw-string, byte-
> string, for-tuple-destruct, UFCS, struct-destructure-in-let).
> Helper shipped RFC-0034 gap 2 (negative usize default) bundled
> in v0.6.56. Audit now has 1 remaining substantive row (char
> literal — type-system gap, not halt-class) plus 2 rows already
> addressed by sister findings.

## Operating constraints (ALL items below)

**Memory + compile budget — "as fast as physics allows":**

- cold compile time: target ≤ 3.5s, hard ceiling 5.93s (warn)
  / 6.5s (e-stop). v0.6.54 baseline: 3.08s.
- hot compile time: ≤ 1.74s. v0.6.54 baseline: 0.25s.
- peak memory: ≤ 770 MB self-host (1 GB e-stop). v0.6.54
  baseline: 316 MB.
- ANY perf regression > +50ms cold or +30 MB peak is a ship
  blocker — bisect with `tools/check_perf_regression.ps1` before
  promoting. The `feedback_perf_regression_pattern.md` user
  memory has the recipe.

**Cadence:** every closure of a punchlist item also runs the
3-sample perf ladder. Save the deltas to
`Desktop\Nucleor_PERF_AUDIT_<date>.md`. Same cadence as the
`feedback_nucleor_perf_audit_cadence.md` rule.

**Validation:** `bash tools/verify.sh` must pass green (783+ steps).
Round-2 fixed-point preserved on every ship. Drift gate clean.
Bootstrap seed refreshed when compiler source changes IR shape.

## Punchlist — Group A: Diagnostic + parse extensions (ship size: small-medium)

These are concrete fixes the helper can prep end-to-end on
`probe/exploration` for main-agent integration. Each is a 1-3
line check or small parse-extension.

### A1 — NUM-021 gap 1: u64 const overflow

`const B: u64 = 18446744073709551615 + 1;` silently compiles
(rc=0, value wraps). Sister to v0.6.50 gap 4 + v0.6.53 gap 3.
Forward-roadmap is u64-aware const-eval — currently
`const_i64_expr` only tracks i64 arithmetic.

**Fix shape:** add unsigned-aware const-eval pass that detects
u64 overflow at the const-decl / let-binding type-check site.
Fire NUM-021. Sister fix to the gap 1 entry of
`findings/promoted/2026-05-02-num-021-coverage-gaps-u64-imin-shift-divzero.md`.

**Risk:** medium. Const-eval substrate change. Use existing
`wrapping_add_u64` / `checked_add_u64` runtime helpers — no new
IR declares needed.

### A2 — u64 strict-arith runtime panics

`let x: u64 = u64::MAX; let y: u64 = x + 1;` silently wraps at
runtime (asymmetric with i64/i32/i16/i8 which already panic via
NUCLEOR_INT_STRICT_INTRIN=1). Sister to A1 at runtime.

**Fix shape:** add 3 runtime helpers
(`__nucleor_panic_add_u64`, `panic_sub_u64`, `panic_mul_u64`)
mirroring the existing i64 versions. Lower u64 binops through
them under NUCLEOR_INT_STRICT_INTRIN=1.

**⚠️ BOOTSTRAP-CYCLE-HOLE RISK CLASS:** new IR declares hit the
v0.6.48-attempt-1 hole. Use the v0.6.52 sidestep pattern (XOR
with sign-bit using existing helpers) where possible. If new
declares are unavoidable, validate the bootstrap chain manually:
build, install, rebuild from current source, confirm round-2
fixed-point, refresh seed, run verify.

### A3 — RFC-0034 gap 2: negative usize default

`fn f[N: usize = -1](x: i64) -> i64 { ... }` silently accepts
the negative default. Tracked in
`findings/promoted/2026-05-02-rfc0034-ct-param-first-pass-residual-edges.md`.

**Fix shape:** validate the default literal in
`skip_compile_time_param_default` — for unsigned CT-param types,
reject kind-5 unary-minus on a kind-1 literal. Small parse-time
check.

**Risk:** low.

### A4 — RFC-0034 gap 1: explicit CT-arg call SEGFAULT

`ct_inc[42](x)` SEGFAULTs at runtime (rc=139). Same finding as
A3.

**Fix shape:** detect the `identifier[expr](args)` shape in
`parse_postfix` when `identifier` resolves to a fn name, halt
with "explicit CT-arg call form not yet supported in RFC-0034
first-pass; omit the [N] and let the default erase."

**Risk:** medium. Touches parse_postfix.

### A5 — Type alias resolver

`type Name = i64; let x: Name = 5;` accepts at parse but the
alias never resolves at use sites — TYP-006 fires. Tracked in
`findings/promoted/2026-05-02-module-scope-decl-silent-noop-gaps-type-mod-union-use.md`.

**Fix shape:** wire alias resolution into `nr_type_to_llvm` and
`type_expr` at type-string lookup time. Walk the parse_type_alias_decl
results, build an alias map, substitute when used.

**Risk:** medium. New resolver substrate.

### A6 — Match-arm literal overflow

`match x { 9223372036854775808 => 1, _ => 0 }` silently dead-arm
because the lexer wraps the literal to i64::MIN at storage.
Tracked in
`findings/promoted/2026-05-01-match-arm-literal-exceeds-i64-silently-dead.md`.

**Fix shape:** lexer-level token flag for decimal literals in
(i64::MAX, u64::MAX]; parse_match_one_pattern checks the flag
and emits a clean diag.

**Risk:** medium. Lexer + parser tweaks.

### A7 — Tuple-struct decl + nested struct pattern (parse extensions)

Tuple-struct `struct P(T1, T2);` halt was shipped in v0.6.53
(clean diag pointing at named-field workaround). The actual
support — positional field synthesis (`__0`, `__1`) and `.0`/`.1`
access path — is still forward-roadmap. Same finding covers
nested struct patterns `match l { Line { a: Point { x }, b } =>
... }` (recurse into inner pattern).

**Fix shape:** extend `parse_struct_decl` to accept the paren-
form, synthesize positional field names; extend
`parse_match_struct_binding_block` to recurse via
`parse_match_one_pattern` for each field's binding.

**Risk:** medium-high. Parse + type-resolver work.

### A8 — Keyword silent-strip remaining cases

`unsafe fn` halt shipped in v0.6.53. Remaining sub-cases of
`findings/promoted/2026-05-01-keyword-silent-strip-audit.md`:

- `move` closure form (clang-link error `@move undefined`).
- `where T: NoSuchTrait` silently accepted (no trait-name validation).
- `'static` lifetime corner-case parse errors.

**Fix shape:** halt at parse for each form. Match the v0.6.53
unsafe-fn precedent. `move` needs lex-time detection + closure-
side capture lowering.

**Risk:** low to medium.

## Punchlist — Group B: Perf objectives ("as fast as physics allows")

These are perf-driven items. Run perf ladder before/after every
ship. Memory hard-cap is 770 MB.

### B1 — Per-call-site tprof guard wrap (deferred from v0.6.54)

Six tprof_mark sites in `type_expr` kind-7 still call
`tprof_mark` unconditionally; the helper does an internal
tprof_enabled check but the fn-call overhead is paid per kind-7
call. The slice patch wrapped each with
`if prof_on_v631 > 0 { tprof_mark(...); };`.

**Fix shape:** wrap each of the 6 unguarded `tprof_mark(tprof,
9, 10, call_start);` sites in `type_expr` kind-7 with the
`prof_on_v631 > 0` guard.

**Expected gain:** marginal (~50-100ms cold). Worth picking up
since the substrate is already there.

### B2 — Hotspot top-5 reductions

v0.6.54 hotspot ranking (re-measure after each ship):

| helper | calls (self-host) | notes |
|---|---|---|
| vec_get | ~118 M | already minimal hot path |
| str_eq | ~61 M | already first-byte-fail; consider intern hashing for known-static strings |
| vec_push | ~39 M | could inline grow path for small caps |
| str_concat | ~3.4 M | candidate for arena-backed bulk concat |
| str_substring | ~2.8 M | candidate for arena-backed substring |

**Forward-roadmap:** an internal-compile string arena (`str_arena_*`
helpers exist for adopters but the compiler doesn't route its own
str_concat/substring through them). Cross-cutting refactor.

**Risk:** medium-high. Sister to A5 alias resolver in invasiveness.

### B3 — vec_get_unchecked variant (compiler-internal)

Compiler emits `vec_get` even when bounds are statically known
(immediately after `vec_len` checks). A `vec_get_unchecked`
variant skipping the bounds check would reduce per-call cost on
the hot path. Cross-cutting compiler-side change (tag known-
in-bounds call sites).

**Expected gain:** could be substantial on vec_get's 118M calls.

**Risk:** medium-high.

### B4 — String constant pool dedup (CLOSED v0.6.70)

`strtab_intern` shipped: 4572 fewer `@.str.` references on the
self-host (-24% string constants), .ll output -3.1% (-306 KB).
Cold time +80ms within natural variance band.

## Punchlist — Group D: Windows-PE link-hang investigation (added 2026-05-04 by main agent)

> **Critical-path item — assigned to probe.**
>
> Two main-agent ships (v0.8.79, v0.8.83) attempted compiler.nr
> text edits, both produced the SAME failure shape:
> stage1+stage2 IR md5 match, but the resulting Windows PE bin
> (built from new seed.ll + nucleor_llvm_rt.c via
> `clang -fuse-ld=lld`) hangs on EVERY user-source compile at
> the line `incremental: module graph cache hit`. Reverting
> compiler.nr + bootstrap/nucleor_s1_seed.ll restores function.
>
> The Stage1 ELF binary (target/nucleor_s1.exe — clang's default
> output target on MSYS bash, Linux ELF format) compiles user
> source CORRECTLY using the same IR. So the bug is not in the
> compiler IR semantics; it's in the LLD-link Windows PE path.
>
> Memory file `feedback_nucleor_self_host_validation.md` has the
> full diagnosis. This blocks ALL Phase 2b compiler-edit ships
> for: T-3, T-4, NUM-G9, E-1/2/3, RT-G1..G10, LAW-1, ROBO-7.
> ~70% of remaining v1.0 critical-path work is gated on this.

### D1 — Bisect the IR delta between working and hanging seed.ll

**Repro recipe** — from a clean tree at v0.8.81 (commit
f9d9c157), the working baseline:

```
git checkout f9d9c157
rm -rf target/.nuc_cache target/.nuc_cache_v2 target/.nuc_native_cache
bin/nucleor.exe build compiler/nucleor_s1_compiler.nr -o nucleor_s1
target/nucleor_s1.exe build compiler/nucleor_s1_compiler.nr -o nucleor_s2
md5sum target/nucleor_s1.ll target/nucleor_s2.ll      # must match
cp target/nucleor_s2.ll /tmp/seed_working.ll
# Build Windows PE from working seed (control)
"/c/Program Files/LLVM/bin/clang.exe" -fuse-ld=lld \
    /tmp/seed_working.ll stdlib/runtime/nucleor_llvm_rt.c \
    -include stdlib/runtime/nuc_alloc.h \
    -o /tmp/nucleor_working.exe -Wno-override-module \
    "-Wl,/STACK:16777216" "-Wl,/Brepro"
/tmp/nucleor_working.exe build tests/features/t3_char_cast_audit_lock.nr
# Should print "compiled: target\\t3_char_cast_audit_lock.exe"
```

Then apply the v0.8.83 audit-text-only edit (recoverable from
CHANGELOG.md commits between v0.8.82 and v0.8.84 — purely
string-literal changes inside `print(...)` calls in the
NUM-G289 audit-pass block; no new code paths added). Rebuild
stage1 → stage2 → seed → /tmp/seed_broken.ll → Windows PE bin.
The new bin will hang on the same fixture.

**Investigation steps requested:**

1. **Confirm repro under clean conditions.** Multi-agent
   contention has been a confounder during main-agent
   attempts. Run on idle machine with no probe / helper /
   main concurrent processes.

2. **Diff the two seed.ll files.** They should differ only in
   string-constant `@.str.NNN = constant ...` declarations
   for the changed audit-text. Are there any differences
   OUTSIDE those string declarations? Different basic-block
   ordering, different `!metadata` sections, different
   COMDAT groups, different data section initializers?

3. **Cross-link experiment** (the load-bearing question):
   build `/tmp/seed_broken.ll` with the same `clang.exe`
   commands but produce a Linux ELF (default target):
   ```
   clang.exe /tmp/seed_broken.ll stdlib/runtime/nucleor_llvm_rt.c \
       -include stdlib/runtime/nuc_alloc.h \
       -o /tmp/nucleor_broken_elf.exe -Wno-override-module
   /tmp/nucleor_broken_elf.exe build tests/features/t3_char_cast_audit_lock.nr
   ```
   Does the ELF binary hang too, or work? If ELF works and
   PE hangs from the SAME .ll, that confirms the hang is in
   the LLD-link Windows PE backend or the C runtime
   linkage path.

4. **Capture stack trace at hang.** Attach WinDbg or lldb to
   the hanging Windows PE binary at the
   "incremental: module graph cache hit" point. What is the
   process spinning on? Is it a tight loop in nucleor.exe
   itself, a deadlock on a CRT mutex, or stuck in a Windows
   syscall? `pstack`-equivalent on the hung process.

5. **PE introspection.** Compare with `dumpbin /HEADERS` and
   `llvm-readobj` between working and hanging PE binaries.
   Look for differences in section sizes, RVA layout,
   COMDAT folding, TLS table, alignment.

**Expected output:** Either:
(a) A finding in `findings/inbox/` named
   `2026-05-04-windows-pe-link-hang-root-cause.md` with the IR
   diff summary, ELF-vs-PE comparison, stack trace, PE-header
   diff, and root-cause hypothesis — OR —
(b) A real fix prepped on `perf/...` branch with all the
   diagnostic artifacts attached as evidence. **Probe is NOT
   limited to investigation; if the root cause is identifiable
   and fixable in tools-suite or runtime-C scope, prep the
   fix end-to-end.** Cross-cutting compiler.nr edits should
   go through normal probe → main integration; smaller fixes
   (e.g., "add `-Wl,/OPT:NOICF` to disable COMDAT folding"
   in the build script) can ship directly.

**No risk cap. No scope cap. Probe has full latitude on this
one — whatever it takes, including:**
- Switching linkers (try `link.exe` from MSVC instead of
  `lld-link`)
- Adding LLD flags (`/OPT:NOICF`, `/OPT:NOREF`, `/MERGE:`,
  `/SECTION:`)
- Patching `nucleor_llvm_rt.c` if a thread-local init or CRT
  startup ordering is implicated
- Pinning a known-working seed and merging text-only deltas
  via diff/patch instead of regenerating
- Anything else that produces a working Windows PE bin from
  the same compiler.nr edit that today produces a hanging bin.

The unblock is worth >=70% of v1.0 critical-path work. Take
whatever wins reach a working bin.

**Why it matters:** unblocks E-class effects, RT-G1..G10,
LAW-1, NUM-G9, ROBO-7, T-3/T-4 Phase 2b real fixes, plus all
future audit-pass text refinements. About 70% of remaining
v1.0 critical-path work in `docs/rfcs/v1_PUNCHLIST.md` is
gated on this one issue.

### D2 — Optional follow-up: stable seed.ll generation

If D1 root-causes the hang to layout/ordering nondeterminism
rather than a real LLD bug, a tools-suite-level workaround
may exist: post-process the regenerated seed.ll to
canonicalize ordering, or pin the seed against a known-good
prior version and only merge actually-needed delta changes.
Probe has authority to ship this in the same workstream as
D1 if it's the cleanest unblock.

**Risk:** depends on D1.

## Group C: Deeper v1 architecture (NOT for helper — flag for main agent)

These are too large for the helper's prep+propose workflow. They
need spec-level design + cross-team alignment. Listed for context
only; do NOT prep these.

- **Drop / RAII / move-semantics / closure-capture-flow** — v1
  borrow-checker workstream (`drop-trait-never-auto-called`,
  `move-semantics-not-enforced`, `vec-allocation-without-drop-leaks`,
  `str-concat-loop-rebind-leak`, closure-capture family).
- **Generic-T inference** (Box::new literal, iter map type-changing,
  generic trait bounds) — bidirectional type inference pass.
- **Length-tagged str ABI** — every `str_*` runtime helper rewritten;
  cross-cutting adopter break.
- **derive(PartialEq) / Hash** — auto-emit element-wise compare for
  Vec/struct/HashMap.
- **RFC-0008 phase 2** — `#[no_alloc]` / `#[no_panic]` call-graph
  propagation through ISR call edges.
- **HashMap<KeyT> key-type-aware** — hash/eq helper family per
  key-type-class. Sister to A2's bootstrap-cycle hole.
- **const-fn parse extension** — full const-eval substrate.

## Workflow (UNCHANGED from PROBE_MANDATE)

Same probe+prep flow as before. Push to
`origin/probe/exploration`, flag heartbeat as
`ready-for-integration`. Main agent integrates and assigns the
version. Don't push to main, don't tag.

When picking the next item, prefer:

1. Group A items with `Risk: low`.
2. Then Group B items that don't risk the bootstrap-cycle hole
   class.
3. Mix at least 1 Group A and 1 Group B per cycle so adopter-
   facing diags ship alongside perf.

## Heartbeat schema

Same `findings/heartbeat.json` shape as before. Add a field:

```json
{
  "current_punchlist_item": "A3",
  "perf_baseline": { "cold": 3.08, "hot": 0.25, "peak_mem": 316 },
  ...
}
```

Update before each push.

## Referenced findings (forward-roadmap detail per item)

All cited findings are in `findings/promoted/`. Read the full
status + adopter-migration sections before starting work — they
have the deferral rationale and workaround patterns.

---

# 2026-05-03 PUNCHLIST REFRESH (post-v0.7.13 + probe-perf-merge 4a7c56e6)

**Status:** main is at commit `de8207ac` with probe's perf work merged. Cold ~3.77s on probe-validated baseline, well under the 4s ceiling. **Job #1 below the line: keep cold under 4s.** Everything else is downstream of that.

**Why this refresh:** main agent shipped 39 ships v0.6.74 → v0.7.13 (mostly defensive halts), then closed a major investigation pass that added 17 RFC drafts + 2 specs + V2 frontier roadmap (commit `4a6b0454`). Build plan tripled in scope — see `docs/rfcs/RFC_v2_FRONTIER_ROADMAP.md` and `docs/rfcs/RFC_v1_FORWARD_ROADMAP.md` Tier 4-6 appends. Probe added perf-attribution helpers and broke the 4s barrier by killing substring allocations in async-keyword + private-fn-mangle preprocessors.

## Standing rules (still in force)

1. **Perf gate is BINDING:** if cold > 4.0s OR peak > 360MB, halt the work, bisect, fix or revert. Hard caps remain 5.93s / 770MB.
2. **No compiler edits to `compiler/nucleor_s1_compiler.nr` without main-agent merge through `findings/inbox/` or coordinated branch.** Probe-branch ships compiler edits ONLY when paired with a runtime/build-script delta that justifies the touch.
3. **Always set `NUC_VERIFY_AGENT=probe` before running verify.sh.** (Per memory rule.)
4. **Heartbeat shape stays the same.** Add `cold` / `hot` / `peak_mem` to every heartbeat write.

## Group P — PERF-DRIFT WATCH (job #1, runs every cycle)

These are not finding-driven. They're guardrail checks the probe runs every cycle to keep cold under 4s.

### P1 — Continuous perf gate
Run `tools/check_perf_regression.ps1` 3 times per cycle. Median cold and median peak go into the heartbeat. **If median cold ≥ 3.95s, push a finding to `findings/inbox/perf_drift_<date>.md` IMMEDIATELY** with: which 5 most-recent commits could have caused it, which `compiler/nucleor_s1_compiler.nr` lines changed, and the str_concat / str_substring / sym_get hot-path counts (use the perf-attribution helpers probe shipped in `4a7c56e6`).

### P2 — Hot-path allocation hunt
Probe just killed substring allocations in 2 preprocessors. There are likely more. Use the runtime helper caller-attribution machinery (b91fca54 / a86cce9f) to enumerate every call site of `__nucleor_str_substring`, `__nucleor_str_concat`, `__nucleor_sym_get`. Rank by per-self-host-build call count. Top 5 callers of each are the next perf-fix candidates. Push findings as `findings/inbox/perf_hotpath_<helper>_<date>.md` with the call-site list and a fix sketch.

### P3 — Cold-time variance investigation
Variance has been wide this session (3.16-5.50s). Probe's measurement at 3.77s suggests system load was the dominant variance driver. Add a wall-clock + CPU-load snapshot to `tools/check_perf_regression.ps1` output so we can correlate variance with system state. Sister to P1.

### P4 — Memory floor enforcement
Peak has crept 318MB → 333MB across recent ships. Run `bisect_mem.sh` against the 5 most-recent ships to find which one moved the peak. Push as `findings/inbox/peak_drift_<date>.md`. **Do NOT auto-revert** — main needs to see the bisect result before deciding.

## Group Q — DEFENSIVE-HALT SHIPS (easy wins, queue these between perf cycles)

The 39-ship session closed the obvious wrong-class diagnostics. Probe should hunt for the less-obvious ones. LOW-RISK SHIPS adopters porting Rust code will hit.

### Q1 — Match arm with `..=` exclusive range pattern
`match x { 0..=10 => ... }` works (closed). But `match x { 0..10 => ... }` (exclusive) — verify status, halt cleanly if it crashes/wrong-class.

### Q2 — Slice patterns `match arr { [a, .., b] => ... }`
The `..` rest pattern in slice match — verify and halt cleanly if unsupported. Probably wrong-class today.

### Q3 — `where T: Trait1 + Trait2 + Trait3` — multi-trait bounds
Confirm the bound parser handles 3+ traits separated by `+`. If not, halt cleanly.

### Q4 — Generic where-clauses with multiple params: `where T: A, U: B`
Multi-line / multi-param where clauses — confirm or halt.

### Q5 — `pub use crate::module::*;` re-export
Currently `mod foo;` is silent passthrough. Confirm `pub use` and `use ... as ...` and `use ... ::*;` all halt cleanly or work.

### Q6 — `for<'a> Fn(&'a T) -> R` higher-rank trait bounds (HRTBs)
Probably parser-rejects wrong-class. Halt cleanly.

### Q7 — `let r = &raw const x;` Rust 1.82 raw-ref syntax
Halt cleanly with workaround pointer (use `&x` or i64 cast).

### Q8 — `c"hello"` C-string literal (Rust 1.77)
Halt cleanly with workaround (`"hello"` plus explicit NUL handling).

### Q9 — Tuple destructure in let `let (a, b) = (5, 7);`
Sister to V1.1. Already-flagged in V1.11 sub-items. Confirm halt is clean.

### Q10 — `#[inline]`, `#[inline(always)]`, `#[cold]` attributes
Currently silently dropped probably. Either honor them (low-effort) or halt cleanly with a note that Nucleor's inliner is decision-driven.

## Group R — CHALLENGING WORK (probe's perf-attribution skill applies)

Bigger than Group Q but still bounded. Uses the perf-attribution machinery probe just landed.

### R1 — `expand_format_macros` allocation profile
The textual format-macros pass walks every source file for `println!`/`format!`/`assert!`. Run perf-attribution against it during a self-host build. Where does it allocate? Are there opportunities to re-use string buffers across calls? Push findings.

### R2 — `parse_postfix` hot-path audit
parse_postfix is called per token after every primary. It has 17+ branches now (after recent ships). Profile per-branch hit-counts during self-host. Find any branch that's always-false on hot paths and gate it cheaper. Push findings.

### R3 — `types_compatible` micro-benchmark
This fn is called on EVERY type check. Recent edits added Box<T> recursion + str/String dispatch + derive(PartialEq) lookup. Each adds a str_eq or str_starts_with. Build a micro-bench for `types_compatible` (compare hot-path call distribution: i64==i64, str==str, struct==struct, generic==generic). Identify the hottest case and ensure it's a single early-return. Push findings.

### R4 — Sym-table linear-scan profile
`sym_get` walks the sym table linearly. With 5072 strings in the v0.7.13 self-host, this could be the largest single-fn cost. Profile depth distribution: how many entries do we walk before finding the hit? If P50 > 100, propose a hash-backed sym table (with the cheap-cache pattern from v0.6.72). Push findings; main agent decides whether to ship the hash table.

### R5 — Bootstrap-seed regeneration timing
`bootstrap/nucleor_s1_seed.ll` regen is triggered on every compiler-source change. Profile how long regeneration takes vs the rest of the build. Is there a faster path (cached partial IR, skip-if-seed-stable-byte-identical)? Push findings.

## Group S — INVESTIGATION + FOLD-IN (highest leverage, longest-tail)

These tap directly into the new V1/V2 roadmap and the ML-expansion brief.

### S1 — Audit V2 roadmap RFCs for cheap-win candidates
Read `docs/rfcs/RFC_v2_FRONTIER_ROADMAP.md` Tier A (RFC-0046 through RFC-0051). For each, identify which subset is "metadata + parser-only, no semantic enforcement" — those are the cheapest first-tranches and the right shape for parallel-agent shipping. Push findings to `findings/inbox/v2_easy_win_subset_<RFC>.md`.

### S2 — ML expansion docs review + integration brief
Read `Desktop/Nucleor_Build_Spine/03_TRIAGE/ML_EXPANSION_SET_INTEGRATION_2026-05-01.md` + `Desktop/Nucleor_Build_Spine/07_CODEX_DOCS/ML_EXPANSION_INPUTS_2026-05-01/` (3 docs). Identify which ML expansion items are:
- Already shipped in OSS (closed).
- Easy wins (mark as Q-class for next cycle).
- Multi-stage (defer to V2 roadmap or main agent).
Push to `findings/inbox/ml_expansion_triage_<date>.md`.

### S3 — Nucleor_Translate spec-phase status check
`Desktop/Nucleor_Translate/` is in spec phase per memory; READ-ONLY on `Nucleor_OSS/` during spec. Check status: are there any compiler-side hooks Nucleor_Translate needs that are NOT yet in OSS? Push as `findings/inbox/translate_compiler_hooks_<date>.md`.

### S4 — Drift restoration RFC review
Read `RFC-0043-fixed-point-IR-type.md`, `RFC-0044-per-binop-overflow-mode.md`, `RFC-0045-differentiable-attribute.md`. For each, sketch the smallest "decoy" implementation that exercises the parser change without committing the IR-type / OverflowMode-field / attribute-storage refactor. Push as `findings/inbox/drift_restore_decoy_<RFC>.md` so main can ship the smallest-possible version first.

## Quick-reference: priority order this cycle

1. **P1-P4 first** (perf is job #1, every cycle).
2. **2-3 Q items** (defensive halts, low-risk).
3. **1-2 R items** (perf-attribution work, leveraged on recent runtime additions).
4. **1 S item** (investigation, longer-tail; rotate which one).

Skip items where the prerequisite isn't met (e.g. don't audit RFC-0046 cheap-wins if P1 fired a perf-drift alarm — clear that first).

## Heartbeat update

Add `roadmap_phase: "v2_post_investigation"` to heartbeat. Add `current_punchlist_item` per item code (e.g. `"P2"`, `"Q3"`, `"R4"`).

## Cross-references

- `Desktop/Nucleor_Drift_Triage_2026-05-03.md` — drift triage memo
- `docs/rfcs/RFC_v1_FORWARD_ROADMAP.md` — V1.1-V1.16 (Tier 4-6 added)
- `docs/rfcs/RFC_v2_FRONTIER_ROADMAP.md` — V2.1-V2.13 (NEW)
- `Desktop/Nucleor_Build_Spine/BUILD_PATH_v0.4_to_v1.3.md` — canonical spine
- `feedback_ns_sage_broken.md` (memory) — NS_Sage = broken; do not cite
