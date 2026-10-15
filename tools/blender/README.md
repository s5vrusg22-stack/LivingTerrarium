# Base2 experimental Blender mantis

This branch adds a **procedural anatomical prototype**, not a finished photorealistic mantis. The existing canonical `assets/models/base1.glb` remains untouched.

## Build (Blender 4.x)

From the repository root:

```bash
blender -b -t 4 --python tools/blender/generate_base2.py
blender -b assets/models/base2.blend --python tools/blender/enhance_base2.py
python3 tools/blender/validate_base2.py assets/models/base2_detailed.glb
```

Expected output files:

- `assets/models/base2.blend` — editable first-pass mesh
- `assets/models/base2.glb` — static prototype
- `assets/models/base2_detailed.blend` — procedural surface shaders and animated controls
- `assets/models/base2_detailed.glb` — experimental Godot import candidate

**Important limitations:** This is not yet photographically accurate, and its head/foreleg animation is object-parented controller animation rather than an anatomical skeletal rig. Blender procedural noise node fidelity in glTF is not guaranteed: for reliable Godot appearance, bake Base Color, Normal and Roughness maps into UV textures in a later pass. The generated model must be inspected for leg articulation, wing shape, clipping, and Godot axis orientation before any runtime replacement. The generation scripts have not yet been executed or visually verified in this development environment.

## Safe integration plan

1. Keep Base1, its runtime node name, existing tests, and the APK unchanged.
2. Generate and validate Base2 with Blender installed.
3. Import the generated GLB into Godot in an isolated test scene; review dimensions, shading, animations and performance.
4. Build LODs, improve real-mantis anatomical reference accuracy, and bake PBR maps.
5. Switch the live scene only after visual tests and user approval. Do not overwrite Base1 or change its protected checksum test.

## Geometry inventory

The prototype includes distinct head and eye objects, two antenna chains, prothorax, thorax, seven abdomen tergites/sternites, six walking legs, two raptorial forelegs, femoral and tibial spines, two wing surfaces and longitudinal veins. These are intentionally independently named for future replacement with manually sculpted retopologized geometry.
