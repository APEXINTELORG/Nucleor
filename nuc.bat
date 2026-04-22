@echo off
rem nuc.bat — Nucleor CLI launcher (Windows)
rem
rem Resolves clang.exe and prepends its directory to PATH, then invokes
rem bin\nucleor.exe with all arguments passed through.
rem
rem Resolution order (first hit wins):
rem   1. %NUCLEOR_CLANG_PATH%        — explicit override (full path to clang.exe)
rem   2. %LLVM_SYS_180_PREFIX%\bin   — LLVM install pointer
rem   3. C:\Program Files\LLVM\bin   — default Chocolatey / installer location
rem   4. PATH                         — whatever the user already has

setlocal
set "NUC_ROOT=%~dp0"
set "NUC_BIN=%NUC_ROOT%bin\nucleor.exe"

if not exist "%NUC_BIN%" (
    echo nuc: bin\nucleor.exe not found at %NUC_BIN%
    echo nuc: re-bootstrap by running: nuc build compiler\nucleor_s1_compiler.nr -o bin\nucleor.exe
    exit /b 1
)

rem Resolve clang location
set "CLANG_DIR="
if defined NUCLEOR_CLANG_PATH (
    for %%I in ("%NUCLEOR_CLANG_PATH%") do set "CLANG_DIR=%%~dpI"
) else if defined LLVM_SYS_180_PREFIX (
    set "CLANG_DIR=%LLVM_SYS_180_PREFIX%\bin"
) else if exist "C:\Program Files\LLVM\bin\clang.exe" (
    set "CLANG_DIR=C:\Program Files\LLVM\bin"
)

if defined CLANG_DIR (
    set "PATH=%CLANG_DIR%;%PATH%"
)

"%NUC_BIN%" %*
exit /b %ERRORLEVEL%
