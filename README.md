# Living Terrarium 3D

The `main` branch baseline is **v8.4.0**. It includes the mantis terrarium
and six selectable habitats: tropical fish aquarium, crayfish habitat,
butterfly greenhouse, land hermit crab tank, and stream valley salamander
habitat.

The app's canonical mantis model is `assets/models/mantis_latest.glb`. The
v8.4 model is a detailed, hand-authored interpretation of the supplied front,
side, dorsal, and rear photos. Its 62-joint rig and 11 animation clips remain
compatible with the simulation. The 4,782,804-byte GLB contains 85 mesh packs
and preserves distinct cuticle, eye, underside, spine, and wing materials. The
editable Blender source is `tools/blender_source/mantis_photo_refined.blend.gz`
(Blender opens the compressed project directly), and its Blender generator is
`tools/generate_mantis_photo_refined_blender.py`. Android imports the committed
GLB as-is; it does not regenerate or replace the model. The baseline test pins
the model's Git object ID (`89e011d132e9e2d5c0c0fc456336481dbbf5296a`) and
checks the rig, clips, body structures, editable source, and app integration.

Build the Android ARM64 APK with `tools/build_android_apk.sh` and Godot 4.3,
Android export templates, and the Android SDK. Run
`python3 tests/check_v84_photo_model.py` and the habitat integration checks
listed in `.github/workflows/android.yml`.

Historical habitat notes are retained in `README_v2.9.md`,
`README_v3.0.md`, `README_v3.8.md`, `README_v3.9.md`, `README_v4.0.md`,
`README_v4.1.md`, `README_v4.3.md`, `README_v4.5.md`, `README_v4.6.md`,
`README_v4.8.md`, `README_v5.0.md`, `README_v5.2.md`, `README_v8.1.md`,
`README_v8.3.md`, and `README_v8.4.md`.
