# Living Terrarium 3D v8.1 — restored landscape build

This update replaces the incorrect portrait V8.0 export and makes camera orbit
work from the actual scene input path. The six species remain in the same app.

## Scene and model changes

- Locks Android to landscape and enables one-finger or mouse-drag orbit with
  pinch zoom. Dragging across UI controls does not rotate the scene.
- Expands the mantis enclosure to five times its previous interior volume,
  rescales its walls, floor details and branches, and restores a dense canopy
  of 300 animated plants. Leaf geometry is batched per plant for mobile use.
- Uses the detailed 61-bone mantis rig by default, keeps the V7 model and both
  photo cutouts as selectable modes, lengthens the cervical link and extends
  the paired foreleg coxae from their thorax sockets. The olive palette and
  scene lighting are darker and more natural.
- Expands the hermit-crab habitat to 20 times its former volume and improves
  shell growth ridges, aperture rim, spiral and mottled surface texture.
- Expands the salamander habitat to 30 times its former volume and adds a
  framed glass aquarium around its stream, wet bank and rock hide.

## Build and verification

The Android ARM64 build is `build/LivingTerrarium3D-v8.1-ARM64.apk`.
Run `tools/build_android_apk.sh` with Godot 4.3, Android export templates, and
the Android SDK. Run `python3 tests/check_v80_full_project.py` and all test
scripts in `tests/` for the integrated-project checks.

The APK manifest and exported assets are verified after export. Running the
app on an Android device or emulator is still needed for device-side visual QA.
