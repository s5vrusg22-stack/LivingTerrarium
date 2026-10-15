# Base 1 — release 1.0.0

## Canonical mantis model

- The only mantis model shipped by the app is **Base 1** at `assets/models/base1.glb`.
- It is the refined continuation of the V7 model recovered from the known-good v8.3 APK: 5,467,920 bytes, Git blob SHA `f2a4dc60e72cfd6dc48861f75e1a0eff735b690c`. `MODEL_CHANGE.json` records the exact input commit/blob and output blob. This revision keeps the original 38-node Base 1 hierarchy and six clips, tapers the pronotum, shapes a smaller triangular head, lengthens the thoracic bridge, slims the abdomen, advances and thickens the paired raptorial coxae, and recolors the existing cuticle and wing textures from the supplied photo. It tucks exposed thoracic supports and retains inward-facing grasping spines, subtle abdomen segments, separate forewing/hindwing shells, and clean LOD normals.
- Godot import metadata sets `nodes/root_name="Base1"`; the running scene names the visible model node `Base1`.
- Alternate mantis GLBs and the old V7 filename are absent from the current model directory. CI rejects any model set other than Base 1 and the separate blue crayfish asset.
- The runtime check requires Base 1 to load, stay visible, and provide its imported animations.

## Recovery provenance

The Base 1 geometry and animation source is the V7 model recovered from the
known-good v8.3 APK. The supplied reference photo does not support a confident
species identification, so the refinements follow a general winged adult mantis.
They retain the original Base 1 identity, node hierarchy, and six clip names;
shape the pronotum, head, thoracic bridge, abdomen, and foreleg bases; and tune
the existing body and wing colors to the photo. Its lineage is recorded in
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
