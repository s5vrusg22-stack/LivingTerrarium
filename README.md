# Living Terrarium 3D

## Current release

The canonical mantis model is **Base 1**, stored at
`assets/models/base1.glb`. Godot imports it with the root name `Base1`, and
the running model node is also named `Base1`. The GLB bytes are unchanged from
the approved V7 model recovered from the known-good APK
(Git blob SHA `11f382981fb1afd2b0506a8ddee16b52a55c8259`); only its repository
filename and imported/runtime label are Base 1.

The app and APK display version is **1.0.0**. Android version code is **84**,
one greater than the previous 8.3 build's code 83, so Android can install this
APK as an update. The ARM64 APK is
`build/LivingTerrarium3D-Base1-v1.0.0-ARM64.apk`.

Build with Godot 4.3, export templates, and the Android SDK using
`tools/build_android_apk.sh`. GitHub Actions checks the exact Base 1 GLB
bytes, the import/runtime root name, startup visibility and animation, the
habitats, the APK's packaged model, and the APK's version before uploading it.

Historical habitat notes are retained in `README_v2.9.md`, `README_v3.0.md`,
`README_v3.8.md`, `README_v3.9.md`, `README_v4.0.md`, `README_v4.1.md`,
`README_v4.3.md`, `README_v4.5.md`, `README_v4.6.md`, `README_v4.8.md`,
`README_v5.0.md`, `README_v5.2.md`, `README_v8.1.md`, and
`README_v8.3.md`.
