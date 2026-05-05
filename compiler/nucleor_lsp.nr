// nucleor-lsp — LSP server daemon, V1.16 Phase A1.
//
// Subprocess-mode LSP daemon per `docs/rfcs/SPEC-LSP-server.md`.
// Speaks LSP base protocol (JSON-RPC 2.0 over stdin/stdout with
// Content-Length-framed messages) on the daemon side. Per-
// request, the daemon (will, in a future Phase A2) spawn
// `nucleor.exe --lsp-mode --emit-diagnostics-json <file>` and
// forward results back to the LSP client.
//
// Phase A1 (this ship):
//   - Reads Content-Length-framed JSON-RPC messages on stdin.
//   - Parses JSON minimally (string-search for method + id).
//   - Dispatches on method:
//       initialize → returns server capabilities
//       initialized → notification, no response
//       shutdown → returns null result
//       exit → process exits
//       textDocument/didOpen, didChange, didClose → ack-only
//   - Frames responses with Content-Length header, writes to
//     stdout.
//
// Phase A2 (deferred): real diagnostic forwarding via per-
// request `nucleor.exe --lsp-mode --emit-diagnostics-json` spawn.
//
// Phase v1 (deferred): library-mode LSP — refactor compiler
// frontend, hold AST in memory, <10ms incremental diagnostics.

import "stdlib/rods/io.nr"

// Header parsing: read lines until blank, extract "Content-Length: N".
// Returns N or 0 on EOF / parse failure.
fn lsp_read_content_length() -> i64 {
    let mut n: i64 = 0;
    let mut got_blank: i64 = 0;
    while got_blank == 0 {
        let line: str = io_read_line();
        let llen: i64 = str_len(line);
        if llen == 0 {
            // Blank line marks end of headers.
            got_blank = 1;
        } else {
            // Look for "Content-Length: ".
            let needle: str = "Content-Length: ";
            let nlen: i64 = str_len(needle);
            if llen > nlen {
                let prefix: str = str_substring(line, 0, nlen);
                if str_eq(prefix, needle) == 1 {
                    let val: str = str_substring(line, nlen, llen);
                    n = str_to_int(val);
                };
            };
        };
        // EOF guard: if read_line returns "" before we saw a header,
        // treat as EOF and bail.
        if llen == 0 && n == 0 { return 0; };
    };
    return n;
}

// Match needle at position p in hay. Manual char-by-char
// comparison since str_eq_at_len is compiler-private.
fn lsp_match_at(hay: str, p: i64, needle: str, nlen: i64) -> i64 {
    let mut k: i64 = 0;
    while k < nlen {
        if str_char_at(hay, p + k) != str_char_at(needle, k) { return 0; };
        k = k + 1;
    };
    return 1;
}

// Find the first occurrence of `needle` in `hay`. Returns -1 if
// not found. Used as a minimal JSON probe (string-search the
// body for "method":"initialize" etc.).
fn lsp_find(hay: str, needle: str) -> i64 {
    let hlen: i64 = str_len(hay);
    let nlen: i64 = str_len(needle);
    if nlen <= 0 { return 0 - 1; };
    if hlen < nlen { return 0 - 1; };
    let mut i: i64 = 0;
    while i + nlen <= hlen {
        if lsp_match_at(hay, i, needle, nlen) == 1 {
            return i;
        };
        i = i + 1;
    };
    return 0 - 1;
}

// Extract the integer "id" field from a JSON-RPC body. Returns
// -1 if not found (request was a notification).
fn lsp_extract_id(body: str) -> i64 {
    let needle: str = "\"id\":";
    let pos: i64 = lsp_find(body, needle);
    if pos < 0 { return 0 - 1; };
    let nlen: i64 = str_len(needle);
    let blen: i64 = str_len(body);
    let mut p: i64 = pos + nlen;
    // Skip whitespace.
    while p < blen {
        let c: i64 = str_char_at(body, p);
        if c == 32 || c == 9 { p = p + 1; } else { break; };
    };
    // Read digits.
    let mut id: i64 = 0;
    let mut got_digit: i64 = 0;
    while p < blen {
        let c: i64 = str_char_at(body, p);
        if c >= 48 && c <= 57 {
            id = id * 10 + (c - 48);
            got_digit = 1;
            p = p + 1;
        } else { break; };
    };
    if got_digit == 0 { return 0 - 1; };
    return id;
}

// Send a Content-Length-framed JSON-RPC message to stdout.
fn lsp_send(body: str) {
    let blen: i64 = str_len(body);
    io_print(str_concat("Content-Length: ", str_concat(str_from_int(blen), "\r\n\r\n")));
    io_print(body);
}

fn lsp_capabilities_json() -> str {
    return "{\"textDocumentSync\":{\"openClose\":true,\"change\":1},\"hoverProvider\":false,\"definitionProvider\":false,\"completionProvider\":{\"triggerCharacters\":[\".\"]},\"codeActionProvider\":true,\"documentFormattingProvider\":true,\"diagnosticProvider\":{\"interFileDependencies\":false,\"workspaceDiagnostics\":false}}";
}

fn lsp_handle_initialize(id: i64) {
    let body: str = str_concat(
        str_concat("{\"jsonrpc\":\"2.0\",\"id\":", str_from_int(id)),
        str_concat(",\"result\":{\"capabilities\":", str_concat(lsp_capabilities_json(), ",\"serverInfo\":{\"name\":\"nucleor-lsp\",\"version\":\"v0.8.153-A1\"}}}"))
    );
    lsp_send(body);
}

fn lsp_handle_shutdown(id: i64) {
    let body: str = str_concat(
        str_concat("{\"jsonrpc\":\"2.0\",\"id\":", str_from_int(id)),
        ",\"result\":null}"
    );
    lsp_send(body);
}

fn main() -> i64 {
    let mut running: i64 = 1;
    while running == 1 {
        let n: i64 = lsp_read_content_length();
        if n <= 0 {
            // EOF or malformed framing — exit cleanly.
            running = 0;
        } else {
            let body: str = io_read_bytes(n);
            // Method dispatch. Probe for the most common method
            // strings; unknown methods get an error response if
            // they have an id, ack-only otherwise.
            let id: i64 = lsp_extract_id(body);
            if lsp_find(body, "\"method\":\"initialize\"") >= 0 && lsp_find(body, "\"method\":\"initialized\"") < 0 {
                if id >= 0 { lsp_handle_initialize(id); };
            } else if lsp_find(body, "\"method\":\"shutdown\"") >= 0 {
                if id >= 0 { lsp_handle_shutdown(id); };
            } else if lsp_find(body, "\"method\":\"exit\"") >= 0 {
                running = 0;
            } else if id >= 0 {
                // Unknown method with id — emit MethodNotFound error.
                let err_body: str = str_concat(
                    str_concat("{\"jsonrpc\":\"2.0\",\"id\":", str_from_int(id)),
                    ",\"error\":{\"code\":-32601,\"message\":\"MethodNotFound (Phase A1: only initialize/shutdown/exit dispatched)\"}}"
                );
                lsp_send(err_body);
            };
            // Notifications (no id) silently acked.
        };
    };
    return 0;
}
