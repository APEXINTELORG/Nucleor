# Track Generic Trait-Bound Dispatch - 2026-05-01

Branch: `v06-track-generic-trait-bound-dispatch`
Base after rebase: `origin/main` `e65f1a2` (`v0.5.29`)

## Scope Shipped

This closes the first-pass version of probe finding
`2026-05-01-generic-T-trait-bound-method-dispatch`.

Pre-fix, a generic body such as:

```nucleor
fn get_show<T: Show>(x: T) -> i64 {
    return x.show();
}
```

kept receiver `x` typed as `T` during lower-time kind-8 method dispatch.
`trait_impl_find(trait_impls, "T", "show")` failed, and the fallback emitted
the synthetic runtime helper `vec_show(x)`, which failed later at LLVM/clang
link.

The fix keeps generic trait-bound metadata in the lower-time symbol table and
adds bound-scoped trait-impl lookup entries. For a receiver whose static type is
a generic parameter, kind-8 dispatch checks that parameter's trait bounds and
routes `.method()` to the single concrete impl for that bound method.

## Conservative Boundary

Nucleor still emits one ABI-level generic function body; this ship does not add
full per-call-site monomorphization. Therefore generic trait-bound method
dispatch is accepted only when the bound has exactly one concrete impl for that
method in the program.

If more than one impl is present, the compiler now halts with `TYP-007`:

```text
error[TYP-007]: generic trait-bound method dispatch for `T: Show` method `.show()` is ambiguous.
```

That is intentionally better than silently choosing one impl or falling through
to `vec_<method>`.

## Fixtures Added

- `tests/features/rfc0024_generic_trait_bound_dispatch.nr`
- `tests/err/err_generic_trait_bound_dispatch_ambiguous.nr`

## Validation Evidence

Focused fixture validation against the refreshed tracked binary:

```text
OK envoff-positive-build exit=0
OK envoff-positive-run
OK envoff-ambiguous-negative exit=1
OK envon-positive-build exit=0
OK envon-positive-run
OK envon-ambiguous-negative exit=1
```

Fixed point under the real-time process-tree e-stop:

```text
stage1: OK peak 590 MB / 1000 MB budget, wall 5.502s
stage2: OK peak 622 MB / 1000 MB budget, wall 4.955s
stage3: OK peak 706 MB / 1000 MB budget, wall 6.081s
stage2_sha = stage3_sha = 63A0C674F46D86BC04F2CEB52D1A2C9FB21BB5DB6D883E63123F197128CC09D4
strict-intrin seed refresh: OK peak 675 MB / 1000 MB budget, wall 6.901s
```

Tight memory gates:

```text
self-host:   OK peak 618 MB / 770 MB budget, wall 4.951s
tools-suite: OK peak 523 MB / 580 MB budget, wall 4.594s
```

Drift gate:

```text
OK: tools-suite ABI tables match nucleor_s1_compiler.nr
OK: helper_manifest.toml is up to date
OK: rod_manifest.toml is up to date
OK: RELEASES.md is up to date
```

NUM-024 audit with captured output under a process-tree e-stop:

```text
compiler=0, peak 693 MB / 770 MB, wall 4.635s
tools-suite=0, peak 436 MB / 580 MB, wall 3.526s
```

Full env-off/env-on verify was intentionally not repeated in the inner loop;
this branch used focused fixture, fixed-point, drift, NUM-024, and tight memory
gates to avoid the long sequential validation path while preserving the checks
that cover this change's behavior.

## Rebase Refresh - 2026-05-01

Rebased cleanly onto `origin/main` `e65f1a2` (`v0.5.29`) and validated with
the v0.5.29 process-tree memory wrapper:

```text
NUC_VERIFY_AGENT=parallel1
pwsh tools/run_with_peakmem.ps1 -VerifyArgs "--range 670-697" -EstopMb 1024 -PollMs 1000

PASS: 28
SKIP: 669
PEAKMEM_MB=744
EXIT=0
KILLED=False
LAST_INDEX=697
```

Earlier env-off coverage in the same rebase pass reached `[669/697]` through
the full gate before the wrapper process exited without a summary row. The
`670-697` rerun above completes the missing tail, including
`RFC-0014 max_depth static analysis + runtime wrapper`.

Strict-intrin env-on was checked narrowly on the Track Y fixtures:

```text
NUCLEOR_INT_STRICT_INTRIN=1 --only "test features/rfc0024_generic_trait_bound_dispatch"
PASS: 1, peak 262 MB, killed=False

NUCLEOR_INT_STRICT_INTRIN=1 --only "negative err_generic_trait_bound_dispatch_ambiguous"
PASS: 1, peak 567 MB, killed=False
```
