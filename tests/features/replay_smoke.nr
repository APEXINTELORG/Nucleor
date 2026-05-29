// v0.8.197 stdlib/rods/replay.nr first test coverage.
//
// RFC-0056 Phase A — deterministic-replay event log. Pre-
// v0.8.197: zero coverage on the runtime API.
//
// Locks five invariants:
//   1. Mode IDs stable: record=1, replay=2, audit=3.
//   2. Mode-name round-trip: name(1) == "record".
//   3. Event-kind IDs stable: rng_draw=1, kernel_launch=2,
//      sensor_read=3, actuator_write=4, model_load=5,
//      checkpoint=6.
//   4. Event-kind name round-trip: name(1) == "RngDraw".
//   5. Open + append + read-back: record-mode log accepts
//      events; event_count tracks; read accessors round-trip.
//
// Expected: rc=0.

import "stdlib/rods/replay.nr"
import "stdlib/rods/fs_extras.nr"

fn check_mode_ids() -> i64 {
    if replay_mode_record() != 1 { return 1; };
    if replay_mode_replay() != 2 { return 2; };
    if replay_mode_audit() != 3 { return 4; };
    return 0;
}

fn check_mode_names() -> i64 {
    if str_eq(replay_mode_name(1), "record") != 1 { return 8; };
    if str_eq(replay_mode_name(2), "replay") != 1 { return 16; };
    if str_eq(replay_mode_name(3), "audit") != 1 { return 32; };
    if str_eq(replay_mode_name(99), "unknown") != 1 { return 64; };
    return 0;
}

fn check_event_kind_ids() -> i64 {
    if replay_event_rng_draw() != 1 { return 128; };
    if replay_event_kernel_launch() != 2 { return 256; };
    if replay_event_sensor_read() != 3 { return 512; };
    if replay_event_actuator_write() != 4 { return 1024; };
    if replay_event_model_load() != 5 { return 2048; };
    if replay_event_checkpoint() != 6 { return 4096; };
    return 0;
}

fn check_event_kind_names() -> i64 {
    if str_eq(replay_event_kind_name(1), "RngDraw") != 1 { return 8192; };
    if str_eq(replay_event_kind_name(3), "SensorRead") != 1 { return 16384; };
    if str_eq(replay_event_kind_name(99), "Unknown") != 1 { return 32768; };
    return 0;
}

fn check_open_append_read_back() -> i64 {
    let path: str = "target/_replay_smoke.log";
    fsx_rm_file(path);
    let h: i64 = replay_log_open(path, replay_mode_record());
    // nuc_replay_open returns slot index in [0, MAX_LOGS); -1 on
    // table-full. Slot 0 is valid.
    if h < 0 { return 65536; };
    replay_log_rng_draw(h, 42, 1234);
    replay_log_sensor_read(h, 7, 9999);
    if replay_log_event_count(h) != 2 { replay_log_close(h); return 131072; };
    if replay_log_event_kind(h, 0) != replay_event_rng_draw() { replay_log_close(h); return 262144; };
    if replay_log_event_a(h, 0) != 42 { replay_log_close(h); return 524288; };
    if replay_log_event_b(h, 0) != 1234 { replay_log_close(h); return 1048576; };
    replay_log_close(h);
    fsx_rm_file(path);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_mode_ids();
    fails = fails + check_mode_names();
    fails = fails + check_event_kind_ids();
    fails = fails + check_event_kind_names();
    fails = fails + check_open_append_read_back();
    return fails;
}
