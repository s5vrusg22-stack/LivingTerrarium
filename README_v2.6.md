# Living Terrarium 3D v2.6 — branch traversal and stance refinement

- Added a dedicated, visible inclined branch with a matching physics cylinder.
- Implemented automatic approach, ascending traversal, and cooldown state. Climbing changes the animal root position in 3D, not merely an animation clip.
- Foot targets project to the cylindrical branch during climbing; stance drift now measures full 3D distance.
- Refined imported skeleton target-directed joint correction using both forward and lateral foot target components.
- **Limitation:** GLB leg bones are siblings under the root, not parent-child chains. The GLB remains rigidly skinned. This cannot produce accurate two-bone skeletal IK until the rig is rebuilt with hierarchical femur/tibia joints and appropriate bind transforms. The procedural fallback does have an analytic two-segment IK solver.
- Climb path is scripted on one specific branch; this is not arbitrary obstacle navigation, collision-driven wall climbing, or autonomous route planning.
- No Godot executable or Android SDK is available for runtime verification. Run in Godot 4 to test visual scale, clipping, pose blending and collision.
