// v0.3.12 RFC-0028 phase 3 — format3_ssi + format3_sis combos.
// Both new entries follow the existing format2/format3 builtin
// path: compile-time ABI-table mapping in s1 + tools_suite,
// IR `declare ptr @__nucleor_format3_*`, runtime impl in
// nucleor_llvm_rt.c.

fn main() -> i32 {
    let s1: str = format3_ssi("[{}] {} = {}", "INFO", "iter", 7);
    print(s1);
    let s2: str = format3_sis("[{} {}] {}", "ERR", 42, "stack overflow");
    print(s2);
    print("OK format3_ssi_sis");
    return 0;
}
