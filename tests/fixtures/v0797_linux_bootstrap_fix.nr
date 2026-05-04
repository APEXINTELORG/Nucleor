// v0.7.94 smoke fixture — compile_error! guard: src_path exclusion.
// Pre-fix: the compile_error-bang textual pre-pass (added v0.7.88) fired
// on self-compilation of nucleor_s1_compiler.nr because the compiler
// source contains the search pattern in string literals and comments.
// On Linux the bootstrap (seed.ll -> bin/nucleor -> self-compile) always
// panicked at this check, making the entire Linux build pipeline broken.
// Post-fix: a src_path guard skips the check when the file ends with
// "nucleor_s1_compiler.nr". The halt still fires for all other user files
// that contain compile_error ! ( (v0788_compile_error_halt.nr remains
// a valid negative fixture).
//
// This fixture exercises the positive path: normal user code compiles
// and runs correctly.

fn add(a: i64, b: i64) -> i64 { return a + b; }

fn main() -> i64 {
    let x: i64 = add(10, 32);
    if x == 42 { return 0; };
    return 1;
}
