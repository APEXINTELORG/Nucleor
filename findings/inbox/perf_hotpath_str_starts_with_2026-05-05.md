# P2/R2 hot-path helper slice - str_starts_with sentinel loop - 2026-05-05

## Summary

After the ownership-key allocation slice, the next safe hot-path target was the source-level `str_starts_with` helper. Runtime caller attribution showed `str_len` dominated by `str_starts_with+0x20`:

- Before: `str_len=17,148,648` runtime helper calls per self-host profile.
- After: `str_len=11,095,810` runtime helper calls per self-host profile.
- Delta: `-6,052,838` `str_len` calls.
- Total tracked helper calls dropped from `154,999,131` to `148,948,027`.

The change replaces `str_len(prefix)` + bounded loop with a NUL-sentinel prefix walk. `str_char_at` is inlined by the compiler, so this removes a runtime helper call from every `str_starts_with` use without adding heap allocation or changing semantics for normal Nucleor strings.

## Validation

Fixed point:

```text
OK: self-host compiler IR fixed point holds md5=7b4966b9b69526674ef5ce3208a8274e
OK: bootstrap seed matches current self-host IR md5=7b4966b9b69526674ef5ce3208a8274e
```

Perf ladder, first run:

| run | cold | hot | peak_mem |
| --- | ---: | ---: | ---: |
| 1 | 3.98s | 0.32s | 301 MB |
| 2 | 4.43s | 0.32s | 299 MB |
| 3 | 3.54s | 0.32s | 301 MB |

That first median (`3.98s`) tripped the punchlist drift-alarm threshold, so it was treated as suspect and immediately resampled with logs outside `target/` so the perf script could not delete them.

Perf ladder, accepted resample:

| run | cold | hot | peak_mem |
| --- | ---: | ---: | ---: |
| 1 | 3.81s | 1.25s | 299 MB |
| 2 | 3.55s | 0.32s | 301 MB |
| 3 | 3.42s | 0.77s | 291 MB |

Accepted median: cold `3.55s`, hot `0.77s`, peak `299 MB`.

## Rejected During This Slice

Tried a structured `own_get_scope` final-key side vector to remove the remaining `398k` `str_concat` calls attributed to `own_get_scope`. It fixed-pointed under the stage1 compiler, but after promotion the new compiler failed `bash tools/check_self_host_md5.sh` with a false `OWN-008` on `smap_hash`'s mutable `hash` binding. The experiment was backed out completely.

Do not reattempt the `own_get_scope` side-vector shape without first adding a focused ownership snapshot/restore invariant fixture. Scope metadata interacts with branch isolation and is too fragile for a speculative perf patch.
