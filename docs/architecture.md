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
│ Optimize │  Built-in algebraic folds + perf diagnostics. See §Optimizer.
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

## Optimizer

The IR optimizer in `compiler/nucleor_s1_compiler.nr` runs before LLVM
gets the IR. Today it applies built-in arithmetic identities and exposes a
metadata-only `@law(...)` pass for the algebraic-laws roadmap.

1. **Built-in arithmetic identities** that always apply:
   - `x + 0 → x`, `0 + x → x`
   - `x * 1 → x`, `1 * x → x`
   - `x * 0 → 0`
   - `x / 1 → x`
   - `x - 0 → x`
   - `-(-x) → x`, `!(!x) → x`

2. **`@law(...)` declarations** on user functions:
   - Lex-time capture and audit/info surfacing are implemented.
   - The optimizer has a metadata-only law pass scaffold.
   - User-law-driven call-site rewrites, generated law property tests, and
     SMT proof obligations are tracked for later RFC-0031 phases.

Run `nuc perf <file>.nr` to see optimizer/performance diagnostics. Treat
`@law(...)` as documentation and audit metadata until the tracked
Phase 2/3 algebraic-laws work lands.

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

A successful build writes cache and diagnostic artifacts in two
places:

- **Project cache (`.nuc_cache/`)** - module-graph manifests
  (`modgraph_<hash>.{manifest,resolved,max_depth}`) and per-output
  native-link logs (`clang_link.<artifact>.log`). The link logs capture
  clang's exit code and stderr for the link step.
- **Target cache (`target/.nuc_cache_v2/`)** - content-addressed LLVM
  IR cache entries. Each entry is grouped by hash prefix and contains
  the cached `.ll` plus metadata (`meta.json`) describing the source,
  canonical cache flags, compiler version, hash, and timestamp.
- **Native-link cache (`target/.nuc_native_cache/`)** - cached native
  executables keyed from the generated IR and link inputs when native
  linking is enabled.

Subsequent builds that do not change a source or the relevant cache
flags can reuse these artifacts rather than re-emitting and relinking.
Pass `--no-cache` to disable the IR/native cache path.

R13-D6 Phase 1 (v0.8.281, audit 2026-05-05): pre-v0.8.281 this
section described the v0.2.x `.nuc_cache/<fn_hash>.ll` layout. Current
code uses `target/.nuc_cache_v2/` for IR cache entries while keeping
module-graph and link-log diagnostics under `.nuc_cache/`.

## What the runtime is not

`nucleor_llvm_rt.c` is the only mandatory C file. It is **not** a libc, a memory allocator, or a managed runtime. It is a thin shim that exposes:

- The few platform syscalls Nucleor programs need (print, file I/O, time, threads, mutex, channels, env)
- The intrinsics Nucleor's IR emits but cannot inline (string concat, vec push/get, hashing, RNG)

There is no garbage collector. Memory ownership follows the rules enforced at compile time by the ownership checker (`OWN-*` codes). `Vec` and `str` use straightforward refcount-and-move semantics.

## Where to look in the source

| You want to understand... | Read... |
|---|---|
| Lexing                   | search `fn lex` in `compiler/nucleor_s1_compiler.nr` |
| Parsing                  | search `fn parse_fn_decl`, `fn parse_struct_decl`, `fn parse_expr` |
| AST → IR lowering        | search `fn lower_fn`, `fn lower_stmt`, `fn lower_expr` |
| Optimizer                | search `fn opt_fn`, `fn opt_fold_block` (constant folding / algebraic), `fn opt_cse_block` (CSE), `fn opt_dce_block` (DCE), `fn opt_prop_block` (copy prop), `fn opt_dead_store_block` |
| LLVM emission            | search `fn emit_fn`, `fn emit_inst`, `fn emit_externs`, `fn nr_type_to_llvm`, `fn escape_llvm_str` |
| Builtin name mapping     | `fn get_rt_name(name: str) -> str` (search for the function declaration; the long string of `__nucleor_*` mappings runs from there for several hundred lines). |
| The CLI                  | `compiler/nucleor_tools_suite.nr` — subcommand dispatch, `nuc test`, `nuc perf`, etc. |
| The clang invocation     | search `fn link_native_module`, `fn llvm_clang_path` |
