// rods/lsp — LSP 3.17 protocol
// envelope + message-type tag surface (rod-only).
//
// The full V1.16 ship is a standalone `nucleor-lsp.exe` JSON-RPC
// daemon. This rod provides the canonical message-tag surface + minimal
// JSON-RPC envelope helpers so adopters / tools can compose
// LSP messages today, ahead of the daemon binary.
//
// Sister to the audit-channel work in v0.8.5-v0.8.15 — same
// "stdlib first, daemon binary later" pattern. The compiler-
// side `--lsp-mode` flag is deferred until the daemon ship
// builds out.
//
// Workflow today:
//
//   import "stdlib/rods/lsp.nr"
//
//   let kind: i64 = lsp_msg_kind_diagnostic();
//   let name: str = lsp_msg_kind_name(kind);   // "Diagnostic"
//   let sev: i64 = lsp_severity_error();
//   let env: str = lsp_jsonrpc_envelope("textDocument/diagnostic",
//                                       "{\"uri\":\"file:///x.nr\"}");

// =====================================================
// LSP method-name tags (stable IDs).
// =====================================================
fn lsp_msg_kind_did_open()        -> i64 { return 1; }
fn lsp_msg_kind_did_change()      -> i64 { return 2; }
fn lsp_msg_kind_did_close()       -> i64 { return 3; }
fn lsp_msg_kind_did_save()        -> i64 { return 4; }
fn lsp_msg_kind_diagnostic()      -> i64 { return 5; }
fn lsp_msg_kind_hover()           -> i64 { return 6; }
fn lsp_msg_kind_definition()      -> i64 { return 7; }
fn lsp_msg_kind_completion()      -> i64 { return 8; }
fn lsp_msg_kind_formatting()      -> i64 { return 9; }
fn lsp_msg_kind_code_action()     -> i64 { return 10; }
fn lsp_msg_kind_initialize()      -> i64 { return 11; }
fn lsp_msg_kind_initialized()     -> i64 { return 12; }
fn lsp_msg_kind_shutdown()        -> i64 { return 13; }
fn lsp_msg_kind_exit()            -> i64 { return 14; }
fn lsp_msg_kind_unknown()         -> i64 { return 0; }

fn lsp_msg_kind_name(id: i64) -> str {
    if id == 1  { return "textDocument/didOpen"; };
    if id == 2  { return "textDocument/didChange"; };
    if id == 3  { return "textDocument/didClose"; };
    if id == 4  { return "textDocument/didSave"; };
    if id == 5  { return "textDocument/diagnostic"; };
    if id == 6  { return "textDocument/hover"; };
    if id == 7  { return "textDocument/definition"; };
    if id == 8  { return "textDocument/completion"; };
    if id == 9  { return "textDocument/formatting"; };
    if id == 10 { return "textDocument/codeAction"; };
    if id == 11 { return "initialize"; };
    if id == 12 { return "initialized"; };
    if id == 13 { return "shutdown"; };
    if id == 14 { return "exit"; };
    return "unknown";
}

// =====================================================
// LSP DiagnosticSeverity values (per LSP 3.17 §3.17.6).
// 1 = Error, 2 = Warning, 3 = Information, 4 = Hint.
// =====================================================
fn lsp_severity_error()       -> i64 { return 1; }
fn lsp_severity_warning()     -> i64 { return 2; }
fn lsp_severity_information() -> i64 { return 3; }
fn lsp_severity_hint()        -> i64 { return 4; }

fn lsp_severity_name(id: i64) -> str {
    if id == 1 { return "Error"; };
    if id == 2 { return "Warning"; };
    if id == 3 { return "Information"; };
    if id == 4 { return "Hint"; };
    return "Unknown";
}

// =====================================================
// LSP CompletionItemKind values (LSP 3.17 §3.17.16). Subset
// most relevant to a Nucleor LSP. Adopters extend by adding
// the LSP-spec integer directly.
// =====================================================
fn lsp_completion_kind_text()        -> i64 { return 1; }
fn lsp_completion_kind_method()      -> i64 { return 2; }
fn lsp_completion_kind_function()    -> i64 { return 3; }
fn lsp_completion_kind_field()       -> i64 { return 5; }
fn lsp_completion_kind_variable()    -> i64 { return 6; }
fn lsp_completion_kind_class()       -> i64 { return 7; }
fn lsp_completion_kind_interface()   -> i64 { return 8; }
fn lsp_completion_kind_module()      -> i64 { return 9; }
fn lsp_completion_kind_property()    -> i64 { return 10; }
fn lsp_completion_kind_keyword()     -> i64 { return 14; }
fn lsp_completion_kind_struct()      -> i64 { return 22; }
fn lsp_completion_kind_enum_member() -> i64 { return 20; }

// =====================================================
// JSON-RPC 2.0 envelope helpers. The LSP wire format is
// JSON-RPC 2.0 with a `Content-Length: N\r\n\r\n` header.
// =====================================================

// Build a JSON-RPC 2.0 notification (no `id` field). Used by
// server-originated messages like `textDocument/diagnostic`
// pushes.
fn lsp_jsonrpc_notification(method: str, params_json: str) -> str {
    let mut out: str = "{\"jsonrpc\":\"2.0\",\"method\":\"";
    out = str_concat(out, method);
    out = str_concat(out, "\",\"params\":");
    out = str_concat(out, params_json);
    out = str_concat(out, "}");
    return out;
}

// Build a JSON-RPC 2.0 request (with `id` field) for client
// → server bidirectional calls.
fn lsp_jsonrpc_request(id: i64, method: str, params_json: str) -> str {
    let mut out: str = "{\"jsonrpc\":\"2.0\",\"id\":";
    out = str_concat(out, str_from_int(id));
    out = str_concat(out, ",\"method\":\"");
    out = str_concat(out, method);
    out = str_concat(out, "\",\"params\":");
    out = str_concat(out, params_json);
    out = str_concat(out, "}");
    return out;
}

// Build a JSON-RPC 2.0 response.
fn lsp_jsonrpc_response(id: i64, result_json: str) -> str {
    let mut out: str = "{\"jsonrpc\":\"2.0\",\"id\":";
    out = str_concat(out, str_from_int(id));
    out = str_concat(out, ",\"result\":");
    out = str_concat(out, result_json);
    out = str_concat(out, "}");
    return out;
}

// Build a JSON-RPC 2.0 error response. code per LSP 3.17 §3.17:
//   -32700 ParseError, -32600 InvalidRequest, -32601 MethodNotFound,
//   -32602 InvalidParams, -32603 InternalError.
fn lsp_jsonrpc_error(id: i64, code: i64, message: str) -> str {
    let mut out: str = "{\"jsonrpc\":\"2.0\",\"id\":";
    out = str_concat(out, str_from_int(id));
    out = str_concat(out, ",\"error\":{\"code\":");
    out = str_concat(out, str_from_int(code));
    out = str_concat(out, ",\"message\":\"");
    out = str_concat(out, message);
    out = str_concat(out, "\"}}");
    return out;
}

// Wrap a JSON-RPC payload with the LSP `Content-Length` header.
// Used at the wire boundary when writing to stdout.
fn lsp_wire_envelope(jsonrpc_body: str) -> str {
    let n: i64 = str_len(jsonrpc_body);
    let mut out: str = "Content-Length: ";
    out = str_concat(out, str_from_int(n));
    out = str_concat(out, "\r\n\r\n");
    out = str_concat(out, jsonrpc_body);
    return out;
}

// =====================================================
// LSP error codes — convenience constants.
// =====================================================
fn lsp_error_parse_error()         -> i64 { return 0 - 32700; }
fn lsp_error_invalid_request()     -> i64 { return 0 - 32600; }
fn lsp_error_method_not_found()    -> i64 { return 0 - 32601; }
fn lsp_error_invalid_params()      -> i64 { return 0 - 32602; }
fn lsp_error_internal_error()      -> i64 { return 0 - 32603; }
fn lsp_error_server_not_initialized() -> i64 { return 0 - 32002; }
fn lsp_error_request_cancelled()   -> i64 { return 0 - 32800; }
fn lsp_error_content_modified()    -> i64 { return 0 - 32801; }

// =====================================================
// Position / Range builders (LSP §3.17.3 / §3.17.5).
// =====================================================
fn lsp_position(line: i64, character: i64) -> str {
    let mut out: str = "{\"line\":";
    out = str_concat(out, str_from_int(line));
    out = str_concat(out, ",\"character\":");
    out = str_concat(out, str_from_int(character));
    out = str_concat(out, "}");
    return out;
}

fn lsp_range(start_line: i64, start_char: i64, end_line: i64, end_char: i64) -> str {
    let mut out: str = "{\"start\":";
    out = str_concat(out, lsp_position(start_line, start_char));
    out = str_concat(out, ",\"end\":");
    out = str_concat(out, lsp_position(end_line, end_char));
    out = str_concat(out, "}");
    return out;
}

// Build a Diagnostic JSON value (LSP §3.17.6).
fn lsp_diagnostic(range_json: str, severity: i64, code: str, message: str) -> str {
    let mut out: str = "{\"range\":";
    out = str_concat(out, range_json);
    out = str_concat(out, ",\"severity\":");
    out = str_concat(out, str_from_int(severity));
    out = str_concat(out, ",\"code\":\"");
    out = str_concat(out, code);
    out = str_concat(out, "\",\"source\":\"nucleor\",\"message\":\"");
    out = str_concat(out, message);
    out = str_concat(out, "\"}");
    return out;
}
