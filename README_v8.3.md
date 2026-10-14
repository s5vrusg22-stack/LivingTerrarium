# Living Terrarium 3D v8.3

## Canonical mantis model

- The runtime uses only `assets/models/mantis_latest.glb`.
- It starts from the mantis model selected by the successful v8.3 APK: the
  `mantis_v7_animated.glb` source at Git commit `bb32cf5`, blob
  `11f382981fb1afd2b0506a8ddee16b52a55c8259`.
- The refinement adds 14 raised cross-veins on each forewing. It preserves the
  source body meshes, head and compound-eye facets, authored materials, and all
  six source animation clips byte-for-byte.
- Other model variants and the mistaken from-scratch v8.4 model are removed
  from the exported project. The generator rejects any source blob other than
  the one pinned above.
- Procedural meshes and photo cutouts stay hidden as mantis alternatives. The
  runtime check verifies that the canonical GLB is selected and visible.

## Recovery record

- The recovered v8.3 ARM64 APK contains compiled Godot scripts, so it does not provide editable `.gd` source.
- Editable scripts and habitat assets were restored from the available full project source archive labeled v8.1. The APK confirms the v8.3 model and habitat script families, but compiled scripts cannot prove byte-for-byte source identity with that archive.
- The app/export version is set to 8.3.0 and Android version code 83. The recoverable pre-restoration `main` is preserved in `backup/main-pre-v8.3-restore-20261012`.

## Build and checks

Build `build/LivingTerrarium3D-v8.3-ARM64.apk` with Godot 4.3, Android export templates, and the Android SDK using `tools/build_android_apk.sh`.

The Android workflow checks the pinned GLB identity and its startup visibility, checks the plant corridor and modeled blue crayfish, then exports an ARM64 APK. It uploads the APK and checksum as workflow artifacts.
