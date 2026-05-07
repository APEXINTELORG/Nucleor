# Nucleor_OSS kludge survey — categorized residuals (2026-05-07)

- **Date:** 2026-05-07
- **Agent:** main (local Claude integrator)
- **Trigger:** user directive — "after you fix this one [T2.1 panic class]
  to survey the entire project for kludgey workarounds that should be
  robust and production ready."
- **Scope:** `Nucleor_OSS` worktree only. Translate / ML_Suite / Aurora /
  external projects are NOT covered here.
- **Bias:** I prioritize what could surprise an adopter or hide a real
  bug; I de-emphasize defensive halts that exist for a reason and have
  clear workaround pointers (those are good design, not kludges).

## Tier-A: production-readiness risks (worth scheduling)

### A-1. NUCLEOR_VEC_OOB_LENIENT / NUCLEOR_OOM_LENIENT / NUCLEOR_SHIFT_LENIENT escape hatches

**What:** runtime panic checks (`stdlib/runtime/nucleor_llvm_rt.c`) print
`PANIC: ...` and abort under default mode, but `NUCLEOR_*_LENIENT=1`
suppresses the abort and continues with a default value. Used in 8+
runtime sites (vec OOB, tensor OOB, str_char_at OOB, str_substring OOB,
oom, shift overflow).

**Risk:** if an adopter sets `LENIENT=1` to "make a build work past a
crash," they ship a binary with silent miscompute. The lenient path is
fine for debugging the runtime itself but is a foot-gun in production.

**Recommendation:** banner-emit a warning at runtime startup when any
LENIENT env var is set (`stderr: "WARNING: NUCLEOR_VEC_OOB_LENIENT=1
suppresses bounds-check aborts; this is a debug option, not a release
mode."`). Optionally add a `--cert-mode` flag to bin/nucleor.exe that
panics if any LENIENT env is set — gates lenient-mode out of certified
builds entirely.

**Owner:** runtime team / partner-Compiler.

### A-2. ERR_SKIP_REGEX in verify.sh + verify_fast.sh

**What:** `tools/verify.sh:451` and `tools/verify_fast.sh:443` carry
identical `ERR_SKIP_REGEX='err_str_char_at_strict_oob.nr$|err_t4_strict_inference.nr$|err_numg2_math_abs_imin.nr$|err_numg2_math_gcd_imin.nr$|err_numg2_math_pow_int_overflow.nr$'`
— 5 negative-test fixtures that get silently skipped from the err-test
loop.

**Risk:** these 5 fixtures presumably caught real bugs in their original
ship and are now disabled. Either (a) the underlying error path was
fixed and the fixture is obsolete (delete the .nr), or (b) the fixture
was never made to pass and this is a "skip the failing test" kludge.
Without a comment stating why each is skipped, the latter is hard to
distinguish from the former.

**Recommendation:** for each of the 5, either:
1. Demonstrate the underlying check is no longer firable (code path
   removed) and delete the fixture + skip entry, or
2. Re-enable the fixture and fix what it caught.

Comment in the SKIP regex pointing at the per-fixture investigation
finding (one finding per fixture).

**Owner:** partner-Compiler team (some of these likely tie back to
NUM-G* work that's already shipped).

### A-3. RFC-0063 Phase 2.0 parser unification residual

**What:** the drift gate currently emits 3 WARNs:

```
WARN: parser fn 'parse_match_stmt' diverges between s1 and tools_suite
       (s1 137L / tools_suite 189L, 37% delta)
WARN: parser fn 'parse_stmt' diverges between s1 and tools_suite
       (s1 241L / tools_suite 22L, 90% delta)
WARN: parser fn 'parse_expr' diverges between s1 and tools_suite
       (s1 238L / tools_suite 85L, 64% delta)
```

These are tracked as RFC-0063 Phase 2.0 — "eliminate the duplicate
parser, not synchronize it." Today's T2.5 / T2.1 fixes (added
`#[manual_drop]` to 7 parse fns in tools-suite to mirror s1) are
patchwork: the underlying body divergence remains. parse_stmt's 90%
delta means `nuc test` / `nuc bench` / `nuc check` may surface yet
more parser bug classes on adopter code that exercises the divergent
paths.

**Risk:** the latent panic class ("findings/inbox/main_t21_class_latent_panic_v0846_2026-05-07.md")
is likely not exhausted. Future fixtures with control-flow shapes
that exercise parse_stmt or parse_expr will hit the same dangling-Vec
class.

**Recommendation:** prioritize RFC-0063 Phase 2.0 (single-source-of-truth
parser) ahead of further patchwork. The parsers should live in a
shared file (similar to `nucleor_rfc0063_shared_wave1.nr`) imported
by both s1 and tools-suite. Eliminates the need to chase
manual_drop divergences ever again.

**Owner:** partner-Compiler team / RFC-0063 lead.

### A-4. tools-suite-only `nuc test` / `nuc bench` / `nuc check` / etc routes through a stale parser

**What:** `compiler/nucleor_s1_compiler.nr:39607` dispatches `test /
bench / check / audit / policy / certify / translate` to
`run_external_tool`, which spawns `bin/nucleor_tools.exe`. Inside
nucleor_tools, `compile_file_mode` (in tools-suite) does the actual
compile via tools-suite's parser. So 7 CLI commands route through the
stale parser surface that we just spent the day patching.

**Risk:** same as A-3. Every command above is a potential surface for
the next latent OOB panic. T2.5 (lifetime params) tripped `nuc test`,
not `nuc build`. T2.1 (range patterns) same.

**Recommendation:** A-3's parser unification closes this. Until then,
flag each tools-suite-routed command in the docs / CLI help as
"experimental — uses the legacy parser surface; report any panics."

**Owner:** partner-Compiler team.

## Tier-B: doc/test-discipline kludges (worth queueing)

### B-1. The PROBE-1/2/3 lane I already filed

**Where:** `docs/rfcs/v1_PUNCHLIST.md` PROBE-1/2/3 section, commits
`1d2e5e1a` and `5d58ee0c`.

**Status:** queued, not started by any agent yet.

**What:** the existing fixture corpus is dominated by 5–10-line
`add(a, b) { return a + b; }` shapes that don't exercise control flow,
multi-arg calls, or list/struct literals. Cloud R1-R5 fixes (`-lm`,
POSIX RNG, `nuc init` mkdir, `nuc clean` no-op, build-id determinism)
all passed fixture gates while breaking real CLI flows.

**Recommendation:** a partner / ML / cloud agent should pick up the
queue. ~30-LOC drivers per CLI sub-command, multi-stage ML pipelines,
README claim audit. See PUNCHLIST entry for full scope.

### B-2. Cache-masked latent panic class (already filed)

**Where:** `findings/inbox/main_t21_class_latent_panic_v0846_2026-05-07.md`.

**Status:** root cause closed today (parse_match_stmt + verify_fast.sh
body alignment). `findings/inbox/main_t21_class_latent_panic_v0846_2026-05-07.md`
is now PARTIALLY OBSOLETE — T2.1 specifically is closed. The "cache
masks failures" theme remains a real concern: any other parser fn
divergence (per A-3) will still be cache-masked.

**Recommendation:** consider adding `--no-cache` to `verify.sh` /
`verify_fast.sh` for the negative-test gates that exercise parser
diagnostics. Trade-off: slower verify (a few minutes extra). Worth it
for fresh-clone correctness.

### B-3. `import_dedupe_lib.nr$` + `_aux.nr$` skip-regex pattern

**What:** TEST_SKIP_REGEX in verify.sh and verify_fast.sh skips
"helper" fixture files that have no `fn main()` and would fail the
parallel-fixture build. The pattern is special-cased per filename
(`import_dedupe_lib.nr$`) instead of a structural marker.

**Risk:** if someone adds another helper fixture, they must remember
to update both `tools/verify.sh:450` and `tools/verify_fast.sh:442`
(today's fix added `import_dedupe_lib.nr$` to verify_fast.sh; it had
been missing for unknown duration).

**Recommendation:** rename helper fixtures to `*_aux.nr` (the existing
generic suffix) and remove the per-filename special-case. Then the
single regex `_aux.nr$` is sufficient.

**Owner:** quick partner-team cleanup.

### B-4. README numeric-claim staleness (already filed)

**Where:** `findings/inbox/main_probe3_readme_audit_v0846_2026-05-07.md`.

**Status:** filed; partner-team queue scheduled in `Control1.md`.
Concrete remediation table provided.

## Tier-C: defensive halts (NOT kludges — keep)

The 16+ `// workaround` mentions in `compiler/nucleor_s1_compiler.nr`
are mostly **defensive halts**: when the parser detects a Rust feature
that doesn't lower cleanly (negative-literal patterns, ref/ref-mut
binding mode, pattern-destructure in fn params, etc.), it `panic()`s
with a clear ERROR diagnostic and a workaround pointer at the supported
alternative. This is good production-design — adopters get an
actionable error, not a silent miscompute.

DO NOT delete these. They represent v0/v1 scope decisions, each tied
to a specific RFC or CHANGELOG entry, and the alternative paths
(adopting Rust-feature-X without lowering it correctly) would be the
real kludge. Future RFC work may relax some (e.g. `&mut <scalar>`
parameter via ptr-deref-store codegen lands when it lands; the halt
guards correctness until then).

## Tier-D: ad-hoc /tmp scratch (cleaned up)

I created `/tmp/verify_t25_full.log`, `/tmp/verify_t25_v2.log`,
`/tmp/verify_fast_t25.log`, `/tmp/verify_fast_v[3-9].log`,
`/tmp/nucv_dbg/`, `/tmp/nucv2/`, `/tmp/nucv3/`, `/tmp/drift_solo.log`,
`/tmp/t357.log` while debugging today. None are committed; they are
ephemeral. No action needed.

I also created tests/smoke/_t21_min.nr, _t21_min2.nr, _t21_excl.nr,
_t21_excl2.nr while bisecting; ALL deleted before the final commit.

## Action recommendations summary

If the partner team wants to spend a day on production-readiness
hardening, ordered by impact:

1. **A-3** (RFC-0063 Phase 2.0 parser unification) — kills the entire
   bug class behind today's T2.5 / T2.1 work. Largest impact.
2. **A-1** (LENIENT env-var banner) — prevents adopter foot-gun.
   Smallest impact for biggest correctness win.
3. **A-2** (ERR_SKIP_REGEX investigation) — 5 tests, 5 hours max.
4. **B-2** (verify gate `--no-cache` for parser-diagnostic tests) —
   one-line per gate; surfaces hidden regressions.
5. **B-1** (PROBE-1/2/3) — the multi-agent queue I already filed.
6. **B-3** (rename helper fixtures to `*_aux.nr`) — 5-minute mechanical
   sweep.
7. **B-4** (README numeric refresh) — already queued.

Items I'm NOT recommending right now: anything in Tier-C. Those are
not kludges; deleting them would create real bugs.

— main agent
