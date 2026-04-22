// =====================================================
// rods/log — Structured logging with severity levels
// =====================================================
// Import: import "stdlib/rods/log.nr"
// Provides: log_debug, log_info, log_warn, log_error, log_fatal,
//   log_set_level, LOG_DEBUG, LOG_INFO, LOG_WARN, LOG_ERROR, LOG_FATAL
// =====================================================

// Log levels
fn LOG_DEBUG() -> i64 { return 0; }
fn LOG_INFO() -> i64 { return 1; }
fn LOG_WARN() -> i64 { return 2; }
fn LOG_ERROR() -> i64 { return 3; }
fn LOG_FATAL() -> i64 { return 4; }

// Global log level — stored as a 1-element vec for mutability across calls
fn log_level_store() -> Vec<i32> {
    let mut v: Vec<i32> = Vec::new();
    v.push(1);
    return v;
}

fn log_set_level(store: Vec<i32>, level: i64) {
    vec_set(store, 0, level);
}

fn log_get_level(store: Vec<i32>) -> i64 {
    return store.get(0);
}

fn log_emit(store: Vec<i32>, level: i64, prefix: str, msg: str) {
    if level < log_get_level(store) { return; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "[");
    sb_append(sb, prefix);
    sb_append(sb, "] ");
    sb_append(sb, msg);
    print(sb_to_str(sb));
}

fn log_debug(store: Vec<i32>, msg: str) {
    log_emit(store, 0, "DEBUG", msg);
}

fn log_info(store: Vec<i32>, msg: str) {
    log_emit(store, 1, "INFO ", msg);
}

fn log_warn(store: Vec<i32>, msg: str) {
    log_emit(store, 2, "WARN ", msg);
}

fn log_error(store: Vec<i32>, msg: str) {
    log_emit(store, 3, "ERROR", msg);
}

fn log_fatal(store: Vec<i32>, msg: str) {
    log_emit(store, 4, "FATAL", msg);
}

// Convenience: log with key=value context
fn log_info_kv(store: Vec<i32>, msg: str, key: str, val: str) {
    let mut sb: i64 = sb_new();
    sb_append(sb, msg);
    sb_append(sb, " ");
    sb_append(sb, key);
    sb_append(sb, "=");
    sb_append(sb, val);
    log_info(store, sb_to_str(sb));
}

fn log_error_kv(store: Vec<i32>, msg: str, key: str, val: str) {
    let mut sb: i64 = sb_new();
    sb_append(sb, msg);
    sb_append(sb, " ");
    sb_append(sb, key);
    sb_append(sb, "=");
    sb_append(sb, val);
    log_error(store, sb_to_str(sb));
}
