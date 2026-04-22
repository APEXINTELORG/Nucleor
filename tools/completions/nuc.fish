# nuc.fish — fish completion for the Nucleor CLI.
#
# Install:
#   cp /path/to/Nucleor_OSS/tools/completions/nuc.fish ~/.config/fish/completions/

set -l nuc_commands build build-fast build-strict build-shared build-wasm build-ptx \
                    run emit test bench perf check audit policy certify translate \
                    summary query graph impact abi evidence \
                    bootstrap stage-dump init lock install publish registry profile sage \
                    explain help clean scram zen mco

# Subcommands at first position
complete -c nuc -n '__fish_use_subcommand' -a build         -d 'Compile to native binary'
complete -c nuc -n '__fish_use_subcommand' -a build-fast    -d 'Fast core compile path'
complete -c nuc -n '__fish_use_subcommand' -a build-strict  -d 'Full strict checker stack'
complete -c nuc -n '__fish_use_subcommand' -a build-shared  -d 'Compile a shared library'
complete -c nuc -n '__fish_use_subcommand' -a build-wasm    -d 'Compile to WebAssembly'
complete -c nuc -n '__fish_use_subcommand' -a build-ptx     -d 'Compile to NVIDIA PTX'
complete -c nuc -n '__fish_use_subcommand' -a run           -d 'Compile and run'
complete -c nuc -n '__fish_use_subcommand' -a emit          -d 'Emit LLVM IR only'
complete -c nuc -n '__fish_use_subcommand' -a test          -d 'Build and run tests'
complete -c nuc -n '__fish_use_subcommand' -a bench         -d 'Benchmark repeated runs'
complete -c nuc -n '__fish_use_subcommand' -a perf          -d 'Performance analysis'
complete -c nuc -n '__fish_use_subcommand' -a check         -d 'Run all checkers'
complete -c nuc -n '__fish_use_subcommand' -a audit         -d 'Governance report'
complete -c nuc -n '__fish_use_subcommand' -a policy        -d 'Policy compliance'
complete -c nuc -n '__fish_use_subcommand' -a certify       -d 'Certification manifest'
complete -c nuc -n '__fish_use_subcommand' -a translate     -d 'Parse and summarize'
complete -c nuc -n '__fish_use_subcommand' -a summary       -d 'Module interface card'
complete -c nuc -n '__fish_use_subcommand' -a query         -d 'Machine-readable interface'
complete -c nuc -n '__fish_use_subcommand' -a abi           -d 'Interop ABI'
complete -c nuc -n '__fish_use_subcommand' -a evidence      -d 'Evidence report'
complete -c nuc -n '__fish_use_subcommand' -a impact        -d 'Reverse call impact'
complete -c nuc -n '__fish_use_subcommand' -a graph         -d 'Call/effect graph'
complete -c nuc -n '__fish_use_subcommand' -a profile       -d 'Execution profile'
complete -c nuc -n '__fish_use_subcommand' -a init          -d 'Scaffold project'
complete -c nuc -n '__fish_use_subcommand' -a bootstrap     -d 'Self-host status'
complete -c nuc -n '__fish_use_subcommand' -a stage-dump    -d 'Compiler stage dump'
complete -c nuc -n '__fish_use_subcommand' -a lock          -d 'Write Nucleor.lock'
complete -c nuc -n '__fish_use_subcommand' -a install       -d 'Add a dependency'
complete -c nuc -n '__fish_use_subcommand' -a publish       -d 'Publish to registry'
complete -c nuc -n '__fish_use_subcommand' -a registry      -d 'Inspect registry'
complete -c nuc -n '__fish_use_subcommand' -a sage          -d 'Sage_NS proof checks'
complete -c nuc -n '__fish_use_subcommand' -a explain       -d 'Explain error code'
complete -c nuc -n '__fish_use_subcommand' -a help          -d 'Print help'
complete -c nuc -n '__fish_use_subcommand' -a clean         -d 'Remove build artifacts'
complete -c nuc -n '__fish_use_subcommand' -a scram         -d 'Alias for clean'
complete -c nuc -n '__fish_use_subcommand' -a zen           -d 'Design principles'
complete -c nuc -n '__fish_use_subcommand' -a mco           -d 'Mars Climate Orbiter blurb'

# Flags
complete -c nuc -s o -l out         -r -d 'Output base name'
complete -c nuc      -l emit        -x -a 'llvm' -d 'Keep IR artifact'
complete -c nuc      -l no-link     -d 'Stop after IR'
complete -c nuc      -l time-passes -d 'Per-phase timings'
complete -c nuc      -l no-cache    -d 'Disable LLVM cache'
complete -c nuc      -l tier        -x -a '0 1 2' -d 'Backend tier'
complete -c nuc      -l json        -d 'Machine-readable output'
complete -c nuc      -l sarif       -d 'SARIF v2.1.0 diagnostics'
complete -c nuc      -l list        -d 'List tests, do not run'
complete -c nuc      -l iterations  -x -d 'Bench iterations'
complete -c nuc      -l warmup      -x -d 'Bench warmup runs'
complete -c nuc      -l c-header    -d 'Emit C declarations'
complete -c nuc      -l rust-extern -d 'Emit Rust extern decls'
complete -c nuc      -l exports     -d 'Inspect pub fn ABI'

# Source file completion
complete -c nuc -n '__fish_seen_subcommand_from build build-fast build-strict build-shared build-wasm build-ptx run emit test bench perf check audit policy certify translate summary query graph impact abi evidence' -F

# Mirror for nucleor binary name
complete -c nucleor --wraps nuc
