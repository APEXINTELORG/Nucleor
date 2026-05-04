// v0883 — RFC C-1 cancel_token smoke fixture
//
// Pre-fix (< v0.8.82): cancel_token_new / cancel_token_cancel /
// cancel_token_is_cancelled were compiler-declared (LLVM preamble
// emits the three `declare` lines) but had NO C-side implementation
// in nucleor_llvm_rt.c on either Win32 or POSIX. Result: linker bomb
// ("undefined symbol: __nucleor_cancel_token_new") on every host.
//
// Post-fix (v0.8.82): NCancelToken struct + three atomic-flag helpers
// added after the Win32/POSIX concurrency block in nucleor_llvm_rt.c.
// Win32 path uses InterlockedExchange64 / InterlockedCompareExchange64;
// POSIX path uses __sync_lock_test_and_set / __sync_val_compare_and_swap.
//
// Expected rc=1 (post - pre = 1 - 0).
fn main() -> i64 {
    let tok: i64 = cancel_token_new(0);
    let pre: i64 = cancel_token_is_cancelled(tok);
    cancel_token_cancel(tok);
    let post: i64 = cancel_token_is_cancelled(tok);
    return post - pre;
}
