#!/usr/bin/env python3
"""Install a locally supplied V54 GLB into the canonical Godot model slot.

Usage:
    python3 tools/install_v54_model.py /path/to/base1_v54_anatomy_shading_repair.glb

The existing Base 1 model is backed up, not discarded. The existing baseline
guard is intentionally NOT bypassed; its expected hash must be reviewed and
updated only after an actual runtime verification of the replacement.
"""
import hashlib
import json
import shutil
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/models/base1.glb"

def inspect_glb(path):
    with path.open("rb") as f:
        head = f.read(20)
        if len(head) != 20:
            raise ValueError("Truncated GLB")
        magic, version, length, json_length, json_type = struct.unpack("<4sIIII", head)
        if magic != b"glTF" or version != 2 or length != path.stat().st_size or json_type != 0x4E4F534A:
            raise ValueError("Invalid GLB 2.0 header")
        doc = json.loads(f.read(json_length))
    if not doc.get("meshes") or not doc.get("scenes"):
        raise ValueError("GLB is missing meshes or scenes")
    return doc

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: install_v54_model.py path/to/v54.glb")
    source = Path(sys.argv[1]).resolve()
    if not source.is_file():
        raise SystemExit(f"Source not found: {source}")
    doc = inspect_glb(source)
    DEST.parent.mkdir(parents=True, exist_ok=True)
    backup = DEST.with_suffix(".before-v54.glb")
    if DEST.exists() and not backup.exists():
        shutil.copy2(DEST, backup)
    shutil.copy2(source, DEST)
    manifest = {
        "model": "V54 candidate (not yet runtime-validated)",
        "path": str(DEST.relative_to(ROOT)),
        "size_bytes": DEST.stat().st_size,
        "sha256": sha256(DEST),
        "meshes": len(doc.get("meshes", [])),
        "skins": len(doc.get("skins", [])),
        "animations": len(doc.get("animations", [])),
        "images": len(doc.get("images", [])),
        "baseline_tests_need_review": True,
    }
    (ROOT / "assets/models/v54-install-manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))
    print("IMPORTANT: run Godot import, scene tests and Android export before merging.")

if __name__ == "__main__":
    main()
