# RECON Audit Pass 1 — Stdlib Robotics, Quantum, FFI (Layer 9b)

- **Date:** 2026-05-08
- **Scope:** Robotics rods (SE(3), TF, URDF, IK, FK, frames, kinematics_transform), quantum rods (qsim, MPS, qsim_graph, quantum_gates, quantum_twin), FFI (rust_bridge crate, ffi-conventions, direct_ffi attribute), graph capabilities (RFC-0061).
- **Project root:** `C:\Users\JoeWe\Desktop\Nucleor_OSS_integrate_r05_with_row_v0842`
- **Mode:** READ-ONLY. No source modifications. No `verify.sh` invocations.
- **Methodology:** Read every public-API rod surface and its companion runtime in scope, traced math against literature, traced FFI ownership conventions, cross-checked against existing tests in `tests/rods/`, scanned the compiler effect-system pass for `direct_ffi` enforcement.

Severity legend (per spec): **Critical** = wrong robotics math (>1e-9 round-trip error) / wrong quantum state / FFI memory unsafety. **High** = wrong API. **Medium** = poor diagnostic, partial edge handling. **Low** = cosmetic. **Note** = observation.

---

## Inventory (rods in scope)

| Family | Rods | Runtime |
|---|---|---|
| Robotics — SE(3)   | `stdlib/rods/se3.nr` | `stdlib/runtime/se3_rt.c` |
| Robotics — TF tree | `stdlib/rods/tf.nr` | `stdlib/runtime/tf_rt.c` |
| Robotics — URDF    | `stdlib/rods/urdf.nr` | `stdlib/runtime/urdf_rt.c` |
| Robotics — IK      | `stdlib/rods/ik_dls.nr` | `stdlib/runtime/ik_dls_rt.c` |
| Robotics — FK chain | `stdlib/rods/fk_chain.nr` | `stdlib/runtime/fk_chain_rt.c` |
| Robotics — Kinematics primitives | `stdlib/rods/kinematics.nr`, `kinematics_frame.nr`, `kinematics_transform.nr` | `stdlib/runtime/kinematics_rt.c` |
| Quantum — qsim     | `stdlib/rods/quantum.nr`, `quantum_gates.nr` | `stdlib/rods/quantum_rt.c` (note: located in `rods/`, not `runtime/`) |
| Quantum — MPS      | `stdlib/rods/mps.nr` | `stdlib/runtime/mps_rt.c` |
| Quantum — qsim_graph | `stdlib/rods/qsim_graph.nr` | `stdlib/runtime/qsim_graph_rt.c` |
| Quantum — twin     | `stdlib/rods/quantum_twin.nr` | (rod-only) |
| FFI — Rust bridge  | `stdlib/rods/rust.nr`, `stdlib/rods/rust_bridge/Cargo.toml` | `stdlib/rods/rust_bridge/src/lib.rs` |
| FFI — graph (RFC-0061) | `stdlib/rods/graph.nr`, `graph_render.nr` | `stdlib/runtime/graph_rt.c` |

Tests in scope (`tests/rods/`): `se3_smoke.nr`, `tf_smoke.nr`, `urdf_smoke.nr`, `fk_chain_smoke.nr`, `ik_dls_smoke.nr`, `kinematics_smoke.nr`, `mps_smoke.nr`, `quantum_basic.nr`, `rust_interop.nr`.

Rust bridge build state: **Pre-built** — `stdlib/rods/rust_bridge/target/release/nucleor_rust_bridge.lib` and `.d` already present. Cargo.toml uses `regex = "1"` and `crate-type = ["staticlib"]`.

---

## Findings

### CRIT-LAYER9B-001 — URDF default joint axis is (0,0,1) instead of URDF-spec (1,0,0)
- **Severity:** Critical (wrong robotics math — every URDF without explicit `<axis>` produces wrong FK).
- **File:** `stdlib/runtime/urdf_rt.c` line 264.
- **Body:** Joint defaults set `j->axis[2] = 1.0` (z-axis). The URDF specification (`http://wiki.ros.org/urdf/XML/joint`) declares the default joint axis is `1 0 0` (x-axis). For any joint where `<axis xyz="..."/>` is omitted, `urdf_to_fk_chain` will rotate (revolute) or translate (prismatic) about the wrong axis. End-effector poses computed downstream by `nuc_fk_chain_update` will be wrong by the rotation that maps z to x.
- **Reproduction sketch:** Parse a single-revolute URDF with no `<axis>`, build FK chain, set var = π/2, observe end-effector position rotated about z instead of x.
- **Remediation:**
  1. Change `j->axis[2] = 1.0;` (line 264) to `j->axis[0] = 1.0;` so default reflects the URDF spec.
  2. Add a fixture: `tests/rods/urdf_default_axis.nr` that parses `<joint type="revolute"><parent link="a"/><child link="b"/></joint>` (no `<axis>` element) and asserts FK end-effector at θ=π/2 lies on the y-axis (i.e., axis was x).
  3. Audit any downstream consumer that may have compensated for the wrong default — there is no test today that exercises the default branch since `urdf_smoke.nr` only asserts empty-state accessors don't crash.

### CRIT-LAYER9B-002 — Rust bridge string returns leak by default in current adopter test
- **Severity:** Critical (FFI memory unsafety — silent leaks in the only end-to-end Rust interop test).
- **File:** `tests/rods/rust_interop.nr`, plus the ownership contract documented in `stdlib/rods/rust_bridge/src/lib.rs` lines 5-23.
- **Body:** Per the lib.rs banner, every Rust function returning `*const c_char` transfers heap ownership to the caller via `CString::into_raw()`; the caller "MUST eventually pass the exact pointer to `rust_free_str` to reclaim memory; otherwise leaks by design." The seven leaking surfaces are: `rust_regex_find`, `rust_regex_replace_all`, `rust_sort_ints`, `rust_sort_strings`, `rust_to_uppercase`, `rust_base64_encode`, `rust_base64_decode`. The shipped end-to-end test (`tests/rods/rust_interop.nr`) calls `rust_base64_encode` and `rust_base64_decode` and never calls `rust_free_str` on the returned pointers — every test invocation leaks two `CString` allocations. This means: (a) the canonical adopter pattern in tree leaks, (b) any reference example downstream users copy from will leak, (c) the test cannot be used to detect a regression in `rust_free_str`'s reclamation path.
- **Remediation:**
  1. Update `tests/rods/rust_interop.nr` to call `rust_free_str(enc)` after the encode-equality assertion and `rust_free_str(dec)` after the decode-equality assertion.
  2. Add a stress-test fixture (e.g., `tests/rods/rust_interop_no_leak.nr`) that does ~10⁶ encode/free cycles to assert the reclamation path actually works (would catch a regression where `rust_free_str` is renamed or omitted from the linker).
  3. Strengthen the FFI conventions doc to mandate `rust_free_str` in every example snippet (currently only the lib.rs banner documents it).
  4. Optional: ship a Nucleor-side RAII-style helper `rust_with_str(ptr) -> str` that both copies and frees, so adopters cannot forget. Phase 2 of R06-D1 already anticipates a `HashSet`-tracked double-free-detection wrapper (lib.rs line 200) — same surface naturally extends.

### HIGH-LAYER9B-003 — `qsim_init` cap (24 qubits) inconsistent with `qsim_graph` cap (1024) and silent qubit-count desync
- **Severity:** High (wrong API surface — adopter cannot rely on cap consistency across rods that interlock).
- **Files:** `stdlib/rods/quantum.nr` lines 80-81, 617-619 (`qsim_max_qubits = 24`); `stdlib/rods/qsim_graph.nr` line 114 (`qsim_graph_max_qubits = 1024`); `stdlib/runtime/qsim_graph_rt.c` line 9 (`NUC_QSIM_MAX_QUBITS 1024`); `stdlib/runtime/quantum_rt.c` line 37 (`MAX_QUBITS 32` for the trace-side union-find).
- **Body:** Three different caps are exposed for the SAME logical entity (a "qubit"):
  - `qsim_max_qubits()` = 24 (state-vector cap; enforced).
  - `qsim_graph_max_qubits()` = 1024 (entanglement graph + gate DAG cap).
  - `quantum_rt.c::MAX_QUBITS` = 32 (trace-side union-find for `rods_trace_*`).

  The qsim runtime `qsim_cnot` calls `qsim_entangle_register(ctrl, tgt)` (via the qsim_graph rod) and `rods_trace_entangle` (via `quantum_rt.c`) WITHOUT first checking that `ctrl, tgt < qsim_max_qubits()`. If an adopter passes `ctrl=30` to `qsim_cnot` after a `qsim_init(2)`, the entanglement graph will accept it (1024-cap), but `rods_trace_entangle` will silently skip the indices >=32, and the actual `qsim_cgate1` will read non-existent bit positions on a 4-amplitude state-vector — producing a state-vector that's left unchanged while `qsim_graph` falsely records the qubit pair as entangled. Adopters get inconsistent reasoning across rods.
- **Remediation:**
  1. Tighten `qsim_cnot` / `qsim_cz` / `qsim_swap` / `qsim_ccx` / `qsim_crk` in `stdlib/rods/quantum.nr` to preflight `q < qsim_num_qubits(sv)` and return a sentinel (or panic via `admit`) on out-of-range, BEFORE calling either entanglement-register or trace-entangle.
  2. Either raise `quantum_rt.c::MAX_QUBITS` to ≥ `qsim_max_qubits()` (current 24 fits in 32, so today is OK — but the inconsistency is an open footgun for the post-v1.0 cap raise), or document the trace-side cap as a hard external invariant.
  3. Add a fixture `tests/rods/qsim_cnot_out_of_range.nr` that passes `qsim_cnot(sv, 0, 30)` on a 2-qubit state and asserts a defined error path (not the current silent miscompute).

### HIGH-LAYER9B-004 — `rods_count_nonzero` uses `mag_sq > threshold` but is documented as "above threshold" (units mismatch)
- **Severity:** High (silent miscompute of the sparsity metric, which is fed into trace-side adopter heuristics).
- **File:** `stdlib/rods/quantum_rt.c` line 487.
- **Body:** The function is called by the rod's `qtrace_sparsity` / `rods_trace_sparsity` path with `threshold = f64(0, 1)` (= 0.1 from the rod-side helper at `quantum.nr` line 67). The C code does `if (mag_sq > threshold) count++;` where `mag_sq = re² + im²`. So a threshold of 0.1 actually filters amplitudes with |amp|² > 0.1, i.e., |amp| > √0.1 ≈ 0.316 — not |amp| > 0.1 as the API surface implies. Downstream sparsity events will undercount nonzero amplitudes vs the documented contract.
- **Remediation:** Either (a) clarify the API to call the parameter `threshold_sq` in the signature/docs, or (b) take the sqrt inside the C runtime so `mag_sq > threshold * threshold` matches the |amp| > threshold semantics adopters expect. Add a `quantum.nr` doc-line clarifying which one of these the trace stream consumes.

### HIGH-LAYER9B-005 — `qsim_swap` is implemented as 3× `qsim_cnot`, double-counts trace events and entangle-registers
- **Severity:** High (trace fidelity — qsim_graph and rods_trace_* events disagree with the gate-level program).
- **File:** `stdlib/rods/quantum.nr` lines 328-332.
- **Body:** SWAP is decomposed as `qsim_cnot(sv, q1, q2); qsim_cnot(sv, q2, q1); qsim_cnot(sv, q1, q2);`. Each call emits its own `gate_apply` trace event (named "CNOT", not "SWAP"), calls `qsim_entangle_register` three times on the same qubit pair (idempotent in the union-find but still records 3 events), and registers 3 gate-DAG entries via `qsim_gate_record_checked`. Downstream consumers (the `rods/quantum_rt.c` profile event, qsim_graph_gate_dag_size queries, the `is_2q_gate` "SWAP" branch in `quantum_rt.c` line 144) then over-count gates and depth. The `is_2q_gate` table in `quantum_rt.c` even includes "SWAP" — but the rod never emits "SWAP" through `rods_trace_gate`, so the table entry is dead. Result: depth_2q for a circuit with one SWAP is reported as 3 instead of the canonical 1.
- **Remediation:**
  1. Promote `qsim_swap` to a first-class gate: emit a single `rods_trace_gate("SWAP", _q2_json(q1, q2), 0, 0)` trace event before the 3-CNOT decomposition (or apply a true SWAP unitary directly via `qsim_gate_2q`-style permutation on the state vector — only marginally more code).
  2. Wrap the 3 inner `qsim_cnot` calls so they DON'T fire trace/entangle/dag events (e.g., a `_qsim_cnot_silent(sv, ctrl, tgt)` private helper that performs the gate but skips trace+register). The current SWAP claims to inherit auto-graph "through its CNOT sequence" (per `qsim_graph_limitations()` text) — but the qsim_graph DAG should record the swap once, not three times.
  3. Add a `tests/rods/qsim_swap_trace.nr` that runs one SWAP and asserts `qsim_gate_dag_size() == 1`.

### HIGH-LAYER9B-006 — `qsim_cnot` registers entanglement BEFORE applying the gate — reports false entanglement for control=|0⟩
- **Severity:** High (semantic miscompute — the entanglement graph claims qubits are entangled when the CNOT physically did not entangle them).
- **File:** `stdlib/rods/quantum.nr` lines 294-301 (`qsim_cnot`).
- **Body:** `qsim_cnot` calls `qsim_entangle_register(ctrl, tgt)` regardless of whether the control qubit's amplitude on |1⟩ is non-zero. A CNOT applied to a product state where the control is in |0⟩ has no entangling effect (the gate is the identity), but `qsim_graph` reports the pair as entangled. Same issue for `qsim_cz` (line 306), `qsim_crk` (line 321), `qsim_ccx` (lines 341-342). Downstream reasoning that uses `qsim_entanglement_same` to predict whether a 2-site reduced density matrix is mixed will be wrong.
- **Remediation:**
  1. Document explicitly that `qsim_entangle_register` is a "potential entanglement" / "syntactic" record, NOT a semantic-state record. The current `qsim_graph_limitations()` text leans toward this but never spells out the "reports false positive when control is |0⟩" footgun.
  2. Optionally provide a `qsim_entanglement_actual(sv)` helper that walks the state and unions only qubits that are entangled in the current ψ (e.g., via reduced-density-matrix purity check). This is a separate metric — the syntactic union-find is fine for resource estimation, but adopters comparing to physical entanglement will be misled.
  3. Add a fixture that asserts the documented behavior: `qsim_init(2); qsim_cnot(sv, 0, 1); qsim_entanglement_same(0, 1)` returns 1 even though the state is still |00⟩ — this tests the syntactic-not-semantic contract.

### HIGH-LAYER9B-007 — URDF parser fails on self-closing `<joint .../>` (defaults to whole-file scan)
- **Severity:** High (real-world URDF hand-edits and ROS exports use self-closing for `<joint type="fixed" .../>` shorthand; this parser silently consumes the rest of the file).
- **File:** `stdlib/runtime/urdf_rt.c` lines 251-253.
- **Body:** The parser locates `</joint>` via `strstr(jstart, "</joint>")` and falls back to `jend = end` when not found. Lots of valid URDF uses `<joint name="..." type="fixed"><parent .../><child .../></joint>` always with explicit close, but the comment at line 251 admits self-closing is "rare" — it isn't, particularly in xacro-generated files for tip / dummy frames. When the close tag is missing (because the joint is fully self-closed at e.g. `<joint .../>` — though strict URDF rarely permits this on `<joint>` itself), `jend = end` is set, and the very next iteration's `_find_elem(cursor, end, "joint")` starts from `cursor = jend + 8 = end + 8` and exits the loop — but the CURRENT joint then absorbs every subsequent element's `<origin>`, `<axis>`, `<parent>`, `<child>`, `<limit>` as attributes of the malformed first joint. This is a silent miscompute where the first joint inherits values from a sibling.
- **Remediation:**
  1. Detect self-closing `/>` in the joint open tag (search for `/>` between `jstart` and the first `<` after) and, when found, set `jend = open_close + 1` so subsequent siblings are reachable.
  2. When `</joint>` is genuinely absent, return `-1` from `nuc_urdf_parse` to signal a malformed source (instead of the current silent absorption).
  3. Add a fixture parsing two adjacent `<joint />`-style records and asserting `urdf_joint_count == 2`.

### MED-LAYER9B-008 — `qsim_init` rejects n=0 with same sentinel (0) as malloc-failure path
- **Severity:** Medium (poor diagnostic — adopters can't distinguish "you asked for 0 qubits" from "out of memory").
- **File:** `stdlib/rods/quantum.nr` lines 79-93.
- **Body:** Returns 0 for `n < 1` AND for `n > 24` AND for any internal allocation failure path. Adopters get a single sentinel for three distinct preconditions. The newer `qsim_init_preflight(n)` (line 633) correctly distinguishes them via status codes (1=invalid_qubit_count, 2=over_capacity), but the legacy `qsim_init` path is what `qsim_init_checked` defers to and the existing in-tree tests use.
- **Remediation:** Document the `qsim_init` -> 0 sentinel as the single-bit handle and steer adopters toward `qsim_init_preflight` + `qsim_init_checked` in the rod's header (the limitations text already covers this — promote it to the API doc-line on `qsim_init` itself).

### MED-LAYER9B-009 — `nuc_se3_distance` mixes translational meters and rotational radians by raw sum
- **Severity:** Medium (the documented formula is what the code implements, but the units are inconsistent and the API offers no scale knob).
- **File:** `stdlib/runtime/se3_rt.c` lines 305-320.
- **Body:** Returns `dt + dr` where `dt` is translation distance (typically meters) and `dr` is `2 · acos(|qA·qB|)` (radians). For a 1m translation + 1 rad rotation, this returns 2.0 — but for a 1mm translation + 1 mrad rotation it returns 0.002, equally weighting the two axes. The API has no λ parameter despite the comment-block on line 302-304 hinting at one ("with λ = 1 by default"). Adopters comparing two poses on a sub-millimeter robot work-cell will get rotation-dominated distances, while large-arena navigation users get translation-dominated.
- **Remediation:** Add `nuc_se3_distance_weighted(tA, qA, tB, qB, lambda_b)` that exposes the rotation-weight scalar, leave `nuc_se3_distance` as the λ=1 backward-compat surface, and document the unit mismatch in the rod's header.

### MED-LAYER9B-010 — `_quat_log_map` in IK 6D uses raw 2π wrap, may select the wrong shortest-arc on near-π targets
- **Severity:** Medium (orientation IK can flip-flop on near-singularity targets).
- **File:** `stdlib/runtime/ik_dls_rt.c` lines 526-540.
- **Body:** After `angle = 2 * atan2(sinhalf, qw)`, the wrap is `if (angle > π) angle -= 2π;` so angle ends in `(-π, π]`. But the input quaternion is the result of `_angular_error(target * current⁻¹)` and is not pre-canonicalized to the short arc (`qw < 0` means q and -q both encode the rotation, with -q being the short arc). For target orientations where the residual is near π, the chosen arc can flip across iterations, manifesting as IK oscillation that never reduces orientation error. Standard practice is to flip q → -q if qw < 0 BEFORE the log-map.
- **Remediation:** Insert `if (qw < 0) { qw = -qw; qx = -qx; qy = -qy; qz = -qz; }` at the top of `_quat_log_map`. Add a fixture that targets a 178°-rotation goal and asserts the IK converges in a bounded iteration count.

### MED-LAYER9B-011 — Joint-limit table in `ik_dls_rt.c` leaks across chain-handle reuse
- **Severity:** Medium (silent state leak between chains; a freed FK chain handle reused by a new chain inherits old joint limits).
- **File:** `stdlib/runtime/ik_dls_rt.c` lines 173-205 (`_g_limits` array, `_get_or_create_limits`, `nuc_ik_set_joint_limit`).
- **Body:** The `_g_limits` global table is keyed by raw `long long ch` handle. When an adopter calls `nuc_fk_chain_new()` after freeing a previous chain, `malloc` may return the same address — and `_lookup_limits` will hand back the old limits. `nuc_fk_chain_free` (if it exists) does NOT clear the corresponding `_g_limits` entry (no FK-chain free hook in this file). The `_g_limits` array also grows unbounded for every distinct chain ever allocated.
- **Remediation:**
  1. Add a `nuc_ik_clear_joint_limits(ch)` API and call it from `nuc_fk_chain_free` when the FK chain is freed.
  2. Or move limits into the `FKChain` struct itself so they get freed with the chain.
  3. Add a fixture: free a chain that had limits set, allocate a new chain, set NO limits, observe that no stale limits clamp the new chain's IK. (Today this fixture would fail intermittently depending on allocator behavior.)

### MED-LAYER9B-012 — TF tree: `tf_lookup_at` rejects timestamps OUTSIDE [prev_stamp, stamp] but doesn't extrapolate
- **Severity:** Medium (silent mid-trajectory failures when the lookup stamp is older than `prev_stamp` or newer than `stamp` by even 1 microsecond).
- **File:** `stdlib/runtime/tf_rt.c` lines 132-146 (`_frame_pose_at`).
- **Body:** Outside the [a-1e-9, b+1e-9] range, returns 0. ROS tf typically requires consumers to extrapolate at the boundary or refuse — the current behavior is to refuse, but the rod's `tf.nr` doc-line at lines 100-102 says "Each frame with two timestamped samples is interpolated at `stamp`; static or single-sample frames use their stored pose" and does NOT warn that out-of-range stamps fail. Adopters of trajectory-tracking code will see lookups silently zero out near the start/end of a buffered trajectory.
- **Remediation:** Either (a) extrapolate (clamp to nearest sample with a warning) or (b) document the strict-bracketing behavior and provide a separate `tf_lookup_at_clamped` variant that returns the nearest sample. Update the rod doc-line.

### MED-LAYER9B-013 — MPS `simple_svd` has 100-sweep hard cap with silent truncation on non-convergence
- **Severity:** Medium (wrong quantum state — for entangled circuits with bond growth, off-diagonal Jacobi may not converge in 100 sweeps; the rod records `last_svd_converged=0` but applies the SVD anyway, so subsequent gate applications operate on a state that is not exactly U S Vᵀ).
- **File:** `stdlib/runtime/mps_rt.c` lines 137-303 (`simple_svd`), specifically lines 171-246.
- **Body:** The Jacobi sweep cap is `100` (line 171). For ill-conditioned 2-site SVDs (e.g., RZ on highly-entangled MPS near max bond), 100 may be insufficient — `mps->last_svd_converged` is set to 0 and the function continues writing U/S/Vᵀ with whatever state the half-converged eigendecomposition holds. The MPS rod ships `mps_total_svd_nonconverged()` and `mps_last_svd_converged()` as observability surfaces, but does NOT make non-convergence a hard error. For a Bell-pair or GHZ circuit this never fires, but for a 50-qubit max-bond=64 simulation it can.
- **Remediation:**
  1. Either escalate the cap (e.g., 1000) for production, or expose a `mps_set_svd_max_sweeps(n)` knob.
  2. Add a fixture circuit (e.g., a brick-wall RZ-rotation circuit at max bond) that exercises the non-convergence path and asserts the resulting `mps_expect_z` deviates from the analytic value by less than a documented bound.
  3. Also: line 252 `if (A_re[i*n+i] < 0.0) negative_clamps++;` clamps negative eigenvalues to 0 — a Hermitian PSD matrix should not have them, so a non-zero count means precision loss. Surface this as an error sentinel from `nuc_mps_gate` itself when it crosses a (currently undefined) threshold.

### MED-LAYER9B-014 — `qsim_measure` divides by `f64_sqrt(norm_sq)` without zero-guard
- **Severity:** Medium (NaN / inf state when measuring a qubit whose conditional probability is zero — e.g., a malformed circuit or a state that has been reduced to all zeros by prior measurements).
- **File:** `stdlib/rods/quantum.nr` lines 497-498.
- **Body:** After collapse, `norm_sq` is the sum of |amp|² for amplitudes consistent with `outcome`. If both `prob(outcome=0)` and `prob(outcome=1)` are zero (impossible in well-formed states, possible after numerical drift in deep circuits with truncation), or if the RNG comparison `f64_lt(r, p0) == 0` selects an outcome whose probability mass was numerically zero, `norm_sq` is 0. Then `norm = 1/sqrt(0) = inf`, and every amplitude is multiplied by inf → state becomes (inf+inf*i, ...) → all subsequent measurements return inf-tainted probs and any cmp-based RNG branch is undefined.
- **Remediation:** Guard `if f64_eq(norm_sq, f64_from_int(0)) == 1 { ... }` and either (a) return a defined error sentinel from `qsim_measure`, or (b) reset the state-vector to |0...0⟩ with a warning. Add a unit test that simulates the failure mode (apply a measurement that should yield |1⟩ with probability 0 due to numerical underflow on a deep circuit).

### MED-LAYER9B-015 — `qsim_dump` prints amplitudes whose |amp|² > 0.1, NOT in canonical basis-state-index order
- **Severity:** Medium (the documented contract says "Print all amplitudes (for debugging small circuits)" but the threshold filters out states with prob between 1e-12 and 0.1, hiding intermediate-magnitude amplitudes).
- **File:** `stdlib/rods/quantum.nr` lines 553-566.
- **Body:** Line 561 filters with threshold = `f64(0, 1)` = 0.1. This prints a 2-qubit Bell state ((1/√2)|00⟩ + (1/√2)|11⟩, each amp² = 0.5) correctly, but a 3-qubit GHZ-like with prob 0.1 per state would barely make the cut, and any amplitude with prob 0.05 (e.g., partially-entangled or after a non-trivial rotation chain) is invisible. Debug surface lies about what's nonzero.
- **Remediation:** Lower the threshold to a small numerical-noise floor (e.g., 1e-10 = `f64(1, -10)`) and additionally print the basis-state index alongside the amplitude. Today only `cx_to_str(amp)` is printed — the index isn't.

### MED-LAYER9B-016 — `nuc_mps_expect_z` env_re/env_im swap aliases the user's caller-allocated scratch
- **Severity:** Medium (correctness of expectation-value contraction depends on a swap pattern that's defensively right but is a code-smell — and the parallel `mps_basis_amplitude` does the same thing).
- **File:** `stdlib/runtime/mps_rt.c` lines 713-716, 775-778.
- **Body:** The contraction uses two scratch buffers and swaps them at each site via a temp pointer. This is fine for a single-threaded contraction, but if any future code path were to read `env_re` mid-contraction (e.g., for a streaming observable), the alias would produce wrong intermediate values. Today no such consumer exists, so this is a Note-to-Medium. The swap is correct.
- **Remediation:** No fix required today; documenting as a maintainer-side note: any future "streaming observable" feature must clone the env buffers before reading.

### MED-LAYER9B-017 — IK `_inverse_6x6` returns 0 (singular) on tolerance < 1e-12 but solver silently breaks the loop
- **Severity:** Medium (the IK 6D solver can return after fewer iterations than the user requested, with no error indicator).
- **File:** `stdlib/runtime/ik_dls_rt.c` lines 670-671 (and the parallel 6D-nullspace path at line 785).
- **Body:** When `_inverse_6x6` returns 0 (numerical singularity), the for-loop breaks via `if (!_inverse_6x6(...)) break;` and the function returns `iter` — the iterations actually performed. Adopters reading the return value can't distinguish "converged at iter N" from "broke early due to singularity". The position-only solver populates `_g_last_singularity` but the 6D solver does NOT — the singularity-metric accessor returns the previous solve's value or the sentinel.
- **Remediation:** Wire `_g_last_singularity` (or a parallel `_g_last_singularity_6d`) updates inside the 6D solver. Or add a return-code mechanism (negative = error, nonneg = iter count) and document.

### LOW-LAYER9B-018 — `tf_is_canonical_frame_id` uses `0 - 1` literal instead of named constant
- **Severity:** Low (cosmetic / consistency).
- **File:** `stdlib/rods/tf.nr` line 138.
- **Body:** `if id == 0 - 1 { return 1; };` — the rod imports `kinematics_frame.nr` indirectly via the typed wrapper section. The kinematics_frame rod ships `kinematics_frame_id_unknown()` returning `0 - 1`. Use that named accessor.
- **Remediation:** `if id == kinematics_frame_id_unknown() { return 1; };`. Same pattern likely shows up elsewhere in `tf.nr`'s typed surface (e.g., line 138).

### LOW-LAYER9B-019 — `quantum.nr` uses `qgate_kind_supported_by_mps(kind)` indirectly but exposes `qgate_*` raw constants without preflight wrappers in qsim itself
- **Severity:** Low (cosmetic / API hygiene — qsim adopters of `qsim_gate1` get no help if they pass a malformed gate matrix).
- **File:** `stdlib/rods/quantum.nr` lines 112-127 (`qsim_gate1`).
- **Body:** Accepts arbitrary 1-qubit matrix entries. A non-unitary matrix produces a non-normalized state, and there's no `qsim_state_norm(sv)` query exposed (the limitations text mentions `qsim_statevec_amplitude` is Phase 2 future work). Adopter mistakes silently corrupt the state.
- **Remediation:** Ship `qsim_state_norm(sv) -> f64_bits` and `qsim_assert_unit(sv, eps_bits) -> i64` Phase 2-style helpers so adopters can preflight after each non-trivial gate sequence.

### LOW-LAYER9B-020 — Tests in `tests/rods/` for in-scope rods are build-only smokes, not correctness tests
- **Severity:** Low → Medium (no functional regression coverage for SE(3), URDF, IK, MPS).
- **Files:** `tests/rods/se3_smoke.nr` (3-line build-only), `tests/rods/urdf_smoke.nr` (only checks empty-state accessors), `tests/rods/ik_dls_smoke.nr` (3-line, no IK actually run), `tests/rods/mps_smoke.nr` (init+free only), `tests/rods/quantum_basic.nr` (X/CNOT/Bell are correctness — only test in scope that's not build-only), `tests/rods/rust_interop.nr` (regex+base64 — but leaks, see CRIT-LAYER9B-002).
- **Body:** Per the doc-headers ("functional URDF parsing requires a string pointer convention which is non-trivial in a single-test-file smoke; correctness coverage is in the direct C unit test"), the rod-level tests delegate to non-existent (or at least undiscovered in the audit scope) "direct C unit tests". A `grep -r "se3_compose" tests/` would reveal whether end-to-end SE(3) coverage exists.
- **Remediation:**
  1. Ship one non-trivial fixture per rod that exercises the actual math:
     - SE(3): compose-then-inverse round-trip → identity within 1e-12.
     - URDF: parse a 2-joint serial chain string + assert axis/origin readback.
     - IK: planar 2-link analytic IK + DLS convergence on a reachable target.
     - MPS: prep Bell state, assert `mps_expect_z(0) == 0`, `mps_prob_basis(0b00) == 0.5`, `mps_prob_basis(0b11) == 0.5`.
  2. The lack of these fixtures is why the URDF default-axis bug (CRIT-LAYER9B-001) survived to v1.0.

### NOTE-LAYER9B-021 — `quantum_rt.c` lives in `stdlib/rods/`, not `stdlib/runtime/`
- **Severity:** Note (consistency).
- **Files:** `stdlib/rods/quantum_rt.c` (this audit's scope hint listed `stdlib/runtime/quantum_rt.c` — that file does not exist).
- **Body:** Every other rod runtime lives in `stdlib/runtime/<name>_rt.c`. Quantum is the lone exception — the `#cfile "quantum_rt.c"` directive in `stdlib/rods/quantum.nr` line 28 paths it inside the rods directory. Build/link works (the `#cfile` directive uses path-relative-to-rod), but maintainers searching `stdlib/runtime/` for the C side will miss it.
- **Remediation:** Move to `stdlib/runtime/quantum_rt.c` and update the `#cfile` directive accordingly. Cross-check `verify.sh` and any tools that grep the runtime directory tree (e.g., `tools/verify_timings.csv`).

### NOTE-LAYER9B-022 — `direct_ffi` effect-pass is a soft warning at build, not a hard error
- **Severity:** Note (per the compiler comments — the path is intentionally Phase 2/4).
- **Files:** `compiler/nucleor_s1_compiler.nr` lines 11202-11226, 33541-33552, 12473-12557.
- **Body:** R4 (G-9) ships `FFI-G9-MISSING-ALLOW-DIRECT-FFI` as a real diagnostic with leaf-effect inference for `extern fn` call sites. The earlier v0.8.26 code path at line 33547 emits a `warning[FFI-DIRECT]` info pass that counts `extern fn` declarations with the comment "Per RFC-0062 G-9 Phase 3 (v1.0): direct `extern fn` calls bypass the safe-code bounds-check insertion that wraps Nucleor index/range operations. Adopter discipline: treat every `extern fn` call site as an unsafe surface. `#[allow(direct_ffi)]` enforcement and bounds-check insertion at call sites are post-v1.0 hardening." So at v1.0 ship, the canonical FFI surfaces enforced via `#[effect(direct_ffi)]` / `#[allow_effect(direct_ffi)]` is real, but the bounds-check insertion is post-v1.0. The audit confirms the effect-system pass is wired (R4 G-9 specialization at line 12553-12557).
- **Remediation:** Treat as a tracked roadmap item (per the comment block, post-v1.0 hardening lifts bounds-check insertion at call sites). No change required for v1.0.

### NOTE-LAYER9B-023 — Rust bridge `regex` crate is the ONLY external Rust dep; no version pin to a security-tracked release
- **Severity:** Note.
- **File:** `stdlib/rods/rust_bridge/Cargo.toml` line 12.
- **Body:** `regex = "1"` resolves to whatever the latest 1.x is at `cargo update` time. Today this is fine (the regex crate is mature), but for reproducibility-critical builds the broad version range allows transitive supply-chain drift.
- **Remediation:** Pin to a specific minor version (e.g., `regex = "1.10"`) and commit the `Cargo.lock` (already present at `stdlib/rods/rust_bridge/Cargo.lock` per the directory listing). Add a `cargo audit` step to the verify pipeline for FFI dependencies.

### NOTE-LAYER9B-024 — `qsim_init` allocates `2^n` complex handles eagerly, ignoring sparsity
- **Severity:** Note (architectural; n=24 ⇒ 16M cx allocations — substantial GC pressure even when state is mostly |0...0⟩).
- **File:** `stdlib/rods/quantum.nr` lines 79-93.
- **Body:** Even at the 24-qubit cap each amplitude is its own heap-allocated `cx_*` handle (a 2-i64 pair). 2²⁴ = 16,777,216 allocations at init; init-loop cost dominates time-to-first-gate. The MPS rod is the answer at scale (and ships a separate cap of 16 for `mps_statevector_max_qubits`), but the qsim path doesn't share amplitude objects across the |0...0⟩ initial states (every zero is a fresh cx_zero).
- **Remediation:** Either intern the global cx_zero / cx_one (only two heap objects shared by all init zero amplitudes) or switch the underlying representation to a flat `double[2*N]` buffer like the MPS rod. The Phase 2 ship plan in `qsim_limitations()` already notes "Phase 2 ships safe statevec readout" — same opportunity to flatten the storage.

---

## Summary

- **Critical:** 2 (URDF default axis wrong; in-tree Rust FFI test leaks).
- **High:** 5 (cap inconsistency across qsim/qsim_graph/trace; sparsity threshold units; SWAP trace double-count; CNOT entanglement false-positive; URDF self-closing parse).
- **Medium:** 10 (qsim_init sentinel ambiguity; SE(3) distance unit-mix; quat log-map sign-flip; IK joint-limit table leak across handles; TF stamp-range refuse vs extrapolate; MPS Jacobi cap; qsim_measure NaN guard; qsim_dump threshold; MPS env-buffer alias note; IK 6D singularity surfacing).
- **Low:** 3 (named-constant hygiene; qsim unitarity preflight; thin smoke tests).
- **Note:** 4 (file-path inconsistency for quantum_rt.c; direct_ffi is post-v1.0 hardening; regex unpinned; eager 2^N allocation).

**No FFI memory unsafety in the rust_bridge crate itself was identified** — the `into_raw` / `from_raw` ownership contract is internally consistent. The unsafety is in the adopter contract (the in-tree test does not honor it) — recorded as CRIT-LAYER9B-002 because the in-tree leak normalizes the bad pattern for downstream copyers.

**No SE(3) round-trip math errors were identified** in the C side (compose∘inverse, exp∘log, slerp ends — all formulas check against the standard Lie-algebra parameterization).

**The MPS SVD path** (`simple_svd` at `mps_rt.c:137-303`) is the highest-risk quantum-correctness surface; see MED-LAYER9B-013. Recommend a numerical-stress fixture before promoting MPS beyond the current ~16-qubit ship cap.

**The IK 6D `_quat_log_map`** (MED-LAYER9B-010) is the highest-risk robotics-correctness surface for adopters using orientation IK on near-π-rotation goals. Easy fix; trace through one short-arc test.

End of pass 1.
