# Cloud Codex Start Here - Linux Perf

Use this file if you cannot find the nested dispatch document.

Canonical dispatch:

```text
docs/rfcs/CLOUD_LINUX_PERF_DISPATCH_v0835_2026-05-06.md
```

GitHub URL:

```text
https://github.com/APEXINTELORG/Nucleor/blob/main/docs/rfcs/CLOUD_LINUX_PERF_DISPATCH_v0835_2026-05-06.md
```

Branch URL:

```text
https://github.com/APEXINTELORG/Nucleor/tree/main
```

Required start commands from a cloud checkout:

```bash
cd /workspace/Nucleor
git fetch origin
git checkout -B cloud/linux-perf-phase4-v0835 origin/main
git rev-parse --short HEAD
git status --short --branch
test -f docs/rfcs/CLOUD_LINUX_PERF_DISPATCH_v0835_2026-05-06.md
sed -n '1,180p' docs/rfcs/CLOUD_LINUX_PERF_DISPATCH_v0835_2026-05-06.md
```

Expected current `origin/main` head when this pointer was written:

```text
db697b9e
```

Scope summary:

- native Linux only, not WSL;
- reproduce `tools/perf_baseline_linux.json`;
- attribute the 9.05s Linux cold self-build path;
- make one evidence-backed optimization only if clear;
- no new Python helpers or dependencies;
- write the report requested in the nested dispatch document.
