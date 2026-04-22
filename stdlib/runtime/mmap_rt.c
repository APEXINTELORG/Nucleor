// mmap_rt.c — Memory-Mapped I/O and Shared Memory for Nucleor
// File mapping, shared memory regions, large dataset access.
//
// Compile: clang -c stdlib/runtime/mmap_rt.c -o target/mmap_rt.obj -O2

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#else
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#endif

static double _mm_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _mm_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

// ================================================================
//  Memory-Mapped File
// ================================================================

typedef struct {
    char *base;
    long long size;
#ifdef _WIN32
    HANDLE file_handle;
    HANDLE map_handle;
#else
    int fd;
#endif
} MMapFile;

long long nuc_mmap_file(const char *path, long long mode) {
    if (!path) return 0;
    MMapFile *m = (MMapFile *)calloc(1, sizeof(MMapFile));

#ifdef _WIN32
    DWORD access = (mode == 1) ? GENERIC_READ | GENERIC_WRITE : GENERIC_READ;
    DWORD share = FILE_SHARE_READ;
    DWORD create = (mode == 1) ? OPEN_ALWAYS : OPEN_EXISTING;
    m->file_handle = CreateFileA(path, access, share, NULL, create, FILE_ATTRIBUTE_NORMAL, NULL);
    if (m->file_handle == INVALID_HANDLE_VALUE) { free(m); return 0; }

    LARGE_INTEGER li;
    GetFileSizeEx(m->file_handle, &li);
    m->size = li.QuadPart;
    if (m->size == 0) { CloseHandle(m->file_handle); free(m); return 0; }

    DWORD prot = (mode == 1) ? PAGE_READWRITE : PAGE_READONLY;
    m->map_handle = CreateFileMappingA(m->file_handle, NULL, prot, 0, 0, NULL);
    if (!m->map_handle) { CloseHandle(m->file_handle); free(m); return 0; }

    DWORD map_access = (mode == 1) ? FILE_MAP_ALL_ACCESS : FILE_MAP_READ;
    m->base = (char *)MapViewOfFile(m->map_handle, map_access, 0, 0, 0);
    if (!m->base) {
        CloseHandle(m->map_handle); CloseHandle(m->file_handle); free(m); return 0;
    }
#else
    int flags = (mode == 1) ? O_RDWR : O_RDONLY;
    m->fd = open(path, flags);
    if (m->fd < 0) { free(m); return 0; }
    struct stat st;
    fstat(m->fd, &st);
    m->size = st.st_size;
    int prot = (mode == 1) ? PROT_READ | PROT_WRITE : PROT_READ;
    m->base = (char *)mmap(NULL, m->size, prot, MAP_SHARED, m->fd, 0);
    if (m->base == MAP_FAILED) { close(m->fd); free(m); return 0; }
#endif
    return (long long)m;
}

long long nuc_mmap_size(long long h) {
    MMapFile *m = (MMapFile *)(void *)h;
    return m ? m->size : 0;
}

// Read bytes from offset into a string
const char *nuc_mmap_read(long long h, long long offset, long long len) {
    MMapFile *m = (MMapFile *)(void *)h;
    if (!m || offset < 0 || offset + len > m->size) return "";
    char *buf = (char *)malloc((int)len + 1);
    memcpy(buf, m->base + (int)offset, (int)len);
    buf[(int)len] = 0;
    return buf;
}

// Read f64 at byte offset
long long nuc_mmap_read_f64(long long h, long long offset) {
    MMapFile *m = (MMapFile *)(void *)h;
    if (!m || offset < 0 || offset + 8 > m->size) return _mm_f2i(0.0);
    double d;
    memcpy(&d, m->base + (int)offset, 8);
    return _mm_f2i(d);
}

// Write bytes at offset
void nuc_mmap_write(long long h, long long offset, const char *data, long long len) {
    MMapFile *m = (MMapFile *)(void *)h;
    if (!m || offset < 0 || offset + len > m->size || !data) return;
    memcpy(m->base + (int)offset, data, (int)len);
}

// Write f64 at byte offset
void nuc_mmap_write_f64(long long h, long long offset, long long val_bits) {
    MMapFile *m = (MMapFile *)(void *)h;
    if (!m || offset < 0 || offset + 8 > m->size) return;
    double d = _mm_i2f(val_bits);
    memcpy(m->base + (int)offset, &d, 8);
}

// Flush changes to disk
void nuc_mmap_sync(long long h) {
    MMapFile *m = (MMapFile *)(void *)h;
    if (!m) return;
#ifdef _WIN32
    FlushViewOfFile(m->base, 0);
#else
    msync(m->base, m->size, MS_SYNC);
#endif
}

void nuc_mmap_close(long long h) {
    MMapFile *m = (MMapFile *)(void *)h;
    if (!m) return;
#ifdef _WIN32
    UnmapViewOfFile(m->base);
    CloseHandle(m->map_handle);
    CloseHandle(m->file_handle);
#else
    munmap(m->base, m->size);
    close(m->fd);
#endif
    free(m);
}

// ================================================================
//  Named Shared Memory
// ================================================================

typedef struct {
    char *base;
    long long size;
#ifdef _WIN32
    HANDLE map_handle;
#else
    int fd;
    char name[256];
#endif
} SharedMem;

long long nuc_shm_create(const char *name, long long size) {
    SharedMem *shm = (SharedMem *)calloc(1, sizeof(SharedMem));
    shm->size = size;
#ifdef _WIN32
    shm->map_handle = CreateFileMappingA(INVALID_HANDLE_VALUE, NULL, PAGE_READWRITE,
                                          (DWORD)(size >> 32), (DWORD)(size & 0xFFFFFFFF), name);
    if (!shm->map_handle) { free(shm); return 0; }
    shm->base = (char *)MapViewOfFile(shm->map_handle, FILE_MAP_ALL_ACCESS, 0, 0, (SIZE_T)size);
#else
    int fd = shm_open(name, O_CREAT | O_RDWR, 0666);
    if (fd < 0) { free(shm); return 0; }
    ftruncate(fd, size);
    shm->base = (char *)mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    shm->fd = fd;
    strncpy(shm->name, name, 255);
#endif
    return (long long)shm;
}

long long nuc_shm_open(const char *name) {
    SharedMem *shm = (SharedMem *)calloc(1, sizeof(SharedMem));
#ifdef _WIN32
    shm->map_handle = OpenFileMappingA(FILE_MAP_ALL_ACCESS, FALSE, name);
    if (!shm->map_handle) { free(shm); return 0; }
    shm->base = (char *)MapViewOfFile(shm->map_handle, FILE_MAP_ALL_ACCESS, 0, 0, 0);
#else
    int fd = shm_open(name, O_RDWR, 0666);
    if (fd < 0) { free(shm); return 0; }
    struct stat st; fstat(fd, &st);
    shm->size = st.st_size;
    shm->base = (char *)mmap(NULL, shm->size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    shm->fd = fd;
    strncpy(shm->name, name, 255);
#endif
    return (long long)shm;
}

void nuc_shm_close(long long h) {
    SharedMem *shm = (SharedMem *)(void *)h;
    if (!shm) return;
#ifdef _WIN32
    UnmapViewOfFile(shm->base);
    CloseHandle(shm->map_handle);
#else
    munmap(shm->base, shm->size);
    close(shm->fd);
#endif
    free(shm);
}
