#!/usr/bin/env bash
# nuc.bash — bash completion for the Nucleor CLI.
#
# Install:
#   source /path/to/Nucleor_OSS/tools/completions/nuc.bash
# Or symlink into your bash-completion.d:
#   ln -s /path/to/Nucleor_OSS/tools/completions/nuc.bash /usr/local/etc/bash_completion.d/nuc

_nuc_complete() {
    local cur prev words cword
    _init_completion 2>/dev/null || {
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
    }

    local commands="build build-fast build-strict build-shared build-wasm build-ptx \
                    run emit test bench perf check audit policy certify translate \
                    summary query graph impact abi evidence \
                    bootstrap stage-dump init lock install add remove update publish registry profile sage \
                    doc fix \
                    explain help clean scram zen mco --version --help"

    local flags="-o --out --emit --no-link --time-passes --no-cache --tier \
                 --json --sarif --check --review --review-filter \
                 --list --iterations --warmup \
                 --c-header --rust-extern --exports --fn \
                 --imports --numeric --registry"

    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
        return 0
    fi

    case "$cur" in
        -*)
            COMPREPLY=( $(compgen -W "$flags" -- "$cur") )
            return 0
            ;;
        *)
            COMPREPLY=( $(compgen -f -X '!*.nr' -- "$cur") $(compgen -d -- "$cur") )
            return 0
            ;;
    esac
}

complete -F _nuc_complete nuc
complete -F _nuc_complete nucleor
