# Living Terrarium 3D v8.3

## Canonical mantis model

- The app uses only `assets/models/mantis_v7_animated.glb` as its canonical mantis model.
- This is the recovered, previously approved 4,280,964-byte GLB with 62 joints, 225 meshes, and 11 animation clips. Its Git object ID is `4536831ef5925acd706a9f607f30d31043e4173c`.
- The Android workflow imports this exact binary. It no longer runs a Blender model generator or commits regenerated model files.
- The obsolete `mantis_detailed.glb` and `mantis_v7_animated.glb` assets, their import sidecars, and their preview scenes have been removed.
- Procedural meshes and photo cutouts are disabled as visible mantis alternatives. The runtime check requires the known-good V7 GLB to load and remain visible.

## Recovery record

- The recovered v8.3 ARM64 APK contains compiled Godot scripts, so it does not provide editable `.gd` source.
- Editable scripts and habitat assets were restored from the available full project source archive labeled v8.1. The APK confirms the v8.3 model and habitat script families, but compiled scripts cannot prove byte-for-byte source identity with that archive.
- The app/export version is set to 8.3.0 and Android version code 83. The recoverable pre-restoration `main` is preserved in `backup/main-pre-v8.3-restore-20261012`.

## Build and checks

Build `build/LivingTerrarium3D-v8.3-ARM64.apk` with Godot 4.3, Android export templates, and the Android SDK using `tools/build_android_apk.sh`.

The Android workflow checks the pinned GLB identity and its startup visibility, checks the plant corridor and modeled blue crayfish, then exports an ARM64 APK. It uploads the APK and checksum as workflow artifacts.
