# Showcase Examples

These programs exercise larger standard-library surfaces in production-shaped
scenarios. They are more domain-specific than the numbered examples and are
intended for interactive terminal runs.

The release verifier build-checks each showcase program. Runtime execution is
manual because the programs produce streaming ANSI output such as heatmaps,
dashboards, and live charts.

All programs share [`_viz.nr`](_viz.nr), a small ANSI visualization helper for
cursor positioning, color palettes, heatmaps, horizontal bars, and progress
spinners.

## Programs

| File | Topic | Notes |
|---|---|---|
| [`lorenz.nr`](lorenz.nr) | Lorenz attractor | RK4 integration of two nearby trajectories rendered as a density heatmap. |
| [`vqe_h2.nr`](vqe_h2.nr) | Variational quantum eigensolver | Two-qubit Hamiltonian minimized with parameter-shift gradient descent. |
| [`market_maker.nr`](market_maker.nr) | Options market-making engine | Black-Scholes pricing, Greeks, and simulated delta hedging. |
| [`wing_simulator.nr`](wing_simulator.nr) | Coupled fluid and EM simulator | Lattice Boltzmann aerodynamics plus FDTD electromagnetics on one airfoil cross-section. |
| [`robotic_arm.nr`](robotic_arm.nr) | Robotics stack showcase | Kinematics, IK, trajectory, collision, BVH, and dynamics rods composed end to end. |

## Build And Run

```bash
bin/nucleor.exe build examples/showcase/lorenz.nr -o lorenz
target/lorenz.exe       # Windows
./target/lorenz         # Linux
```

Run these in a terminal that supports ANSI cursor movement. For automation,
use the numbered examples in `examples/`; those produce bounded text output and
are run by the verifier.
