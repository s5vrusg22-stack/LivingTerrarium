# Living Terrarium 3D

The app remains on the **v8.3.0** simulation baseline and has one canonical
mantis model: `assets/models/mantis_latest.glb`. The photo refinement starts
from that exact GitHub model, whose Git blob is
`4536831ef5925acd706a9f607f30d31043e4173c` at commit `1bdf2ee`.

The refinement adds fine compound-eye facets and cross-veins to the existing
forewings. It preserves the original 62-joint rig, 11 animation clips, meshes,
and materials. The generator reads the pinned v8.3 model directly from Git
history and refuses a different source:

```sh
python3 tools/refine_v83_mantis_glb.py
python3 tests/check_v83_baseline.py
```

Only `assets/models/mantis_latest.glb` is used by the simulation. Obsolete
mantis model variants and the separate Blender model from the mistaken 8.4
change are removed and rejected by the baseline check. The Android build
imports the committed canonical model and produces
`build/LivingTerrarium3D-v8.3-ARM64.apk`.

The GitHub Actions workflow regenerates the model from the pinned v8.3 source,
checks that the committed file matches, imports the Godot project, verifies the
habitats and canonical mantis, and exports the Android ARM64 APK.

Historical habitat notes are retained in `README_v2.9.md`, `README_v3.0.md`,
`README_v3.8.md`, `README_v3.9.md`, `README_v4.0.md`, `README_v4.1.md`,
`README_v4.3.md`, `README_v4.5.md`, `README_v4.6.md`, `README_v4.8.md`,
`README_v5.0.md`, `README_v5.2.md`, `README_v8.1.md`, and `README_v8.3.md`.
