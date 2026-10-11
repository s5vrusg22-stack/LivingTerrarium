# Living Terrarium 3D v2.7 — Hierarchical rig and CCD IK

## Changes
- Rebuilt the existing GLB joint hierarchy into six Coxa → Joint (knee) → Tibia chains, plus foreleg and head parenting.
- Preserved each joint's **world bind transform** by recalculating child-local matrices; original inverse-bind matrices and rigid vertex weights remain unchanged.
- Replaced the old direction-only correction with a **three-iteration CCD skeletal IK** in `scripts/rigged_pose_driver.gd`.
- Converts world-space planted-foot anchors to Skeleton3D-local targets, caps unreachable targets, caps each joint's incremental angle, and reduces influence during swing.
- Detects older flat rigs and falls back to the prior rotation correction instead of treating them as a valid chain.
- Preserved inclined-branch climbing movement and contact targets from v2.6.

## Important limitations
- The existing generated mesh is still rigidly weighted and its tibia joint is approximately located; the bone origin is only an approximate foot endpoint. This is not anatomically perfect IK.
- Imported animation and runtime override composition, appearance, clipping, and collisions **require a real Godot runtime test**; no engine executable is available in this environment.
- Free-form branch climbing, robust navigation, and Android APK are not complete.

## Test
`python tests/check_v27_hierarchy.py` and `python tests/check_project.py`.
