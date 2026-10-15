# LivingTerrarium agent instructions

These instructions apply to every code, model, simulation, and APK task in this repository.

## Read this before editing

1. Read this file and `README_v8.3.md`.
2. Inspect the current `main` commit, the active scene, its script, the canonical model file, and the model checks in CI.
3. Do not begin model or simulation edits until the source file and runtime path below are verified against the checkout.

## Canonical mantis source

- Repository branch: `main`.
- Approved baseline: `assets/models/base1.glb`.
- Current approved Base 1 Git blob SHA: `17b3b5f96e5413595d9cc5a41fa33de78d525fbc` (6,853,796 bytes).
- This model continues the V7 Base 1 source recovered from the known-good v8.3 APK. It keeps the same 38-node model, root, and six animation clips; the current revision builds separated, curved forewing/hindwing shells, fine low-contrast wing venation and relief maps, and shallow segmented abdomen plates while refining the original Base 1 mesh. `MODEL_CHANGE.json` records the exact input commit/blob and output blob hashes.
- Runtime/imported root name: `Base1`. The app loads it through `scripts/main.gd` in the main scene.
- The app release name is Base 1 / version 1.0.0. Do not change the model name, app version, or runtime asset path unless the user explicitly requests that change.

“V7” identifies the source model to develop. Continue editing the current GitHub `main` model at the canonical path above; do not load a separate, older, or replacement GLB.

## Mandatory gate before any mantis modeling

If a task asks to edit, remodel, recolor, rig, animate, resize, or otherwise change the mantis model:

1. Start from a clean clone or clean worktree of this repository.
2. Run `bash tools/start_mantis_model_edit.sh` before opening or editing any model. It fetches GitHub `origin/main`, verifies the approved Base1 Git blob and rejects legacy mantis assets, then creates a fresh branch directly from that exact main commit.
3. Record the commit and blob SHA printed by the script. Work only on `assets/models/base1.glb` in that new branch. Never open an older branch, APK-extracted alternate, generated replacement, or similarly named GLB as the starting model.
4. If the model is changed, run `python3 tools/finalize_model_change.py --summary 'specific description of the actual edits'`. Commit the generated `MODEL_CHANGE.json` with the model change.
5. If the script reports any mismatch, stop. Do not search for a “closest” model or continue from another asset.

For a task that does not explicitly request a model change, preserve the locked GLB bytes. A changed model without a matching lineage record fails CI.


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

- Start from the verified canonical Base 1 asset and preserve its identity, node structure, and animation clips unless the request explicitly changes them. A requested movement change may refine keyframes while retaining the existing clip names and model hierarchy.
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
