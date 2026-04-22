// rods/serial — Serial port I/O
#cfile "../runtime/serial_rt.c"

extern fn nuc_serial_open(port: str, baud: i64) -> i64;
extern fn nuc_serial_write(h: i64, data: str, len: i64) -> i64;
extern fn nuc_serial_read(h: i64, max_len: i64) -> i64;
extern fn nuc_serial_close(h: i64);

fn serial_open(port: str, baud: i64) -> i64 { return nuc_serial_open(port, baud); }
fn serial_write(h: i64, data: str, len: i64) -> i64 { return nuc_serial_write(h, data, len); }
fn serial_read(h: i64, max_len: i64) -> i64 { return nuc_serial_read(h, max_len); }
fn serial_close(h: i64) { nuc_serial_close(h); }
