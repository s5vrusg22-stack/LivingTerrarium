# Living Terrarium 3D v2.3 — rigged glTF preview

- `assets/models/mantis_rigged.glb`: generated glTF 2.0 binary with an actual `skin`, joint nodes, inverse bind matrices, vertex JOINTS_0/WEIGHTS_0, and 10 animation clips.
- `scenes/mantis_rigged_preview.tscn`: isolated Godot preview of the imported model.
- `scripts/rigged_mantis_preview.gd`: tries to play a named imported animation through AnimationPlayer.

## Limitations

This is **rigid one-joint-per-mesh skinning**, not artist-weighted deformable Blender rigging. It uses simple procedural shapes and basic rotation clips. The existing game still uses the older procedural mantis for IK/AI; switching to this GLB would require integrating bone poses, correcting axes and testing animations. Godot and Blender binaries were unavailable, so visual runtime/import verification and APK build were not performed. This is a technical rigged asset, not a photorealistic finished model.
