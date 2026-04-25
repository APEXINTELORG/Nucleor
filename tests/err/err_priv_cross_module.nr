// EXPECT: link error — call to private fn from another module rejected.
// T1.5c (v0.2.342) resolver-layer privatization. lib_optin.nr has a
// `pub fn` so opt-in privatization is active there. lib_helper is
// non-pub → renamed inside lib_optin.nr to __priv_<file_id>__lib_helper.
// This file calls `lib_helper` (unmangled), which finds no symbol →
// clang link fails with "use of undefined value '@lib_helper'".
// T1.5d will turn this into a friendly compile-time MOD-003 diagnostic.
import "../smoke/t15c_pkg/lib_optin.nr";

fn main() -> i64 {
    let v: i64 = lib_helper();
    return v;
}
