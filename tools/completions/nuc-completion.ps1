# nuc-completion.ps1 — PowerShell argument completer for the Nucleor CLI.
#
# Install (one-time, in your $PROFILE):
#   . C:\path\to\Nucleor_OSS\tools\completions\nuc-completion.ps1
#
# After dot-sourcing, tab completion works for `nuc` and `nucleor`.

$nuc_subcommands = @(
    'build', 'build-fast', 'build-strict', 'build-shared', 'build-wasm', 'build-ptx',
    'run', 'emit', 'test', 'bench', 'perf', 'check', 'audit', 'policy',
    'certify', 'translate', 'summary', 'query', 'graph', 'impact', 'abi', 'evidence',
    'bootstrap', 'stage-dump', 'init', 'lock', 'install', 'publish', 'registry',
    'profile', 'sage', 'explain', 'help',
    'clean', 'scram', 'zen', 'mco'
)

$nuc_flags = @(
    '-o', '--out', '--emit', '--no-link', '--time-passes', '--no-cache', '--tier',
    '--json', '--sarif', '--check', '--review', '--review-filter',
    '--list', '--iterations', '--warmup',
    '--c-header', '--rust-extern', '--exports', '--fn',
    '--version', '--help'
)

$nuc_completer = {
    param($wordToComplete, $commandAst, $cursorPosition)

    # First positional after command name → subcommand
    $tokens = $commandAst.CommandElements
    if ($tokens.Count -le 2) {
        return $nuc_subcommands |
            Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }

    # Flag completion
    if ($wordToComplete.StartsWith('-')) {
        return $nuc_flags |
            Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterName', $_) }
    }

    # File completion: prefer .nr files, fall back to directories
    $matches = @()
    if ($wordToComplete) {
        $matches += Get-ChildItem -Path "$wordToComplete*" -Filter "*.nr" -ErrorAction SilentlyContinue
        $matches += Get-ChildItem -Path "$wordToComplete*" -Directory -ErrorAction SilentlyContinue
    } else {
        $matches += Get-ChildItem -Filter "*.nr" -ErrorAction SilentlyContinue
        $matches += Get-ChildItem -Directory -ErrorAction SilentlyContinue
    }
    return $matches | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_.Name, $_.Name, 'ParameterValue', $_.Name)
    }
}

Register-ArgumentCompleter -CommandName nuc     -ScriptBlock $nuc_completer -Native
Register-ArgumentCompleter -CommandName nucleor -ScriptBlock $nuc_completer -Native
