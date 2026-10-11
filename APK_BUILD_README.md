# Living Terrarium 3D — APK build package

This is a Godot source project, **not a built APK**. Godot and Android SDK are not installed in the ChatGPT runtime, so no local Android build or runtime test was performed.

## Build using GitHub Actions
1. Create a GitHub repository and upload the **contents** of this folder (keep `project.godot` at repository root, including hidden `.github` folder).
2. In Actions, run **Build Android APK**. The workflow downloads Godot 4.3 and export templates and attempts to build a debug APK.
3. Download the `LivingTerrarium3D-debug-apk` artifact after the workflow succeeds.
4. Verify `SHA256SUMS.txt`, then install the APK on Android.

**Warning:** workflow and Godot scripts are not yet engine-tested; build may require changes based on the logs. This package does not contain a photorealistic animal model.
