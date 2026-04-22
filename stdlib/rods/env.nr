// =====================================================
// rods/env — Environment variable utilities
// =====================================================
// Import: import "stdlib/rods/env.nr"
// Provides: env_get, env_has, env_require
// Note: Uses the same C FFI as os.nr (rods_os_getenv)
// =====================================================

#cfile "os_rt.c"

extern fn rods_os_getenv(name: str) -> str;
extern fn rods_os_exit(code: i32);

// Get an environment variable value, returns "" if not set
fn env_get(name: str) -> str {
    return rods_os_getenv(name);
}

// Check if an environment variable is set (non-empty)
fn env_has(name: str) -> i64 {
    let val: str = rods_os_getenv(name);
    if str_len(val) > 0 { return 1; };
    return 0;
}

// Get an environment variable or exit with error if missing
fn env_require(name: str) -> str {
    let val: str = rods_os_getenv(name);
    if str_len(val) == 0 {
        let mut sb: i64 = sb_new();
        sb_append(sb, "ERROR: required environment variable '");
        sb_append(sb, name);
        sb_append(sb, "' is not set");
        print(sb_to_str(sb));
        rods_os_exit(1);
    };
    return val;
}
