# Living Terrarium 3D

The `main` branch baseline is **v8.3.0**. It restores the articulated mantis
and the six selectable habitats: mantis terrarium, tropical fish aquarium,
crayfish habitat, butterfly greenhouse, land hermit crab tank, and stream
valley salamander habitat.

The detailed mantis model is `assets/models/mantis_rigged.glb`. Its SHA-256 is
`8580a9c00936b436f121db546f5a758e5d306fa829e1b4198ec663ccc1e9a3c2`, matching
the model in the recovered v8.3 APK. Baseline and recovery provenance are in
[`README_v8.3.md`](README_v8.3.md).

Build the Android ARM64 APK with `tools/build_android_apk.sh` and Godot 4.3,
Android export templates, and the Android SDK. Run
`python3 tests/check_v83_baseline.py` and the habitat checks in `tests/`.

Historical model and habitat notes are retained in `README_v2.9.md`,
`README_v3.0.md`, `README_v3.8.md`, `README_v3.9.md`, `README_v4.0.md`,
`README_v4.1.md`, `README_v4.3.md`, `README_v4.5.md`, `README_v4.6.md`,
`README_v4.8.md`, `README_v5.0.md`, `README_v5.2.md`, and `README_v8.1.md`.
