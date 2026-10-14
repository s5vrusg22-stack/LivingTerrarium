# Living Terrarium 3D

The app stays on the **v8.3.0** simulation baseline and uses one canonical
mantis asset: `assets/models/mantis_latest.glb`. This model is based on the
mantis selected by the successful v8.3 APK: Git blob
`11f382981fb1afd2b0506a8ddee16b52a55c8259`, from
`assets/models/mantis_v7_animated.glb` at commit `bb32cf5`.

The refinement adds raised cross-veins to both forewings. It retains the APK
model's authored body meshes, compound-eye facets, materials, and six original
animation clips. The generator refuses any source other than that exact v8.3
model:

```sh
python3 tools/refine_v83_mantis_glb.py
python3 tests/check_v83_baseline.py
```

Only `mantis_latest.glb` is shipped as the mantis model. Older alternatives
and the separate from-scratch model from the mistaken v8.4 change are removed.
The Android build imports the committed canonical asset and produces
`build/LivingTerrarium3D-v8.3-ARM64.apk`.

GitHub Actions rebuilds the model deterministically from its pinned source,
checks the committed output, imports the Godot project, verifies the habitats
and default mantis model, and exports the Android ARM64 APK.

Historical habitat notes are retained in `README_v2.9.md`,
`README_v3.0.md`, `README_v3.8.md`, `README_v3.9.md`, `README_v4.0.md`,
`README_v4.1.md`, `README_v4.3.md`, `README_v4.5.md`, `README_v4.6.md`,
`README_v4.8.md`, `README_v5.0.md`, `README_v5.2.md`, `README_v8.1.md`,
and `README_v8.3.md`.
