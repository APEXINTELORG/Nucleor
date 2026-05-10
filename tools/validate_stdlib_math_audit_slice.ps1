param(
    [string]$CompilerPath = ".\bin\nucleor.exe",
    [ValidateSet("all","F-MATH-001","F-MATH-002","F-MATH-003","F-MATH-004","F-MATH-005","F-MATH-011","F-MATH-012","F-MATH-027")]
    [string]$Finding = "all"
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

function Fail($msg) { Write-Error $msg; exit 1 }
function Pass($msg) { Write-Host "PASS: $msg" }

function Run-Capture {
    param([string[]]$ArgList)
    $out = Join-Path "target" ("stdlib_math_" + [Guid]::NewGuid().ToString("N") + ".out")
    $err = Join-Path "target" ("stdlib_math_" + [Guid]::NewGuid().ToString("N") + ".err")
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
    $runOut = Join-Path "target" ("stdlib_math_run_" + [Guid]::NewGuid().ToString("N") + ".out")
    $runErr = Join-Path "target" ("stdlib_math_run_" + [Guid]::NewGuid().ToString("N") + ".err")
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

function Assert-NotContains {
    param([string]$Path, [string]$Pattern, [string]$Label)
    $text = Get-Content -LiteralPath $Path -Raw
    if ($text -match $Pattern) { Fail "$Label found forbidden pattern $Pattern in $Path" }
    Pass $Label
}

$script:Compiler = (Resolve-Path $CompilerPath).Path
New-Item -ItemType Directory -Force -Path "target" | Out-Null

function Invoke-Finding {
    param([string]$Id)
    switch ($Id) {
        "F-MATH-001" {
            Expect-BuildRun "tests\rods\tt_svd_reconstruction.nr" "_math_tt_svd_recon" "F-MATH-001 TT-SVD reconstructs rank-1 tensor"
            Expect-BuildRun "tests\features\tensor_decomp_tt_svd_smoke.nr" "_math_tt_svd_arity" "F-MATH-001 TT-SVD public arity stays valid"
            Assert-Contains "stdlib\runtime\tensor_decomp_rt.c" "_td_thin_svd" "F-MATH-001 real SVD helper present"
        }
        "F-MATH-002" {
            Expect-BuildRun "tests\features\tensor_decomp_cp_als_rank1_smoke.nr" "_math_cp_als_rank1" "F-MATH-002 CP-ALS rank-1 reconstruction"
            Assert-Contains "stdlib\runtime\tensor_decomp_rt.c" "_td_invert_rxr" "F-MATH-002 dense Gram inverse helper present"
            Assert-Contains "stdlib\runtime\tensor_decomp_rt.c" "_td_factor_update\(A, V, gram" "F-MATH-002 A update uses dense solve helper"
            Assert-Contains "stdlib\runtime\tensor_decomp_rt.c" "_td_factor_update\(B, V, gram" "F-MATH-002 B update uses dense solve helper"
            Assert-Contains "stdlib\runtime\tensor_decomp_rt.c" "_td_factor_update\(C, V, gram" "F-MATH-002 C update uses dense solve helper"
        }
        "F-MATH-003" {
            Expect-BuildRun "tests\features\linalg_audit_edges_smoke.nr" "_math_linalg_edges" "F-MATH-003 ridge prediction remains unbounded"
            Assert-NotContains "stdlib\runtime\tensor_rt.c" "pred->data\[i\]\s*=\s*sum\s*<" "F-MATH-003 no lower clip assignment remains"
            Assert-NotContains "stdlib\runtime\tensor_rt.c" "pred->data\[i\]\s*=\s*sum\s*>" "F-MATH-003 no upper clip assignment remains"
        }
        "F-MATH-004" {
            Expect-BuildRun "tests\features\linalg_audit_edges_smoke.nr" "_math_rank_edges" "F-MATH-004 repeated rank query succeeds"
            Assert-Contains "stdlib\runtime\linalg_rt.c" "free\(U->data\); free\(U\);" "F-MATH-004 rank frees U"
            Assert-Contains "stdlib\runtime\linalg_rt.c" "free\(S->data\); free\(S\);" "F-MATH-004 rank frees S"
            Assert-Contains "stdlib\runtime\linalg_rt.c" "free\(V->data\); free\(V\);" "F-MATH-004 rank frees V"
            Assert-Contains "stdlib\runtime\linalg_rt.c" "free\(svd\);" "F-MATH-004 rank frees SVDResult"
        }
        "F-MATH-005" {
            Expect-BuildRun "tests\features\linalg_audit_edges_smoke.nr" "_math_eig_edges" "F-MATH-005 eig rejects non-symmetric input"
            Assert-Contains "stdlib\runtime\linalg_rt.c" "fabs\(diff\) > sym_tol" "F-MATH-005 symmetry gate present"
        }
        "F-MATH-011" {
            Expect-BuildRun "tests\features\ml_sklearn_kmeans_predict_f64.nr" "_math_kmeans_predict" "F-MATH-011 KMeans direct public predict fixture"
        }
        "F-MATH-012" {
            Expect-BuildRun "tests\features\ml_decision_tree_predict_i64_smoke.nr" "_math_dt_predict" "F-MATH-012 decision-tree direct public predict fixture"
        }
        "F-MATH-027" {
            Expect-BuildRun "tests\features\tensor_nd_slice_bounds_smoke.nr" "_math_t3_slice_bounds" "F-MATH-027 tensor slice bounds fixture"
            Assert-Contains "stdlib\runtime\tensor3d_rt.c" "idx < 0 \|\| idx >= src->shape\[d\]" "F-MATH-027 slice index bounds check present"
        }
    }
}

if ($Finding -eq "all") {
    @("F-MATH-001","F-MATH-002","F-MATH-003","F-MATH-004","F-MATH-005","F-MATH-011","F-MATH-012","F-MATH-027") | ForEach-Object { Invoke-Finding $_ }
} else {
    Invoke-Finding $Finding
}

Pass "stdlib math audit slice complete"
