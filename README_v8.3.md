# Living Terrarium 3D v8.3

## Mantis model
- The app opens with `assets/models/mantis_latest.glb`, the newest canonical model built for this project.
- The Blender source produces a 62-bone rig with 247 mesh resources and 11 animation clips.
- The former `mantis_rigged.glb` was selected by mistake during the v8.3 source restoration. That obsolete GLB, its import file, and its generator were removed. No app selector points to it.
- The older `mantis_v7_animated.glb` remains as an unused source asset; it is not loaded by the app.

## Recovery record
- The recovered v8.3 ARM64 APK contains compiled Godot scripts, so it does not provide editable `.gd` source.
- Editable scripts and habitat assets were restored from the available full project source archive labeled v8.1. The APK confirms the v8.3 model and habitat script families, but compiled scripts cannot prove byte-for-byte source identity with that archive.
- The app/export version is set to 8.3.0 and Android version code 83. The recoverable pre-restoration `main` is preserved in `backup/main-pre-v8.3-restore-20261012`.

## Build and checks
Build `build/LivingTerrarium3D-v8.3-ARM64.apk` with Godot 4.3, Android export templates, and the Android SDK using `tools/build_android_apk.sh`.

The Android workflow regenerates the canonical model from Blender before import, verifies the model contract and its startup visibility, checks the plant corridor, and exports an ARM64 APK. It commits the regenerated GLB to `main` after the checks pass.
