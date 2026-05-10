// F-CONC-006: mutex recursion semantics must be explicit and portable.
//
// Nucleor currently chooses recursive mutex semantics: Windows uses
// CRITICAL_SECTION and POSIX initializes pthread mutexes with
// PTHREAD_MUTEX_RECURSIVE. This fixture catches any return to
// platform-divergent behavior where Windows passes but POSIX deadlocks.

import "stdlib/rods/concurrency.nr"

fn main() -> i64 {
    let m: i64 = conc_mutex();
    if m == 0 { return 1; };

    conc_lock(m);
    conc_lock(m);
    conc_unlock(m);
    conc_unlock(m);
    conc_mutex_free(m);
    return 0;
}
