# v8.4.0 — Photo-refined mantis model

This release replaces the canonical adult mantis model with a detailed Blender
build based on the supplied front, side, dorsal, and rear photographs. It keeps
the existing Godot-facing model path, 62-joint rig, and 11 animation clip names.

## Model details

- Triangular head with large faceted compound eyes, forward pseudopupils,
  forehead ocelli, mandibles, palps, and curved antennae.
- Long pronotum with dorsal keel and lateral margins, plus paired folded
  tegmina and veined hindwing membranes.
- Seven segmented abdomen plates with ventral segmentation, paired spiracles,
  and terminal cerci.
- Six walking legs with articulated joints, spines, segmented feet, and claws;
  paired raptorial forelegs with flattened femora, inner spines, and tibial combs.
- Separate cuticle, eye, membrane, joint, and spine materials.
- Six-direction review renders: front, rear, left, right, dorsal, and ventral.

The geometry is a hand-authored anatomical interpretation of photographs, not
photogrammetry. The checked-in editable source is compressed as
`tools/blender_source/mantis_photo_refined.blend.gz`; Blender opens it directly.
The generator writes a regular `.blend` source and the canonical GLB with
Blender 4.x:

```sh
blender --background --python tools/generate_mantis_photo_refined_blender.py
```

The model stays at `assets/models/mantis_latest.glb`, which is the path loaded by
the running simulation. The Godot integration keeps the authored GLB materials
and hides the folded adult wings during juvenile instars.

## Build and checks

- App version: `8.4.0` (Android version code `84`)
- Android output: `build/LivingTerrarium3D-v8.4-ARM64.apk`
- Model check: `python3 tests/check_v84_photo_model.py`
- Main-scene check: `tests/check_mantis_model_default.gd`
- CI also imports the project, checks the canopy and crayfish scene, and exports
  the Android ARM64 APK.
