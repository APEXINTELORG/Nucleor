// v0.8.152 V1.16 Phase A1 dependency — raw N-byte stdin read
// smoke fixture.
//
// Adds `io_read_bytes(n)` rod fn + `rods_io_read_n_bytes(n)`
// runtime helper. Required by Phase A1 of the LSP server: LSP
// base protocol frames JSON-RPC bodies with a Content-Length
// header followed by exactly N body bytes. The existing
// `io_read_line` strips newlines and breaks on LF, which
// truncates any JSON body that embeds a `\n` inside a string.
//
// This fixture verifies the surface compiles + links. Real
// behavioral verification requires piped stdin which is harder
// to do from a unit fixture; integration verification will be
// part of the Phase A1 LSP daemon ship.
//
// Note: calling io_read_bytes() inside a fixture without piped
// stdin would block. We only DECLARE-and-deadcode the call;
// the binary returns rc=0 to lock the build path.
//
// Expected: rc=0 (compiles, no runtime call).

import "stdlib/rods/io.nr"

fn never_called() -> str {
    return io_read_bytes(0);
}

fn main() -> i64 {
    return 0;
}
