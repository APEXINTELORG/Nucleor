# Helper1 Finding: RT Transitive Closure v0838

## Summary

RT-G1 and RT-G3 now have bounded same-file helper-chain enforcement.

The compiler already caught direct `#[no_alloc]` body allocations and one-hop
same-file allocation helpers. This slice adds one additional same-file closure
layer and mirrors the same closure shape for `#[no_panic]`.

Covered now:

- `#[no_alloc]` caller -> helper -> allocator.
- `#[no_panic]` caller -> helper -> panic-prone helper.
- clean same-file helper chains remain accepted.

Still deliberately not claimed:

- cross-module callee traversal.
- fn-pointer, closure, trait, or dynamic dispatch traversal.
- deeper arbitrary call-graph fixed points.
- full AST/IR effect propagation.

## Changed Files

- `compiler/nucleor_s1_compiler.nr`
- `tests/err/err_no_alloc_transitive_two_hop.nr`
- `tests/err/err_no_panic_transitive_same_file.nr`
- `tests/features/rt_transitive_clean_helper_chain_smoke.nr`
- `tools/verify.sh`
- `docs/spec/Nucleor_Error_Codes.md`
- `docs/rfcs/v1_PUNCHLIST.md`

## Validation

```powershell
.\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _helper1_s1_rt_laws_v0838 --no-cache
.\target\_helper1_s1_rt_laws_v0838.exe build tests\err\err_no_alloc_transitive_two_hop.nr -o _rt_no_alloc_two_hop_v0838 --no-cache
.\target\_helper1_s1_rt_laws_v0838.exe build tests\err\err_no_panic_transitive_same_file.nr -o _rt_no_panic_transitive_v0838 --no-cache
.\target\_helper1_s1_rt_laws_v0838.exe build tests\features\rt_transitive_clean_helper_chain_smoke.nr -o _rt_transitive_clean_v0838 --no-cache
.\target\_rt_transitive_clean_v0838.exe
```

Result:

- `err_no_alloc_transitive_two_hop.nr`: PASS, failed with `error[RT-001]`.
- `err_no_panic_transitive_same_file.nr`: PASS, failed with `error[RT-002]`.
- `rt_transitive_clean_helper_chain_smoke.nr`: PASS, built and ran rc=0.

## Residual Risk

This is a bounded source-level scanner, not the final RT effect system. The
remaining closure work should move to AST/IR traversal so cross-module calls,
closures, fn pointers, and trait dispatch cannot escape through spelling or
dispatch shape.
