# Ownership Diagnostic Codes

This page reserves the `OWN-*` diagnostic namespace used by Nucleor's
ownership, move, drop, and borrow checks. Codes are stable once published so
tooling can link to them safely.

Each diagnostic entry has:

- **Code:** stable diagnostic identifier.
- **Severity:** `error`, `warning`, or `info`.
- **Status:** `active`, `reserved`, `retired`, or `superseded`.
- **Trigger:** the condition reported by the compiler.
- **Fix direction:** the usual repair path.

## Active Codes

### OWN-001 - Use After Move

- **Severity:** error
- **Status:** active
- **Trigger:** an owned value is read after ownership has moved.
- **Fix direction:** pass by reference, clone intentionally, or restructure so
  the moved value is not used again.

### OWN-002 - Drop Order Ambiguous

- **Severity:** error
- **Status:** active
- **Trigger:** the compiler cannot prove a safe drop order for an owned value.
- **Fix direction:** introduce an explicit local binding or narrow the value's
  lifetime.

### OWN-012 - Double Free Or Use After Drop

- **Severity:** error
- **Status:** active
- **Trigger:** the same owned heap value can be freed twice, or used after the
  point where ownership transferred.
- **Fix direction:** keep one owner, pass `&value` for borrowing, and avoid
  manually retaining a moved handle.

Example diagnostic shape:

```text
error[OWN-012]: double free or use after drop

  value moved here and later used again

  --> path/to/file.nr:LINE
   |
   | let y = x;
   |         ^
```

## Allocation Rule

New ownership diagnostics are allocated in ascending order and remain reserved
even if a later check supersedes them. Retired codes stay documented with a
pointer to their replacement.
