# Helper Manifest Schema

`docs/rfcs/helper_manifest.toml` is the generated catalog of runtime helper
symbols known to the compiler and tools suite. It is used by drift checks,
documentation tooling, and release validation.

## Top-Level Shape

```toml
[helper.<name>]
name = "<compiler helper name>"
symbol = "<runtime symbol>"
class = "<semantic class>"
linkage = "<linkage model>"
allocates = false
may_panic = false
pure = true
deterministic = true
notes = "short explanation"
introduced = "1.1.0"
```

Fields may be omitted only when the generator can derive a safe default.

## Required Fields

| Field | Meaning |
|---|---|
| `name` | Compiler-facing helper name. |
| `symbol` | Runtime symbol emitted into IR or linked from the runtime. |
| `class` | Semantic category used by safety and documentation tooling. |
| `linkage` | `runtime`, `intrinsic`, `lowered`, `reserved`, or `unknown`. |
| `allocates` | Whether the helper may allocate heap memory. |
| `may_panic` | Whether the helper may abort, panic, or raise a diagnostic trap. |
| `pure` | Whether calls are side-effect free for compiler reasoning. |
| `deterministic` | Whether repeated calls with the same inputs produce the same result. |
| `notes` | Human explanation for non-obvious metadata. |
| `introduced` | Release line where the helper first became public. |

## Semantic Classes

| Class | Meaning |
|---|---|
| `String` | String allocation, slicing, conversion, formatting, and comparison. |
| `Vec` | Vector allocation, indexing, mutation, and length/capacity helpers. |
| `HashMap` | Map creation, lookup, mutation, and key enumeration. |
| `IO` | File, environment, process, and console operations. |
| `Numeric` | Numeric casts, math helpers, overflow behavior, and formatting. |
| `RT` | Real-time, deadline, allocation, panic, or dynamic-dispatch checks. |
| `Contract` | Design-by-contract runtime checks. |
| `Atomic` | Atomic, lock-free, and synchronization helpers. |
| `FFI` | Host-call, ABI, pointer, and nullability boundaries. |
| `Diagnostics` | Diagnostic and explain-registry support. |
| `ToolingMeta` | Generator, drift-check, or compiler-tooling metadata helpers. |
| `Reserved` | Symbol reserved for a future or platform-specific implementation. |

## Maintenance Rules

1. Regenerate the manifest when helper declarations, runtime symbols, or helper
   safety metadata change.
2. Keep the schema concise. Put historical notes in commit history, not in the
   generated public schema.
3. Unknown allocation, panic, purity, or determinism metadata should fail the
   drift gate unless the helper is explicitly marked `reserved`.
4. Public docs should describe what the helper does now, not the internal path
   used to discover it.
