# Living Terrarium 3D v8.3

## Mantis model
- The app opens with `assets/models/mantis_latest.glb`, the newest canonical model already built for this project.
- This Blender-authored GLB has 62 bones, 247 mesh resources, and 11 animation clips.
- The former `mantis_rigged.glb` was an obsolete model selected by mistake during the v8.3 source restoration. It has been removed from the build, and both model selectors now point to the canonical latest GLB.
- The older `mantis_v7_animated.glb` remains as an unused source asset; it is not loaded by the app.

## Recovery record
- The recovered v8.3 ARM64 APK contains compiled Godot scripts, so it does not provide editable `.gd` source.
- Editable scripts and habitat assets were restored from the available full project source archive labeled v8.1. The APK confirms the v8.3 model and habitat script families, but compiled scripts cannot prove byte-for-byte source identity with that archive.
- The app/export version is set to 8.3.0 and Android version code 83. The recoverable pre-restoration `main` is preserved in `backup/main-pre-v8.3-restore-20261012`.

## Build and checks
Build `build/LivingTerrarium3D-v8.3-ARM64.apk` with Godot 4.3, Android export templates, and the Android SDK using `tools/build_android_apk.sh`.

Run `python3 tests/check_v83_baseline.py` to verify the canonical model contract, selected default, and six-habitat project. The Android workflow also imports the project, verifies the mantis model in the running scene, checks the plant corridor, and exports an ARM64 APK.
