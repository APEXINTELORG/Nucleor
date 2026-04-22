# Nucleor Test Suite

Each `.nr` file in this tree is a self-contained, runnable test program.
Convention: print `OK <name>` on success or `FAIL <name>: <reason>` on
failure, then return 0 on overall pass and a non-zero code on failure.

## Running

The Nucleor compiler has a built-in test runner:

```
nuc test tests/
```

Or to compile and run a single test:

```
nuc build tests/lang/arith.nr -o arith
./target/arith.exe
```

## Layout

| Directory | Coverage |
|---|---|
| `lang/`     | Core language: arithmetic, strings, vec, structs, control flow, closures, enums, imports |
| `attrs/`    | V2 attributes: `@hot`, `@law`, `@const_fn`, `@layout` |
| `runtime/`  | Runtime primitives: I/O, files, time |
| `rods/`     | Stdlib rods: bitwise, complex, quantum, json, regex, base64 |
| `err/`      | Negative tests — programs that *should* produce a specific compiler error |

## Negative tests (`err/`)

Files in `err/` are not built by the standard runner — they are expected
to fail at compile time with a specific error code. The first line of each
file documents the expected error (e.g. `// EXPECT: NR031 type mismatch`).
Run them via:

```
nuc check tests/err/<filename> --json
```

and verify the diagnostics match the `EXPECT:` annotation.
