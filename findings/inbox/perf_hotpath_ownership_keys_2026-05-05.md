# P2/R1 hot-path allocation slice - 2026-05-05

## Summary

Ran runtime helper caller attribution against the self-host compiler after syncing to `origin/main` v0.8.185. The largest proven avoidable allocation cluster was ownership metadata key construction:

- Baseline optimized-debug self-host profile: `str_concat=1,255,998`, total tracked allocation `282,680,268 B` (`269 MB`).
- After direct ownership-key construction: `str_concat=805,380`, total tracked allocation `276,295,507 B` (`263 MB`).
- Delta: `-450,618` `str_concat` calls per self-host compile, about `-6.1 MB` tracked allocation.

The shipped fix keeps the same metadata key names but bypasses nested `str_concat("prefix_", name)` -> `own_get_i/own_set_i` -> `str_concat("__oi_", key)` construction. Hot wrappers now construct the final key directly and call the raw lookup/set helpers.

## Attribution evidence

Command shape used for named attribution:

```powershell
.\bin\nucleor.exe build .\compiler\nucleor_s1_compiler.nr -o nuc_profile_p2 --no-link --no-cache
# then link emitted IR with -gcodeview /DEBUG and rerun with:
$env:NUCLEOR_PROFILE='1'
$env:NUCLEOR_PROFILE_CALLERS='1'
$env:NUC_TRACE_ALLOC='1'
.\target\nuc_profile_p2_dbg.exe build .\compiler\nucleor_s1_compiler.nr -o nuc_profile_dbg_child --no-link --no-cache
```

Top baseline `str_concat` call sites:

| rank | caller | calls | share |
| --- | --- | ---: | ---: |
| 1 | `own_get_i+0x31` | 402,370 | 32.0% |
| 2 | `own_get_scope+0x31` | 398,238 | 31.7% |
| 3 | `type_expr+0x10083` | 161,678 | 12.9% |
| 4 | `own_get+0x31` | 39,144 | 3.1% |
| 5 | `own_get_type+0x31` | 28,207 | 2.2% |

Post-fix `str_concat` top sites:

| rank | caller | calls | share |
| --- | --- | ---: | ---: |
| 1 | `own_get_scope+0x31` | 398,238 | 49.4% |
| 2 | `type_expr+0x10083` | 161,678 | 20.1% |
| 3 | `own_get+0x31` | 39,144 | 4.9% |
| 4 | `own_get_type+0x31` | 28,207 | 3.5% |
| 5 | `own_get_ref_target+0x31` | 23,417 | 2.9% |

Interpretation: the first nested layer (`own_get_i+0x31`) is gone from the top table. The remaining `own_get_scope` cost is the one required final key construction per lookup. A later cache attempt was rejected because it caused an `OWN-008` false positive during self-host; do not re-land that shape without a dedicated ownership-cache invariant test.

## Rejected experiments

1. `own_get_scope` last-name cache: rejected. It reduced the apparent allocation path but caused a self-host `OWN-008` false positive (`base` / `p` immutable binding reports in different attempts). The cache interacted with ownership checker state too riskily.
2. `expand_format_macros_with_src` no-macro identifier fast path: rejected. It self-hosted once but failed an official perf-gate sample with `OWN-008` in `priv_mangle_private_fns`. The idea is still plausible, but not safe without a smaller fixture and a proof that source text is byte-preserved across the macro pass.

## Validation

Promoted compiler fixed point:

```text
OK: self-host compiler IR fixed point holds md5=f26490fa833d690dff9981982e2fdde1
OK: bootstrap seed matches current self-host IR md5=f26490fa833d690dff9981982e2fdde1
```

Fresh 3-run perf series after rejecting unsafe experiments:

| run | cold | hot | peak_mem |
| --- | ---: | ---: | ---: |
| 1 | 3.63s | 0.31s | 295 MB |
| 2 | 3.62s | 0.78s | 300 MB |
| 3 | 4.05s | 0.31s | 290 MB |

Median: cold `3.63s`, hot `0.31s`, peak `295 MB`.

## Next candidates

- `own_get_scope` remains the top `str_concat` site. Avoid speculative caching; a safe next step would be a structured ownership side table for scope depths rather than a string-key cache.
- `expand_format_macros_with_src+0xc95` remains the top `str_substring` site. Revisit only with a minimal byte-preservation fixture for non-macro identifiers and multiple self-host/perf samples.
- `str_starts_with` and `str_eq_at` dominate `str_len` calls. A length-accepting variant (`str_eq_at_len` is already present in source-level code) may be useful if mirrored into the hottest call sites.
