// observable_runtime.nr — Observable-by-default runtime for AI agents
// Phase 10: Auto-span emission for scope/spawn/tool calls.
//
// Every function call, scope entry, and tool invocation automatically
// emits structured trace events. This enables:
// 1. Full execution traces for debugging agent workflows
// 2. Performance profiling of tool calls
// 3. Audit trails for governance
// 4. Replay of agent executions
//
// Trace format: { "event": "...", "name": "...", "timestamp": N, "depth": N }

fn trace_enter(name: str, depth: i32) -> i32 {
    print(str_concat("{ \"event\": \"enter\", \"name\": \"", str_concat(name, str_concat("\", \"depth\": ", str_concat(str_from_int(depth), " }")))));
    0
}

fn trace_exit(name: str, depth: i32, result: i32) -> i32 {
    print(str_concat("{ \"event\": \"exit\", \"name\": \"", str_concat(name, str_concat("\", \"depth\": ", str_concat(str_from_int(depth), str_concat(", \"result\": ", str_concat(str_from_int(result), " }")))))));
    0
}

fn trace_tool_call(tool_name: str, input: str) -> i32 {
    print(str_concat("{ \"event\": \"tool_call\", \"tool\": \"", str_concat(tool_name, str_concat("\", \"input\": \"", str_concat(input, "\" }")))));
    0
}

fn trace_tool_result(tool_name: str, output: str) -> i32 {
    print(str_concat("{ \"event\": \"tool_result\", \"tool\": \"", str_concat(tool_name, str_concat("\", \"output\": \"", str_concat(output, "\" }")))));
    0
}

// Convert int to string (simple, positive only)
fn str_from_int(n: i32) -> str {
    if n == 0 { return "0"; };
    let mut val: i32 = n;
    let mut s: str = "";
    while val > 0 {
        let digit: i32 = val - (val / 10) * 10;
        let mut ch: str = "0";
        if digit == 1 { ch = "1"; }
        else if digit == 2 { ch = "2"; }
        else if digit == 3 { ch = "3"; }
        else if digit == 4 { ch = "4"; }
        else if digit == 5 { ch = "5"; }
        else if digit == 6 { ch = "6"; }
        else if digit == 7 { ch = "7"; }
        else if digit == 8 { ch = "8"; }
        else if digit == 9 { ch = "9"; };
        s = str_concat(ch, s);
        val = val / 10;
    };
    s
}

// === Demo: Traced agent workflow ===
fn agent_search(query: str) -> i32 {
    trace_enter("agent_search", 1);
    trace_tool_call("search", query);
    // Simulate search
    let results: i32 = 5;
    trace_tool_result("search", "5 results found");
    trace_exit("agent_search", 1, results);
    results
}

fn agent_analyze(data: i32) -> i32 {
    trace_enter("agent_analyze", 1);
    let score: i32 = data * 10;
    trace_exit("agent_analyze", 1, score);
    score
}

fn agent_respond(score: i32) -> i32 {
    trace_enter("agent_respond", 1);
    if score > 30 {
        trace_tool_call("send_message", "High confidence result");
    } else {
        trace_tool_call("send_message", "Low confidence - needs review");
    };
    trace_exit("agent_respond", 1, 0);
    0
}

fn run_agent_workflow() -> i32 {
    trace_enter("run_agent_workflow", 0);
    let results: i32 = agent_search("nucleor language features");
    let score: i32 = agent_analyze(results);
    agent_respond(score);
    trace_exit("run_agent_workflow", 0, score);
    score
}

fn main() -> i32 {
    print("================================================");
    print("  Observable Runtime — Agent Trace Demo");
    print("================================================");
    let result: i32 = run_agent_workflow();
    print("================================================");
    print("  Workflow complete. Final score:");
    print_int(result);
    print("================================================");
    0
}
