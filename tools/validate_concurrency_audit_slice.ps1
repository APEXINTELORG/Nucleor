param(
    [Parameter(Mandatory = $true)]
    [string]$Finding,
    [string]$Root = ""
)

$ErrorActionPreference = "Stop"

if ($Root -eq "") {
    $scriptDir = $PSScriptRoot
    if ($scriptDir -eq "") {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    $Root = (Resolve-Path (Join-Path $scriptDir "..")).Path
}

function Invoke-NucleorBuild {
    param(
        [string]$Source,
        [string]$OutName
    )

    $oldErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = & (Join-Path $Root "bin\nucleor.exe") build $Source -o $OutName --no-cache 2>&1
    $rc = $LASTEXITCODE
    $ErrorActionPreference = $oldErrorAction
    if ($rc -ne 0) {
        $out | ForEach-Object { Write-Output $_ }
        throw "build failed for $Source rc=$rc"
    }
}

function Invoke-NucleorBuildEmit {
    param(
        [string]$Source,
        [string]$OutName
    )

    $oldErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = & (Join-Path $Root "bin\nucleor.exe") build $Source -o $OutName --no-cache --emit=llvm 2>&1
    $rc = $LASTEXITCODE
    $ErrorActionPreference = $oldErrorAction
    if ($rc -ne 0) {
        $out | ForEach-Object { Write-Output $_ }
        throw "emit build failed for $Source rc=$rc"
    }
}

function Invoke-Target {
    param([string]$OutName)

    $exe = Join-Path $Root ("target\" + $OutName + ".exe")
    if (-not (Test-Path -LiteralPath $exe)) {
        $exe = Join-Path $Root ("target\" + $OutName)
    }
    if (-not (Test-Path -LiteralPath $exe)) {
        throw "target executable not found for $OutName"
    }
    $oldErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = & $exe 2>&1
    $rc = $LASTEXITCODE
    $ErrorActionPreference = $oldErrorAction
    if ($rc -ne 0) {
        $out | ForEach-Object { Write-Output $_ }
        throw "target failed for $OutName rc=$rc"
    }
}

function Invoke-TargetExpect {
    param(
        [string]$OutName,
        [int]$ExpectedExitCode,
        [string]$ExpectedText
    )

    $exe = Join-Path $Root ("target\" + $OutName + ".exe")
    if (-not (Test-Path -LiteralPath $exe)) {
        $exe = Join-Path $Root ("target\" + $OutName)
    }
    if (-not (Test-Path -LiteralPath $exe)) {
        throw "target executable not found for $OutName"
    }
    $oldErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = & $exe 2>&1
    $rc = $LASTEXITCODE
    $ErrorActionPreference = $oldErrorAction
    $text = ($out | Out-String)
    if ($rc -ne $ExpectedExitCode) {
        $out | ForEach-Object { Write-Output $_ }
        throw "target $OutName exited $rc; expected $ExpectedExitCode"
    }
    if ($text -notmatch [regex]::Escape($ExpectedText)) {
        $out | ForEach-Object { Write-Output $_ }
        throw "target $OutName did not contain expected text $ExpectedText"
    }
}

function Invoke-Positive {
    param(
        [string]$Source,
        [string]$OutName
    )

    Push-Location $Root
    try {
        Invoke-NucleorBuild $Source $OutName
        Invoke-Target $OutName
    } finally {
        Pop-Location
    }
}

function Invoke-Negative {
    param(
        [string]$Source,
        [string]$OutName,
        [string]$Diagnostic
    )

    Push-Location $Root
    try {
        $oldErrorAction = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $out = & (Join-Path $Root "bin\nucleor.exe") build $Source -o $OutName --no-cache 2>&1
        $rc = $LASTEXITCODE
        $ErrorActionPreference = $oldErrorAction
        $text = ($out | Out-String)
        if ($rc -eq 0) {
            $out | ForEach-Object { Write-Output $_ }
            throw "negative build unexpectedly succeeded for $Source"
        }
        if ($text -notmatch [regex]::Escape($Diagnostic)) {
            $out | ForEach-Object { Write-Output $_ }
            throw "negative build for $Source did not contain $Diagnostic"
        }
    } finally {
        Pop-Location
    }
}

function Assert-RuntimeContains {
    param([string[]]$Needles)

    $runtimePath = Join-Path $Root "stdlib\runtime\nucleor_llvm_rt.c"
    $runtime = Get-Content -LiteralPath $runtimePath -Raw
    foreach ($needle in $Needles) {
        if ($runtime -notmatch [regex]::Escape($needle)) {
            throw "runtime missing required source marker: $needle"
        }
    }
}

function Assert-ThreadRuntimeContains {
    param([string[]]$Needles)

    $runtimePath = Join-Path $Root "stdlib\runtime\thread_rt.c"
    $runtime = Get-Content -LiteralPath $runtimePath -Raw
    foreach ($needle in $Needles) {
        if ($runtime -notmatch [regex]::Escape($needle)) {
            throw "thread runtime missing required source marker: $needle"
        }
    }
}

function Assert-RuntimeMissing {
    param([string[]]$Needles)

    $runtimePath = Join-Path $Root "stdlib\runtime\nucleor_llvm_rt.c"
    $runtime = Get-Content -LiteralPath $runtimePath -Raw
    foreach ($needle in $Needles) {
        if ($runtime -match [regex]::Escape($needle)) {
            throw "runtime still contains forbidden source marker: $needle"
        }
    }
}

function Assert-IRContains {
    param(
        [string]$OutName,
        [string[]]$Needles
    )

    $llPath = Join-Path $Root ("target\" + $OutName + ".ll")
    if (-not (Test-Path -LiteralPath $llPath)) {
        throw "LLVM output missing for $OutName"
    }
    $ll = Get-Content -LiteralPath $llPath -Raw
    foreach ($needle in $Needles) {
        if ($ll -notmatch [regex]::Escape($needle)) {
            throw "LLVM output for $OutName missing required marker: $needle"
        }
    }
}

switch ($Finding) {
    "F-CONC-001" {
        Assert-RuntimeContains @("NUC_ATOMIC_I64_MAGIC", "WARN[F-CONC-001]", "__nuc_atomic_i64_active_cell")
        Invoke-Negative "tests\err\err_conc_forge_atomic_handle.nr" "_audit_f_conc_001_forged_struct" "CONC-G6-OPAQUE-HANDLE"
        Invoke-Positive "tests\lang\conc_handle_round_trip.nr" "_audit_f_conc_001_typed_roundtrip"
        Invoke-Positive "tests\features\concurrency_atomic_raw_handle_guard.nr" "_audit_f_conc_001_raw_guard"
    }
    "F-CONC-002" {
        Assert-ThreadRuntimeContains @("int consumed;", "WARN[F-CONC-002]")
        Invoke-Positive "tests\features\concurrency_future_double_get_smoke.nr" "_audit_f_conc_002_future_double_get"
    }
    "F-CONC-003" {
        Assert-RuntimeContains @("__nucleor_deadline_enter", "__nucleor_deadline_poll", "__nucleor_deadline_exit", "__nucleor_deadline_stack")
        Push-Location $Root
        try {
            Invoke-NucleorBuildEmit "tests\features\concurrency_deadline_midloop_poll.nr" "_audit_f_conc_003_deadline_midloop"
            Assert-IRContains "_audit_f_conc_003_deadline_midloop" @(
                "call i64 @__nucleor_deadline_enter",
                "call i64 @__nucleor_deadline_poll",
                "call i64 @__nucleor_deadline_exit"
            )
            Invoke-TargetExpect "_audit_f_conc_003_deadline_midloop" 1 "RT-004"
        } finally {
            Pop-Location
        }
    }
    "F-CONC-004" {
        Invoke-Negative "tests\err\err_no_alloc_with_capacity.nr" "_audit_f_conc_004_with_capacity" "RT-001"
        Invoke-Negative "tests\err\err_no_alloc_box_new.nr" "_audit_f_conc_004_box_new" "RT-001"
    }
    "F-CONC-005" {
        Invoke-Negative "tests\err\err_atomic_blocking_via_wrapper.nr" "_audit_f_conc_005_atomic_wrapper" "ATOMIC-001"
        Invoke-Negative "tests\err\err_isr_blocking_via_wrapper.nr" "_audit_f_conc_005_isr_wrapper" "ATOMIC-001"
    }
    "F-CONC-006" {
        Assert-RuntimeContains @("PTHREAD_MUTEX_RECURSIVE", "pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE)")
        Invoke-Positive "tests\features\concurrency_mutex_recursive_semantics.nr" "_audit_f_conc_006_recursive_mutex"
    }
    "F-CONC-007" {
        Assert-RuntimeContains @("CONDITION_VARIABLE not_empty", "CONDITION_VARIABLE not_full", "SleepConditionVariableCS(&ch->not_full", "SleepConditionVariableCS(&ch->not_empty", "WakeConditionVariable(&ch->not_empty", "WakeConditionVariable(&ch->not_full")
        Assert-RuntimeMissing @("WaitForSingleObject(ch->not_full, 100)", "WaitForSingleObject(ch->not_empty, 100)")
        Invoke-Positive "tests\fixtures\v0885_c2_channel_smoke.nr" "_audit_f_conc_007_channel_roundtrip"
        Invoke-Positive "tests\features\lane3_channel_contention.nr" "_audit_f_conc_007_channel_contention"
    }
    "F-CONC-016" {
        Invoke-Positive "tests\features\lane3_mutex_contention.nr" "_audit_f_conc_016_mutex_contention"
        Invoke-Positive "tests\features\lane3_channel_contention.nr" "_audit_f_conc_016_channel_contention"
        Invoke-Positive "tests\features\concurrency_future_double_get_smoke.nr" "_audit_f_conc_016_future_double_get"
        Invoke-Positive "tests\features\concurrency_mutex_recursive_semantics.nr" "_audit_f_conc_016_recursive_mutex"
        Invoke-Negative "tests\err\err_conc_forge_atomic_handle.nr" "_audit_f_conc_016_forged_handle" "CONC-G6-OPAQUE-HANDLE"
    }
    default {
        throw "unknown finding for concurrency audit validator: $Finding"
    }
}

Write-Output "PASS $Finding"
