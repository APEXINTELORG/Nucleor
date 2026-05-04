// rods/replay — RFC-0056 Phase A: deterministic-replay event
// log + handle surface (rod-only).
//
// The full RFC-0056 ship adds language-level
// `replay { rng_seed, deterministic, kernel_version, log_path }
// { ... }` block with PRNG hijack + GPU determinism flag +
// sensor/actuator log + model-hash assertion (~500 LOC compiler
// + ~700 LOC stdlib + per-backend deterministic-kernel flags).
// Phase A (this rod + runtime) lands the canonical event-log
// surface adopters can use today: open a log, append events,
// close + replay.
//
// Sister to RFC-0052 / 53 / 54 / 55 Phase A landings — fifth
// V2 frontier Tier-B follow-on after the Tier-A close-out at
// v0.7.90.
//
// Workflow today:
//
//   import "stdlib/rods/replay.nr"
//
//   let h: i64 = replay_log_open("run.replay", replay_mode_record());
//   replay_log_rng_draw(h, 42);
//   replay_log_sensor_read(h, 1, 1234);
//   replay_log_actuator_write(h, 7, 99);
//   replay_log_close(h);
//
//   // On replay:
//   let h2: i64 = replay_log_open("run.replay", replay_mode_replay());
//   let n: i64 = replay_log_event_count(h2);
//   ...

#cfile "../runtime/replay_rt.c"

extern fn nuc_replay_open(path: str, mode_id: i64) -> i64;
extern fn nuc_replay_close(handle: i64) -> i64;
extern fn nuc_replay_event_count(handle: i64) -> i64;
extern fn nuc_replay_append(handle: i64, kind: i64, a: i64, b: i64) -> i64;
extern fn nuc_replay_event_kind(handle: i64, idx: i64) -> i64;
extern fn nuc_replay_event_a(handle: i64, idx: i64) -> i64;
extern fn nuc_replay_event_b(handle: i64, idx: i64) -> i64;
extern fn nuc_replay_assert_byte_identical(handle: i64, want_a: i64, want_b: i64) -> i64;

// =====================================================
// Replay mode tags.
// =====================================================
fn replay_mode_record()  -> i64 { return 1; }
fn replay_mode_replay()  -> i64 { return 2; }
fn replay_mode_audit()   -> i64 { return 3; }   // open log read-only, no replay-side checks

fn replay_mode_name(id: i64) -> str {
    if id == 1 { return "record"; };
    if id == 2 { return "replay"; };
    if id == 3 { return "audit"; };
    return "unknown";
}

// =====================================================
// Event-kind tags.
// Each event packs two i64 payload fields (a, b) — interpretation
// is per-kind:
//   RngDraw       (seed, value)
//   KernelLaunch  (kernel_id, version_hash)
//   SensorRead    (sensor_id, value_q1616 or raw bits)
//   ActuatorWrite (actuator_id, command_q1616 or raw bits)
//   ModelLoad     (model_id, weights_hash_lo)
//   Checkpoint    (checkpoint_id, byte_count)
// =====================================================
fn replay_event_rng_draw()       -> i64 { return 1; }
fn replay_event_kernel_launch()  -> i64 { return 2; }
fn replay_event_sensor_read()    -> i64 { return 3; }
fn replay_event_actuator_write() -> i64 { return 4; }
fn replay_event_model_load()     -> i64 { return 5; }
fn replay_event_checkpoint()     -> i64 { return 6; }

fn replay_event_kind_name(id: i64) -> str {
    if id == 1 { return "RngDraw"; };
    if id == 2 { return "KernelLaunch"; };
    if id == 3 { return "SensorRead"; };
    if id == 4 { return "ActuatorWrite"; };
    if id == 5 { return "ModelLoad"; };
    if id == 6 { return "Checkpoint"; };
    return "Unknown";
}

// =====================================================
// Open / close / introspect.
// =====================================================
fn replay_log_open(path: str, mode_id: i64) -> i64 {
    return nuc_replay_open(path, mode_id);
}

fn replay_log_close(handle: i64) -> i64 {
    return nuc_replay_close(handle);
}

fn replay_log_event_count(handle: i64) -> i64 {
    return nuc_replay_event_count(handle);
}

// =====================================================
// Append helpers — one per event kind, reaching for the
// canonical names that match the RFC-0056 RecordEvent enum.
// =====================================================
fn replay_log_rng_draw(handle: i64, seed: i64, value: i64) -> i64 {
    return nuc_replay_append(handle, replay_event_rng_draw(), seed, value);
}

fn replay_log_kernel_launch(handle: i64, kernel_id: i64, version_hash: i64) -> i64 {
    return nuc_replay_append(handle, replay_event_kernel_launch(), kernel_id, version_hash);
}

fn replay_log_sensor_read(handle: i64, sensor_id: i64, value: i64) -> i64 {
    return nuc_replay_append(handle, replay_event_sensor_read(), sensor_id, value);
}

fn replay_log_actuator_write(handle: i64, actuator_id: i64, command: i64) -> i64 {
    return nuc_replay_append(handle, replay_event_actuator_write(), actuator_id, command);
}

fn replay_log_model_load(handle: i64, model_id: i64, weights_hash_lo: i64) -> i64 {
    return nuc_replay_append(handle, replay_event_model_load(), model_id, weights_hash_lo);
}

fn replay_log_checkpoint(handle: i64, checkpoint_id: i64, byte_count: i64) -> i64 {
    return nuc_replay_append(handle, replay_event_checkpoint(), checkpoint_id, byte_count);
}

// =====================================================
// Read-back accessors — for replay / audit mode.
// =====================================================
fn replay_log_event_kind(handle: i64, idx: i64) -> i64 {
    return nuc_replay_event_kind(handle, idx);
}

fn replay_log_event_a(handle: i64, idx: i64) -> i64 {
    return nuc_replay_event_a(handle, idx);
}

fn replay_log_event_b(handle: i64, idx: i64) -> i64 {
    return nuc_replay_event_b(handle, idx);
}

// =====================================================
// Replay-side assertion: returns 1 if (want_a, want_b) match
// the next un-consumed event in the log; 0 otherwise.
// Phase A: simple in-order consume; Phase B promotes to
// per-kind tolerance + structured `ReplayMismatch` diag.
// =====================================================
fn replay_log_assert_byte_identical(handle: i64, want_a: i64, want_b: i64) -> i64 {
    return nuc_replay_assert_byte_identical(handle, want_a, want_b);
}
