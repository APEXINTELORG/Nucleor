param(
    [string]$CompilerPath = ".\bin\nucleor.exe",
    [string]$ClangPath = ""
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

function Fail($msg) {
    Write-Error $msg
    exit 1
}

function Pass($msg) {
    Write-Host "PASS: $msg"
}

function Require-Text($Path, $Pattern, $Label) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Fail "missing file for ${Label}: $Path"
    }
    $hit = Select-String -LiteralPath $Path -Pattern $Pattern -SimpleMatch -Quiet
    if (-not $hit) {
        Fail "missing required text for ${Label}: $Pattern"
    }
}

function Resolve-Clang {
    param([string]$Explicit)
    if ($Explicit -and (Test-Path -LiteralPath $Explicit -PathType Leaf)) {
        return (Resolve-Path $Explicit).Path
    }
    if ($env:NUCLEOR_CLANG_PATH -and (Test-Path -LiteralPath $env:NUCLEOR_CLANG_PATH -PathType Leaf)) {
        return (Resolve-Path $env:NUCLEOR_CLANG_PATH).Path
    }
    $default = "C:\Program Files\LLVM\bin\clang.exe"
    if (Test-Path -LiteralPath $default -PathType Leaf) {
        return $default
    }
    $cmd = Get-Command clang.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    Fail "clang.exe not found; set -ClangPath or NUCLEOR_CLANG_PATH"
}

function Run-ProcessCapture {
    param(
        [string]$Exe,
        [string[]]$Args,
        [hashtable]$Env = @{}
    )
    $out = Join-Path "target" ("rtabi_" + [Guid]::NewGuid().ToString("N") + ".out")
    $err = Join-Path "target" ("rtabi_" + [Guid]::NewGuid().ToString("N") + ".err")
    $old = @{}
    foreach ($k in $Env.Keys) {
        $old[$k] = [Environment]::GetEnvironmentVariable($k, "Process")
        [Environment]::SetEnvironmentVariable($k, [string]$Env[$k], "Process")
    }
    try {
        if ($Args -and $Args.Count -gt 0) {
            $p = Start-Process -FilePath $Exe -ArgumentList $Args -NoNewWindow -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
        } else {
            $p = Start-Process -FilePath $Exe -NoNewWindow -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
        }
        $text = ""
        if (Test-Path -LiteralPath $out) { $text += Get-Content -LiteralPath $out -Raw }
        if (Test-Path -LiteralPath $err) { $text += Get-Content -LiteralPath $err -Raw }
        return @{ ExitCode = $p.ExitCode; Output = $text }
    } finally {
        foreach ($k in $Env.Keys) {
            [Environment]::SetEnvironmentVariable($k, $old[$k], "Process")
        }
        Remove-Item -LiteralPath $out,$err -Force -ErrorAction SilentlyContinue
    }
}

$repo = (Resolve-Path ".").Path
$compiler = (Resolve-Path $CompilerPath).Path
$runtime = Join-Path $repo "stdlib\runtime\nucleor_llvm_rt.c"
$memrt = Join-Path $repo "stdlib\runtime\mem_rt.c"
$processrt = Join-Path $repo "stdlib\runtime\process_rt.c"
$alloc = Join-Path $repo "stdlib\runtime\nuc_alloc.h"
$manifest = Join-Path $repo "docs\rfcs\helper_manifest.toml"
$clang = Resolve-Clang $ClangPath

& "C:\Program Files\Git\bin\bash.exe" -lc "./tools/check_nvec_layout.sh"
if ($LASTEXITCODE -ne 0) { Fail "A1 NVec layout verifier failed" }
Pass "A1 NVec layout is single-sourced"

foreach ($sym in @(
    "__nucleor_proc_run",
    "__nucleor_proc_run1",
    "__nucleor_proc_capture_stdout",
    "__nucleor_proc_capture_status",
    "__nucleor_proc_capture_with_status",
    "__nucleor_mutex_free",
    "__nucleor_mutex_free_value",
    "__nucleor_channel_close",
    "__nucleor_channel_is_closed",
    "__nucleor_vec_u8_extend_from_ptr",
    "__nucleor_str_intern_stats"
)) {
    Require-Text $manifest "symbol           = `"$sym`"" "manifest row $sym"
}
Pass "1.2-G1..G10/C1 manifest rows cover runtime public symbols"

Require-Text $runtime "capacity %lld exceeds INT_MAX" "A2 vec_with_capacity large cap panic"
Require-Text $runtime "capacity growth %lld exceeds INT_MAX" "A2 vec_push growth panic"
Require-Text $runtime "if (!grown) {" "A3/A4 realloc failure guard"
Require-Text $runtime "if (!v->data) { free(v); return 0; }" "A4 typed Vec inner allocation guard"
Require-Text $memrt "__nucleor_vec_free(handle);" "A5 mem_rt delegates to shared vec free guard"
Require-Text $runtime "memchr(s + start, '\0', (size_t)n)" "V1 str_substring over-end guard"
Require-Text $runtime "__nucleor_owned_empty_string" "S1 heap-owned empty string helper"
Require-Text $processrt "if (!r) return NULL;" "S1 process empty allocation never returns literal"
Require-Text $processrt "if (!body) return NULL;" "S1 proc capture status handles allocation failure"
Require-Text $processrt "static _Thread_local long long g_last_capture_status" "S2 proc capture TLS"
Require-Text $processrt "PROC-QUOTE-001" "S3 proc_run1 quote rejection"
Require-Text $runtime "_Static_assert(offsetof(NucAtomicI64Cell, value) % 8 == 0" "C2 atomic value 8-byte alignment"
Require-Text $runtime "_Alignof(_Atomic long long)" "C2 atomic value C11 alignment"
Pass "runtime ABI static invariants present"

& $compiler build "tests\fixtures\probe_str_substring_oob.nr" -o "_rtabi_str_oob" --no-cache | Out-Host
if ($LASTEXITCODE -ne 0) { Fail "failed to build str_substring OOB probe" }
$strRun = Run-ProcessCapture -Exe (Join-Path $repo "target\_rtabi_str_oob.exe") -Args @()
if ($strRun.ExitCode -eq 0 -or $strRun.Output -notmatch "STR-SUBSTR-OOB") {
    Fail "V1 str_substring OOB probe did not panic with STR-SUBSTR-OOB"
}
Pass "V1 str_substring over-end panics at runtime"

& $compiler build "tests\rods\lane6_proc_run1_quote.nr" -o "_rtabi_proc_quote" --no-cache | Out-Host
if ($LASTEXITCODE -ne 0) { Fail "failed to build proc_run1 quote probe" }
$procRun = Run-ProcessCapture -Exe (Join-Path $repo "target\_rtabi_proc_quote.exe") -Args @()
if ($procRun.ExitCode -ne 0 -or $procRun.Output -notmatch "OK lane6_proc_run1_quote") {
    Fail "S3 proc_run1 quote rejection probe failed"
}
Pass "S3 proc_run1 rejects unquotable shell arguments"

$capProbe = Join-Path $repo "target\rtabi_vec_cap_probe.c"
@"
#include <limits.h>
#include <stdint.h>
typedef struct NVec NVec;
NVec *__nucleor_vec_with_capacity(long long n);
int main(void) {
    (void)__nucleor_vec_with_capacity((long long)INT_MAX + 1LL);
    return 0;
}
"@ | Set-Content -LiteralPath $capProbe -Encoding ASCII
$capExe = Join-Path $repo "target\rtabi_vec_cap_probe.exe"
& $clang -O2 -fuse-ld=lld $capProbe $runtime -o $capExe "-Wl,/STACK:16777216" | Out-Host
if ($LASTEXITCODE -ne 0) { Fail "failed to compile A2 C probe" }
$capRun = Run-ProcessCapture -Exe $capExe -Args @()
if ($capRun.ExitCode -eq 0 -or $capRun.Output -notmatch "INT_MAX") {
    Fail "A2 large vec_with_capacity probe did not panic before truncation"
}
Pass "A2 vec_with_capacity fails fast before int truncation"

$freeProbe = Join-Path $repo "target\rtabi_vec_free_probe.c"
@"
#include <stdint.h>
NVec *__nucleor_vec_new(void);
void nuc_vec_free(long long handle);
int main(void) {
    long long h = (long long)(intptr_t)__nucleor_vec_new();
    nuc_vec_free(h);
    nuc_vec_free(h);
    return 0;
}
"@ | Set-Content -LiteralPath $freeProbe -Encoding ASCII
$freeExe = Join-Path $repo "target\rtabi_vec_free_probe.exe"
& $clang -O2 -fuse-ld=lld "-include" $alloc $freeProbe $runtime $memrt -o $freeExe "-Wl,/STACK:16777216" | Out-Host
if ($LASTEXITCODE -ne 0) { Fail "failed to compile A5 C probe" }
$freeRun = Run-ProcessCapture -Exe $freeExe -Args @() -Env @{ NUC_VEC_FREE_GUARD = "1" }
if ($freeRun.ExitCode -eq 0 -or $freeRun.Output -notmatch "PANIC-DOUBLE-FREE") {
    Fail "A5 mem_rt double-free probe did not route through shared guard"
}
Pass "A5 mem_rt nuc_vec_free uses shared double-free guard"

$s1Probe = Join-Path $repo "target\rtabi_s1_owned_empty_probe.c"
@"
#include <stdio.h>
#include <string.h>

const char *__nucleor_str_substring_strict(const char *s, long long start, long long end);
const char *__nucleor_str_to_lower(const char *s);
const char *__nucleor_str_to_upper(const char *s);
const char *__nucleor_str_trim(const char *s);
const char *__nucleor_file_read_string(const char *path);
const char *__nucleor_proc_capture_stdout(const char *cmdline);
void __nucleor_str_free(const char *s);

static int assert_owned_empty(const char *label, const char *s) {
    if (!s) {
        fprintf(stderr, "%s returned NULL\n", label);
        return 1;
    }
    if (strcmp(s, "") != 0) {
        fprintf(stderr, "%s returned non-empty value '%s'\n", label, s);
        __nucleor_str_free(s);
        return 1;
    }
    __nucleor_str_free(s);
    return 0;
}

int main(void) {
    int fail = 0;
    fail |= assert_owned_empty("substring_strict_null", __nucleor_str_substring_strict(0, 0, 0));
    fail |= assert_owned_empty("lower_null", __nucleor_str_to_lower(0));
    fail |= assert_owned_empty("upper_null", __nucleor_str_to_upper(0));
    fail |= assert_owned_empty("trim_null", __nucleor_str_trim(0));
    fail |= assert_owned_empty("file_missing", __nucleor_file_read_string("target/rtabi_s1_missing_file.txt"));
    fail |= assert_owned_empty("proc_capture_null", __nucleor_proc_capture_stdout(0));
    return fail;
}
"@ | Set-Content -LiteralPath $s1Probe -Encoding ASCII
$s1Exe = Join-Path $repo "target\rtabi_s1_owned_empty_probe.exe"
& $clang -O2 -fuse-ld=lld "-include" $alloc $s1Probe $runtime $processrt -o $s1Exe "-Wl,/STACK:16777216" | Out-Host
if ($LASTEXITCODE -ne 0) { Fail "failed to compile S1 owned-empty C probe" }
$s1Run = Run-ProcessCapture -Exe $s1Exe -Args @()
if ($s1Run.ExitCode -ne 0) {
    Fail "S1 owned-empty probe failed: $($s1Run.Output)"
}
Pass "S1 empty-string error paths return freeable heap strings"

Pass "runtime ABI audit slice complete"
