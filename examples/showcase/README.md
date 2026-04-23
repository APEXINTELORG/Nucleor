# `examples/showcase/`

End-to-end programs that exercise the v0.2.x stdlib in
production-shaped scenarios. Larger and more domain-specific
than the numbered examples in `examples/01..18`. **Not part of
the verify gate** — they produce streaming visual output
(ANSI heatmaps, dashboards, live charts), so they're meant to
be run interactively and watched.

All four programs build with the shipped `bin/nucleor.exe` and
share the local `_viz.nr` helper for ANSI cursor positioning,
256-color heatmaps, horizontal bar charts, and progress
spinners.

## Programs

| File | Topic | Notes |
|---|---|---|
| [`lorenz.nr`](lorenz.nr) | **Lorenz strange attractor** | RK4 integration of two trajectories started 1e-5 apart, rendered as a heatmap of trajectory density. The iconic butterfly shape emerges in your console; visual demonstration of sensitive dependence on initial conditions. |
| [`vqe_h2.nr`](vqe_h2.nr) | **Variational Quantum Eigensolver** | Ground state of a 2-qubit Hamiltonian via parameter-shift gradient descent. Live convergence chart with parameter and energy bars updating in place. Other-stack equivalent: PennyLane + PyTorch + OpenFermion + SciPy. |
| [`market_maker.nr`](market_maker.nr) | **Live options market-making engine** | Black-Scholes pricing + full Greeks + PID-driven delta hedging at simulated 10 ms tick. Bloomberg-style dashboard. Other-stack equivalent: Python + QuantLib + filterpy + simple-pid + a C++ rewrite for the latency path. |
| [`wing_simulator.nr`](wing_simulator.nr) | **Coupled fluid + EM simulator** | Lattice Boltzmann (D2Q9) for aerodynamics + FDTD on a Yee grid for electromagnetics, both on the same airfoil cross-section in one file with one shared geometry. 256-color heatmaps for density, vorticity, and E_z field. Other-stack equivalent: OpenFOAM + Meep + a custom mesh bridge + matplotlib. |

## Helpers

[`_viz.nr`](_viz.nr) — shared ANSI visualization helpers
(cursor positioning, 24-bit-safe 256-color palette, heatmap
palette, horizontal bar charts, progress spinner). Imported
by all four showcase programs. Works in modern Windows
Terminal, PowerShell 7, conhost, and any POSIX terminal that
honors VT escapes.

## Build & run

```bash
# Any showcase program builds the same way as a regular example:
bin/nucleor.exe build examples/showcase/lorenz.nr -o lorenz
./lorenz.exe                    # POSIX
target\lorenz.exe               # Windows
```

These programs are visual — they expect a TTY and produce
streaming ANSI output. Redirecting stdout to a file or piping
to `head` will produce a noisy fragment of the live render.
For automation use the numbered examples in `examples/01..18`,
all of which produce non-streaming text output and are gated
in `tools/verify.sh` / `tools/verify.ps1`.

## Why no gate coverage?

The verify gate runs every example to completion and checks
non-empty stdout. The showcase programs:

- Run for many seconds (or until the user interrupts) producing
  thousands of lines of ANSI escape sequences;
- Re-render the same screen region in place via cursor moves;
- Aren't designed to "complete" — they're live dashboards.

A future gate addition could be a build-only smoke (verify the
`.exe` is produced). That's tracked but not yet shipped.
