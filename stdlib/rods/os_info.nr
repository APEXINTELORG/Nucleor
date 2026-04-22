// =====================================================
// rods/os_info — OS family detection + pointer-width queries
// =====================================================
// Import: import "stdlib/rods/os_info.nr"
//
// Newer additions to the OS interface (existing rods/os.nr provides
// getenv/getpid/exit/getcwd; this rod adds family detection and
// portable env mutation).
// =====================================================

// ---- OS family ----
// Tag: 1=Win, 2=Linux, 3=Darwin, 4=BSD, 0=unknown.
fn os_family_tag() -> i64 { return os_family(); }

fn os_is_windows() -> i64 { if os_family() == 1 { return 1; }; return 0; }
fn os_is_linux() -> i64 { if os_family() == 2 { return 1; }; return 0; }
fn os_is_macos() -> i64 { if os_family() == 3 { return 1; }; return 0; }
fn os_is_bsd() -> i64 { if os_family() == 4 { return 1; }; return 0; }
fn os_is_unix() -> i64 {
    let f: i64 = os_family();
    if f == 2 { return 1; };
    if f == 3 { return 1; };
    if f == 4 { return 1; };
    return 0;
}

fn os_family_name() -> str {
    let f: i64 = os_family();
    if f == 1 { return "windows"; };
    if f == 2 { return "linux"; };
    if f == 3 { return "macos"; };
    if f == 4 { return "bsd"; };
    return "unknown";
}

// ---- Pointer width ----
fn os_pointer_bits() -> i64 { return os_pointer_width(); }
fn os_is_64bit() -> i64 { if os_pointer_width() == 64 { return 1; }; return 0; }

// ---- Environment mutation (cross-platform) ----
fn os_env_set(name: str, value: str) -> i64 { return env_set(name, value); }
fn os_env_unset(name: str) -> i64 { return env_unset(name); }
