# Verify Timing Contract

`tools/verify.sh` records per-step timing data to `tools/verify_timings.csv`
by default. The CSV is a local rolling artifact and is ignored by git.

## CSV Format

```csv
run_iso,index,seconds,status,name
2026-05-12T12:00:00Z,1,0.085,PASS,"binary present"
```

Each row is one verify step from one run. Use `run_iso` to group a single
run, and use the last row for a step when comparing current local behavior.

## Paths

- Default path: `tools/verify_timings.csv`
- Override path: `NUC_VERIFY_CSV=/path/to/file.csv`
- Namespaced path: `NUC_VERIFY_AGENT=<name>` writes
  `tools/verify_timings.<name>.csv`

## Review Rule

Before declaring a release gate complete, check:

- total verify duration
- slowest steps
- any `FAIL` rows from the latest run
- memory-budget rows, when the platform supports them

Do not commit `tools/verify_timings*.csv`; they are machine-local evidence.
