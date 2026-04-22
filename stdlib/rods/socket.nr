// =====================================================
// rods/socket — TCP/UDP networking
// =====================================================
// Import: import "stdlib/rods/socket.nr"
// Provides: TCP connect/listen/accept/send/recv/close;
//   UDP open/send/recv.
// =====================================================

#cfile "../runtime/socket_rt.c"

extern fn nuc_tcp_connect(host: str, port: i64) -> i64;
extern fn nuc_tcp_listen(port: i64, backlog: i64) -> i64;
extern fn nuc_tcp_accept(server: i64) -> i64;
extern fn nuc_tcp_send(h: i64, data: str, len: i64) -> i64;
extern fn nuc_tcp_recv(h: i64, max_len: i64) -> i64;
extern fn nuc_tcp_close(h: i64);
extern fn nuc_udp_open(port: i64) -> i64;
extern fn nuc_udp_send(h: i64, host: str, port: i64, data: str, len: i64) -> i64;
extern fn nuc_udp_recv(h: i64, max_len: i64) -> i64;
extern fn nuc_http_get(url: str) -> str;

fn tcp_connect(host: str, port: i64) -> i64 { return nuc_tcp_connect(host, port); }
fn tcp_listen(port: i64, backlog: i64) -> i64 { return nuc_tcp_listen(port, backlog); }
fn tcp_accept(server: i64) -> i64 { return nuc_tcp_accept(server); }
fn tcp_send(h: i64, data: str, len: i64) -> i64 { return nuc_tcp_send(h, data, len); }
fn tcp_recv(h: i64, max_len: i64) -> i64 { return nuc_tcp_recv(h, max_len); }
fn tcp_close(h: i64) { nuc_tcp_close(h); }
fn udp_open(port: i64) -> i64 { return nuc_udp_open(port); }
fn udp_send(h: i64, host: str, port: i64, data: str, len: i64) -> i64 { return nuc_udp_send(h, host, port, data, len); }
fn udp_recv(h: i64, max_len: i64) -> i64 { return nuc_udp_recv(h, max_len); }

// --- HTTP client (blocking, plaintext) ---
// http_get(url) returns the response body of an HTTP/1.0 GET. The URL must
// start with "http://"; HTTPS arrives in v0.4 with a TLS rod. Returns the
// empty string on connect failure.
fn http_get(url: str) -> str { return nuc_http_get(url); }
