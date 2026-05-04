# P1 perf drift alarm - 2026-05-03

## Summary

P1 fired after syncing `probe/exploration` to current `origin/main` and applying the P3 host-load snapshot patch. The fresh punchlist target is cold `< 4.0s`, with a P1 alarm at median cold `>= 3.95s`. The initial three-sample median was `5.00s`; after the direct existing-IR isolated-link mitigation and full validation, the final three-sample median is back in the 3-second regime at `3.32s`.

## Perf gate samples

| sample | cold | hot | peak_mem | host note |
| --- | ---: | ---: | ---: | --- |
| 1 | 5.08s | 0.55s | 300 MB | CPU 14% -> 2%; top cumulative CPU included `WmiPrvSE`, `MsMpEng`, `System`, `explorer` |
| 2 | 4.94s | 0.56s | 301 MB | CPU 9% -> 4%; same low host-load shape |
| 3 | 5.00s | 0.55s | 301 MB | CPU 8% -> 2%; same low host-load shape |

Initial median: cold `5.00s`, hot `0.55s`, peak `301 MB`.

## Recovery validation

After the `link_existing_native_module` mitigation and regenerated `bin/nucleor.exe` / `bootstrap/nucleor_s1_seed.ll`, the final P1 samples were:

| sample | cold | hot | peak_mem |
| --- | ---: | ---: | ---: |
| 1 | 3.28s | 0.41s | 300 MB |
| 2 | 3.32s | 0.39s | 301 MB |
| 3 | 3.42s | 0.39s | 300 MB |

Final median: cold `3.32s`, hot `0.39s`, peak `300 MB`.

Additional validation:

- `bash tools/check_compiler_drift.sh`: pass.
- `NUC_VERIFY_AGENT=probe bash tools/verify.sh`: `808 pass / 2 skip / 0 fail`.
- Verify self-host budget line: `compiler/nucleor_s1_compiler.nr peak 272 MB / 770 MB e-stop, wall 3.208s`.

## Five most recent commits at alarm time

```text
ecf41c2f docs: refresh parallel-agent punchlist post-v0.7.13 + probe-perf-merge
de8207ac Merge remote-tracking branch 'origin/probe/exploration'
4a6b0454 docs: V2 frontier roadmap + drift restoration RFCs (17 RFCs + 2 specs)
4a7c56e6 merge: sync probe with origin main v0.7.13 and regain perf
6bfb1309 v0.7.13: defensive halt - trait alias `trait Foo = Bar;` (RFC 1733)
```

## Compiler lines changed in this probe attempt

These are attempted mitigation lines, not proof of original causality:

- `compiler/nucleor_s1_compiler.nr:25806` changes `link_existing_native_module` to accept `native_key_hint`.
- `compiler/nucleor_s1_compiler.nr:25806-25880` links the already-emitted isolated child `.ll` directly instead of reading it into the parent and rewriting the same IR before clang.
- `compiler/nucleor_s1_compiler.nr:27164-27177` computes a native cache hint in `compile_file_mode_native_isolated` and passes it to the direct existing-IR linker.

`origin/main` at `ecf41c2f` does not itself add a compiler source diff on top of the merged probe work; this file diff is local probe mitigation.

## Hot-path caller attribution

Command shape:

```powershell
$env:NUCLEOR_PROFILE_CALLERS='1'
Remove-Item -Recurse -Force .nuc_cache,target -ErrorAction SilentlyContinue
.\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o caller_profile_probe --no-link --no-cache *> caller_profile_probe.out
```

Top helper totals from the self-host no-link/no-cache caller profile:

- `str_concat`: `2,495,896 total`
  - `00007FF68721139E`: `1,308,354` (`52.4%`)
  - `00007FF6872A86C1`: `378,581` (`15.2%`)
  - `00007FF6872A8E51`: `374,713` (`15.0%`)
  - `00007FF6872D1043`: `158,614` (`6.4%`)
  - `00007FF6872A8501`: `36,904` (`1.5%`)
- `str_substring`: `473,031 total`
  - `00007FF68734BD25`: `104,011` (`22.0%`)
  - `00007FF68732D7E2`: `104,011` (`22.0%`)
  - `00007FF687213E51`: `104,011` (`22.0%`)
  - `00007FF68735A5E8`: `32,596` (`6.9%`)
  - `00007FF6872DFE41`: `32,596` (`6.9%`)
- `sym_get`: not emitted by the current runtime helper caller-attribution output.

## Current read

The direct existing-IR link mitigation removes one obvious parent-side 10 MB IR read/write path in isolated native mode and restores the fresh `< 4.0s` cold target in the final three-sample P1 run. Next work should use the caller-attribution counts to attack the top `str_concat` / `str_substring` sites and should keep the new P3 host snapshots in every perf gate so future cold-time variance is attributable instead of guessed.
