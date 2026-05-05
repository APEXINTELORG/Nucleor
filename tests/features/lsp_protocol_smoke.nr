// v0.8.153 V1.16 LSP Phase A1 main work — LSP base protocol
// daemon smoke fixture (lifecycle marker only).
//
// The actual daemon is `bin/nucleor-lsp.exe`, built from
// `compiler/nucleor_lsp.nr`. Behavioral verification is via
// piped JSON-RPC payloads (PowerShell + bin/nucleor-lsp.exe;
// integration test in CHANGELOG demonstrates initialize +
// shutdown + exit lifecycle works end-to-end).
//
// This .nr file exists as the fixture-mapping marker for the
// CHANGELOG entry and to lock that the build path completes.
// Behavioral asserts on a stdin-loop daemon are out of scope
// for in-process fixtures.
//
// Phase A1 scope (this ship):
//   - Reads Content-Length-framed JSON-RPC over stdin.
//   - Dispatches initialize / shutdown / exit on the daemon side.
//   - Emits proper JSON-RPC 2.0 responses with Content-Length
//     framing on stdout.
//   - Returns MethodNotFound (-32601) for any other method with
//     an id (notifications without id are silently acked).
//
// Phase A2 (deferred):
//   - Forwards diagnostic requests to `nucleor.exe --lsp-mode
//     --emit-diagnostics-json <file>` per request.
//   - Wires textDocument/didOpen, didChange, didClose to file
//     state tracking.
//
// Expected: rc=0.

fn main() -> i64 {
    return 0;
}
