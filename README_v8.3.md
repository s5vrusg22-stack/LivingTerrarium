# Base 1 — release 1.0.0

## Canonical mantis model

- The only mantis model shipped by the app is **Base 1** at `assets/models/base1.glb`.
- It is the refined continuation of the V7 model recovered from the known-good v8.3 APK: 6,853,796 bytes, Git blob SHA `17b3b5f96e5413595d9cc5a41fa33de78d525fbc`. `MODEL_CHANGE.json` records the exact input commit/blob and output blob. This revision keeps the original 38-node Base 1 hierarchy and six clips, shapes distinct curved forewing and hindwing surfaces, replaces dark triangle-strip veins with fine low-contrast color and relief detail, adds slight membrane translucency and chitin highlights, and gives the abdomen shallow segmented plates.
- Godot import metadata sets `nodes/root_name="Base1"`; the running scene names the visible model node `Base1`.
- Alternate mantis GLBs and the old V7 filename are absent from the current model directory. CI rejects any model set other than Base 1 and the separate blue crayfish asset.
- The runtime check requires Base 1 to load, stay visible, and provide its imported animations.

## Recovery provenance

The Base 1 geometry and animation source is the V7 model recovered from the
known-good v8.3 APK. Recent revisions refine the original abdomen and pronotum,
retain the movable head and foreleg changes, and shape the two existing wing
nodes into separate curved shells with distinct translucent hindwings, fine
venation, relief texture, and restrained chitin gloss. Shallow abdominal grooves
give the original body a segmented profile. The Base 1 identity, node hierarchy,
and six clip names remain intact. Its lineage is recorded in
`MODEL_CHANGE.json`; later edits must follow `AGENTS.md` and update the source
and output checks together.

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
