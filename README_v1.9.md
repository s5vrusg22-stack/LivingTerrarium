# Living Terrarium 3D v1.9 — Interaction stabilization

## Implemented
- Moving prey now apply distance- and speed-dependent impulses to nearby plant leaf joints.
- Leaf-touch events have a 0.45-second cooldown per joint to prevent every simulation tick being counted as a new touch.
- Humidity-dependent leaf droop is applied in the final plant animation pass, rather than being overwritten every frame.
- Interaction activity display separates mantis–leaf and prey–leaf events.
- Existing ten mantis animation states, 30 habitat rules, procedural plants, and textures remain present.

## Limitations
- Leaf proximity uses joint points, not mesh collision; touching a leaf visually may not always register.
- No navmesh climbing, Blender-skinned GLB, or verified APK.
- Static source checks are not a substitute for Godot 4 engine/runtime testing.
