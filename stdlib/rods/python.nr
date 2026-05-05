// =====================================================
// rods/python — Embedded Python interop
// =====================================================
// Import: import "stdlib/rods/python.nr"
// Provides: py_available, py_init, py_exec, py_eval, py_call_str
// Uses dynamic loading — works even if Python isn't installed (returns errors)
// =====================================================

#cfile "python_rt.c"

extern fn rods_py_available() -> i64;
extern fn rods_py_init() -> i64;
extern fn rods_py_exec(code: str) -> i64;
extern fn rods_py_eval(expr: str) -> str;
extern fn rods_py_call_str(module_name: str, func_name: str, arg: str) -> str;
// R06-D2 Phase 1 (v0.8.273) — string-result reclaim hook for the
// heap copies returned by py_eval / py_call_str.
extern fn rods_py_free_str(s: str);

fn py_available() -> i64 {
    return rods_py_available();
}

fn py_init() -> i64 {
    return rods_py_init();
}

fn py_exec(code: str) -> i64 {
    return rods_py_exec(code);
}

fn py_eval(expr: str) -> str {
    return rods_py_eval(expr);
}

fn py_call_str(module_name: str, func_name: str, arg: str) -> str {
    return rods_py_call_str(module_name, func_name, arg);
}

// R06-D2 Phase 1 (v0.8.273) — string-result reclaim. Caller MUST
// pass a pointer returned by py_eval or py_call_str. The static
// "<error>" / "" fallbacks are safe (no-op). Null is safe.
fn py_free_str(s: str) { rods_py_free_str(s); }
