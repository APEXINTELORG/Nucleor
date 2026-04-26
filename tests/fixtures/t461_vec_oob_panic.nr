// t461_vec_oob_panic.nr -- v0.3.200 regression fixture (positive case).
//
// Pre-v0.3.200 the runtime helpers __nucleor_vec_get and __nucleor_vec_set
// silently returned 0 / no-op'd on OOB indexing. This hid real adopter
// bugs: a stale index, an off-by-one walk, or a wrong-len assumption all
// quietly produced 0 in user code, and downstream computations carried
// the silent zero forward as if it were valid data — a silent miscompute
// hazard.
//
// Fix (v0.3.200): Vec OOB now PANICs by default with the offending index
// and the actual length in the message:
//
//   PANIC: vec_get OOB: index 10, len 3 (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)
//
// Adopters porting old code that depended on silent-zero can opt back in
// via the env var `NUCLEOR_VEC_OOB_LENIENT=1`.
//
// This fixture exercises in-bounds reads and writes (the common case)
// and verifies the silent path never triggers a false PANIC. The
// negative case (deliberate OOB) is in `tests/fixtures/probe_vec_oob.nr`
// and is verified manually (default exit 1 with PANIC line; lenient
// returns 0).

fn main() -> i64 {
    let mut v: Vec<i64> = vec![10, 20, 30];
    let mut s: i64 = 0;
    let mut i: i64 = 0;
    while i < 3 {
        s = s + v[i];
        i = i + 1;
    };
    v[0] = 100;
    v[2] = 200;
    println!("{}", s);          // 60
    println!("{}", v[0]);       // 100
    println!("{}", v[1]);       // 20
    println!("{}", v[2]);       // 200
    return 0;
}
