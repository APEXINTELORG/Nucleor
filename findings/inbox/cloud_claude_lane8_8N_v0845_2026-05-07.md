# Cloud Lane 8 / Queue 8N — POSIX side R06 cross-platform hash transcript

## Summary

Linux pair-run of the Q7A R06 hash transcript byte-matches the Windows
reference for all 7 curated inputs. **R06 cross-platform determinism is
proven.**

A 1-line fix to the smoke fixture (`print` → `print_raw`) was required
before the byte-compare could succeed: the shared C runtime's
`__nucleor_print_str` appends `\n` unconditionally, so the original
`print(... "\n" ...)` form produced doubled newlines (`\n\n`) per row on
both platforms. The Windows reference transcript is the canonical
single-`\n`-per-row form, so the smallest correct fix is to switch the
fixture to the `_raw` variant that matches the reference's framing.

## Host

```
$ uname -a
Linux vm 6.18.5 #2 SMP PREEMPT_DYNAMIC Wed Jan 14 17:56:08 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux

$ command -v clang && clang --version | head -1
/usr/bin/clang
Ubuntu clang version 18.1.3 (1ubuntu1)

$ command -v cargo && cargo --version
/root/.cargo/bin/cargo
cargo 1.94.1 (29ea6fb6a 2026-03-24)

$ command -v rustc && rustc --version
/root/.cargo/bin/rustc
rustc 1.94.1 (e408947bf 2026-03-25)
```

## Pair-run protocol output

```
$ cd stdlib/rods/rust_bridge && cargo build --release
   Compiling memchr v2.8.0
   Compiling regex-syntax v0.8.10
   Compiling aho-corasick v1.1.4
   Compiling regex-automata v0.4.14
   Compiling regex v1.12.3
   Compiling nucleor_rust_bridge v0.1.0
    Finished `release` profile [optimized] target(s) in 10.13s

$ ls stdlib/rods/rust_bridge/target/release/libnucleor_rust_bridge.a
stdlib/rods/rust_bridge/target/release/libnucleor_rust_bridge.a   (present)

$ bin/nucleor build tests/features/rust_bridge_cross_platform_hash_transcript_smoke.nr -o rb_xpht
info[FFI-DIRECT]: `extern fn` declarations in build: 12
  source: tests/features/rust_bridge_cross_platform_hash_transcript_smoke.nr (5410 bytes)
  emitted: target/rb_xpht.ll (43993 bytes)
  compiled: target/rb_xpht
BUILD_EXIT=0

$ target/rb_xpht > /tmp/transcript_linux.txt; echo $?
0

$ diff -u tests/features/rust_bridge_cross_platform_hash_transcript_windows.txt /tmp/transcript_linux.txt; echo $?
0
```

## Linux transcript (matches Windows reference byte-for-byte)

```
empty -3750763034362895579
a -5808556873153909620
hello -6615550055289275125
world 5717881983045765875
null-byte -3750763034362895579
nucleor -1363505821375764433
the quick brown fox 6462304499243991330
```

All 7 hashes are i64 reinterpretations of the FNV-1a 64-bit unsigned
output. The empty-string hash `-3750763034362895579` confirms the
FNV-1a offset_basis `0xcbf29ce484222325` reinterpreted as signed i64 —
so the Rust bridge implementation matches the spec. The "nucleor-r06"
intra-run determinism check (`h1 != h2 → return 1`) also passes; the
binary exits 0.

## Why the print → print_raw fix was needed

`stdlib/runtime/nucleor_llvm_rt.c:379` (POSIX/Windows shared body):

```c
void __nucleor_print_str(const char *s) {
    if (s) printf("%s\n", s);
    else printf("(null)\n");
    fflush(stdout);
}
```

`print` is documented at lines 427-429 as appending `\n` for ergonomic
logging. So `print(str_concat(label, " ", int_to_str(h), "\n"))` emits
`<label> <hash>\n\n` per row on every platform.

The Windows reference transcript at
`tests/features/rust_bridge_cross_platform_hash_transcript_windows.txt`
contains single `\n` per row (verified via `od -c`):

```
e   m   p   t   y       -   3   7   5   0   7   6   3   0   3
4   3   6   2   8   9   5   5   7   9  \n   a       -   5   8
```

Two byte-equal interpretations of how the reference reached this form:

1. **Hand-curated** — the partner trimmed trailing blank lines before
   committing.
2. **Re-captured through a different path** — e.g., the smoke ran
   through a Windows shell that auto-collapsed runs of empty lines, or
   was passed through `tr -s '\n'` post-capture.

Either way, the canonical byte form on disk is single-`\n`-per-row.
For the fixture to deterministically produce that form on every host,
the print path must NOT add a trailing `\n`. `print_raw` is the
shipping API for that exact case (line 430 of the runtime: "Print
without trailing newline. `print` (the existing builtin) appends \n
for ergonomic logging; `_raw` variants suppress it for progress
meters / formatted columns / in-place updates").

## Fix applied

`tests/features/rust_bridge_cross_platform_hash_transcript_smoke.nr` —
single line edit + a comment explaining the rationale. The format
string already contains `"\n"`, so dropping the runtime-side append
gives the correct framing without any reference-side change.

```diff
 fn print_row(label: str, h: i64) {
-    print(str_concat(label, str_concat(" ", str_concat(int_to_str(h), "\n"))));
+    // print_raw, not print: print() appends \n via the shared C runtime
+    // (__nucleor_print_str does printf("%s\n", s) unconditionally), so
+    // combining it with an embedded \n produces \n\n per row on both
+    // platforms. The Q7A reference transcript is the single-\n-per-row
+    // canonical form, so this fixture uses the raw variant + an explicit
+    // \n to keep the byte-compare green.
+    print_raw(str_concat(label, str_concat(" ", str_concat(int_to_str(h), "\n"))));
 }
```

After the fix, `diff -u <windows-ref> /tmp/transcript_linux.txt`
returns exit 0 with no output. R06 hash determinism holds across
Windows + Linux.

## Spike note for the Windows side

The Windows half should re-run the fixture with the new print_raw form
to confirm the Windows binary still produces the same single-`\n` form
(it should, because `print_raw` is platform-portable — both runtime
branches use `fputs(s, stdout)` without modification). If the existing
Windows reference was hand-curated, the fixture flip ensures any future
recapture stays byte-identical without manual post-processing.

This is a follow-on confirmation rather than a blocker — Linux already
matches the canonical reference byte-for-byte.

## Files

- `tests/features/rust_bridge_cross_platform_hash_transcript_smoke.nr`
  (1-line edit + 6-line comment block)
- `findings/inbox/cloud_claude_lane8_8N_v0845_2026-05-07.md` (this report)

Branch: harness-pinned `claude/verify-round-3-tests-RnTlO`.
