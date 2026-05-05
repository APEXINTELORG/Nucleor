# Self-Host Integrity

The self-host compiler has two bootstrap invariants:

1. The host compiler build of `compiler/nucleor_s1_compiler.nr` must emit the same LLVM IR as the compiler built from that output.
2. The resulting fixed-point IR must match `bootstrap/nucleor_s1_seed.ll`.

Run the focused gate:

```sh
bash tools/check_self_host_md5.sh
```

The script builds:

- `target/_self_host_md5_stage1[.exe]` from `bin/nucleor[.exe]`
- `target/_self_host_md5_stage2[.exe]` from the stage1 compiler

It compares the stage1 and stage2 `.ll` files by `md5sum`, then compares the stage2 `.ll` with the committed bootstrap seed. Any mismatch is a ship blocker because it means either the self-host compiler is not fixed-point or the committed seed is stale.

`tools/verify_fast.sh` and `tools/verify.sh` both run this as `T1.8 self-host compiler IR fixed point`. The older `T1.7 bootstrap seed matches current compiler` check stays in place as a cheap single-pass seed freshness check.

For diagnostics, preserve the generated stage artifacts:

```sh
NUCLEOR_SELF_HOST_KEEP=1 bash tools/check_self_host_md5.sh
```

To prove the seed-mismatch path without touching the committed seed, pass a copied seed path:

```sh
cp bootstrap/nucleor_s1_seed.ll target/_seed_corrupt.ll
printf '\n; corrupt\n' >> target/_seed_corrupt.ll
bash tools/check_self_host_md5.sh --seed target/_seed_corrupt.ll
```

That command must fail with `FAIL: bootstrap seed is stale relative to stage2 compiler IR`.
