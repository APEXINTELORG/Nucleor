# Nucleor Architecture

How a `.nr` file becomes an `.exe`, and how the compiler bootstraps from itself.

## Compilation pipeline

```
source.nr
    │
    ▼
┌──────────┐
│  Lexer   │  produces a token stream
└──────────┘
    │
    ▼
┌──────────┐
│  Parser  │  produces an AST (function decls, struct decls, expressions)
└──────────┘
    │
    ▼
┌──────────┐
│  Lower   │  AST → Nucleor IR. This is the canonical form the rest of the
└──────────┘  pipeline operates on.
    │
    ▼
┌──────────┐
│ Optimize │  Algebraic-rewrite optimizer + perf diagnostics. See §Optimizer.
└──────────┘
    │
    ▼
┌──────────┐
│ Emit IR  │  IR → LLVM textual IR (.ll). One module per program.
└──────────┘
    │
    ▼
┌──────────┐
│  clang   │  Compiles the .ll file together with stdlib/runtime/
│          │  nucleor_llvm_rt.c (always linked) and any #cfile sources
│          │  from imported rods. Produces a native .exe / .dll.
└──────────┘
    │
    ▼
   .exe
```

The compiler is one binary (`bin/nucleor.exe`) compiled from one Nucleor source file (`compiler/nucleor_s1_compiler.nr`). All the stages above are functions inside that source.

## Self-hosting

The bootstrap chain:

```
                  ┌──────────────────────────┐
                  │  bin/nucleor.exe         │
                  │  (committed to the repo) │
                  └────────────┬─────────────┘
                               │ builds
                               ▼
       ┌──────────────────────────────────────────┐
       │  compiler/nucleor_s1_compiler.nr (source)│
       └──────────────────────┬───────────────────┘
                              │ produces
                              ▼
                    ┌──────────────────┐
                    │  new nucleor.exe │
                    └──────────────────┘
```

To rebuild the compiler from source:

```
nuc build compiler\nucleor_s1_compiler.nr -o bin\nucleor.exe.new
```

If the resulting binary builds the same `.nr` programs and produces the same outputs, the self-host loop has closed. This is one of the strongest "the language isn't broken" signals available — every change to the compiler must keep the compiler itself buildable.

## Tier system

The compiler emits LLVM IR optimized at one of three tiers, controlled by `--tier`:

| Tier | Backend | Use case |
|---|---|---|
| 0 | LLVM `-O0` (fast)   | Fast dev builds; default for `build-fast` |
| 1 | LLVM `-O1` (default)| Staging |
| 2 | LLVM `-O3` + LTO    | Release |

The default `nuc build` runs at tier 1.

## Optimizer

The IR optimizer in `compiler/nucleor_s1_compiler.nr` runs an algebraic-rewrite pass before LLVM gets the IR. It uses two sources of information:

1. **Built-in arithmetic identities** that always apply:
   - `x + 0 → x`, `0 + x → x`
   - `x * 1 → x`, `1 * x → x`
   - `x * 0 → 0`
   - `x / 1 → x`
   - `x - 0 → x`
   - `-(-x) → x`, `!(!x) → x`

2. **`@law(...)` declarations** on user functions:
   - `identity=N`: removes calls of the form `f(x, N)` or `f(N, x)`.
   - `absorbing=N`: replaces `f(x, N)` with `N`.
   - `idempotent`: rewrites `f(f(x))` to `f(x)`.
   - `involution`: rewrites `f(f(x))` to `x`.
   - `associative`: normalizes call trees to left-leaning form (enables further fusion).
   - `commutative`: enables argument reordering for canonical comparison.
   - `fusion`: rewrites `f(a, f(b, c))` to `f(compose(a, b), c)` for fusion-eligible functions.

Run `nuc perf <file>.nr` to see which laws fired and which performance violations were reported.

## Performance diagnostics

The `@hot` attribute and the `--strict` build mode trigger a separate pass that scans for:

- Heap allocation in `@hot` functions
- String formatting in `@hot` functions
- Indirect dispatch (closure calls, virtual calls) in `@hot` functions
- Heap allocation inside loops (any function)
- Missing `@layout` annotations on hot-path structs
- Missing `@law` annotations on functions with provable algebraic structure

Each diagnostic is one of: `LargeCopy`, `HeapInLoop`, `VirtualDispatchHot`, `RcOverhead`, `StringFormatHot`, `MissingLayout`, `LawMissing`, `HotViolation`.

## Module resolution

When a program does `import "path/to/x.nr"`, the compiler:

1. Resolves the path (relative to working directory).
2. Recursively reads `x.nr` and any of its `import`s, building a dependency graph.
3. Concatenates the unique sources in topological order.
4. Collects all `#cfile`, `#link`, `#libpath` directives from the resolved module set.
5. Compiles the concatenated source as a single LLVM module.
6. At link time, passes every collected `#cfile` source to `clang` together with `nucleor_llvm_rt.c`.

This single-translation-unit approach is intentional — it gives the optimizer and the type checker complete cross-module visibility without the complexity of a separate-compilation linker.

## Caching

A successful build writes per-function LLVM IR to `.nuc_cache/<fn_hash>.ll`. Subsequent builds that don't change a function reuse its cached IR rather than re-emitting it. Pass `--no-cache` to disable.

## What the runtime is not

`nucleor_llvm_rt.c` is the only mandatory C file. It is **not** a libc, a memory allocator, or a managed runtime. It is a thin shim that exposes:

- The few platform syscalls Nucleor programs need (print, file I/O, time, threads, mutex, channels, env)
- The intrinsics Nucleor's IR emits but cannot inline (string concat, vec push/get, hashing, RNG)

There is no garbage collector. Memory ownership follows the rules enforced at compile time by the ownership checker (`OWN-*` codes). `Vec` and `str` use straightforward refcount-and-move semantics.

## Where to look in the source

| You want to understand... | Read... |
|---|---|
| Lexing                   | search `fn lex`, `fn next_token` in `compiler/nucleor_s1_compiler.nr` |
| Parsing                  | search `fn parse_fn`, `fn parse_struct`, `fn parse_expr` |
| AST → IR lowering        | search `fn lower_`, `fn build_ir` |
| Optimizer                | search `fn optimize`, `fn algebraic_rewrite` |
| LLVM emission            | search `fn emit_llvm`, `fn nr_type_to_llvm`, `fn escape_llvm_str` |
| Builtin name mapping     | `fn get_rt_name(name: str) -> str` (line 2004 as of v0.2.129; the long string of `__nucleor_*` mappings runs from there for several hundred lines) |
| The CLI                  | `compiler/nucleor_tools_suite.nr` — subcommand dispatch, `nuc test`, `nuc perf`, etc. |
| The clang invocation     | search `fn link_native_module`, `fn llvm_clang_path` |
