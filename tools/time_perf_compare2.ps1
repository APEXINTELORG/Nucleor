Stop-Process -Name nucleor*,clang* -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

# Use the previously emitted .ll (already built) but link with O2 to get an
# optimized compiler binary, then measure how long it takes to do an emit.
& 'C:\Program Files\LLVM\bin\clang.exe' -O2 target/nucleor_emit_only.ll stdlib/runtime/nucleor_llvm_rt.c -o bin/nucleor_O2.exe '-Wno-override-module' '-Wl,/STACK:16777216' 2>&1 | Out-Null

# Now time the O2-built compiler doing an emit
Remove-Item -Recurse -Force .nuc_cache,target -ErrorAction SilentlyContinue
$sw1 = [Diagnostics.Stopwatch]::StartNew()
& bin/nucleor_O2.exe emit compiler/nucleor_s1_compiler.nr -o nuc_O2_emit 2>&1 | Out-Null
$sw1.Stop()
Write-Host ("O2-built compiler emit:  " + [math]::Round($sw1.Elapsed.TotalSeconds, 2) + "s")

# Compare to baseline (current bin/nucleor.exe was built with O0)
Remove-Item -Recurse -Force .nuc_cache,target -ErrorAction SilentlyContinue
$sw2 = [Diagnostics.Stopwatch]::StartNew()
& bin/nucleor.exe emit compiler/nucleor_s1_compiler.nr -o nuc_O0_emit 2>&1 | Out-Null
$sw2.Stop()
Write-Host ("O0-built compiler emit:  " + [math]::Round($sw2.Elapsed.TotalSeconds, 2) + "s")

$speedup = [math]::Round($sw2.Elapsed.TotalSeconds / $sw1.Elapsed.TotalSeconds, 2)
Write-Host ("speedup:                 " + $speedup + "x")
