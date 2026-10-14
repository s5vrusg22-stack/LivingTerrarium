# Base 1 — release 1.0.0

## Canonical mantis model

- The only mantis model shipped by the app is **Base 1** at `assets/models/base1.glb`.
- It is the refined continuation of the V7 model recovered from the known-good v8.3 APK: 2,779,608 bytes, Git blob SHA `2337fea7502d59c3cad235412fecdf906a9b9dd1`. `MODEL_CHANGE.json` records the exact input commit and blob, and the output blob. The repository filename and Godot imported/runtime root remain Base 1.
- Godot import metadata sets `nodes/root_name="Base1"`; the running scene names the visible model node `Base1`.
- Alternate mantis GLBs and the old V7 filename are absent from the current model directory. CI rejects any model set other than Base 1 and the separate blue crayfish asset.
- The runtime check requires Base 1 to load, stay visible, and provide its imported animations.

## Recovery provenance

The Base 1 geometry and animation source is the V7 model recovered from the
known-good v8.3 APK. This revision extends that model with adjusted neck and
foreleg proportions and no head rotation during walking. The runtime restores
the V7 cuticle and wing colors under the brighter habitat lighting. Its lineage is recorded in `MODEL_CHANGE.json`; later edits
must follow `AGENTS.md` and update the source and output checks together.

## Release and build checks

The app version and Android version name are `1.0.0`. Android version code is
`84`, incremented from the previous code 83 so Android can install the new APK
over the earlier build. The ARM64 output is
`build/LivingTerrarium3D-Base1-v1.0.0-ARM64.apk`.

Use Godot 4.3, Android export templates, and the Android SDK with
`tools/build_android_apk.sh`. GitHub Actions verifies the pinned model bytes,
Base 1 import/runtime naming and startup visibility, the plant corridor and
blue crayfish, the packaged APK model, and the exported APK version. It uploads
the APK and checksum only after every check passes.
