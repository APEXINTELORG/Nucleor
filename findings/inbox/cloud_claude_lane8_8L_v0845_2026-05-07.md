# Cloud Lane 8 / Queue 8L — path_utils Linux skip already on main

## Summary

The Windows-only assertion `path_is_absolute("C:/foo") == 1` already
has the Linux gate applied in current `origin/main`. No further patch
required.

## Verification

The gate landed in commit `c1eea2e` (Round-2 follow-on) at lines 22-28
of `tests/runtime/path_utils.nr`:

```
// Drive-letter roots (C:/foo) are only absolute on Windows. POSIX
// hosts treat C:/foo as a relative path whose first component is
// the literal directory "C:". Gate on path_separator() == "\\".
let on_windows: i64 = if str_eq(sep, "\\") == 1 { 1 } else { 0 };
if on_windows == 1 {
    if path_is_absolute("C:/foo") != 1 { fail = fail + 1; print("FAIL is_abs drive (windows)"); };
} else {
    if path_is_absolute("C:/foo") != 0 { fail = fail + 1; print("FAIL is_abs drive (posix)"); };
};
```

The gate uses `path_separator()` rather than a `cfg!`/`#[cfg]` macro
because the runtime helper is the platform oracle the test already
relies on. On POSIX it expects `"C:/foo"` to be reported as relative
(value 0); on Windows absolute (value 1).

In the Round-3 8J verify transcript, this fixture passes without
cascade:

```
$ bash tools/verify.sh --only "test runtime/path_utils"
[...filtered run...] OK    test runtime/path_utils
```

(`tests/runtime/path_utils` is included in the parallel-fixtures bucket
at run-time and contributed 0 failures to the 8J PASS=1292 run.)

## Status

CLOSED — no patch required. The Wave-A R10 fix from c1eea2e covers 8L.
This report exists only to confirm the close.

No follow-on branch.
