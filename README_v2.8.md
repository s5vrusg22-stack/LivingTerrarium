# Living Terrarium 3D v2.8 — IK stabilization and branch-contact fixes

## Implemented
1. Validate real Coxa → Joint → Tibia bone lengths from imported skeleton rest pose.
2. Reject degenerate/incorrect hierarchical rigs and use legacy fallback.
3. Clamp target reach to the measured limb length instead of a fixed world-unit guess.
4. Blend stance vs. swing IK influence per leg to reduce popping.
5. Stop CCD iterations early when the tip is close to its target.
6. Clear prior-frame global pose overrides before applying new IK, reducing pose accumulation.
7. Preserve clip-based head and foreleg adjustments.
8. During climbing, do not raycast the desired foot target back down to the substrate.
9. Keep climb feet on the branch cylinder surface and maintain planted-foot anchors.
10. Add a GLB structural/skin/joint and GDScript static integration test.

## Validation limits
Python static tests and GLB structural checks are not equivalent to executing Godot.
No Godot or Blender executable is installed; animation import, skeleton transform
composition, physical contacts, rendering and APK are not runtime-validated.
The generated GLB still has rigid skin weights and approximate distal joint origins;
free climbing on arbitrary geometry is not implemented.

## Run
`python tests/check_v28_integrity.py` and `python tests/check_project.py`.
