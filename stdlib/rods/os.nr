// =====================================================
// rods/os — Operating system interface
// =====================================================
// Import: import "stdlib/rods/os.nr"
// Provides: os_getenv, os_exit, os_getcwd, os_getpid, os_system
// =====================================================

#cfile "os_rt.c"

extern fn rods_os_getenv(name: str) -> str;
extern fn rods_os_exit(code: i32);
extern fn rods_os_getcwd() -> str;
extern fn rods_os_getpid() -> i64;

fn os_getenv(name: str) -> str {
    return rods_os_getenv(name);
}

fn os_exit(code: i64) {
    rods_os_exit(code);
}

fn os_getcwd() -> str {
    return rods_os_getcwd();
}

fn os_getpid() -> i64 {
    return rods_os_getpid();
}

fn os_system(cmd: str) -> i64 {
    return system(cmd);
}
