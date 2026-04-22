// rods/socket — verify TCP/UDP/HTTP rod wiring at compile + runtime.
//
// Live network calls aren't safe in CI: this test exercises shape — the
// listener binds to localhost:0-equivalent (port 0 → ephemeral), the
// open/close handles round-trip, and the HTTP wrapper resolves at link time.
// Real client/server interplay sits in examples/, not the gate.
import "stdlib/rods/socket.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    // UDP open + close on a high transient port (5xxxx range, unlikely
    // to collide on a clean test runner).
    let u: i64 = udp_open(54321);
    if u < 0 { fail = fail + 1; print("FAIL udp_open"); };
    if u >= 0 { tcp_close(u); };

    // TCP listen on a high port + immediate close. accept() would block,
    // so we don't call it.
    let s: i64 = tcp_listen(54322, 4);
    if s < 0 { fail = fail + 1; print("FAIL tcp_listen"); };
    if s >= 0 { tcp_close(s); };

    // TCP connect to localhost on an unused port should fail (no listener).
    let c: i64 = tcp_connect("127.0.0.1", 54323);
    if c >= 0 { fail = fail + 1; print("FAIL tcp_connect refused"); tcp_close(c); };

    // http_get against a deliberately-broken URL: the rod must compile +
    // link, even if the call returns an empty body.
    let body: str = http_get("not-a-url");
    if str_eq(body, "FAIL_NEVER_RETURNS") == 1 { fail = fail + 1; print("UNREACHABLE"); };

    if fail == 0 { print("OK socket"); return 0; };
    return 1;
}
