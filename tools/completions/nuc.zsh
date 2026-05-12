#compdef nuc nucleor
# nuc.zsh — zsh completion for the Nucleor CLI.
#
# Install:
#   fpath=(/path/to/Nucleor/tools/completions $fpath)
#   autoload -U compinit && compinit

_nuc() {
    local -a commands flags
    commands=(
        'build:Compile to native binary'
        'build-fast:Fast core compile path (ownership + type only)'
        'build-strict:Compile with full strict checker stack'
        'build-shared:Compile a shared library from `pub fn` exports'
        'build-wasm:Compile to WebAssembly'
        'build-ptx:Compile to NVIDIA PTX'
        'run:Compile and run'
        'emit:Emit LLVM IR only'
        'test:Build and run @test / test_* functions'
        'bench:Benchmark repeated runs'
        'perf:Compile-path performance analysis'
        'check:Run all checkers, report diagnostics'
        'audit:Provenance and governance report'
        'policy:Policy compliance check'
        'certify:Compile + produce certification manifest'
        'translate:Parse, validate, and summarize source'
        'summary:Compact module interface card'
        'query:Machine-readable module interface'
        'abi:Inspect import/export ABI for C / Rust interop'
        'evidence:Governance evidence report'
        'impact:Reverse call impact for a function'
        'graph:Source-level call/effect graph'
        'profile:Timed binary execution profile'
        'init:Scaffold a new project'
        'bootstrap:Self-host bootstrap status / corpus report'
        'stage-dump:Dump compiler stage summaries'
        'lock:Write Nucleor.lock'
        'install:Add a path or registry dependency'
        'add:Alias for install (RFC-0019 phase 4 ergonomics)'
        'remove:Alias for install --remove'
        'update:Alias for install --update'
        'publish:Copy a package into a local registry directory'
        'registry:List/search/inspect packages in a local registry'
        'sage:Sage_NS prove / certificate / gap checks'
        'explain:Explain a compiler error code'
        'doc:Render /// doc comments as Markdown (RFC-0029)'
        'fix:Migration linters (--imports / --numeric — RFC-0015 / RFC-0018)'
        'clean:Remove target/ and .nuc_cache/'
        'scram:Alias for clean'
        'zen:The design principles of Nucleor'
        'mco:Mars Climate Orbiter'
        'help:Print full command list'
    )

    flags=(
        '-o[output base name]:name:'
        '--out[output base name]:name:'
        '--emit[keep an artifact]:format:(llvm)'
        '--no-link[stop after writing IR]'
        '--time-passes[print per-phase timings]'
        '--no-cache[disable resolved-source and content-addressed LLVM caches]'
        '--cache-stats[print cache hit/miss counters]'
        '--cache[clean only: remove compilation caches]'
        '--tier[backend tier]:tier:(0 1 2)'
        '--json[machine-readable output]'
        '--sarif[SARIF v2.1.0 diagnostics]'
        '--list[list discovered tests]'
        '--iterations[bench iterations]:n:'
        '--warmup[bench warmup runs]:n:'
        '--c-header[emit C declarations]'
        '--rust-extern[emit Rust unsafe extern declarations]'
        '--exports[inspect pub fn ABI]'
        '--imports[nuc fix: migrate legacy import syntax to use std::]'
        '--numeric[nuc fix: migrate to RFC-0015 narrow-width suffix syntax]'
        '--registry[nuc registry: path to local registry directory]'
    )

    if (( CURRENT == 2 )); then
        _describe 'command' commands
    else
        _arguments $flags '*:source file:_files -g "*.nr"'
    fi
}

compdef _nuc nuc
compdef _nuc nucleor
