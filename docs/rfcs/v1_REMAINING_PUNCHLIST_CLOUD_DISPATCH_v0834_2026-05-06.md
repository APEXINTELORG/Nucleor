# Nucleor v1.0 Remaining Punchlist - Cloud Dispatch Pack v0834

**Date:** 2026-05-06  
**Purpose:** Full-visibility dispatch map for cloud agents working the remaining v1.0 punchlist.  
**Primary source:** `docs/rfcs/v1_PUNCHLIST.md`  
**Production roadmap:** `docs/rfcs/RFC-0063-production-readiness-roadmap.md`  

## Base Rule

Until this integration branch is merged, cloud agents should base from:

```bash
git fetch origin
git checkout -B <agent-branch> origin/fix/main-qm7-surface-code-v0827
git merge-base HEAD origin/fix/main-qm7-surface-code-v0827
```

If `origin/main` already contains commit `bd58937f` or a later merge of
`fix/main-qm7-surface-code-v0827`, agents may base from `origin/main` instead.

Every cloud branch should:

- use a fresh branch per lane,
- avoid overlapping write scopes with other active agents,
- write a report under `findings/inbox/`,
- run focused validation plus the required lane gates,
- push the branch and report the branch name, head SHA, base SHA, changed files,
  and validation transcript.

## Global Constraints

- Do not add new Python helpers or new Python requirements to the product,
  compiler, bootstrap, release, or normal verification paths.
- Existing Python interop (`stdlib/rods/python.nr` and runtime support) is
  intentional and out of scope unless a lane explicitly targets FFI ownership.
- Existing maintenance Python scripts may be used as references while replacing
  them, but new closure work should prefer native Nucleor, shell, PowerShell, or
  existing toolchain primitives.
- Keep cold compile and memory overhead tight. For compiler, tools-suite,
  bootstrap, cache, parser, or hot verification changes, run the perf gate.
- Do not delete generated/binary artifacts just to make a diff smaller. If an
  artifact is meant to be built or promoted, either regenerate it through the
  documented path or leave it alone and report the dependency.
- Keep changes scoped. If a lane needs design beyond the stated work, file a
  finding and stop rather than guessing across ownership boundaries.

## Current Completion Estimate

This is an unweighted status estimate for the remaining ten lanes only. It is
not a whole-project completion number.

| Lane | Estimated complete | State |
|---|---:|---|
| 1. RFC-0063 parser/tools-suite unification | 35% | Audit complete; deletion/import waves open |
| 2. Effect/capability enforcement | 55% | Several Phase 2b slices landed; full propagation still open |
| 3. T-3/T-4 type-system strictness | 48% | Phase 1, partial char work, and core plus IO/path strict rtypes landed; strict modes open |
| 4. ROBO-7 frame typing | 10% | Open compiler/type work |
| 5. RT determinism | 30% | Direct same-file checks landed; deeper traversal and deadline backing open |
| 6. Algebraic laws | 50% | Capture and bounded checks landed; rewrite/proof gates open |
| 7. PKG-1 Linux signed publish proof | 75% | Dry-run/preflight staged; native signed transcript open |
| 8. R06 FFI ownership | 60% | Harnesses staged; native POSIX and broader FFI contract open |
| 9. Quantum residuals | 80% | Most QM Phase 1/2 surfaces closed; targeted residuals open |
| 10. Hermetic/native tooling | 55% | Several ports landed; remaining generator ports and Python-free drift open |

**2026-05-06 update:** R10-D3 POSIX perf native evidence is no longer an
open native-Linux blocker. It is closed by
`findings/promoted/2026-05-06-r10-d3-native-linux-perf-baseline-captured.md`
and `tools/perf_baseline_linux.json` with cold 9.05s, hot 0.47s, cold
process-tree RSS 286MB, and hot process-tree RSS 17MB. Remaining
native-Linux-only evidence should focus on PKG-1 signed publish proof and
R06 rust_bridge native ownership/artifact proof unless a lane explicitly
targets RFC-0063 Phase 4 Linux perf optimization.

## Recommended Cloud-Agent Split

The highest leverage split is:

| Cloud lane | Primary work | Why |
|---|---|---|
| Cloud A | RFC-0063 parser/tools-suite duplicate deletion, Wave 1 | Biggest correctness and maintenance payoff; possible cold-path savings |
| Cloud B | Effect/capability plus T-3/T-4 strictness | Compiler trust-gap closure |
| Cloud C | PKG-1/R06 native POSIX evidence | External environment evidence and release proof; R10-D3 perf baseline is already closed |
| Cloud D | Quantum residual closure | Mostly stdlib/test work with clear residuals |
| Cloud E | Hermetic/native tooling ports | Removes Python/toolchain requirements without touching semantics |

Cloud A should be treated as the main critical path. Other lanes should avoid
touching `compiler/nucleor_tools_suite.nr` unless assigned to parser
unification.

---

## Lane 1 - RFC-0063 Parser/Tools-Suite Unification

**Estimate:** 35% complete  
**Priority:** Highest  
**Source RFCs and docs:**

- `docs/rfcs/RFC-0063-production-readiness-roadmap.md`
- `docs/rfcs/v1_PUNCHLIST.md`
- `findings/promoted/2026-05-06-phase-2-0-0-cross-module-import-verified.md`
- `findings/promoted/2026-05-06-parser-unification-survey-rfc-0063-phase-2-0-1.md`
- `findings/promoted/2026-05-06-phase-2-0-3a-dup-fn-audit-results.md`
- `tools/audit_dup_fns_report.csv`

**Current state:**

- Cross-module import viability is confirmed.
- `tools/audit_dup_fns.nr` exists.
- Current duplicate report after helper/cloud integration:
  - 436 duplicate function names
  - 257 `IDENTICAL`
  - 163 `SIG_MATCH_BODY_DIFFERS`
  - 16 `SIG_DIFFERS`
- No duplicate deletion/import savings have landed yet.

**Primary files:**

- `compiler/nucleor_tools_suite.nr`
- `compiler/nucleor_s1_compiler.nr`
- `tools/audit_dup_fns.nr`
- `tools/audit_dup_fns_report.csv`
- `tools/check_compiler_drift.sh`
- `tools/verify.sh`
- `tools/verify.ps1`

**Next build work:**

1. Create a reviewed Wave 1 deletion plan for the 257 `IDENTICAL` candidates.
2. Delete/import a coherent Wave 1 batch from `compiler/nucleor_tools_suite.nr`.
3. Avoid duplicate-name import collisions. If remaining duplicate names block
   import, use the documented `_tools_legacy` strategy or split the work into
   compile-proven intermediate batches.
4. Re-run duplicate audit and update `tools/audit_dup_fns_report.csv`.
5. Prove `nuc check examples/01_hello.nr`, `nuc build-strict`, and
   `nuc abi inspect` no longer regress on the parser/tools-suite path.

**Required gates:**

```bash
bash tools/check_compiler_drift.sh
git diff --check
```

If compiler/tools-suite behavior or binary artifacts change:

```powershell
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

If `bin/nucleor.exe` or `bootstrap/nucleor_s1_seed.ll` changes:

```bash
bash tools/check_self_host_md5.sh
bash tools/check_compiler_drift.sh
```

**Non-scope:**

- Do not rewrite both compilers wholesale.
- Do not remove tools-only CLI dispatch surfaces.
- Do not delete generated artifacts without regeneration evidence.

---

## Lane 2 - Effect/Capability Enforcement

**Estimate:** 55% complete  
**Priority:** High  
**Source RFCs and docs:**

- `docs/rfcs/RFC-0032-effects.md`
- `docs/rfcs/RFC-0033-effects-in-function-types.md`
- `docs/rfcs/gap-analyses/Nucleor_Effect_Capability_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/v1_PUNCHLIST.md`

**Current state:**

Closed or partially closed:

- `pure fn` direct print/alloc/ambient checks.
- `pure fn` plus `requires [...]` contradiction.
- Same-file pure transitive user-helper checks.
- Undeclared extern calls in pure functions.
- Structured scheduling surfaces in pure functions.
- Builtin print-family I/O in pure/const/hot scans.
- `restricts [...] { ... }` now fails closed instead of pretending
  enforcement exists.

Still open:

- Full standalone `requires [...]` row enforcement beyond bounded same-file
  direct/wrapper calls.
- Real block-form `restricts [...]` enforcement.
- Deeper transitive `requires [...]` row propagation.
- Cross-module propagation.
- Method, closure, and higher-order effect propagation.
- Broader RFC-0033 effect-row subtyping.

**Primary files:**

- `compiler/nucleor_s1_compiler.nr`
- `compiler/nucleor_tools_suite.nr` only if parser unification has landed or
  the lane explicitly updates tools-suite diagnostics.
- `docs/rfcs/helper_manifest.toml`
- `tests/err/err_pure_*.nr`
- `tests/err/err_effect*.nr`
- `tests/err/err_restricts*.nr`

**Cloud slices:**

- EFF-A: cross-module `requires [...]` propagation fixture plus compiler path.
- EFF-B: real `restricts [...] { ... }` block enforcement.
- EFF-C: method/closure/higher-order effect propagation audit and first
  fail-closed implementation.

**Required gates:**

```bash
bash tools/verify.sh --only "<focused EFF step>"
bash tools/check_compiler_drift.sh
git diff --check
```

Run perf gate if compiler hot path changes materially.

---

## Lane 3 - T-3/T-4 Type-System Strictness

**Estimate:** 40% complete  
**Priority:** High  
**Source RFCs and docs:**

- `docs/rfcs/gap-analyses/Nucleor_Type_System_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/RFC-0015-numeric-types.md`
- `docs/rfcs/RFC-0027-lifetimes.md`
- `docs/rfcs/v1_PUNCHLIST.md`

**Current state:**

- T-3 char-cast Phase 1 is done.
- Const-foldable invalid `as char` codepoints emit `TYP-026`.
- T-4 Phase 1 canary exists.
- T-4 Phase 2b partial covers core helper return types in strict
  inference: `str_len`, `str_char_at`, `str_substring`, trim variants,
  `args_get`, and `file_read_string`.
- T-4 Phase 2b partial also covers direct IO/env/path runtime helper
  return types in strict inference: `env_*`, `getcwd`/`getenv`,
  OS-info, read-only FS, path, and byte-compare helpers.
- T-4 Phase 2b partial also covers direct format/string runtime helper
  return types in strict inference: string predicates, string utilities,
  integer parse/format helpers, and `format*` helpers.

Still open:

- T-4 strict empty-type compatibility beyond covered core/IO/path/format/string helper returns:
  generic/helper expansion, default-on promotion, and broad stdlib audit.
- Broader T-3 char distinctness.
- Non-constant char-cast proof.
- Runtime/IR char distinctness.

**Primary files:**

- `compiler/nucleor_s1_compiler.nr`
- `compiler/nucleor_tools_suite.nr` only after or with parser/tools-suite
  unification.
- `tests/err/err_t3_*.nr`
- `tests/fixtures/`
- `docs/rfcs/Nucleor_Error_Codes.md` if new diagnostics are added.

**Cloud slices:**

- TYPE-A: strict empty-type compatibility with focused negative fixtures.
- TYPE-B: non-constant char-cast proof and diagnostic coverage.
- TYPE-C: char distinctness audit for IR/runtime representation.

**Required gates:**

```bash
bash tools/verify.sh --only "<focused TYP step>"
bash tools/check_compiler_drift.sh
git diff --check
```

Run perf gate for any broad type-check traversal change.

---

## Lane 4 - ROBO-7 Frame Typing

**Estimate:** 10% complete  
**Priority:** High  
**Source RFCs and docs:**

- `docs/rfcs/RFC-0003-typed-frames.md`
- `docs/rfcs/RFC-0013-urdf-static-frames.md`
- `docs/rfcs/RFC-0046-coordinate-frame-types.md`
- `docs/rfcs/RFC-0047-typed-units-7vector.md`
- `docs/rfcs/gap-analyses/Nucleor_Robotics_Control_Stack_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/v1_PUNCHLIST.md`

**Current state:**

- The gap is confirmed open.
- Compiler-edit ship path is unblocked by recent self-host/perf evidence.

Still open:

- Unit/frame tagging in types.
- Compile-time frame consistency checks across operations.
- Clear diagnostics for frame mismatch.
- Fixtures for safe and unsafe robotics pose/twist transforms.

**Primary files:**

- `compiler/nucleor_s1_compiler.nr`
- `stdlib/rods/` robotics/control rods as needed.
- `tests/err/`
- `tests/features/`
- `docs/rfcs/Nucleor_Error_Codes.md` if new diagnostics are added.

**Cloud slices:**

- ROBO-A: design-to-code survey: exact type representation and diagnostics.
- ROBO-B: Phase 1 tagging and positive fixtures.
- ROBO-C: Phase 2b mismatch rejection fixtures.

**Required gates:**

```bash
bash tools/verify.sh --only "<focused ROBO/frame step>"
bash tools/check_compiler_drift.sh
git diff --check
```

Run perf gate for compiler type-system changes.

---

## Lane 5 - Real-Time / Determinism

**Estimate:** 30% complete  
**Priority:** High  
**Source RFCs and docs:**

- `docs/rfcs/RFC-0001-rt-attributes.md`
- `docs/rfcs/RFC-0002-allocator-types.md`
- `docs/rfcs/RFC-0009-heptane-wcet.md`
- `docs/rfcs/RFC-0014-max-depth.md`
- `docs/rfcs/gap-analyses/Nucleor_RealTime_Determinism_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/v1_PUNCHLIST.md`

**Current state:**

- Direct same-file `#[no_alloc]` helper allocation checks landed.
- `#[no_panic]` same-file helper call checks landed.

Still open:

- Deeper transitive calls.
- Cross-module callees.
- Fn-pointer dispatch.
- Numeric/WCET backing for `#[deadline]`.
- Broader RT attribute enforcement audit.

**Primary files:**

- `compiler/nucleor_s1_compiler.nr`
- `tests/err/err_no_alloc*.nr`
- `tests/err/err_no_panic*.nr`
- `tests/fixtures/t*_deadline*.nr`
- `docs/rfcs/Nucleor_Error_Codes.md`

**Cloud slices:**

- RT-A: AST/IR traversal for deeper transitive `no_alloc` and `no_panic`.
- RT-B: cross-module RT attribute propagation after parser unification.
- RT-C: `#[deadline]` numeric/WCET backing and diagnostic gates.

**Required gates:**

```bash
bash tools/verify.sh --only "<focused RT step>"
bash tools/check_compiler_drift.sh
git diff --check
```

Run perf gate for traversal changes.

---

## Lane 6 - Algebraic Laws

**Estimate:** 50% complete  
**Priority:** Medium-high  
**Source RFCs and docs:**

- `docs/rfcs/RFC-0031-algebraic-laws.md`
- `docs/rfcs/gap-analyses/Nucleor_Algebraic_Laws_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/v1_PUNCHLIST.md`
- `docs/architecture.md`

**Current state:**

- `@law(...)` capture exists.
- Metadata-only optimizer pass scaffold exists.
- `nuc test --check-laws` has bounded integer checks for low-risk law forms.
- Unknown/deprecated law diagnostics exist for the first surface.

Still open:

- Arbitrary-driven broader property tests.
- `distributive_over`, `inverse`, and `fusion` generation.
- Float `eps` / approximate semantics.
- Optimizer rewrite gating using verified law metadata.
- Cert-profile SMT/proof obligations and float-law safeguards.

**Primary files:**

- `compiler/nucleor_s1_compiler.nr`
- `nuc_router.ps1`
- `docs/rfcs/RFC-0031-algebraic-laws.md`
- `tests/attrs/laws.nr`
- `tests/features/`
- `tests/err/err_law*.nr`

**Cloud slices:**

- LAW-A: broaden generated property checks for non-float laws.
- LAW-B: float approximate semantics and fail-closed diagnostics.
- LAW-C: optimizer rewrite gate for low-risk verified laws only.

**Required gates:**

```bash
bash tools/verify.sh --only "CLI: nuc test --check-laws validates laws and schema"
git diff --check
```

Run compiler drift/perf gates if optimizer/compiler source changes.

---

## Lane 7 - PKG-1 Linux Signed Publish Proof

**Estimate:** 75% complete  
**Priority:** High for release proof  
**Source RFCs and docs:**

- `docs/rfcs/RFC-0019-package-manager.md`
- `docs/rfcs/RFC-0022-cross-platform.md`
- `docs/rfcs/RFC-0063-production-readiness-roadmap.md`
- `docs/rfcs/gap-analyses/Nucleor_Module_Packaging_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/v1_PUNCHLIST.md`

**Current state:**

- `nuc publish --dry-run` and `native_release.ps1 package-sign-preflight`
  have been staged.
- Existing prep is non-mutating and does not create keys, signatures, or
  registry writes.

Still open:

- Native Linux transcript against throwaway registry/key.
- Signature creation and verification evidence.
- Release notes showing the proof command and expected artifacts.

**Primary files:**

- `compiler/nucleor_tools_suite.nr` or CLI dispatch files if publish command
  logic changes.
- `tools/native_release.ps1`
- `tools/VERIFY_TIMING_RECIPE.md`
- `docs/`
- `findings/inbox/`

**Cloud slices:**

- PKG-A: run native Linux signed publish proof with throwaway registry/key.
- PKG-B: document exact transcript and failure modes.
- PKG-C: optional CI-ready wrapper, only if it stays hermetic and non-mutating
  by default.

**Required gates:**

```bash
git diff --check
```

Native Linux agent should include:

```bash
uname -a
./bin/nucleor --version
<publish dry-run command>
<throwaway sign command>
<signature verify command>
```

Do not use WSL/Windows `.exe` interop as POSIX evidence.

---

## Lane 8 - R06 FFI Ownership

**Estimate:** 60% complete  
**Priority:** High  
**Source RFCs and docs:**

- `docs/rfcs/RFC-0010-dlpack.md`
- `docs/rfcs/RFC-0011-nuc-cxx.md`
- `docs/rfcs/RFC-0012-nuc-bindgen.md`
- `docs/rfcs/RFC-0062-memory-safety-borrow-ownership-gap-closure.md`
- `docs/rfcs/gap-analyses/Nucleor_Interop_FFI_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/v1_PUNCHLIST.md`

**Current state:**

- `rust_free_str` and deterministic Rust bridge hashing work landed.
- PowerShell/POSIX opt-in ownership harnesses are staged.
- JSON/self-test/fail-closed improvements were added by helper2.

Still open:

- Native POSIX compiler/artifact evidence.
- Optional ASAN/valgrind-style leak-signal evidence.
- Broader cross-boundary ownership contract for Python/shared-library FFI.

**Primary files:**

- `stdlib/rods/rust_bridge/src/lib.rs`
- `stdlib/rods/rust_bridge.nr`
- `tools/check_rust_bridge_ownership.ps1`
- `tools/check_rust_bridge_ownership.sh`
- `tests/features/rust_bridge_*`
- `docs/ffi-conventions.md`

**Cloud slices:**

- FFI-A: native POSIX rust_bridge ownership transcript.
- FFI-B: optional ASAN/valgrind evidence if available on the host.
- FFI-C: broader FFI ownership contract doc and first fail-closed checks for
  shared-library/Python ownership boundaries.

**Required gates:**

```powershell
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Doctor
```

On POSIX:

```bash
bash tools/check_rust_bridge_ownership.sh --doctor
```

Plus focused fixture validation when prerequisites are present.

---

## Lane 9 - Quantum Residuals

**Estimate:** 80% complete  
**Priority:** Medium-high  
**Source RFCs and docs:**

- `docs/rfcs/RFC-0054-logical-qubit-type.md`
- `docs/rfcs/RFC-0048-hardware-capability-queries.md`
- `docs/rfcs/RFC-0049-memory-space-type-tags.md`
- `docs/rfcs/RFC-0055-distributed-collectives.md`
- `docs/rfcs/RFC-0056-deterministic-replay.md`
- `docs/rfcs/gap-analyses/Nucleor_Quantum_Subsystem_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/v1_PUNCHLIST.md`

**Current state:**

Closed or mostly closed:

- QM-6 MPS probability/statevector extraction Phase 1/2c.
- QM-2 qsim checked init.
- QM-7 Clifford d=3 surface coverage.
- QM-8/QM-9 qsim graph preflight and checked record.
- QM-11 diff_sim checked init.
- QM-12 shared common gate constants.
- QM-13 schedule overlap and checked insertion.
- QM-14 logical-qubit registry cap and partial release.

Still open:

- Published Clifford weight-enumerator parity and API.
- High-qubit MPS streaming/external-sink extraction.
- qsim graph thread safety.
- Typed rotation IDs or unified native rotation dispatch.
- Backend calibration/resource scheduler and hardware target lowering.
- Logical registry thread safety.

**Primary files:**

- `stdlib/rods/clifford.nr`
- `stdlib/rods/mps.nr`
- `stdlib/rods/qsim_graph.nr`
- `stdlib/rods/quantum.nr`
- `stdlib/rods/diff_sim.nr`
- `tests/features/qm7_*.nr`
- `tests/features/qsim_*.nr`
- `tests/features/mps_*.nr`

**Cloud slices:**

- QM-A: Clifford weight-enumerator API plus published parity fixture.
- QM-B: MPS high-qubit streaming/external sink design and first safe API.
- QM-C: qsim graph/thread-safety audit and fail-closed process-local warning or
  lock-backed implementation.
- QM-D: typed rotation IDs or dispatch-unification finding if implementation is
  larger than a clean stdlib/runtime slice.

**Required gates:**

```bash
bash tools/verify.sh --only "<focused quantum step>"
git diff --check
```

Run compiler drift only if compiler/source manifest changes. Run perf if
runtime changes affect hot paths.

---

## Lane 10 - Hermetic / Native Tooling

**Estimate:** 55% complete  
**Priority:** Medium-high  
**Source RFCs and docs:**

- `docs/rfcs/RFC-0063-production-readiness-roadmap.md`
- `docs/rfcs/RFC-0019-package-manager.md`
- `docs/rfcs/RFC-0022-cross-platform.md`
- `docs/rfcs/gap-analyses/Nucleor_Performance_Envelope_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/gap-analyses/Nucleor_Self_Hosting_Bootstrap_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/v1_PUNCHLIST.md`

**Current state:**

- `gen_releases_index.py`, `gen_rod_manifest.py`,
  `gen_benchmark_summary.py`, and `gen_helper_manifest.py` have native paths.
- `verify-reproducible` no longer requires Python for Windows byte compare.
- Python interop is classified as intentional.
- `tools/check_compiler_drift.sh` no longer invokes a Python generator for any
  active generated-artifact freshness check.

Still open:

- Port `gen_numerics_matrix.py` to native Nucleor or remove it from required
  product/toolchain paths.
- Refresh or retire `gen_numerics_matrix.py` before any native port: its current
  output rewrites 10 committed matrix fixtures back to older syntax.
- Keep maintenance-only Python references clearly optional.

**Primary files:**

- `tools/gen_numerics_matrix.py`
- `tools/gen_helper_manifest.py`
- `tools/check_compiler_drift.sh`
- `tools/gen_rod_manifest.nr`
- `tools/gen_benchmark_summary.nr`
- `docs/rfcs/helper_manifest.toml`
- `docs/rfcs/rod_manifest.toml`
- `tests/lang/numerics_matrix/`

**Cloud slices:**

- HERM-A: native numerics matrix generator only after the Python oracle is
  refreshed, or evidence that the generator stays optional/offline.
- HERM-B: native helper manifest generator path is present; keep the Python
  source only as a temporary comparison oracle.
- HERM-C: active drift-gated generator checks are Python-free; keep future
  `.py` fallback checks out of release-critical paths unless explicitly
  re-justified.

**Required gates:**

```bash
bash tools/check_compiler_drift.sh
git diff --check
```

If generated manifests change:

```bash
bash tools/verify.sh --only "compiler ABI tables synced"
```

Run perf gate if compiler/toolchain hot paths change.

---

## External Product Integration Visibility - ML Suite and Translate

This section is deliberately outside the ten core compiler/runtime lanes above.
It is included so cloud agents have full visibility into adjacent work products
without accidentally importing external product repos into `Nucleor_OSS`.

### ML Expansion / ML Suite

**Status:** spine-wired, code remains external.
**Core rule:** no ML Suite implementation code is imported into `Nucleor_OSS`.
Only compiler/runtime/CLI/package substrate needed by Nucleor itself belongs in
this repository.

**Canonical spine references:**

- `C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_Build_Spine\BUILD_PATH_v0.4_to_v1.3.md`
  - `§1.6` ML Expansion Set Crosswalk
  - `§8.7.1` closure note for ML Expansion live milestone enrichment
  - `§12.1` ML Expansion Spine Integration Brief anchor
- `C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_ML_Expansion_Spine_Integration_Brief_2026-05-01.md`

**Observed local sibling repos / workspaces on this machine:**

- `C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_ML_Suite`
- `C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_ML_Suite_ParallelAgent`
- `C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_ML_Suite_ParallelAgent_Mainline`
- `C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\MLV_Kernel`

Older spine and brief text may cite equivalent Desktop-root paths such as
`C:\Users\JoeWe\Desktop\Nucleor_ML_Suite_ParallelAgent_Mainline`. On this
machine, the currently observed copies are under `Nucleor_OSS_Files`.

**ML Expansion lanes already wired in the spine:**

| Lane | Theme | Nucleor-facing substrate |
|---|---|---|
| A | Strategic review response | Evidence-bound performance claims and backend dispatch before speed claims |
| B | Build brief | HF / ONNX / vLLM / Arrow / boosting frontend surfaces as Nucleor substrate, not ML Suite code import |
| C | Implementation plan | Kernel backend, shape phase, `nuc serve`, package contracts |
| D | Numeric model | Public dtype claim rule: storage + convert + kernel + parity + docs |
| E | Hugging Face frontend | Local model package metadata for `nuc serve` / `.ncap` |
| F | ONNX / GGUF interchange | GGUF / safetensors loader first, then ONNX |
| G | vLLM serving contract | KV cache, prefill/decode, batching, paged-attention smoke evidence |
| H | Tabular engine substrate | Arrow / DLPack / zero-copy interop; ML Suite owns dataframe library |
| I | Boosting runtime | Fitted-tree scoring + model import substrate |
| J | Kernel backend | Backend manifest and accounting for BLAS / oneDNN / cuBLAS / GGML-class targets |
| K | Ecosystem blueprints | Package manifest, lockfile, signed NCAP, conformance dashboard |

**Dispatchable cloud work:**

- ML-EXT-A: audit the observed ML Suite repos and produce a current status
  report: repo path, branch, HEAD, verification command, pass/fail, and which
  spine lanes A-K they substantiate.
- ML-EXT-B: produce an integration-gap matrix from the current ML Suite docs to
  Nucleor core lanes: what belongs in `Nucleor_OSS`, what remains external, and
  what requires only docs/CLI contract.
- ML-EXT-C: verify whether `Nucleor_ML_Suite_ParallelAgent_Mainline` is still
  the canonical ML Suite reference or whether another sibling repo supersedes
  it. Do not modify `Nucleor_OSS` for this; write a finding only.

**Non-scope:**

- Do not import ML Suite library source into `Nucleor_OSS`.
- Do not claim HF/ONNX/vLLM/DuckDB/Polars/XGBoost/LightGBM/CatBoost
  replacement without native execution evidence.
- Do not turn ML Suite library work into compiler work unless the task is a
  core compiler/runtime/CLI substrate required by Nucleor itself.

### Nucleor Translate

**Status:** external, not fully validated for pull-in.
**Core rule:** Translate stays a standalone workspace. `Nucleor_OSS` should only
gain a `nuc port` CLI shim/invocation contract after Translate reaches its own
completion and is revalidated against the then-current Nucleor compiler.

**Canonical spine references:**

- `C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_Build_Spine\BUILD_PATH_v0.4_to_v1.3.md`
  - `§12.2` `Nucleor_Translate` forward commitment
  - `§12.3` Translate completion watch

**Observed local workspace:**

- `C:\Users\JoeWe\Desktop\Nucleor_OSS_Files\Nucleor_Translate`

**Spine-recorded state to verify before action:**

- Polished MVP, not complete.
- 6 of 20 languages recorded as done: Python, Rust, C, Go, TypeScript,
  JavaScript.
- 368 tests recorded as passing in the spine.
- Compiler pin recorded as Nucleor 0.4.5, so revalidation against current
  Nucleor is mandatory before any `nuc port` integration claim.

**Dispatchable cloud work:**

- TRANS-A: current-state verification only: branch, HEAD, test command,
  pass/fail count, language matrix, and compiler version pin.
- TRANS-B: adopter-readiness gap report for control-flow IR, float parsing,
  C structs, and any remaining language blockers.
- TRANS-C: once Translate is declared complete, draft the `nuc port` CLI shim
  contract for `Nucleor_OSS` without copying Translate implementation source.

**Non-scope:**

- Do not pull Translate into `Nucleor_OSS` early.
- Do not duplicate Translate source in `Nucleor_OSS`.
- Do not wire `nuc port` until Translate reaches completion and passes
  revalidation against the current compiler.

---

## Dispatch Priority Order

1. RFC-0063 parser/tools-suite duplicate deletion Wave 1.
2. Effect/capability enforcement cross-module and real `restricts`.
3. PKG-1 and R06 native POSIX evidence lanes, because they are mostly
   transcript/proof work and can run in parallel with compiler work.
4. T-3/T-4 strictness and ROBO-7 frame typing.
5. Algebraic laws rewrite/proof gates.
6. Quantum residuals.
7. Hermetic native tooling ports that are not already blocking parser
   unification or release proof.
8. External ML Suite / Translate visibility audits. These are useful in
   parallel, but they must stay read-only against `Nucleor_OSS` unless a
   separate integration task is explicitly opened.

## Minimum Report Format for Cloud Agents

Each cloud agent should end with:

```text
Branch:
HEAD:
Base:
Merge-base:
Changed files:
Validation:
Residual risk:
Report path:
```

If a lane stops on a blocker, the report must include the exact command,
output, file path, and smallest next unblocking action.
