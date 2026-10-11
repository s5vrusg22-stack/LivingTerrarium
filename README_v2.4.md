# Living Terrarium 3D v2.4 — Rigged GLB main-scene integration

This release moves the **existing skinned GLB and its ten animation clips into the main simulator**, while retaining the procedural animal as an invisible IK/behavior reference and a selectable fallback. It does **not** yet drive the imported skeleton with the procedural foot IK: GLB WALK/CLIMB are baked animations, and feet may slide. The model remains stylized. Godot/Blender/Android tools were unavailable in this environment; no runtime or APK claim is made.

## Thirty integration/verification steps

1. Preserve v2.3 baseline and assets.
2. Validate binary GLB presence.
3. Check GLB header magic.
4. Check GLB version 2.
5. Check GLB byte length.
6. Parse glTF JSON chunk.
7. Verify glTF 2.0 metadata.
8. Verify default scene.
9. Verify mesh payloads.
10. Verify node graph.
11. Verify skin entry.
12. Verify joint count.
13. Verify inverse-bind accessor.
14. Verify JOINTS_0 vertex attribute.
15. Verify WEIGHTS_0 vertex attribute.
16. Check IDLE clip.
17. Check WALK clip.
18. Check ALERT clip.
19. Check GROOM clip.
20. Check HUNT clip.
21. Check STRIKE clip.
22. Check SCAN clip.
23. Check FEED clip.
24. Check CLIMB clip.
25. Check DEFEND clip.
26. Load the GLB as PackedScene from the game code.
27. Parent the visual under the existing animal root so AI movement/growth remain shared.
28. Map clip names and crossfade without restarting clips every frame.
29. Keep procedural mesh fallback, preserving IK and collision references.
30. Add an in-game model switch for side-by-side comparison.

Additional integration work: recursive AnimationPlayer discovery; handling library-qualified animation names; fallback for missing imported animation; IDLE during molting; play/pause speed synchronization; a manual STRIKE replay; and no duplicate growth scale.

## Verify

From the extracted project directory:

```sh
python tests/check_v24_integration.py
for f in tests/check*.py; do python "$f"; done
```

Open `project.godot` in Godot 4, let it import the GLB, then launch `scenes/main.tscn`. Use **3D 모델 전환 (GLB / 기본)** to compare the imported visual and the old procedural visual. Use animation demonstration buttons to switch clips. Observe for GLB import warnings, incorrect facing direction, visual scale, foot sliding, skeleton deformations, and collisions. If import fails, the old procedural geometry remains visible.

## Remaining risks / next development

- Need actual Godot editor/headless import and scene launch.
- Need align imported Skeleton3D bone axes to world-space procedural IK (foot locking currently applies only to hidden reference geometry).
- Need align model visual scale/orientation after viewing in-engine.
- Need physically grounded climbing, realistic deformable rig and production-quality PBR assets.
- Need Android SDK export templates and device performance tests before APK.
