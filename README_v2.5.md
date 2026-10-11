# v2.5 — Skeletal pose integration and validation

Ten development improvements:

1. Find imported `Skeleton3D` recursively.
2. Validate required named walking-leg bones.
3. Validate foreleg and antenna bones.
4. Keep imported animation playback and crossfades.
5. Derive world-anchored stance targets from existing procedural gait.
6. Apply bounded coxa pose corrections to six legs.
7. Apply paired tibia/joint compensation.
8. Drive head aim from existing head pivot.
9. Blend attack/alert foreleg corrections.
10. Reset overrides when switching to procedural model and fall back on missing bones.

**Limitations:** Orientation-only bone correction, not a full analytical skeletal IK; no physical climbing or Android APK. Godot/Blender binaries are unavailable in this environment, so actual engine import and visual playback remain unverified.
