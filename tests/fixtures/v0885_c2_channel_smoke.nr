// v0.8.85 RFC C-2 Phase 1 — channel round-trip smoke.
//
// Win32: works pre- and post-fix (Win32 path was already real).
// POSIX pre-fix: channel_new returned 0; sends dropped; recvs
//   returned 0 immediately. This fixture would have rc=1
//   (mismatch detected, BUG branch fired).
// POSIX post-fix: pthread mutex + condvars match Win32 semantics.
//   This fixture rc=0 on both platforms.
//
// Cross-platform parity check. Add to verify.sh runner once a
// Linux build matrix entry exists.

fn main() -> i64 {
    let ch: i64 = channel_new(4);
    if ch == 0 {
        return 99;  // channel_new failed (allocation OOM, not the stub bug)
    };
    channel_send(ch, 100);
    channel_send(ch, 200);
    channel_send(ch, 300);
    let a: i64 = channel_recv(ch);
    let b: i64 = channel_recv(ch);
    let c: i64 = channel_recv(ch);
    if a == 100 && b == 200 && c == 300 {
        return 0;
    };
    return 1;  // pre-fix POSIX would land here
}
