# Helper1 Extern ABI Evidence Sweep v0822

Date: 2026-05-05
Branch: `probe/helper1-extern-abi-evidence-sweep-v0822`
Base: `8b9a3ba0f833ec2b8a59cbf104c3595a7c83b8f2` (`origin/main` after latest main fast-forward)
Mode: append-only findings lane

## Summary

Swept `stdlib/rods/*.nr` `extern fn` declarations against C definitions in
`stdlib/runtime/*.c` and `stdlib/rods/*.c`.

Conservative result:

- Confirmed arity mismatches: 0
- Confirmed return-type ABI mismatches: 11
- Confirmed pointer/value argument ABI mismatches: 0
- False positives caused by parser/regex limitations: 16 candidate rows
- Needs manual review due macro-generated or split declarations: 0 from this pass

The current live issue class is void-returning C functions declared as
`-> i64` in rod externs. The linker will not catch this. If a Nucleor caller
uses the returned value, it reads an undefined return register. Even when
today's internal callers ignore the result, the public rod ABI is wrong.

## Base and Branch

```
git fetch origin
git checkout -b probe/helper1-extern-abi-evidence-sweep-v0822 origin/main
git merge-base HEAD origin/main
```

Merge-base result:

```
8b9a3ba0f833ec2b8a59cbf104c3595a7c83b8f2
```

## Commands Run

Inventory:

```powershell
rg -n "extern fn " stdlib compiler examples tests
rg --files stdlib\runtime stdlib\rods compiler | rg "(\.c$|\.h$|\.nr$|helper_manifest|rod_manifest)"
rg -n "nuc_attn_|nuc_kv_|extern_arity|arity mismatch|ABI parity|helper_manifest" findings docs stdlib\rods stdlib\runtime tools -g "*.md" -g "*.nr" -g "*.c" -g "*.sh" -g "*.ps1" -g "*.toml"
```

Mechanical candidate screen:

```powershell
# Inline PowerShell screen, no Python helpers:
# - Accumulated multiline `extern fn ...;` records from stdlib/rods/*.nr.
# - Accumulated C function definitions from stdlib/runtime/*.c and stdlib/rods/*.c.
# - Compared symbol name, parameter count, and void/non-void return shape.
# - Then manually reviewed every non-match candidate with targeted rg/Get-Content.
```

Targeted evidence checks:

```powershell
rg -n "nuc_dyn_cartesian_impedance_6d|nuc_pnp_solve" stdlib\rods\dynamics.nr stdlib\runtime\dynamics_rt.c stdlib\rods\pnp.nr stdlib\runtime\pnp_rt.c
rg -n "nuc_gnn_gatv2_adam_step|nuc_gnn_gatv2_zero_grad|nuc_gnn_graph_free" stdlib\rods\gnn.nr stdlib\runtime\gnn_rt.c
rg -n "nuc_nn_adam_step_dense|nuc_nn_adam_step_logits|nuc_nn_adam_step_logits_no_tick|nuc_nn_adam_tick|nuc_nn_dense_set_cache|nuc_nn_dense_zero_grad|nuc_nn_lbfgs_step_dense|nuc_nn_reset_rng" stdlib\rods\nn.nr stdlib\runtime\nn_rt.c
rg -n "nuc_decompress_lz77|nuc_http_get|nuc_tok_decode|rods_complex_to_str|rods_i64_to_str|rods_io_read_line|rods_io_read_n_bytes|rods_io_run_capture|rods_os_getcwd|rods_os_getenv|rods_py_call_str|rods_py_eval|rods_time_format_ms" stdlib\rods stdlib\runtime compiler docs\rfcs\helper_manifest.toml
```

Mechanical screen output from the reliable candidate pass:

```text
externs=1617 cdefs=1762 compared_rows=1688
arity-mismatch=2
match=1661
needs-manual-no-c-match=14
return-mismatch=11
```

The 2 arity candidates and 14 no-C-match candidates were manually checked and
classified as false positives below.

## Counts By Classification

| Classification | Count | Notes |
|---|---:|---|
| Confirmed arity mismatch | 0 | `attention2`, `bayesian`, and `kv_cache` prior bug classes now match on current main. |
| Confirmed return-type ABI mismatch | 11 | All are C `void` definitions declared as Nucleor `-> i64`. |
| Confirmed pointer/value argument ABI mismatch | 0 | No confirmed pointer/value arg mismatch surfaced in reviewed candidates. |
| False positive: parser/regex limitation | 16 | 2 arity false positives plus 14 no-C-match false positives. |
| Needs manual review: macro/split C signature | 0 | No remaining candidate required this classification after targeted evidence checks. |

## Confirmed Issues

### GNN rod: C void declared as `-> i64`

| Symbol | Rod declaration | C definition | Issue |
|---|---|---|---|
| `nuc_gnn_graph_free` | `stdlib/rods/gnn.nr:13` `-> i64` | `stdlib/runtime/gnn_rt.c:64` `void` | Return register undefined if used. |
| `nuc_gnn_gatv2_adam_step` | `stdlib/rods/gnn.nr:21` `-> i64` | `stdlib/runtime/gnn_rt.c:358` `void` | Mutating optimizer step has no C return. |
| `nuc_gnn_gatv2_zero_grad` | `stdlib/rods/gnn.nr:22` `-> i64` | `stdlib/runtime/gnn_rt.c:405` `void` | Mutating zero-grad has no C return. |

The public wrappers also return these extern results:

- `stdlib/rods/gnn.nr:44` `fn gnn_graph_free(...) -> i64 { return nuc_gnn_graph_free(...); }`
- `stdlib/rods/gnn.nr:50` `fn gnn_gatv2_adam_step(...) -> i64 { return nuc_gnn_gatv2_adam_step(...); }`
- `stdlib/rods/gnn.nr:51` `fn gnn_gatv2_zero_grad(...) -> i64 { return nuc_gnn_gatv2_zero_grad(...); }`

### NN rod: C void declared as `-> i64`

| Symbol | Rod declaration | C definition | Issue |
|---|---|---|---|
| `nuc_nn_reset_rng` | `stdlib/rods/nn.nr:53` `-> i64` | `stdlib/runtime/nn_rt.c:54` `void` | Reset command has no C return. |
| `nuc_nn_dense_zero_grad` | `stdlib/rods/nn.nr:17` `-> i64` | `stdlib/runtime/nn_rt.c:113` `void` | Mutating zero-grad has no C return. |
| `nuc_nn_dense_set_cache` | `stdlib/rods/nn.nr:18` `-> i64` | `stdlib/runtime/nn_rt.c:120` `void` | Mutating cache setter has no C return. |
| `nuc_nn_adam_step_dense` | `stdlib/rods/nn.nr:31` `-> i64` | `stdlib/runtime/nn_rt.c:232` `void` | Mutating optimizer step has no C return. |
| `nuc_nn_adam_step_logits` | `stdlib/rods/nn.nr:32` `-> i64` | `stdlib/runtime/nn_rt.c:263` `void` | Mutating optimizer step has no C return. |
| `nuc_nn_adam_tick` | `stdlib/rods/nn.nr:33` `-> i64` | `stdlib/runtime/nn_rt.c:390` `void` | Tick command has no C return. |
| `nuc_nn_adam_step_logits_no_tick` | `stdlib/rods/nn.nr:35` `-> i64` | `stdlib/runtime/nn_rt.c:427` `void` | Mutating optimizer step has no C return. |
| `nuc_nn_lbfgs_step_dense` | `stdlib/rods/nn.nr:50` `-> i64` | `stdlib/runtime/nn_rt.c:716` `void` | Mutating optimizer step has no C return. |

Some internal calls currently use these as statements, so those call sites do
not consume the bogus value. The extern ABI is still wrong and the public
surface invites users to consume undefined results.

## False-Positive Classes Found

### 1. Inline C comments inside parameter lists

The first mechanical screen flagged these as arity mismatches:

- `nuc_dyn_cartesian_impedance_6d`
- `nuc_pnp_solve`

Manual check shows both match.

Evidence:

- `stdlib/rods/dynamics.nr:119` declares 14 args.
- `stdlib/runtime/dynamics_rt.c:827` defines the same 14 args.
- `stdlib/rods/pnp.nr:39` declares 10 args.
- `stdlib/runtime/pnp_rt.c:103` defines the same 10 args.

Cause: regex counting tripped on comments and split formatting in C parameter
lists, especially the `K_ptr` inline comment in `dynamics_rt.c`.

### 2. Pointer-return C functions without whitespace between `*` and name

The initial C regex missed valid definitions like:

- `const char *nuc_decompress_lz77(...)` at `stdlib/runtime/compress_rt.c:104`
- `const char *nuc_http_get(...)` at `stdlib/runtime/socket_rt.c:140`
- `const char *nuc_tok_decode(...)` at `stdlib/runtime/tokenizer_rt.c:177`
- `const char *rods_complex_to_str(...)` at `stdlib/rods/complex_rt.c:236`
- `const char *rods_io_read_line(void)` at `stdlib/rods/io_rt.c:6`
- `const char *rods_os_getenv(...)` at `stdlib/rods/os_rt.c:13`
- `const char *rods_py_eval(...)` at `stdlib/rods/python_rt.c:139`
- `const char *rods_time_format_ms(...)` at `stdlib/rods/time_rt.c:38`

These are not missing C definitions. They are string-return ABI matches for
Nucleor `-> str` externs.

### 3. Function-call lines can look like definitions to naive regex

A too-broad parser that accepts `;` as well as `{` after a C parameter list can
misclassify call sites such as `return rods_complex_new(...)` as definitions.
The report counts above do not treat those as confirmed findings.

## Recommended Next Implementation Lanes

1. Fix the 11 confirmed void-vs-i64 externs.
   Smallest clean patch: change the Nucleor extern declarations and public
   wrappers for command-like mutation/free functions to return `void`, then
   update any caller that currently returns the value. If preserving a status
   return is desired, add C shim wrappers that return `long long 0` and keep
   the public Nucleor API explicitly status-returning.

2. Add a real rod-vs-C ABI parity gate.
   The repeated ML-1, bayesian, kv-cache, and now NN/GNN findings are the same
   class. A gate should parse each `#cfile` unit for symbol arity and return
   category, then compare against rod `extern fn` declarations. It should
   understand C pointer-return spellings (`char *name`, `char* name`) and strip
   comments before parameter counting.

3. Add targeted smoke fixtures after the ABI fixes.
   The minimum fixtures should call `gnn_graph_free`, `gnn_gatv2_zero_grad`,
   `nuc_nn_dense_zero_grad`, `nuc_nn_adam_tick`, and `nuc_nn_reset_rng` through
   their rod surfaces. The smoke should prove the call executes, not merely
   build/link.

## Validation

Final branch validation:

```powershell
git diff --check
git status --short
```

Results:

```text
git diff --check: PASS
git status --short --branch: only this report is changed before commit
```
