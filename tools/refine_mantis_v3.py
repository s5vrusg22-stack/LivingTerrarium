#!/usr/bin/env python3
"""Apply the photo-guided v3 body-proportion pass to the existing rigged GLB.

This pass preserves the skeleton, weights, animations, and materials while
making both tegmina fuller, the pronotum more legible, and the raptorial
forelegs easier to read at the simulator's normal viewing distance.
"""
from __future__ import annotations

import upgrade_mantis_glb as glb


PROJECT = glb.PROJECT
MODEL = PROJECT / "assets" / "models" / "mantis_rigged.glb"
MARKER = "photo_proportions_v3"


def factors_for(name: str) -> tuple[float, float, float] | None:
    """Return per-axis local-mesh scales (GLB axes: width, depth, body length)."""
    if name.startswith("Wing_"):
        # Open up each leaf-shaped wing in width and extend its rearward tip.
        return (1.22, 1.12, 1.12)
    if name == "Thorax":
        # Keep the pronotum slender while giving its plate a visible profile.
        return (1.30, 1.16, 1.14)
    if name.startswith("ForeFemur_"):
        return (1.14, 1.14, 1.14)
    if name.startswith("ForeTibia_"):
        return (1.20, 1.12, 1.12)
    if name.startswith("Spine_"):
        return (1.22, 1.22, 1.22)
    return None


def main() -> None:
    if not MODEL.exists():
        raise FileNotFoundError(MODEL)
    document, binary = glb.read_glb(MODEL)
    extras = document.setdefault("asset", {}).setdefault("extras", {})
    current = extras.get("reference_mantis_refinement")
    if current in {MARKER, "photo_proportions_v4", "photo_proportions_v5", "photo_proportions_v6", "photo_proportions_v7_80_detail", "photo_proportions_v8_forelegs_100", "photo_proportions_v10_photo_forelegs_100"}:
        print("The v3 photo-proportion pass or a later pass is already applied; leaving the GLB unchanged.")
        return
    if current != "v2":
        raise ValueError(f"Expected the v2-refined GLB, found {current!r}; refusing to rescale an unknown base.")

    processed: set[int] = set()
    changed: list[str] = []
    for mesh in document.get("meshes", []):
        name = mesh.get("name", "")
        factors = factors_for(name)
        if factors is None:
            continue
        for primitive in mesh.get("primitives", []):
            attributes = primitive.get("attributes", {})
            position_index = attributes.get("POSITION")
            if position_index is None or position_index in processed:
                continue
            positions = glb.read_vectors(document, binary, position_index)
            sx, sy, sz = factors
            scaled = [(p[0] * sx, p[1] * sy, p[2] * sz) for p in positions]
            glb.write_vectors(document, binary, position_index, scaled)
            index = primitive.get("indices")
            indices = glb.read_indices(document, binary, index) if index is not None else list(range(len(scaled)))
            normal_index = attributes.get("NORMAL")
            normals = glb.vertex_normals(scaled, indices)
            if normal_index is None:
                attributes["NORMAL"] = glb.append_normal_accessor(document, binary, normals)
            else:
                glb.write_vectors(document, binary, normal_index, normals)
            processed.add(position_index)
        if name not in changed:
            changed.append(name)

    expected = {"Wing_L", "Wing_R", "Thorax", "ForeFemur_L", "ForeFemur_R", "ForeTibia_L", "ForeTibia_R"}
    missing = expected.difference(changed)
    if missing:
        raise ValueError(f"Required anatomy meshes are missing: {sorted(missing)}")
    extras["reference_mantis_refinement"] = MARKER
    glb.write_glb(MODEL, document, binary)
    print(f"Updated {MODEL.name}: {len(changed)} anatomy meshes; preserved all GLB animations and skin data.")


if __name__ == "__main__":
    main()
