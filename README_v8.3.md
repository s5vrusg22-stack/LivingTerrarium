# Living Terrarium 3D v8.3 — recovered baseline

This is the restored starting point for future work on the v8.3 mantis model
and its multi-species habitats. The project opens with the articulated
61-bone mantis, and its species selector includes tropical fish, crayfish,
swallowtail butterflies, land hermit crabs, and stream salamanders.

## Recovery record

- The recovered v8.3 ARM64 APK was inspected. It contains compiled Godot
  scripts, so it does not provide editable `.gd` source.
- The exact `assets/models/mantis_rigged.glb` was verified against the APK and
  the previous GitHub `main` tree. Its SHA-256 is
  `8580a9c00936b436f121db546f5a758e5d306fa829e1b4198ec663ccc1e9a3c2`.
- Editable scripts and habitat assets were restored from the available full
  project source archive labeled v8.1. The APK confirms the v8.3 model and
  habitat script families, but compiled scripts cannot prove byte-for-byte
  source identity with that archive.
- The app/export version is set to 8.3.0 and Android version code 83. The
  recoverable pre-restoration `main` is preserved in
  `backup/main-pre-v8.3-restore-20261012`.

## Build and checks

Build `build/LivingTerrarium3D-v8.3-ARM64.apk` with Godot 4.3, Android export
templates, and the Android SDK using `tools/build_android_apk.sh`.

Run `python3 tests/check_v83_baseline.py` to guard the recovered model,
version, and species set. The historical integrated-project and habitat
checks are also retained in `tests/`.
