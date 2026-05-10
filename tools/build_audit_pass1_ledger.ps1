param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$OutPath = ""
)

$ErrorActionPreference = "Stop"

if ($OutPath -eq "") {
    $OutPath = Join-Path $Root "docs/audit/audit_pass1_closure_ledger_2026-05-09.csv"
}

$findingsDir = Join-Path $Root "docs/audit/findings"
if (-not (Test-Path -LiteralPath $findingsDir)) {
    throw "missing findings dir: $findingsDir"
}

$layerMap = @{
    "audit_recon_pass1_lexer_parser_2026-05-08.md" = @("Layer 1 Lexer/Parser/AST", "source_bytes_and_lexer")
    "audit_recon_pass1_typesystem_2026-05-08.md" = @("Layer 2 Type System", "type_contracts_and_substitution")
    "audit_recon_pass1_diagnostics_2026-05-08.md" = @("Layer 3 Diagnostics", "diagnostic_contract")
    "audit_recon_pass1_memsafe_2026-05-08.md" = @("Layer 4 Memory Safety/Effects", "ownership_borrow_init_flow")
    "audit_recon_pass1_concurrency_2026-05-08.md" = @("Layer 5 Concurrency/RT", "concurrency_and_rt")
    "audit_recon_pass1_codegen_2026-05-08.md" = @("Layer 6 Codegen/IR", "type_contracts_and_substitution")
    "audit_recon_pass1_runtime_abi_2026-05-08.md" = @("Layer 7 Runtime ABI", "runtime_abi_and_layout")
    "audit_recon_pass1_numeric_2026-05-08.md" = @("Layer 8 Numeric/SI", "numeric_semantics")
    "audit_recon_pass1_stdlib_math_2026-05-08.md" = @("Layer 9a Stdlib Math", "stdlib_domain_correctness")
    "audit_recon_pass1_stdlib_robo_quantum_ffi_2026-05-08.md" = @("Layer 9b Robotics/Quantum/FFI", "stdlib_domain_correctness")
    "audit_recon_pass1_examples_docs_2026-05-08.md" = @("Layer 10 Examples/Docs/Install", "docs_and_release_surface")
}

function CsvEscape([string]$s) {
    if ($null -eq $s) { return '""' }
    return '"' + ($s -replace '"', '""') + '"'
}

function Normalize-Text([string]$s) {
    if ($null -eq $s) { return "" }
    $t = $s
    $t = $t -replace ([string][char]0x2014), "-"
    $t = $t -replace ([string][char]0x2013), "-"
    $t = $t -replace ([string][char]0x2018), "'"
    $t = $t -replace ([string][char]0x2019), "'"
    $t = $t -replace ([string][char]0x201C), '"'
    $t = $t -replace ([string][char]0x201D), '"'
    $t = $t -replace "[^\x09\x0A\x0D\x20-\x7E]", ""
    return $t.Trim()
}

function Normalize-Severity([string]$id, [string]$text) {
    if ($id -match "^(CRIT|Critical)") { return "Critical" }
    if ($id -match "^(HIGH|High)") { return "High" }
    if ($text -match "(?i)\bcritical\b|\[CRITICAL\]|\[Critical\]|\*\*CRITICAL") { return "Critical" }
    if ($text -match "(?i)\bhigh\b|\[HIGH\]|\[High\]|\*\*HIGH") { return "High" }
    return ""
}

function Normalize-Id([string]$id) {
    return ($id -replace "\s+", "")
}

$rows = New-Object System.Collections.Generic.List[object]

Get-ChildItem -LiteralPath $findingsDir -Filter "audit_recon_pass1_*_2026-05-08.md" |
    Sort-Object Name |
    ForEach-Object {
        $file = $_
        $layerInfo = $layerMap[$file.Name]
        if ($null -eq $layerInfo) {
            $layerInfo = @("Unknown", "verification_and_provenance")
        }
        $lines = Get-Content -LiteralPath $file.FullName -Encoding UTF8
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $id = ""
            $title = ""
            $severity = ""

            if ($line -match "^#{3,4}\s+(?<id>(?:F-[A-Z0-9-]+|C-\d+|CRIT-[A-Z0-9-]+|HIGH-[A-Z0-9-]+|CRIT-LAYER9B-\d+|HIGH-LAYER9B-\d+|G\d-[A-Z0-9-]+|Critical-\d+|High-\d+))\s*(?<rest>.*)$") {
                $id = Normalize-Id $Matches.id
                $title = Normalize-Text $Matches.rest
                $severity = Normalize-Severity $id $line
            } elseif ($line -match "^\s*-\s+\*\*(?<id>(?:A\d+|V\d+|S\d+|C\d+|MM\d+))\s+\((?<sev>Critical|High)[^)]*\)\s*[-]\s*(?<title>.+?)\*\*") {
                $id = Normalize-Id $Matches.id
                $severity = $Matches.sev
                $title = Normalize-Text $Matches.title
            } elseif ($line -match "^\|\s*(?<id>(?:A\d+|V\d+|S\d+|C\d+|MM\d+|1\.2-G\d+(?:\.\.G\d+)?))\s*\|\s*(?<sev>\*\*Critical\*\*|\*\*High\*\*|Critical|High)\s*\|\s*(?<title>[^|]+)\|") {
                $id = Normalize-Id $Matches.id
                $severity = ($Matches.sev -replace "\*", "")
                $title = Normalize-Text $Matches.title
            }

            if ($id -eq "" -or ($severity -ne "Critical" -and $severity -ne "High")) {
                continue
            }

            $rows.Add([pscustomobject]@{
                layer = $layerInfo[0]
                finding_id = $id
                severity = $severity
                root_cause_bucket = $layerInfo[1]
                audit_doc = "docs/audit/findings/$($file.Name)"
                source_line = $i + 1
                original_reproducer = ""
                expected_invariant = $title
                status_v100 = "audit_reported"
                status_candidate = "claimed_closed_needs_proof"
                status_final = "open"
                closing_commit = ""
                validation_command = ""
                validation_result = ""
                perf_result = ""
                notes = "generated_from_audit_heading"
            }) | Out-Null
        }
    }

$deduped = $rows |
    Sort-Object audit_doc, source_line, finding_id -Unique

$header = "layer,finding_id,severity,root_cause_bucket,audit_doc,source_line,original_reproducer,expected_invariant,status_v100,status_candidate,status_final,closing_commit,validation_command,validation_result,perf_result,notes"
$outLines = New-Object System.Collections.Generic.List[string]
$outLines.Add($header) | Out-Null

foreach ($row in $deduped) {
    $outLines.Add(@(
        CsvEscape $row.layer
        CsvEscape $row.finding_id
        CsvEscape $row.severity
        CsvEscape $row.root_cause_bucket
        CsvEscape $row.audit_doc
        CsvEscape ([string]$row.source_line)
        CsvEscape $row.original_reproducer
        CsvEscape $row.expected_invariant
        CsvEscape $row.status_v100
        CsvEscape $row.status_candidate
        CsvEscape $row.status_final
        CsvEscape $row.closing_commit
        CsvEscape $row.validation_command
        CsvEscape $row.validation_result
        CsvEscape $row.perf_result
        CsvEscape $row.notes
    ) -join ",") | Out-Null
}

Set-Content -LiteralPath $OutPath -Value $outLines -Encoding UTF8
Write-Output "wrote $($deduped.Count) Critical/High audit rows to $OutPath"
