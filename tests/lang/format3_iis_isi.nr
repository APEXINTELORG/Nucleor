// v0.3.13 RFC-0028 phase 3 — format3_iis + format3_isi combos.
// Closes the str/int trio (sii/iss/sss/ssi/sis/iis/isi all
// ship now). Same wiring shape as the prior format3_*
// additions: ABI-table mapping in s1 + tools_suite, IR
// `declare ptr @__nucleor_format3_*`, runtime impl in
// nucleor_llvm_rt.c.

fn main() -> i32 {
    let s1: str = format3_iis("{}/{}: {}", 3, 10, "items");
    print(s1);
    let s2: str = format3_isi("{}: {} ({})", 7, "kind", 42);
    print(s2);
    print("OK format3_iis_isi");
    return 0;
}
