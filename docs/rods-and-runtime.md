# Rods and the Runtime

Nucleor's standard library is organized as **rods**: small, focused modules paired with their C runtime.

## Anatomy of a rod

A rod is two files in `stdlib/rods/`:

- `<name>.nr` — the Nucleor-side wrapper. Declares `extern fn` bindings for the C symbols and provides Nucleor-friendly wrappers around them. Declares `#cfile "<name>_rt.c"` to tell the compiler what to compile and link.
- `<name>_rt.c` — the C implementation.

Example: `stdlib/rods/quantum.nr` calls into `stdlib/rods/quantum_rt.c`. When a user program does `import "stdlib/rods/quantum.nr"`, the compiler reads the `#cfile` directive and arranges for `quantum_rt.c` to be compiled and linked into the final binary.

## The shipping rod catalog (v0.1, all 36 build clean)

### Core utilities

| Rod | Provides |
|---|---|
| `strings.nr`     | `strings_contains`, `strings_starts_with`, `strings_ends_with`, `strings_to_upper/lower`, `strings_split`, `strings_join`, `strings_trim`, `strings_replace`, `strings_repeat`, `strings_pad_*`, `strings_char_to_str` |
| `fmt.nr`         | `fmt_int`, `fmt_bool`, `fmt_hex/oct/bin`, `fmt_float_approx`, `fmt_pad_*`, `fmt_format`, `fmt_to_int` |
| `bitwise.nr`     | `bit_and`, `bit_or`, `bit_xor`, `bit_not`, `bit_shift_left/right`, `bit_test`, `bit_set`, `bit_clear` |
| `math.nr`        | Common math functions (sqrt, sin, cos, ...) |
| `complex.nr`     | f64 helpers: `f64_add/sub/mul/div`, `f64_lt/gt/eq`, `f64_from_int`, `f64_to_str_6`, `f64_abs`, complex-number arithmetic, RNG (`rng_seed`, `rng_f64`, `rng_normal`) |

### Data structures

| Rod | Provides |
|---|---|
| `collections.nr` | Higher-level vector ops |
| `option.nr`      | `Option` type and helpers |
| `result.nr`      | `Result` type and helpers |
| `queue.nr`       | FIFO queue |
| `stack.nr`       | LIFO stack |
| `sort.nr`        | Sorting primitives |

### Text and serialization

| Rod | Provides |
|---|---|
| `json.nr`        | JSON parse, stringify, value construction |
| `csv.nr`         | CSV parse and format |
| `ini.nr`         | INI file parse |
| `regex.nr`       | Simple character-class predicates (use `rust.nr` for full regex) |
| `base64.nr`      | base64 encode/decode |
| `uuid.nr`        | UUID generation |

### System and concurrency

| Rod | Provides |
|---|---|
| `io.nr`          | Console output extensions |
| `fs.nr`          | File system primitives |
| `os.nr`          | Process exit, OS info |
| `env.nr`         | Environment variable access |
| `path.nr`        | Path manipulation |
| `time.nr`        | `time_now_ms`, `time_sleep_ms`, `time_format_ms` |
| `concurrency.nr` | `conc_mutex`, `conc_lock`, `conc_unlock`, `conc_spawn`, `conc_join` |
| `cli.nr`         | Command-line argument parsing (`cli_new`, `cli_flag`, `cli_option`, `cli_parse`, ...) |
| `log.nr`         | Logging primitives |
| `test.nr`        | Test framework with assertions |

### Domain rods

| Rod | Provides |
|---|---|
| `quantum.nr`    | Built-in quantum simulator: `qsim_init`, `qsim_h`, `qsim_x`, `qsim_y`, `qsim_z`, `qsim_cnot`, `qsim_measure`, ... |
| `nn.nr`         | Neural network primitives: dense layers, backprop, Adam, attention |
| `gnn.nr`        | Graph Neural Network: GATv2Conv, global attention pooling |
| `gpu.nr`        | GPU kernel orchestration |
| `multi_core.nr` | Multi-core trace recording for ensemble experiments |
| `ridge.nr`      | Ridge regression with gradient descent |
| `twin_core.nr`  | Twin-core comparison utilities |
| `python.nr`     | Optional Python FFI (requires Python on PATH) |
| `rust.nr`       | Rust crate interop via `rust_bridge` (regex, base64, hashing, sorting) |

## The runtime boundary

Every Nucleor program is linked with `stdlib/runtime/nucleor_llvm_rt.c`. This file is the **mandatory boundary** — it provides:

- Basic I/O: `__nucleor_print_str`, `__nucleor_print_i64`, `__nucleor_print_bool`
- File access: `__nucleor_file_read_string`, `__nucleor_file_write_string`
- Process: `__nucleor_system`, `__nucleor_exit`, `__nucleor_args_count`, `__nucleor_args_get`
- Hashing, timing
- Vec / string-builder primitives
- Threads: `__nucleor_thread_spawn`, `__nucleor_thread_join`
- Mutex: `__nucleor_mutex_new`, `__nucleor_mutex_lock`, `__nucleor_mutex_unlock` (and `_value`-suffixed variants for the V2 ABI)
- Channels: `__nucleor_channel_new`, `__nucleor_channel_send`, `__nucleor_channel_recv`
- Atomic helpers
- Numeric intrinsics
- Tensor / allocator / device hooks
- RNG: `nuc_rng_seed`, `nuc_rng_f64`, `nuc_rng_normal`, ... (included via `#include "rng_rt.c"` at the bottom of `nucleor_llvm_rt.c`)

The compiler emits `__nucleor_*` calls; the runtime defines them. Some symbols carry the suffix `_value` to indicate the V2 value-passing calling convention; both forms forward to the same underlying implementation.

Beyond `nucleor_llvm_rt.c`, the C runtime files in `stdlib/runtime/` (e.g. `fft_rt.c`, `hashmap_rt.c`, `crypto_rt.c`, `tensor_rt.c`, ...) are **opt-in**: they are only compiled and linked when a rod that uses them includes the appropriate `#cfile` directive. A program that only uses `print` and arithmetic links exactly one C file (`nucleor_llvm_rt.c`).

## Writing your own rod

The fastest way to add a function from C, Rust, Zig, or Go to Nucleor:

### From C

Create `my_rod_rt.c`:

```c
long long my_double(long long x) {
    return x * 2;
}
```

Create `my_rod.nr`:

```nr
#cfile "my_rod_rt.c"

extern fn my_double(x: i64) -> i64;
```

Use it:

```nr
import "path/to/my_rod.nr"

fn main() -> i64 {
    print(str_from_int(my_double(21)));
    return 0;
}
```

### From Rust

The shipping `rust_bridge` (in `stdlib/rods/rust_bridge/`) is a working example. The pattern:

1. Build a Rust crate with `crate-type = ["staticlib"]`.
2. Mark exported functions `#[no_mangle] pub extern "C"`.
3. Take and return `*const c_char` (with `CString::into_raw`) for string interop.
4. Build with `cargo build --release` to produce a `.lib`.
5. In your `.nr` wrapper, declare `extern fn` bindings, add `#libpath "rust_bridge/target/release"`, and `#link "your_crate_name"`.

The compile-and-link step is then identical to a C rod — the user just `import`s the `.nr` wrapper.

### From any language with C-ABI static-library output

The mechanism (`#cfile` for C, `#link` + `#libpath` for everything else) is language-neutral. Anything that produces a static library with `extern "C"`-style symbols can be wrapped in a `.nr` file the same way.
