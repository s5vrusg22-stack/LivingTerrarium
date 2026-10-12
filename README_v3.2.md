# Living Terrarium 3D v3.2

## Growth stages

- Each individual can be set to L1, L2, L3, L4, L5, L6, or adult.
- Nymph body size increases at each instar. Wing pads grow across L1–L6, and the adult wing meshes appear at the final molt.
- Molting advances exactly one instar. Automatic molts stop when the individual reaches adulthood, and the manual molt command is disabled for adults.
- Existing saves that use the older `약충` label migrate to the closest instar using their saved molt count; adult and terrarium records remain intact.

## Adult rig and animation

- The Blender source builds the canonical adult GLB with a tapered triangular head, compound-eye facets, segmented abdomen and spiracles, articulated forelegs with spines, articulated antennae, and layered cambered wings with branching veins.
- The rig keeps two visible walking leg pairs and the raptorial pair. A third unused leg chain remains in the skeleton for contract compatibility.
- The imported model has 62 bones, 225 mesh resources, and 11 animation clips. Startup hides all old procedural render meshes and displays no mantis if the canonical rig fails validation.
- `tools/generate_rigged_mantis_blender.py` generates the rig; CI regenerates it before import, visual renders, and Android export.

## APK build and verification

- The Android preset exports a debug ARM64 APK (`org.livingterrarium.simulator`). The workflow checks APK ZIP integrity, package ID, and the ARM64 library before uploading the artifact.
- A push to `codex/mantis-l1-l6-apk-20261012` builds and uploads the APK. Other runs only build it when the `build_android` workflow input is enabled.
- `tests/check_v32_instars_and_model.py` verifies stage progression, old-save migration, the no-adult-molt rule, and the canonical GLB rig contract.
