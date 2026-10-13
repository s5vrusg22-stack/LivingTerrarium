# Living Terrarium 3D

The `main` branch baseline is **v8.3.0**. It includes the mantis terrarium
and six selectable habitats: tropical fish aquarium, crayfish habitat,
butterfly greenhouse, land hermit crab tank, and stream valley salamander
habitat.

The app's canonical mantis model is
`assets/models/mantis_latest.glb`. It is restored from the approved 4,280,964-byte
model (62 joints, 247 meshes, and 11 animation clips). The Android workflow
imports this exact file as-is; it does not regenerate or replace the model.
The baseline check pins the model's Git object ID
(`4536831ef5925acd706a9f607f30d31043e4173c`) and rejects obsolete mantis
model files.

Build the Android ARM64 APK with `tools/build_android_apk.sh` and Godot 4.3,
Android export templates, and the Android SDK. Run
`python3 tests/check_v83_baseline.py` and the habitat checks in `tests/`.

Historical habitat notes are retained in `README_v2.9.md`,
`README_v3.0.md`, `README_v3.8.md`, `README_v3.9.md`, `README_v4.0.md`,
`README_v4.1.md`, `README_v4.3.md`, `README_v4.5.md`, `README_v4.6.md`,
`README_v4.8.md`, `README_v5.0.md`, `README_v5.2.md`, `README_v8.1.md`,
and `README_v8.3.md`.
