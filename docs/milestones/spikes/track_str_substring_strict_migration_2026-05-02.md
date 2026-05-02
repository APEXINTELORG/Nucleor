# Track str_substring_strict Migration - 2026-05-02

Branch: `spike/v06-str-substring-strict-migration`
Initial base: `origin/main` `f6231c9` (`v0.6.8`)
Final base after rebase: `origin/main` `cc8311f` (`v0.6.10`)

## Scope

This closes the doc/fixture slice for the probe finding
`str-substring-default-no-end-bounds-check`: make the existing strict helper
discoverable without changing `str_substring` hot-path semantics.

## Changes

- Added `docs/migrations/str_substring_strict.md`.
- Added `tests/features/str_substring_strict_basic.nr`.
- Added a focused verify step:
  `v0.6 str_substring_strict migration fixture`.
- Added a language-tour pointer from the string builtin section to the
  migration guide.

## Validation

Focused verify under the real-time peak-memory wrapper:

```text
bash tools/verify.sh --only "v0.6 str_substring_strict migration fixture"
PASS: step 0.75s
wrapper peak: 175 MB
wall: 60.14s
killed: False
```

`git diff --check`: PASS.

After rebasing onto `origin/main` `270ef86`, the focused migration fixture was
rerun and passed again:

```text
PASS: step 1.06s
wrapper peak: 174 MB
wall: 53.50s
killed: False
```

The final rebase from `270ef86` to `cc8311f` was docs-only on
`docs/milestones/v0.6.0.md`; no compiler or verify hook changed.
