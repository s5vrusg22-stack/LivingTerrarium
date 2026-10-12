# Living Terrarium 3D v1.3 — Material Pass

Godot 4 / GDScript Android-targeted terrarium prototype.

## Changes from v1.2
- 5 extra normal maps + 5 roughness maps (512×512 PNG), for a total of 15 textures.
- Godot StandardMaterial3D hookup for cuticle, eyes, bark, stones, substrate.
- Includes deterministic source texture processing script `tools/generate_pbr_maps.py`.
- Existing 10 animation states, physics-based foot raycasts, enclosure editor, saves retained.

## Limitations
- Normal and roughness maps are **estimated from albedo**, not scanned or physically measured.
- The in-game mantis remains procedural geometry; `tools/generate_mantis_blender.py` is a separate Blender base-GLB authoring script and does not automatically replace the in-game model.
- Godot/Blender/Android SDK are unavailable in this environment. The project has NOT been launched or built as APK.


## v1.4: Independent articulated body joints
- Thorax pivot with state-dependent pitch.
- Each grasping foreleg now has independent shoulder, elbow, and tibial claw nodes.
- HUNT, STRIKE, GROOM, FEED, DEFEND and CLIMB drive elbow/claw angles separately.
- Existing six-leg IK, ten animation states and PBR texture assets retained.
- The geometry remains procedural; this is not a skinned Blender GLB.
- Godot runtime and Android APK were not verified in this environment.


See README_v1.6.md for twenty additional procedural anatomical details.


See README_v1.8.md for 30 additional ecological interactions and limitations.


See README_v1.9.md for prey-to-leaf collision approximation, event throttling, and humidity droop fixes.


## v2.4
See `README_v2.4.md` for main-scene rigged GLB integration, 30 validation steps, and known limitations.

## Taller habitat and reference mantis detail pass

The adult mantis uses volumetric body meshes with PBR cuticle and wing maps,
guided by the supplied green mantis photographs. Its tapered triangular head
has a raised compound-eye line. The abdomen uses a 64 by 48 shell grid, the
pronotum a 40 by 32 grid, and each wing a 48 by 18 double surface with modeled
veins. Generated cuticle and wing maps are 1024 px; smaller habitat maps stay
512 px for mobile memory use.

The enclosure measures 7.2 by 5.8 by 5.2 scene units. A tall climbing trunk
reaches into the upper canopy, with five branch tiers and 18 curved vines with
leaves. Roaming uses a slower gait and longer pauses; climbing pauses midway.

Camera controls: drag to orbit, use the mouse wheel to zoom, arrow keys to
orbit, WASD to pan, Q/E to raise or lower the view, Page Up/Page Down to zoom,
F to follow the mantis, and Home to reset. On touch screens, drag to orbit and
pinch to zoom.
