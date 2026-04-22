// rods/fs runtime — Filesystem primitives for Nucleor
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

long long rods_fs_exists(const char *path) {
    if (!path) return 0;
    struct stat st;
    if (stat(path, &st) == 0) return 1;
    return 0;
}

long long rods_fs_is_file(const char *path) {
    if (!path) return 0;
    struct stat st;
    if (stat(path, &st) != 0) return 0;
    return (st.st_mode & 0100000) ? 1 : 0;  // S_IFREG
}

long long rods_fs_is_dir(const char *path) {
    if (!path) return 0;
    struct stat st;
    if (stat(path, &st) != 0) return 0;
    return (st.st_mode & 0040000) ? 1 : 0;  // S_IFDIR
}

long long rods_fs_size(const char *path) {
    if (!path) return -1;
    struct stat st;
    if (stat(path, &st) != 0) return -1;
    return (long long)st.st_size;
}

long long rods_fs_remove(const char *path) {
    if (!path) return -1;
    return (long long)remove(path);
}

long long rods_fs_rename(const char *old_path, const char *new_path) {
    if (!old_path || !new_path) return -1;
    return (long long)rename(old_path, new_path);
}
