param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$Ledger = "",
    [switch]$ListOnly,
    [switch]$ClosedOnly
)

$ErrorActionPreference = "Stop"

if ($Ledger -eq "") {
    $Ledger = Join-Path $Root "docs/audit/audit_pass1_closure_ledger_2026-05-09.csv"
}

if (-not (Test-Path -LiteralPath $Ledger)) {
    throw "missing audit closure ledger: $Ledger"
}

$rows = Import-Csv -LiteralPath $Ledger
$total = 0
$pass = 0
$fail = 0
$todo = 0

function Get-ExpectedValidation([object]$row) {
    $expectedRc = 0
    $expectedDiagnostic = ""
    $result = [string]$row.validation_result

    if ($result -match "(?i)\brc=(-?\d+)") {
        $expectedRc = [int]$Matches[1]
    }
    if ($result -match "(?i)\bexpected_diag=([A-Z][A-Z0-9_-]+)") {
        $expectedDiagnostic = $Matches[1]
    }

    return [pscustomobject]@{
        Rc = $expectedRc
        Diagnostic = $expectedDiagnostic
    }
}

function Split-ValidationCommand([string]$cmd, [int]$expectedRc) {
    if ($expectedRc -eq 0) {
        return @($cmd)
    }

    $parts = @($cmd -split "\s*;\s*" | Where-Object { $_.Trim() -ne "" })
    if ($parts.Count -eq 0) {
        return @($cmd)
    }
    return $parts
}

function Invoke-MatrixCommand([string]$cmd) {
    if ($IsWindows -or $env:OS -eq "Windows_NT") {
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $cmd 2>&1
        $rc = $LASTEXITCODE
    } else {
        $out = & bash -lc $cmd 2>&1
        $rc = $LASTEXITCODE
    }

    return [pscustomobject]@{
        Rc = $rc
        Output = @($out)
    }
}

Push-Location $Root
try {
    foreach ($row in $rows) {
        if ($row.severity -ne "Critical" -and $row.severity -ne "High") {
            continue
        }
        if ($ClosedOnly -and $row.status_final -ne "proven_closed") {
            continue
        }
        $total += 1
        $cmd = [string]$row.validation_command
        $label = "$($row.layer) $($row.finding_id) $($row.severity)"

        if ($cmd.Trim() -eq "" -or $cmd.Trim().ToUpperInvariant() -eq "TBD") {
            $todo += 1
            Write-Output "TODO  $label  no validation_command"
            continue
        }

        $expected = Get-ExpectedValidation $row
        $commands = Split-ValidationCommand $cmd $expected.Rc

        if ($ListOnly) {
            $diagLabel = ""
            if ($expected.Diagnostic -ne "") {
                $diagLabel = " diag=$($expected.Diagnostic)"
            }
            Write-Output "CASE  $label  expect_rc=$($expected.Rc)$diagLabel  $cmd"
            continue
        }

        Write-Output "RUN   $label"

        $caseFailed = $false
        foreach ($caseCmd in $commands) {
            $result = Invoke-MatrixCommand $caseCmd
            $outputText = ($result.Output | Out-String)
            $rcOk = ($result.Rc -eq $expected.Rc)
            $diagOk = ($expected.Diagnostic -eq "" -or $outputText -match [regex]::Escape($expected.Diagnostic))

            if (-not $rcOk -or -not $diagOk) {
                $caseFailed = $true
                Write-Output "FAIL  $label  rc=$($result.Rc) expected_rc=$($expected.Rc)"
                if ($expected.Diagnostic -ne "") {
                    Write-Output "      expected_diag=$($expected.Diagnostic)"
                }
                Write-Output "      command=$caseCmd"
                $result.Output | Select-Object -Last 40 | ForEach-Object { Write-Output "      $_" }
            }
        }

        if (-not $caseFailed) {
            $pass += 1
            Write-Output "PASS  $label"
        } else {
            $fail += 1
        }
    }
} finally {
    Pop-Location
}

Write-Output "SUMMARY total=$total pass=$pass fail=$fail todo=$todo"
if ($fail -ne 0 -or $todo -ne 0) {
    exit 1
}
