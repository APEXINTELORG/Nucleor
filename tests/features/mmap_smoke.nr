// v0.8.230 stdlib/rods/mmap.nr first test coverage.
//
// Memory-mapped file I/O + named shared memory. Pre-v0.8.230:
// zero coverage on the standalone rod.
//
// Locks four invariants. The file is pre-populated via io_write_file
// because mmap_open returns 0 for empty files (CreateFileMapping
// minimum). Shared-memory APIs not exercised (named SHM has
// system-wide visibility risk on a CI host).
//
//   1. **Open returns valid handle** for an existing 16-byte file.
//   2. **mmap_size matches file size** — 16 bytes.
//   3. **write_f64 → sync → reopen → read_f64 round-trip** —
//      writes a known bit pattern at offset 0 and reads it back
//      after re-opening read-only.
//   4. **Open of nonexistent file in read-only mode returns 0** —
//      no crash.
//
// Expected: rc=0.

import "stdlib/rods/mmap.nr"
import "stdlib/rods/io.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_open_valid() -> i64 {
    let path: str = "target/mmap_smoke_open.bin";
    io_write_file(path, "0123456789ABCDEF");  // exactly 16 bytes
    let h: i64 = mmap_open(path, 0);
    if h == 0 { return 1; };
    mmap_close(h);
    return 0;
}

fn check_size_matches() -> i64 {
    let path: str = "target/mmap_smoke_size.bin";
    io_write_file(path, "0123456789ABCDEF");
    let h: i64 = mmap_open(path, 0);
    let s: i64 = mmap_size(h);
    mmap_close(h);
    if s != 16 { return 2; };
    return 0;
}

fn check_write_read_round_trip() -> i64 {
    let path: str = "target/mmap_smoke_rt.bin";
    io_write_file(path, "0123456789ABCDEF");

    // Open r/w, write a known f64 at offset 0
    let hw: i64 = mmap_open(path, 1);
    if hw == 0 { return 4; };
    mmap_write_f64(hw, 0, f64_to_bits(3.14159265358979));
    mmap_sync(hw);
    mmap_close(hw);

    // Reopen read-only and verify
    let hr: i64 = mmap_open(path, 0);
    let v: i64 = mmap_read_f64(hr, 0);
    mmap_close(hr);
    if close(v, f64_to_bits(3.14159265358979), 1e-12) != 1 { return 8; };
    return 0;
}

fn check_open_missing_returns_zero() -> i64 {
    let h: i64 = mmap_open("target/mmap_DOES_NOT_EXIST_xyzzy_8421.bin", 0);
    if h != 0 { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_open_valid();
    fails = fails + check_size_matches();
    fails = fails + check_write_read_round_trip();
    fails = fails + check_open_missing_returns_zero();
    return fails;
}
