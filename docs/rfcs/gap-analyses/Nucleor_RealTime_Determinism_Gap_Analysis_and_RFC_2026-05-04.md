# Nucleor — Real-Time, Determinism, and the Safety Attribute Quad: Gap Analysis and RFC

**Date:** 2026-05-04
**Author:** Claude (Opus 4.7) for Joseph Wescott
**Document type:** Combined gap analysis + RFC
**Status:** Draft for main-agent integration
**Disposition:** No file writes were made into `Nucleor_OSS` while drafting this.

---

# Part I — Definitions

## 1.1. The real-time / determinism pillar

This is one of Nucleor's headline differentiators. The README and RFC-0001 claim: "Nobody mainstream ships all four guarantees as first-class language features that compose cleanly with an ownership type system." The four guarantees are `#[no_alloc]`, `#[no_panic]`, `#[no_dyn]`, `#[deadline]`.

This document audits whether that claim is honestly defensible today, plus the related real-time surface: `#[isr]`, `#[max_depth]`, embedded targets, WCET estimation, and reproducibility/determinism.

## 1.2. Fifteen real-time validation categories (RT-G1 through RT-G15)

Maps to the gap inventory.

---

# Part II — Gap Analysis

## 2.1. Stated goals

- **RFC-0001 (Status: "Implemented, audited v0.4.187"):** All four attributes parse + enforce. `#[no_alloc]`/`#[no_panic]` use "forward dataflow pass over IR." `#[deadline]` "fail to link if it transitively calls an un-annotated function whose body cannot be shown to satisfy the constraints."
- **RFC-0008 (Draft, v0.6.0):** `#[isr]` implies `#[no_alloc, no_panic, no_dyn]` plus no-blocking-call rule.
- **RFC-0009 (Draft, v0.7.0):** Heptane WCET integration, `--profile=cert` mode.
- **RFC-0014:** `#[max_depth = N]` with conservative structural depth analysis.
- **v0.6.0 milestone:** `#[isr]` `[x]` shipped v0.6.9. Embedded sysroots, embedded test suite, QEMU gate all `[ ]`.
- **README (potential marketing surface):** four-guarantee composability claim.

## 2.2. The fifteen gaps

### RT-G1 — False-negative surface: transitive allocation through unchecked callee — **HIGH**
`#[no_alloc]` only scans the annotated function's own body for hardcoded allocating-function name patterns, plus any callee explicitly tagged `with [Alloc]`. A helper function that calls `str_concat` internally will NOT be caught unless the helper appears in `no_alloc_check_list()` or carries a `with [Alloc]` annotation. **RFC promises transitive inference; implementation provides one-level source-text pattern matching.** Concrete failure: `#[no_alloc] fn motor_step() { let s: str = format_path(x, y); }` where `format_path` calls `str_concat` internally — no RT-001 fires.

### RT-G2 — False-negative: function pointer calls in `#[no_alloc]`/`#[no_dyn]` fns — **HIGH**
Source-level scanner for `#[no_dyn]` only looks for literal token `"dyn "`. Indirect call through fn-pointer stored in a struct field produces no RT-003. Same for `#[no_alloc]` — callee invoked through fn-pointer, scanner can't see through, no RT-001 fires.

### RT-G3 — False-negative: `#[no_panic]` does not check arithmetic, bounds, or division — **HIGH**
`no_panic_check_list()` contains only 7 entries: `panic`, `assert_eq`, `assert_ne`, `unwrap`, `expect`, `.unwrap`, `.expect`. **Array index OOB, integer overflow in debug mode, integer division by zero — all sources of panic per RFC-0001 §3.2.2 — none are checked.** A `#[no_panic]` function with `let x: i64 = arr[idx];` where `idx` is unconstrained compiles without warning. Directly contradicts RFC claim "the pass errs on the side of may panic."

### RT-G4 — `#[deadline]` runtime enforcement is measurement-based, not guaranteed — **MEDIUM**
Deadline wrapper uses `time_monotonic_us()` — wall-clock elapsed time on host OS. Not a hardware timer trap; software measurement. On preemptive host OS, process can be descheduled between start/end measurement, causing false overrun reports or missed actual overruns. RFC-0001 §3.2.4 describes "Runtime check via SIGALRM + isolcpus pinning" for `--profile=rt-linux` — **this mode does not exist.** The `--profile` mechanism does not exist. One implementation: software elapsed-time check on all platforms.

### RT-G5 — `#[deadline(ms)]` numeric claim is completely unbacked — **HIGH (marketing)**
`#[deadline = 1000]` declares 1 ms budget. Compiler emits nothing that bounds or estimates actual execution time. **No cost table, no WCET pass, no loop-bound analysis.** Declaration is accepted and overrun trap is set, but the user has zero compiler-assisted assurance that the function will complete in 1 ms on any target. **Central claim backing "first-class deadline enforcement" is advisory-only today.**

### RT-G6 — No embedded sysroots — "embedded language" claim has no grounding — **HIGH (marketing)**
v0.6.0 shipped `#[isr]` with parse + IR marker, but **no Cortex-M or RISC-V sysroot exists.** No `arm-none-eabi` toolchain support, no linker script, no vector table emission. ISR test fixture `rfc0008_isr_minimal.nr` runs on x86_64 Windows host and prints "OK" — does not generate interrupt handler code. **A user reading "ISR support" and attempting to target an STM32F4 has no path to do so.**

### RT-G7 — `#[isr]` inheritance is source-scan only — same gap as RT-G1/G3 — **MEDIUM**
`#[isr]` inherits `#[no_alloc]`/`#[no_panic]` checks via the same source-level substring scan. False-negative surface of RT-G1 and RT-G3 applies equally. ISR calling a helper containing `Vec::push` is not caught unless helper name is in hardcoded list.

### RT-G8 — `#[no_alloc]`/`#[no_panic]` scope is per-file — cross-module gap — **MEDIUM**
Both check fns operate on a single source string. `#[no_alloc]` fn calling imported function from another rod — callee body not available for scanning. `check_effect_call_violations()` catches cases where callee has explicit `with [Alloc]` annotation, but **rod audit manifests (RFC-0001 §3.5) are not implemented.** No `rod_rt.audit.toml` consumed by compiler.

### RT-G9 — `allow_fn`/`deny_fn` scope inconsistency — **LOW**
`#[allow(RT-001)]` is file-wide; `#[allow_fn(RT-001)]` is per-fn. But RT-001/002/003 are errors, not warnings — `#[allow]`/`#[allow_fn]` cannot suppress them. **Correct semantic** (unsuppressible errors = sound guarantee), but RFC implies overrides exist. Documentation gap.

### RT-G10 — RFC-0009 WCET codes registered but no enforcement pass — **HIGH (documentation)**
`is_known_diag_code()` registers WCET-001..006. `nuc explain` will explain these codes. **No compiler pass emits them.** User reading RFC and expecting `nuc check --profile=cert` to produce WCET report finds the flag does not exist. Existence of registrations implies implementation that is not there.

### RT-G11 — `#[max_depth]` analysis is conservative-structural, not formally proved — **MEDIUM**
RFC-0014: "conservative structural depth analysis." Compiler recognizes specific idioms. Recursion patterns outside these idioms (mutual recursion with non-trivial termination, recursion through fn-pointer callbacks, recursion through trait dispatch) either fall through to runtime depth counter (debug profile) or are not caught at all. `--profile=cert` mode requiring static provability does not exist.

### RT-G12 — `#[no_dyn]` misses fn-ptr indirect calls in data structures — **MEDIUM**
Same as RT-G2 with specific framing. `struct Handler { f: fn(Msg) -> Reply }` — `handler.f(msg)` does not contain literal `dyn` and passes the check. RFC-0001 open question 5 anticipated this; implementation answers "no, silently," wrong answer for hard-RT.

### RT-G13 — Deterministic execution: no language-level guarantee — **MEDIUM (documentation)**
Nucleor makes no language-level guarantee of deterministic execution order for concurrent code. `governed_parallel_guarded` is a policy in RFC-0060 not yet shipped. `rand()`/`rng` produce non-deterministic output by default with no seeding requirement. RFC-0056 (deterministic replay) is V2.11 frontier draft. **`.nucprov` section guarantees build determinism (strong); runtime determinism is not guaranteed.**

### RT-G14 — Effect system and RT attributes are parallel tracks, not unified — **MEDIUM**
RFC-0001 §5.1: team "picked attributes instead" of effect system. RFC-0033 defines `with [no_alloc]` as eventual unification. Currently both work and both feed `collect_no_alloc_fns()`. **Redundant spellings with no enforced relationship.** Function carrying `with [Alloc]` effect AND `#[no_alloc]` attribute simultaneously would be contradictory; no diagnostic.

### RT-G15 — `#[deadline]` + `spawn` interaction not checked — **LOW**
RT-006 fires when `#[no_alloc]` is on `async fn`. Calling `#[deadline]` fn from inside `spawn { }` block is not checked. Spawned closure could call deadline-marked fn across thread boundary; runtime check still fires but budget measurement is relative to spawned thread's wall clock (arbitrarily preempted). No diagnostic.

## 2.3. Cross-cutting risks

- **Marketing-claim risk (highest priority):** RFC-0001 headline ("Nobody mainstream ships all four guarantees as first-class language features...") is technically false in two ways:
  1. Enforcement is source-text substring scanning, not type-system enforcement. "First-class" implies compile-time type checking.
  2. "Compose cleanly with ownership type system" — borrow checker exists but no integration between RT attribute enforcement and borrow checker IR.
  Documented as v1 limitations in compiler comments but **the RFC's status field "Implemented (audited v0.4.187)" is accurate for what ships, while the RFC's design section describes a stronger implementation that does not yet exist.**
- **Interaction with effect system:** Effect system has its own `Alloc`/`Panic` tags. Some integration via `collect_fns_with_effect`, but effect inference described in RFC-0032 (recursive IR pass) is not implemented as recursive — single-level source scan.
- **Interaction with auto-drop gap (memory-safety G-1):** Without auto-drop, `#[no_alloc]` fn that holds a heap-backed collection and lets it go out of scope implicitly calls destructor (deallocation). User must call `vec_free()` manually. If they forget, deallocation happens implicitly and does not fire RT-001 (since `vec_free` not in `no_alloc_check_list()`). **Soundness hole: `#[no_alloc]` function appears clean but performs deallocation on scope exit.**
- **Reproducibility gates — genuine strength:** `.nucprov` section, byte-identical IR gate in `verify.sh`, content-addressed compilation cache are real, verified, production-quality. Determinism-of-build, not runtime-determinism.

---

# Part III — RFC

## 3.1. Goals

1. Close the false-negative gaps that undermine the four-attribute composability claim.
2. Make the `#[deadline]` numeric claim actually backed by something (Heptane WCET, or until then, an honest disclosure).
3. Ship at least one embedded target so the "embedded language" claim has grounding.
4. **Adjust marketing claims to match implementation reality** until enforcement matches RFC ambition.

## 3.2. Closure plan, by gap

### RT-G1, RT-G2, RT-G3 (false-negative surface) — Phase 1-2

**Phase 1 (immediate):** Honest disclosure. Every `#[no_alloc]`/`#[no_panic]`/`#[no_dyn]` attribute produces a doc comment in the explain output: "Enforcement is source-text-pattern based; transitive call analysis is one-level deep; fn-pointer indirect calls and panics from arithmetic/bounds/division are not detected. See RFC-0001 §3 for limitations."

**Phase 2 (short-term):** AST-based traversal pass that replaces source-text scanning. Starts with `#[no_alloc]`:
- Walk the function body AST
- For each call expression, check the callee's known effect annotation OR recursively analyze the callee body (with cycle detection)
- For fn-pointer calls, conservatively assume worst case (all effects) unless the fn-pointer is provably bound to a known fn
- For `#[no_panic]`, add detection of: array indexing (`vec_get`), integer arithmetic that could overflow under strict mode, division by zero, explicit `panic!`/`assert!`

**Phase 3 (v1.0 gate):** Full IR-level dataflow pass per RFC-0001 §3.2.1 design. Effect bits computed bottom-up. False-negative surface eliminated.

### RT-G4 (deadline runtime is software-measurement) — Phase 2-3

**Phase 2:** Document the limitation. Software measurement on preemptive OS is best-effort; for hard-RT use, target an embedded OS or bare-metal where preemption is controlled.

**Phase 3:** Implement `--profile=rt-linux` per RFC-0001: SIGALRM + isolcpus pinning. Implement `--profile=embedded` with hardware timer interrupt for ARM Cortex-M (depends on RT-G6 closure).

### RT-G5 (deadline numeric unbacked) — Phase 2-4

**Phase 2:** Disclosure. `#[deadline = 1000]` produces a doc comment: "Deadline declarations are runtime-measured advisory bounds; static WCET enforcement requires `--profile=cert` (planned v0.7 via Heptane)."

**Phase 3:** Implement basic cost tables for arithmetic, function call, branch. `nuc check --profile=cert` produces a static-bound estimate per `#[deadline]` fn and warns if the estimate exceeds the declared bound.

**Phase 4 (v1.0 or v1.x):** Heptane WCET integration per RFC-0009. Real WCET-001..006 emission.

### RT-G6 (no embedded sysroots) — Phase 2-3

**Phase 2:** Pick one embedded target (recommend ARM Cortex-M4F via QEMU emulation). Add `arm-none-eabi-gcc` toolchain detection in build system. Add minimal sysroot stubs. Add linker script for Cortex-M memory layout. Add vector table emission for `#[isr]` functions. Ship the embedded test suite per v0.6.0 milestone.

**Phase 3:** Add second embedded target (RISC-V via QEMU). Add QEMU gate to verify.sh.

**Phase 4 (v1.0):** Bare-metal-capable cross-compilation as a first-class feature.

### RT-G7 (ISR inheritance scan-based) — Phase 2
Closes when RT-G1/G2/G3 Phase 2 closes. Same AST-based traversal applies.

### RT-G8 (cross-module scope) — Phase 2
Implement rod audit manifests per RFC-0001 §3.5. Each rod ships a `rod_rt.audit.toml` declaring per-function effect annotations. Compiler consumes these when checking cross-module `#[no_alloc]` callees.

### RT-G9 (allow/deny inconsistency) — Phase 1
Documentation fix. Update RFC and `nuc explain` to clarify that RT-001/002/003 cannot be suppressed.

### RT-G10 (WCET codes registered, no impl) — Phase 1 + 4
Phase 1: remove WCET-001..006 from `is_known_diag_code` until the enforcement pass exists, OR add an explicit "(not yet implemented)" suffix to their explain text.
Phase 4: implementation per RT-G5 Phase 4.

### RT-G11 (max_depth conservative-structural) — Phase 3
Implement Heptane-backed depth analysis per RT-G5 Phase 4.

### RT-G12 (no_dyn misses fn-ptr in struct fields) — Phase 2
Closes with RT-G2 Phase 2 (AST-based fn-ptr detection).

### RT-G13 (no language-level runtime determinism) — Phase 3
Implement RFC-0056 (deterministic replay) as a v1.x feature. Disclosure in v1.0: "Build determinism guaranteed; runtime determinism requires explicit RNG seeding and `--governed_parallel_guarded` execution policy."

### RT-G14 (effect system and RT attributes parallel tracks) — Phase 3-4
Cross-references the effects RFC. Once effect system is real (E-RFC Phase 2-3), RT attributes become syntactic sugar over the effect system. `#[no_alloc]` desugars to `with [no_alloc]`. Conflicts produce diagnostic.

### RT-G15 (deadline+spawn interaction) — Phase 2
Add diagnostic when a `#[deadline]` fn is called transitively from inside a `spawn { }` block — warn that wall-clock measurement is unreliable across thread boundaries.

## 3.3. Phasing summary

| Phase | What lands | Closures |
|---|---|---|
| **Phase 1 (emergency)** | Honest disclosure on all four RT attributes; allow/deny doc fix; WCET code registry cleanup | RT-G1 P1, RT-G2 P1, RT-G3 P1, RT-G5 P1, RT-G9, RT-G10 P1 |
| **Phase 2** | AST-based effect traversal; arithmetic/bounds/div panic detection; fn-ptr indirect call detection; rod audit manifests; one embedded target (Cortex-M); deadline+spawn diagnostic | RT-G1 P2, RT-G2 P2, RT-G3 P2, RT-G6 P2, RT-G7, RT-G8, RT-G12, RT-G15 |
| **Phase 3** | rt-linux profile (SIGALRM + isolcpus); basic cost tables for `nuc check --profile=cert`; second embedded target (RISC-V); QEMU gate | RT-G4 P3, RT-G5 P3, RT-G6 P3, RT-G11, RT-G13 |
| **Phase 4 (v1.0/v1.x)** | Full IR dataflow; Heptane WCET integration; effect-system unification | RT-G1 P3, RT-G5 P4, RT-G10 P4, RT-G14 |

## 3.4. v1.0 release gate

Phases 1-2 minimum. Phase 3 for hard-RT users (rt-linux profile, second embedded target). Phase 4 acceptable to ship as v1.x.

**MARKETING CLAIM DISCIPLINE:** Until Phase 2 lands, the README and any public-facing materials must NOT claim that the four-attribute composition is "first-class" or "type-system-enforced." Acceptable language: "first-class attributes with source-text-pattern enforcement; full IR-level type-system enforcement planned for v1.0." This honest framing protects credibility and gives Phase 2 work the runway it needs.

## 3.5. Open questions

1. Embedded target priority — Cortex-M4F first (most common embedded MCU) or Cortex-M0+ first (lowest barrier, simplest)? Recommendation: M4F because users targeting embedded want FPU + DSP.
2. Heptane integration — vendor the Heptane source or shell out to an installed binary? Recommendation: shell out for v0.7 prototype; consider vendoring for v1.0 reproducibility.
3. RT-G14 unification timing — defer until effect system Phase 3 (likely v1.0+) or attempt earlier? Recommendation: defer; the parallel-tracks situation is acceptable until effect system itself is real.

---

# Part IV — Disposition

**Document path:** `C:\Users\JoeWe\Desktop\Nucleor_RealTime_Determinism_Gap_Analysis_and_RFC_2026-05-04.md`

*End of document.*
