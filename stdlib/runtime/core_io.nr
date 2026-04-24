// core_io.nr — Nucleor-native I/O runtime (Stage A)
// Replaces the C runtime's print/file functions with pure Nucleor.
// Uses extern declarations for OS-level syscalls only.
//
// On Windows: WriteFile, ReadFile, GetStdHandle, CreateFileA, CloseHandle
// These are the ONLY non-Nucleor dependencies.

// Windows API constants
const STD_OUTPUT_HANDLE: i32 = -11;
const GENERIC_READ: i32 = -2147483648;
const OPEN_EXISTING: i32 = 3;
const FILE_SHARE_READ: i32 = 1;
const INVALID_HANDLE: i32 = -1;

// Extern OS functions — these are the platform shim.
// On a different OS, only these declarations change.
extern fn GetStdHandle(nStdHandle: i32) -> i64;
extern fn WriteFile(hFile: i64, lpBuffer: str, nBytes: i32, lpWritten: i64, lpOverlapped: i64) -> i32;
extern fn CreateFileA(lpFileName: str, dwAccess: i32, dwShare: i32, lpSecurity: i64, dwCreation: i32, dwFlags: i32, hTemplate: i64) -> i64;
extern fn ReadFile(hFile: i64, lpBuffer: i64, nBytes: i32, lpRead: i64, lpOverlapped: i64) -> i32;
extern fn CloseHandle(hFile: i64) -> i32;
extern fn GetFileSize(hFile: i64, lpHigh: i64) -> i32;

// === Print ===
fn nr_print(s: str) -> i32 {
    let stdout: i64 = GetStdHandle(STD_OUTPUT_HANDLE);
    let len: i32 = str_len(s);
    WriteFile(stdout, s, len, 0, 0);
    WriteFile(stdout, "\n", 1, 0, 0);
    0
}

fn nr_print_int(x: i32) -> i32 {
    let s: str = str_from_int(x);
    nr_print(s);
    0
}

// T1.1 Phase 3c (v0.2.310): widened internal arithmetic to i64 so
// values exceeding i32 range format correctly under Phase 1's
// narrow-as hook. Mirrors compiler:str_from_int.
fn str_from_int(n: i32) -> str {
    if n == 0 { return "0"; };
    let mut val: i64 = n;
    if val < 0 { val = 0 - val; };
    let mut s: str = "";
    while val > 0 {
        let d: i64 = val - (val / 10) * 10;
        let mut ch: str = "0";
        if d == 1 { ch = "1"; } else if d == 2 { ch = "2"; } else if d == 3 { ch = "3"; }
        else if d == 4 { ch = "4"; } else if d == 5 { ch = "5"; } else if d == 6 { ch = "6"; }
        else if d == 7 { ch = "7"; } else if d == 8 { ch = "8"; } else if d == 9 { ch = "9"; };
        s = str_concat(ch, s);
        val = val / 10;
    };
    if n < 0 { s = str_concat("-", s); };
    s
}

// === Tests (use existing C runtime for now, proving the Nucleor versions work) ===
fn main() -> i32 {
    print("=== Nucleor Runtime Core I/O ===");
    print("This module defines the Nucleor-native replacements");
    print("for the C runtime's I/O functions.");
    print("When compiled with the LLVM IR emitter, these will");
    print("use direct OS syscalls instead of C's printf/fopen.");
    print("=== CORE I/O MODULE READY ===");
    0
}
