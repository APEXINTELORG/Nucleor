# Rod Manifest Schema

`docs/rfcs/rod_manifest.toml` is the generated catalog of standard-library rods.
It lets tooling verify that rod files, runtime companions, docs, and feature
metadata stay in sync.

## Top-Level Shape

```toml
[rod.<name>]
name = "<rod name>"
path = "stdlib/rods/<name>.nr"
runtime = "stdlib/runtime/<name>_rt.c"
category = "<category>"
status = "public"
summary = "short user-facing description"
```

## Fields

| Field | Meaning |
|---|---|
| `name` | Importable rod name. |
| `path` | Source path for the `.nr` rod. |
| `runtime` | Optional C runtime companion path. |
| `category` | Broad area such as `core`, `math`, `robotics`, `quantum`, `ml`, `ffi`, or `system`. |
| `status` | `public`, `experimental`, `reserved`, or `internal`. |
| `summary` | One-sentence description suitable for docs and inventories. |

## Maintenance Rules

1. Regenerate the manifest when rods are added, removed, moved, or renamed.
2. Keep status conservative. Use `experimental` when a rod is shipped but not a
   stable public API.
3. Runtime companions must be named explicitly when the rod depends on C code.
4. Drift checks should fail when a public rod is missing from the manifest or a
   manifest row points at a missing file.
