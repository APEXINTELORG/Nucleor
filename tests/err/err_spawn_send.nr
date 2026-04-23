// EXPECT: link error (false-positive negative test)
// compiler should fire concurrency check; actually link-fails on __nucleor_device_alloc/free v0.4 placeholders. v0.2.87 finding; v0.4 will tighten.
// Phase 7b: Spawn block should reject non-Send captured resources

fn main() -> i32 {
    let buf: DeviceBuffer = device_alloc(64, 0);
    scope {
        spawn {
            device_free(buf);
        }
    }
    0
}
