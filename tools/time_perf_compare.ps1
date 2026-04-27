Stop-Process -Name nucleor*,clang* -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Remove-Item -Recurse -Force .nuc_cache,target -ErrorAction SilentlyContinue

$sw1 = [Diagnostics.Stopwatch]::StartNew()
& ./bin/nucleor.exe emit compiler/nucleor_s1_compiler.nr -o nucleor_emit_only 2>&1 | Out-Null
$sw1.Stop()
Write-Host ("emit only:     " + [math]::Round($sw1.Elapsed.TotalSeconds, 2) + "s")

$sw2 = [Diagnostics.Stopwatch]::StartNew()
& 'C:\Program Files\LLVM\bin\clang.exe' target/nucleor_emit_only.ll stdlib/runtime/nucleor_llvm_rt.c -o target/n_link_O0.exe '-Wno-override-module' '-Wl,/STACK:16777216' 2>&1 | Out-Null
$sw2.Stop()
Write-Host ("clang link O0: " + [math]::Round($sw2.Elapsed.TotalSeconds, 2) + "s")

$sw3 = [Diagnostics.Stopwatch]::StartNew()
& 'C:\Program Files\LLVM\bin\clang.exe' -O2 target/nucleor_emit_only.ll stdlib/runtime/nucleor_llvm_rt.c -o target/n_link_O2.exe '-Wno-override-module' '-Wl,/STACK:16777216' 2>&1 | Out-Null
$sw3.Stop()
Write-Host ("clang link O2: " + [math]::Round($sw3.Elapsed.TotalSeconds, 2) + "s")

# Also time the resulting binaries on a workload (compile a small test fixture)
if (Test-Path target/n_link_O0.exe) {
    $sw4 = [Diagnostics.Stopwatch]::StartNew()
    & target/n_link_O0.exe build tests/fixtures/t459_f64_literal_precision.nr -o /tmp/test_O0 2>&1 | Out-Null
    $sw4.Stop()
    Write-Host ("workload O0:   " + [math]::Round($sw4.Elapsed.TotalSeconds, 2) + "s")
}

if (Test-Path target/n_link_O2.exe) {
    $sw5 = [Diagnostics.Stopwatch]::StartNew()
    & target/n_link_O2.exe build tests/fixtures/t459_f64_literal_precision.nr -o /tmp/test_O2 2>&1 | Out-Null
    $sw5.Stop()
    Write-Host ("workload O2:   " + [math]::Round($sw5.Elapsed.TotalSeconds, 2) + "s")
}
