// Error test: DeviceBuffer use-after-move should be caught by type checker
// Expected: type checker error about use of moved value

fn main() -> i32 {
    let buf: DeviceBuffer = device_alloc(1024, 0);
    device_free(buf);
    // buf has been moved (consumed by device_free), using it again is an error
    device_free(buf);
    0
}
