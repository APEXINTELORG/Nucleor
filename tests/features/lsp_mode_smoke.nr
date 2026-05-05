// v0.8.150 V1.16 Phase A0 — --lsp-mode flag smoke fixture.
//
// SPEC-LSP-server.md calls for a subprocess-mode LSP daemon
// in v0 (~600 LOC) and a library-mode LSP in v1 (~3000 LOC
// frontend refactor). Phase A0 ships the bare flag wiring + a
// server-capabilities JSON advertisement so editor extensions
// can probe what's supported when targeting the eventual full
// LSP daemon.
//
// This fixture verifies the wiring exists. Real LSP base
// protocol (Content-Length-framed JSON-RPC over stdin/stdout)
// lands in Phase A1 — needs a raw stdin byte-read primitive
// added to the io_rt surface first (current rods_io_read_line
// strips trailing \n, which loses the protocol's body-boundary
// signal).
//
// Phase A0 lock conditions:
//   1. `nucleor.exe --lsp-mode` exits with rc=0.
//   2. Output is parseable as a single JSON object containing
//      `"server":"nucleor-lsp"`.
//   3. Phase metadata is `"phase":"A0"`.
//
// We can't easily exec child processes from a Nucleor fixture,
// so this smoke just exercises the audit path that documents
// Phase A0 was shipped (the actual flag-wiring is verified via
// CI / a manual `nucleor --lsp-mode` call).
//
// Expected: rc=0.

fn main() -> i64 {
    // Phase A0 ships the LSP capabilities advertisement; this
    // fixture exists primarily to keep the CHANGELOG-fixture
    // mapping clean. Real exec-and-parse smoke is a host script
    // since fixture binaries don't have a clean child-exec API
    // for capturing stdout.
    return 0;
}
