// rods/fs_extras — verify the rod wrapper
import "stdlib/rods/fs_extras.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    if fsx_exists("README.md") != 1 { fail = fail + 1; print("FAIL exists"); };
    if fsx_is_file("README.md") != 1 { fail = fail + 1; print("FAIL is_file"); };
    if fsx_is_dir("docs") != 1 { fail = fail + 1; print("FAIL is_dir"); };

    if fsx_size("README.md") <= 0 { fail = fail + 1; print("FAIL size"); };

    let joined: str = fsx_join("docs", "rfcs");
    if str_eq(joined, "docs/rfcs") != 1 { fail = fail + 1; print("FAIL join"); };

    let bn: str = fsx_basename("a/b/c.txt");
    if str_eq(bn, "c.txt") != 1 { fail = fail + 1; print("FAIL basename"); };

    let ext: str = fsx_extension("README.md");
    if str_eq(ext, "md") != 1 { fail = fail + 1; print("FAIL extension"); };

    if fsx_has_extension("README.md", "md") != 1 { fail = fail + 1; print("FAIL has_extension yes"); };
    if fsx_has_extension("README.md", "txt") != 0 { fail = fail + 1; print("FAIL has_extension no"); };

    if fail == 0 { print("OK fs_extras"); return 0; };
    return 1;
}
