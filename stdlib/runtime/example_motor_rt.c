// example_motor_rt.c — C side for examples/20_rt_motor_ffi.nr.
//
// Models a 1-DOF DC motor as a pure integrator:
//   encoder = encoder + torque_cmd  (each tick)
// Production code would memory-map peripheral register
// addresses (CAN bus, EtherCAT, raw GPIO, etc.); the API
// shape is the same.
//
// All three exported symbols match the corresponding
// `extern fn` declarations in the Nucleor source. The Nucleor
// caller annotates them with #[ffi_no_alloc] + #[ffi_no_panic]
// markers (RFC-0001 §3.5, shipped v0.3.24) so RT-005 doesn't
// fire from inside the #[deadline]-marked motor_step kernel.

#include <stdint.h>

static int64_t g_torque_cmd = 0;
static int64_t g_encoder    = 0;

int64_t host_motor_read_encoder(void) {
    g_encoder += g_torque_cmd;
    return g_encoder;
}

int64_t host_motor_write_torque(int64_t cmd) {
    g_torque_cmd = cmd;
    return 0;
}

int64_t host_get_clock_us(void) {
    // Production: read peripheral high-resolution timer.
    // Stub: monotonically increment so callers can compute
    // dt without falling into "always 0" false-positives.
    static int64_t fake_clock = 0;
    fake_clock += 100;
    return fake_clock;
}
