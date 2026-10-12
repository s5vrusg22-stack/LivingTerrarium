# Living Terrarium 3D v3.1

## Runtime model lock

- `assets/models/mantis_rigged.glb` is the single canonical visible rig.
- Startup validates the asset path, 61-bone skeleton, ten animation clips, and at least 30 mesh parts.
- If validation fails, the runtime hides all procedural reference meshes and shows an error. It never switches to an older model.
- Juvenile mode keeps the canonical rig, scales it to nymph size, hides adult wings, and adds small wing buds. This is the first in-game juvenile profile; a separate juvenile GLB can be authored later.

## Controls and habitats

- Hold the arrow keys or WASD to pan freely. Hold Shift to move faster; Q/E move vertically. Page Up/Down zoom continuously.
- Touch users can hold the on-screen direction pad. Drag to orbit and pinch or use the zoom buttons.
- The enclosure is 11.2 × 8.2 × 7.1 scene units. Rainforest, dry grassland, desert, and temperate forest profiles set different lighting, foliage tint, temperature, and humidity defaults.
- Twelve independent terrarium slots preserve the individual name, species profile, life stage, biome, care values, decorations, feeder types, and position. Slot 1 can migrate existing v2–v6 saves.

## Animal and food controls

- Direct commands include flight, hunting, jumping, upside-down leaf hanging, molting, threat display, a non-injury fight display, courtship display, and trunk climbing.
- Six named profiles currently share the canonical model with distinct color and size profiles. The mint Chiang Mai type (Hierodula sp.) is the default; each terrarium save slot can keep a different individual.
- Feeders include crickets, Dubia roaches, fruit flies, blow flies, mealworms, waxworms, locusts, and moths. Larval, roach, fly, moth, and locust forms use different sizes, colors, or visible anatomy.
- Trunk climbing uses staggered foot steps around the bark surface, alternating weight shifts, and a wall-facing body orientation.

## Verification

`tests/check_v31_features.py` checks the model lock and new camera, command, save, stage, prey, biome, and climb contracts. GitHub Actions imports the project in Godot 4.3, compiles each GDScript, runs the startup scene, and captures six model views. Android APK export is an explicit manual workflow option and stays off by default.
