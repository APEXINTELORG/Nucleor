# Parallel agent dispatch v0842 full package

Date: 2026-05-07
Base for all agents: current `origin/main`

Fetch before every queue. Each agent should push its branch and write its
report. Do not stack queues unless explicitly told to continue on the same
branch; the default is one fresh branch per queue from current `origin/main`.

## Local agents

### Helper1

Document:

```text
findings/_helper1_assignment_v0828_r11_qsim_auto_entangle_2026-05-06.md
```

Queues:

1. Queue 11: ROBO-7 stdlib frame migration pack.
2. Queue 12: RT determinism attribute closure pack.

### Helper2

Document:

```text
findings/_helper2_assignment_v0828_r06_rust_bridge_ownership_harness_2026-05-06.md
```

Queues:

1. Queue 16: RFC-0063 tools-suite Wave 6.
2. Queue 17: RFC-0063 tools-suite Wave 7.

### Helper3

Document:

```text
findings/_helper3_assignment_v0842_type_units_closure_2026-05-07.md
```

Queues:

1. UNIT-1 positive typed-unit API surface.
2. T-3/T-4 strict type tail pack.

### Local Claude1

Document:

```text
docs/rfcs/LOCAL_CLAUDE_R05_EFFECTS_COMPILER_DISPATCH_v0840_2026-05-06.md
```

Queues:

1. v0841 R05 same-file transitive effect slice.
2. v0842 R05 RFC-0033 row subtyping / `with` bridge.

### Local Claude2

Document:

```text
docs/rfcs/LOCAL_CLAUDE2_LAWS_DISPATCH_v0842_2026-05-07.md
```

Queues:

1. Algebraic laws Phase 3b broad property pack.
2. Algebraic law optimizer rewrite gate.

### Local Claude3

Document:

```text
docs/rfcs/LOCAL_CLAUDE3_QUANTUM_CLOSURE_DISPATCH_v0842_2026-05-07.md
```

Queues:

1. QM-7 OpenQASM2 minimal interop.
2. QM-6 MPS external sink / streaming range.

## Cloud/Linux agent

Recommended if one more cloud/Linux agent is available. Keep it Linux-only.

Document:

```text
docs/rfcs/CLOUD_LINUX_PKG_R06_DISPATCH_v0842_2026-05-07.md
```

Queues:

1. PKG-1 native signed publish proof.
2. R06 POSIX rust_bridge ownership proof.

## Integration guardrails

- No Python helpers in product/toolchain paths.
- Keep compiler cold compile under 4 seconds and compiler RSS under the
  current 350MB guard. Any compiler-source lane must run the perf gate.
- Do not edit `bin/` or `bootstrap/` unless compiler source changes and the
  agent has rebuilt/promoted with self-host validation.
- Run `git diff --check` in every lane.
- Run full verify only when asked; focused validation is preferred for these
  queued slices.
