// v0836 C-16 - channel close semantics smoke.
//
// Locks explicit close semantics for the concurrency rod channel wrapper:
// buffered values remain readable, sends after close are ignored, and recv
// on a closed empty channel returns 0 instead of blocking forever.

import "stdlib/rods/concurrency.nr"

fn check_channel_close_drains_buffer() -> i64 {
    let ch: i64 = conc_channel(4);
    conc_send(ch, 11);
    conc_send(ch, 22);
    if conc_channel_len(ch) != 2 { return 1; };
    if conc_channel_is_closed(ch) != 0 { return 2; };
    conc_channel_close(ch);
    if conc_channel_is_closed(ch) != 1 { return 4; };
    if conc_recv(ch) != 11 { return 8; };
    if conc_recv(ch) != 22 { return 16; };
    if conc_channel_len(ch) != 0 { return 32; };
    return 0;
}

fn check_send_after_close_is_noop() -> i64 {
    let ch: i64 = conc_channel(1);
    conc_channel_close(ch);
    conc_send(ch, 99);
    if conc_channel_len(ch) != 0 { return 64; };
    if conc_recv(ch) != 0 { return 128; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_channel_close_drains_buffer();
    fails = fails + check_send_after_close_is_noop();
    return fails;
}
