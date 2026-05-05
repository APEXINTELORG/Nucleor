// v0.8.122 stdlib/rods/fs.nr first test coverage.
//
// Per the zero-coverage rod survey, fs.nr (file existence /
// type / size / rename / remove / read / write / path
// helpers) had no existing tests. Silent regressions in path
// parsing or write/read round-trip would corrupt every adopter
// I/O pipeline.
//
// This fixture sticks to in-memory path helpers + a write/read
// round-trip in target/_fs_smoke_tmp/ (cleaned at end). Avoids
// asserting against any pre-existing file layout.
//
// Locks:
//   1. fs_path_join joins two segments with a separator.
//   2. fs_path_ext extracts the extension (with dot or empty).
//   3. fs_path_stem extracts the filename without extension.
//   4. fs_path_parent extracts the directory portion.
//   5. fs_path_filename extracts the leaf component.
//   6. write + exists + is_file + size + read round-trip a known
//      string. is_dir returns 0 for a file.
//   7. remove deletes; subsequent exists returns 0.
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/fs.nr"

fn check_path_helpers() -> i64 {
    if str_eq(fs_path_ext("foo.txt"), ".txt") != 1 { return 1; };
    if str_eq(fs_path_ext("foo"), "") != 1 { return 2; };
    if str_eq(fs_path_stem("foo.txt"), "foo") != 1 { return 4; };
    if str_eq(fs_path_filename("a/b/c.txt"), "c.txt") != 1 { return 8; };
    let parent: str = fs_path_parent("a/b/c.txt");
    // Accept either "a/b" or "a\\b" depending on host
    if str_eq(parent, "a/b") != 1 && str_eq(parent, "a\\b") != 1 { return 16; };
    let joined: str = fs_path_join("a", "b");
    if str_eq(joined, "a/b") != 1 && str_eq(joined, "a\\b") != 1 { return 32; };
    return 0;
}

fn check_write_read_round_trip() -> i64 {
    let path: str = "target/_fs_smoke_tmp.txt";
    let payload: str = "hello fs round-trip";
    fs_write(path, payload);
    if fs_exists(path) != 1 { return 64; };
    if fs_is_file(path) != 1 { return 128; };
    if fs_is_dir(path) != 0 { return 256; };
    let sz: i64 = fs_size(path);
    if sz != str_len(payload) { return 512; };
    let got: str = fs_read(path);
    if str_eq(got, payload) != 1 { return 1024; };
    return 0;
}

fn check_remove() -> i64 {
    let path: str = "target/_fs_smoke_tmp_rm.txt";
    fs_write(path, "ephemeral");
    if fs_exists(path) != 1 { return 2048; };
    fs_remove(path);
    if fs_exists(path) != 0 { return 4096; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_path_helpers();
    fails = fails + check_write_read_round_trip();
    fails = fails + check_remove();
    // Cleanup the round-trip file (best-effort).
    fs_remove("target/_fs_smoke_tmp.txt");
    return fails;
}
