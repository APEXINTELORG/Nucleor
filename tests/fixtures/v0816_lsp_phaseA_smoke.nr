// v0.8.16 V1.16 SPEC-LSP-server Phase A smoke fixture — LSP
// 3.17 protocol envelope + message-tag surface. Validates:
//   - 14 method-name tags + name lookup
//   - 4 DiagnosticSeverity values + name
//   - 12 CompletionItemKind values
//   - JSON-RPC notification / request / response / error
//     envelope shapes
//   - Wire envelope wraps with Content-Length header
//   - Position / Range / Diagnostic builders produce valid
//     JSON shapes (size sanity)
import "stdlib/rods/lsp.nr"

fn main() -> i64 {
    // Method-name tags.
    if lsp_msg_kind_did_open() != 1 { return 1; };
    if lsp_msg_kind_diagnostic() != 5 { return 2; };
    if lsp_msg_kind_initialize() != 11 { return 3; };
    if str_eq(lsp_msg_kind_name(1), "textDocument/didOpen") == 0 { return 4; };
    if str_eq(lsp_msg_kind_name(11), "initialize") == 0 { return 5; };
    if str_eq(lsp_msg_kind_name(99), "unknown") == 0 { return 6; };

    // DiagnosticSeverity.
    if lsp_severity_error() != 1 { return 7; };
    if lsp_severity_hint() != 4 { return 8; };
    if str_eq(lsp_severity_name(2), "Warning") == 0 { return 9; };

    // CompletionItemKind.
    if lsp_completion_kind_function() != 3 { return 10; };
    if lsp_completion_kind_struct() != 22 { return 11; };

    // JSON-RPC notification.
    let n: str = lsp_jsonrpc_notification("textDocument/didOpen", "{\"uri\":\"file:///x\"}");
    if str_contains(n, "\"jsonrpc\":\"2.0\"") == 0 { return 12; };
    if str_contains(n, "\"method\":\"textDocument/didOpen\"") == 0 { return 13; };
    if str_contains(n, "\"id\"") == 1 { return 14; };  // notifications have no id

    // JSON-RPC request.
    let r: str = lsp_jsonrpc_request(7, "textDocument/hover", "{}");
    if str_contains(r, "\"id\":7") == 0 { return 15; };
    if str_contains(r, "\"method\":\"textDocument/hover\"") == 0 { return 16; };

    // JSON-RPC response.
    let resp: str = lsp_jsonrpc_response(7, "{\"contents\":\"fn foo\"}");
    if str_contains(resp, "\"result\":") == 0 { return 17; };

    // JSON-RPC error.
    let err: str = lsp_jsonrpc_error(7, lsp_error_invalid_params(), "missing uri");
    if str_contains(err, "\"code\":-32602") == 0 { return 18; };
    if str_contains(err, "\"message\":\"missing uri\"") == 0 { return 19; };

    // Wire envelope.
    let wire: str = lsp_wire_envelope(n);
    if str_contains(wire, "Content-Length: ") == 0 { return 20; };

    // Position / Range / Diagnostic.
    let pos: str = lsp_position(5, 12);
    if str_contains(pos, "\"line\":5") == 0 { return 21; };
    if str_contains(pos, "\"character\":12") == 0 { return 22; };

    let rng: str = lsp_range(0, 0, 1, 10);
    if str_contains(rng, "\"start\":") == 0 { return 23; };
    if str_contains(rng, "\"end\":") == 0 { return 24; };

    let diag: str = lsp_diagnostic(rng, lsp_severity_error(), "TYP-005", "undefined fn");
    if str_contains(diag, "\"severity\":1") == 0 { return 25; };
    if str_contains(diag, "\"code\":\"TYP-005\"") == 0 { return 26; };
    if str_contains(diag, "\"source\":\"nucleor\"") == 0 { return 27; };

    // Error code constants.
    if lsp_error_parse_error() != 0 - 32700 { return 28; };
    if lsp_error_method_not_found() != 0 - 32601 { return 29; };

    return 0;
}
