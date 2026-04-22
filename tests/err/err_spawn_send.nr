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
