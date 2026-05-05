// rods/python runtime — Embedded CPython for Nucleor
#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// We dynamically load Python so the rod works even if Python isn't installed
// (gracefully returns errors). On Windows, load python311.dll.

#ifdef _WIN32
#include <windows.h>
static HMODULE py_dll = NULL;
#else
#include <dlfcn.h>
static void *py_dll = NULL;
#endif

// Python C API function pointers
typedef void (*Py_Initialize_t)(void);
typedef int (*Py_IsInitialized_t)(void);
typedef void (*Py_Finalize_t)(void);
typedef int (*PyRun_SimpleString_t)(const char *);
typedef void* (*PyImport_ImportModule_t)(const char *);
typedef void* (*PyObject_GetAttrString_t)(void *, const char *);
typedef void* (*PyObject_CallObject_t)(void *, void *);
typedef void* (*PyObject_Str_t)(void *);
typedef const char* (*PyUnicode_AsUTF8_t)(void *);
typedef void* (*PyTuple_New_t)(long long);
typedef int (*PyTuple_SetItem_t)(void *, long long, void *);
typedef void* (*PyUnicode_FromString_t)(const char *);
typedef void* (*PyLong_FromLongLong_t)(long long);
typedef long long (*PyLong_AsLongLong_t)(void *);
typedef void (*Py_DecRef_t)(void *);
typedef void* (*PyErr_Occurred_t)(void);
typedef void (*PyErr_Clear_t)(void);
typedef void* (*Py_BuildValue_t)(const char *, ...);
typedef int (*PyLong_Check_t)(void *);

static Py_Initialize_t pPy_Initialize = NULL;
static Py_IsInitialized_t pPy_IsInitialized = NULL;
static PyRun_SimpleString_t pPyRun_SimpleString = NULL;
static PyImport_ImportModule_t pPyImport_ImportModule = NULL;
static PyObject_GetAttrString_t pPyObject_GetAttrString = NULL;
static PyObject_CallObject_t pPyObject_CallObject = NULL;
static PyObject_Str_t pPyObject_Str = NULL;
static PyUnicode_AsUTF8_t pPyUnicode_AsUTF8 = NULL;
static PyTuple_New_t pPyTuple_New = NULL;
static PyTuple_SetItem_t pPyTuple_SetItem = NULL;
static PyUnicode_FromString_t pPyUnicode_FromString = NULL;
static PyLong_FromLongLong_t pPyLong_FromLongLong = NULL;
static PyLong_AsLongLong_t pPyLong_AsLongLong = NULL;
static Py_DecRef_t pPy_DecRef = NULL;
static PyErr_Occurred_t pPyErr_Occurred = NULL;
static PyErr_Clear_t pPyErr_Clear = NULL;

static int py_loaded = 0;
static int py_initialized = 0;

static void *load_sym(const char *name) {
#ifdef _WIN32
    return (void *)GetProcAddress(py_dll, name);
#else
    return dlsym(py_dll, name);
#endif
}

static int load_python_dll(void) {
    if (py_loaded) return py_dll != NULL;
    py_loaded = 1;

#ifdef _WIN32
    // Try Python 3.11, 3.12, 3.13, 3.10 in order
    const char *dlls[] = {"python311.dll", "python312.dll", "python313.dll", "python310.dll", NULL};
    for (int i = 0; dlls[i]; i++) {
        py_dll = LoadLibraryA(dlls[i]);
        if (py_dll) break;
    }
#else
    py_dll = dlopen("libpython3.so", RTLD_LAZY);
    if (!py_dll) py_dll = dlopen("libpython3.11.so", RTLD_LAZY);
#endif

    if (!py_dll) return 0;

    pPy_Initialize = (Py_Initialize_t)load_sym("Py_Initialize");
    pPy_IsInitialized = (Py_IsInitialized_t)load_sym("Py_IsInitialized");
    pPyRun_SimpleString = (PyRun_SimpleString_t)load_sym("PyRun_SimpleString");
    pPyImport_ImportModule = (PyImport_ImportModule_t)load_sym("PyImport_ImportModule");
    pPyObject_GetAttrString = (PyObject_GetAttrString_t)load_sym("PyObject_GetAttrString");
    pPyObject_CallObject = (PyObject_CallObject_t)load_sym("PyObject_CallObject");
    pPyObject_Str = (PyObject_Str_t)load_sym("PyObject_Str");
    pPyUnicode_AsUTF8 = (PyUnicode_AsUTF8_t)load_sym("PyUnicode_AsUTF8");
    pPyTuple_New = (PyTuple_New_t)load_sym("PyTuple_New");
    pPyTuple_SetItem = (PyTuple_SetItem_t)load_sym("PyTuple_SetItem");
    pPyUnicode_FromString = (PyUnicode_FromString_t)load_sym("PyUnicode_FromString");
    pPyLong_FromLongLong = (PyLong_FromLongLong_t)load_sym("PyLong_FromLongLong");
    pPyLong_AsLongLong = (PyLong_AsLongLong_t)load_sym("PyLong_AsLongLong");
    pPy_DecRef = (Py_DecRef_t)load_sym("Py_DecRef");
    pPyErr_Occurred = (PyErr_Occurred_t)load_sym("PyErr_Occurred");
    pPyErr_Clear = (PyErr_Clear_t)load_sym("PyErr_Clear");

    if (!pPy_Initialize || !pPyRun_SimpleString) {
        py_dll = NULL;
        return 0;
    }
    return 1;
}

static void ensure_python(void) {
    if (!py_initialized) {
        if (load_python_dll() && pPy_Initialize) {
            pPy_Initialize();
            py_initialized = 1;
        }
    }
}

// === Public API ===

/// Initialize the Python interpreter. Returns 1 on success, 0 on failure.
long long rods_py_init(void) {
    if (py_initialized) return 1;
    if (!load_python_dll()) return 0;
    pPy_Initialize();
    py_initialized = 1;
    return 1;
}

/// Execute a Python code string. Returns 0 on success, -1 on error.
long long rods_py_exec(const char *code) {
    ensure_python();
    if (!py_initialized || !code) return -1;
    int rc = pPyRun_SimpleString(code);
    return (long long)rc;
}

/// Evaluate a Python expression and return the result as a string.
/// Uses a temporary module trick: exec("_nr_result = str(expr)") then read _nr_result.
const char *rods_py_eval(const char *expr) {
    ensure_python();
    if (!py_initialized || !expr) return "";

    // Build: _nr_result = str(<expr>)
    size_t len = strlen(expr) + 64;
    char *code = (char *)malloc(len);
    snprintf(code, len, "_nr_result = str(%s)", expr);

    if (pPyRun_SimpleString(code) != 0) {
        free(code);
        if (pPyErr_Clear) pPyErr_Clear();
        return "<error>";
    }
    free(code);

    // Read _nr_result from __main__
    void *main_mod = pPyImport_ImportModule("__main__");
    if (!main_mod) return "<error>";

    void *result_obj = pPyObject_GetAttrString(main_mod, "_nr_result");
    if (!result_obj) {
        pPy_DecRef(main_mod);
        return "<error>";
    }

    const char *utf8 = pPyUnicode_AsUTF8(result_obj);
    // Copy to heap so it survives DecRef
    char *copy = "";
    if (utf8) {
        size_t slen = strlen(utf8);
        copy = (char *)malloc(slen + 1);
        memcpy(copy, utf8, slen + 1);
    }

    pPy_DecRef(result_obj);
    pPy_DecRef(main_mod);
    return copy;
}

/// Call a Python function by module.function name with a single string argument.
/// Returns the result as a string.
const char *rods_py_call_str(const char *module_name, const char *func_name, const char *arg) {
    ensure_python();
    if (!py_initialized) return "<error: python not loaded>";

    void *mod = pPyImport_ImportModule(module_name);
    if (!mod) {
        if (pPyErr_Clear) pPyErr_Clear();
        return "<error: module not found>";
    }

    void *func = pPyObject_GetAttrString(mod, func_name);
    if (!func) {
        pPy_DecRef(mod);
        if (pPyErr_Clear) pPyErr_Clear();
        return "<error: function not found>";
    }

    void *args = pPyTuple_New(1);
    pPyTuple_SetItem(args, 0, pPyUnicode_FromString(arg ? arg : ""));

    void *result = pPyObject_CallObject(func, args);
    pPy_DecRef(args);
    pPy_DecRef(func);
    pPy_DecRef(mod);

    if (!result) {
        if (pPyErr_Clear) pPyErr_Clear();
        return "<error: call failed>";
    }

    void *str_obj = pPyObject_Str(result);
    const char *utf8 = pPyUnicode_AsUTF8(str_obj);
    char *copy = "";
    if (utf8) {
        size_t slen = strlen(utf8);
        copy = (char *)malloc(slen + 1);
        memcpy(copy, utf8, slen + 1);
    }

    pPy_DecRef(str_obj);
    pPy_DecRef(result);
    return copy;
}

/// Check if Python is available on this system.
long long rods_py_available(void) {
    return load_python_dll() ? 1 : 0;
}

/// R06-D2 Phase 1 (v0.8.273) — string-result reclamation hook.
///
/// Both `rods_py_eval` and `rods_py_call_str` return heap copies
/// (malloc'd) of the Python-side UTF-8 result. Pre-v0.8.273 these
/// returns had no exposed reclaim path — adopters either leaked or
/// guessed the right `free()`. Phase 1 ships an explicit hook.
///
/// Caller MUST pass a pointer that was previously returned by
/// `rods_py_eval` or `rods_py_call_str`. Passing the literal
/// "<error>" / "" string returned on the failure path is safe (the
/// pointer compares against a static and is rejected as no-op).
/// Null is safe (no-op). Double-free is undefined behavior.
///
/// Phase 2 wires GIL ensure/release brackets per call (the C-Python
/// API requires the GIL be held before each Py* call); Phase 1
/// matches the existing thread-unaware behavior so the rod
/// continues to work for single-threaded adopters.
void rods_py_free_str(const char *s) {
    if (!s) return;
    // Reject the static fallback strings the bridge returns on
    // failure — those are not heap-owned.
    if (s[0] == '<' && s[1] == 'e' && s[2] == 'r' && s[3] == 'r') return;  // "<error>"
    if (s[0] == '\0') return;  // ""
    free((void *)s);
}
