# Living Terrarium 3D v1.8 — 30 ecological interactions

Added `scripts/habitat_interactions.gd` as a low-frequency (12.5 Hz), bounded interaction layer. It uses procedural visuals and lightweight steering, **not** physical cloth/branch simulation or full navigation/pathfinding.

## Implemented behaviors (30)

**Plants (1–10):** 1 body-to-leaf contact; 2 movement-dependent impact; 3 elastic springback; 4 damped oscillation; 5 near-contact airflow; 6 sheltered plant response; 7 neighboring leaf impulse propagation; 8 per-plant condition parameter; 9 low-humidity leaf droop; 10 individual stiffness response.

**Prey (11–20):** 11 predator proximity fear; 12 fear buildup; 13 panic speed; 14 move toward vegetation cover; 15 pause while hidden; 16 gradual fear recovery; 17 intermittent rest; 18 direction-facing; 19 prey separation; 20 decoration avoidance.

**Habitat (21–30):** 21 branch contact response; 22 branch springback; 23 branch damping; 24 wind response; 25 footstep dust kick; 26 dust settling; 27 moisture droplets; 28 evaporation visibility; 29 fungal patches with humidity; 30 slow lighting variation.

**Limitations:** Branch movement only applies to newly placed user wood decorations, not original static scene branches. The per-plant condition parameter is initialized but does not yet affect appearance. Prey steering is heuristic and does not guarantee pathfinding through clutter. The dust specks are simplified mesh particles. Daylight variation is aesthetic, not tied to real time. Engine execution and Android APK export are not verified.

## Testing
Run `python3 tests/check_v18.py` from the project directory for source-level checks. For real behavior verification, import into Godot 4, inspect the debugger and test mobile performance. The project retains all earlier systems.
