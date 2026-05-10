param(
    [string]$CompilerPath = ".\bin\nucleor.exe",
    [ValidateSet("all","CRIT-LAYER9B-001","CRIT-LAYER9B-002","HIGH-LAYER9B-003","HIGH-LAYER9B-004","HIGH-LAYER9B-005","HIGH-LAYER9B-006","HIGH-LAYER9B-007")]
    [string]$Finding = "all"
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

function Fail($msg) { Write-Error $msg; exit 1 }
function Pass($msg) { Write-Host "PASS: $msg" }

function Run-Capture {
    param([string[]]$ArgList)
    $out = Join-Path "target" ("stdlib_robo_" + [Guid]::NewGuid().ToString("N") + ".out")
    $err = Join-Path "target" ("stdlib_robo_" + [Guid]::NewGuid().ToString("N") + ".err")
    try {
        $p = Start-Process -FilePath $script:Compiler -ArgumentList $ArgList -NoNewWindow -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
        $text = ""
        if (Test-Path -LiteralPath $out) { $text += Get-Content -LiteralPath $out -Raw }
        if (Test-Path -LiteralPath $err) { $text += Get-Content -LiteralPath $err -Raw }
        return @{ ExitCode = $p.ExitCode; Output = $text }
    } finally {
        Remove-Item -LiteralPath $out,$err -Force -ErrorAction SilentlyContinue
    }
}

function Expect-BuildRun {
    param([string]$Fixture, [string]$OutName, [string]$Label)
    $r = Run-Capture -ArgList @("build", $Fixture, "-o", $OutName, "--no-cache")
    if ($r.ExitCode -ne 0) { Fail "$Label build failed:`n$($r.Output)" }
    $exe = Join-Path "target" "$OutName.exe"
    $runOut = Join-Path "target" ("stdlib_robo_run_" + [Guid]::NewGuid().ToString("N") + ".out")
    $runErr = Join-Path "target" ("stdlib_robo_run_" + [Guid]::NewGuid().ToString("N") + ".err")
    try {
        $p = Start-Process -FilePath $exe -NoNewWindow -Wait -PassThru -RedirectStandardOutput $runOut -RedirectStandardError $runErr
        $text = ""
        if (Test-Path -LiteralPath $runOut) { $text += Get-Content -LiteralPath $runOut -Raw }
        if (Test-Path -LiteralPath $runErr) { $text += Get-Content -LiteralPath $runErr -Raw }
        if ($p.ExitCode -ne 0) { Fail "$Label run failed: rc=$($p.ExitCode), output:`n$text" }
    } finally {
        Remove-Item -LiteralPath $runOut,$runErr -Force -ErrorAction SilentlyContinue
    }
    Pass $Label
}

function Assert-Contains {
    param([string]$Path, [string]$Pattern, [string]$Label)
    $text = Get-Content -LiteralPath $Path -Raw
    if ($text -notmatch $Pattern) { Fail "$Label missing pattern $Pattern in $Path" }
    Pass $Label
}

function Expect-ToolOk {
    param([string]$File, [string[]]$ToolArgs, [string]$Label)
    $out = Join-Path "target" ("tool_" + [Guid]::NewGuid().ToString("N") + ".out")
    $err = Join-Path "target" ("tool_" + [Guid]::NewGuid().ToString("N") + ".err")
    try {
        $p = Start-Process -FilePath "powershell" -ArgumentList (@("-NoProfile","-ExecutionPolicy","Bypass","-File",$File) + $ToolArgs) -NoNewWindow -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
        $text = ""
        if (Test-Path -LiteralPath $out) { $text += Get-Content -LiteralPath $out -Raw }
        if (Test-Path -LiteralPath $err) { $text += Get-Content -LiteralPath $err -Raw }
        if ($p.ExitCode -ne 0) { Fail "$Label failed: rc=$($p.ExitCode), output:`n$text" }
    } finally {
        Remove-Item -LiteralPath $out,$err -Force -ErrorAction SilentlyContinue
    }
    Pass $Label
}

$script:Compiler = (Resolve-Path $CompilerPath).Path
New-Item -ItemType Directory -Force -Path "target" | Out-Null

function Invoke-Finding {
    param([string]$Id)
    switch ($Id) {
        "CRIT-LAYER9B-001" {
            Expect-BuildRun "tests\features\urdf_axis_self_closing_smoke.nr" "_robo_urdf_axis" "CRIT-LAYER9B-001 URDF default axis is x"
            Assert-Contains "stdlib\runtime\urdf_rt.c" "axis\[0\] = 1.0" "CRIT-LAYER9B-001 runtime default axis set to x"
        }
        "CRIT-LAYER9B-002" {
            Assert-Contains "tests\rods\rust_interop.nr" "rust_free_str\(enc\)" "CRIT-LAYER9B-002 encoded string freed"
            Assert-Contains "tests\rods\rust_interop.nr" "rust_free_str\(dec\)" "CRIT-LAYER9B-002 decoded string freed"
            Assert-Contains "stdlib\rods\rust_bridge\Cargo.toml" "regex = `"1\.10`"" "CRIT-LAYER9B-002 regex pin present"
            Expect-ToolOk "tools\check_rust_bridge_ownership.ps1" @("-SelfTest") "CRIT-LAYER9B-002 rust bridge ownership harness self-test"
        }
        "HIGH-LAYER9B-003" {
            Expect-BuildRun "tests\features\qsim_state_capacity_status_smoke.nr" "_robo_qsim_capacity" "HIGH-LAYER9B-003 qsim capacity status fixture"
            Assert-Contains "stdlib\rods\quantum.nr" "qsim_max_qubits" "HIGH-LAYER9B-003 public qsim cap surface present"
        }
        "HIGH-LAYER9B-004" {
            Expect-BuildRun "tests\features\qsim_count_nonzero_threshold_smoke.nr" "_robo_qsim_nonzero" "HIGH-LAYER9B-004 qsim sparsity threshold units"
            Assert-Contains "stdlib\rods\quantum_rt.c" "threshold \* threshold" "HIGH-LAYER9B-004 runtime squares amplitude threshold"
        }
        "HIGH-LAYER9B-005" {
            Expect-BuildRun "tests\features\qsim_graph_auto_record_smoke.nr" "_robo_qsim_record" "HIGH-LAYER9B-005 SWAP records one DAG event"
            Expect-BuildRun "tests\features\qsim_graph_query_contract_smoke.nr" "_robo_qsim_query" "HIGH-LAYER9B-005 query contract reflects primitive SWAP"
            Assert-Contains "stdlib\rods\quantum.nr" "_qsim_swap_state" "HIGH-LAYER9B-005 primitive SWAP helper present"
        }
        "HIGH-LAYER9B-006" {
            Expect-BuildRun "tests\features\qsim_graph_auto_entangle_smoke.nr" "_robo_qsim_entangle" "HIGH-LAYER9B-006 CNOT false entanglement regression"
            Expect-BuildRun "tests\features\qsim_graph_lifecycle_auto_record_smoke.nr" "_robo_qsim_lifecycle" "HIGH-LAYER9B-006 lifecycle auto-record regression"
            Assert-Contains "stdlib\rods\quantum.nr" "_qsim_control_has_both_branches" "HIGH-LAYER9B-006 control-branch preflight helper present"
        }
        "HIGH-LAYER9B-007" {
            Expect-BuildRun "tests\features\urdf_axis_self_closing_smoke.nr" "_robo_urdf_selfclose" "HIGH-LAYER9B-007 URDF self-closing joint fixture"
            Assert-Contains "stdlib\runtime\urdf_rt.c" "self_closed" "HIGH-LAYER9B-007 parser detects self-closing joint"
        }
    }
}

if ($Finding -eq "all") {
    @("CRIT-LAYER9B-001","CRIT-LAYER9B-002","HIGH-LAYER9B-003","HIGH-LAYER9B-004","HIGH-LAYER9B-005","HIGH-LAYER9B-006","HIGH-LAYER9B-007") | ForEach-Object { Invoke-Finding $_ }
} else {
    Invoke-Finding $Finding
}

Pass "stdlib robotics/quantum/FFI audit slice complete"
