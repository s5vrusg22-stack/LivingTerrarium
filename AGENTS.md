# LivingTerrarium agent instructions

These instructions apply to every code, model, simulation, and APK task in this repository.

## Read this before editing

1. Read this file and `README_v8.3.md`.
2. Inspect the current `main` commit, the active scene, its script, the canonical model file, and the model checks in CI.
3. Do not begin model or simulation edits until the source file and runtime path below are verified against the checkout.

## Canonical mantis source

- Repository branch: `main`.
- Approved baseline: `assets/models/base1.glb`.
- Approved baseline Git blob SHA: `11f382981fb1afd2b0506a8ddee16b52a55c8259` (2,779,044 bytes).
- This exact file is the approved model recovered byte-for-byte from the known-good v8.3 APK.
- Runtime/imported root name: `Base1`. The app loads it through `scripts/main.gd` in the main scene.
- The app release name is Base 1 / version 1.0.0. Do not change the model name, app version, or runtime asset path unless the user explicitly requests that change.

The historical note that the recovered source was once tracked as “V7” describes provenance only. It does not authorize loading a separate V7 asset. The path and approved blob SHA above identify the source of truth.

## Never substitute another mantis

Do not replace, rebuild from scratch, or silently switch the canonical model to:

- `mantis_v7_animated.glb`
- `mantis_latest.glb`
- `mantis_detailed.glb`
- `mantis_rigged.glb`
- a photo cutout, a procedural mesh, or any other unapproved mantis asset

Do not add a fallback that displays one of these if Base 1 fails to import or load. A missing file, checksum mismatch, import failure, or wrong runtime node is a blocking error: report the exact mismatch and stop instead of guessing or substituting.

## How to make an explicitly requested model change

If the user asks to change Base 1's geometry, materials, or rig:

- Start from the verified canonical Base 1 asset and preserve its identity, skeleton, and animation clips unless the request explicitly changes them.
- Use reference photos to guide the requested edits; do not use them to reconstruct a different mantis from scratch.
- Keep the runtime asset path `assets/models/base1.glb` and root name `Base1`.
- Preserve the previous approved file in Git history. Update the pinned SHA in `README_v8.3.md` and `tests/check_base1_baseline.py` only after the edited model has been visually reviewed and its lineage from the previous approved SHA is documented.
- Never change the expected SHA merely to make a failing check pass.

For tasks that do not request a model-asset change, preserve the pinned GLB bytes. Do not “improve” or replace the model as an incidental part of simulation work.

## Required verification

Before calling a task complete:

- Run `python3 tests/check_base1_baseline.py`.
- Run the Godot runtime check `godot --headless --path . --script res://tests/check_mantis_model_default.gd`.
- For APK work, require the GitHub Actions workflow `.github/workflows/android.yml` to pass, including its packaged-model and version checks.
- Inspect the final runtime model, not only source files. For visual model changes, compare before/after renders from the same camera and lighting and report what was actually checked.
- Report the source commit, model SHA, changed files, and test results. Never claim a runtime or APK check passed unless that check actually ran and passed.
