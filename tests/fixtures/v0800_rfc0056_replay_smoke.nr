// v0.8.0 RFC-0056 Phase A smoke fixture — deterministic-replay
// event log surface. Validates:
//   - Mode tags + name lookup
//   - Event-kind tags + name lookup
//   - Open / append (6 event kinds) / close round-trip
//   - Read-back via kind / a / b accessors
//   - assert_byte_identical consumes events in order
//   - mismatched assert returns 0
import "stdlib/rods/replay.nr"

fn main() -> i64 {
    // Mode tags.
    if replay_mode_record() != 1 { return 1; };
    if replay_mode_replay() != 2 { return 2; };
    if replay_mode_audit() != 3 { return 3; };
    if str_eq(replay_mode_name(1), "record") == 0 { return 4; };

    // Event-kind tags.
    if replay_event_rng_draw() != 1 { return 5; };
    if replay_event_kernel_launch() != 2 { return 6; };
    if replay_event_sensor_read() != 3 { return 7; };
    if replay_event_actuator_write() != 4 { return 8; };
    if replay_event_model_load() != 5 { return 9; };
    if replay_event_checkpoint() != 6 { return 10; };
    if str_eq(replay_event_kind_name(3), "SensorRead") == 0 { return 11; };

    // Open + append + close cycle.
    let h: i64 = replay_log_open("test.replay", replay_mode_record());
    if h < 0 { return 12; };

    if replay_log_event_count(h) != 0 { return 13; };

    replay_log_rng_draw(h, 42, 12345);
    replay_log_kernel_launch(h, 7, 99);
    replay_log_sensor_read(h, 1, 6553600);   // 100 in Q1.16
    replay_log_actuator_write(h, 11, 5);
    replay_log_model_load(h, 33, 0xABC);
    replay_log_checkpoint(h, 1, 4096);

    if replay_log_event_count(h) != 6 { return 14; };

    // Read-back via accessors.
    if replay_log_event_kind(h, 0) != replay_event_rng_draw() { return 15; };
    if replay_log_event_a(h, 0) != 42 { return 16; };
    if replay_log_event_b(h, 0) != 12345 { return 17; };

    if replay_log_event_kind(h, 2) != replay_event_sensor_read() { return 18; };
    if replay_log_event_a(h, 2) != 1 { return 19; };
    if replay_log_event_b(h, 2) != 6553600 { return 20; };

    if replay_log_event_kind(h, 5) != replay_event_checkpoint() { return 21; };
    if replay_log_event_b(h, 5) != 4096 { return 22; };

    replay_log_close(h);

    // Reopen + replay-side asserts.
    let h2: i64 = replay_log_open("test2.replay", replay_mode_record());
    replay_log_rng_draw(h2, 7, 100);
    replay_log_rng_draw(h2, 7, 200);
    replay_log_rng_draw(h2, 7, 300);

    if replay_log_assert_byte_identical(h2, 7, 100) != 1 { return 23; };
    if replay_log_assert_byte_identical(h2, 7, 200) != 1 { return 24; };
    // Mismatch should return 0 (still consumes the event).
    if replay_log_assert_byte_identical(h2, 99, 99) != 0 { return 25; };
    // No more events to consume.
    if replay_log_assert_byte_identical(h2, 0, 0) != 0 { return 26; };

    replay_log_close(h2);

    // Out-of-range read returns 0.
    let h3: i64 = replay_log_open("empty.replay", replay_mode_record());
    if replay_log_event_kind(h3, 999) != 0 { return 27; };
    replay_log_close(h3);

    return 0;
}
