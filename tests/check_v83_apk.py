#!/usr/bin/env python3
"""Verify the exported Android APK packages only the approved Base 1 mantis."""
from pathlib import Path
import re
import sys
import zipfile

apk_path = Path(sys.argv[1])
if not apk_path.is_file() or apk_path.stat().st_size == 0:
    raise SystemExit(f"APK is missing or empty: {apk_path}")

with zipfile.ZipFile(apk_path) as apk:
    corrupt_entry = apk.testzip()
    if corrupt_entry is not None:
        raise SystemExit(f"APK contains a corrupt ZIP entry: {corrupt_entry}")

    names = set(apk.namelist())
    scene_prefix = "assets/.godot/imported/mantis_v7_animated.glb-"
    mantis_scenes = sorted(
        name for name in names
        if name.startswith("assets/.godot/imported/mantis_")
        and name.endswith(".scn")
    )
    if len(mantis_scenes) != 1 or not mantis_scenes[0].startswith(scene_prefix):
        raise SystemExit(f"Expected only the Base 1 imported scene, found: {mantis_scenes}")

    sidecar = "assets/assets/models/mantis_v7_animated.glb.import"
    if sidecar not in names:
        raise SystemExit(f"Base 1 import metadata is missing: {sidecar}")

    metadata = apk.read(sidecar).decode("utf-8", errors="replace")
    match = re.search(r'^path="res://\.godot/imported/([^"]+\.scn)"$', metadata, re.MULTILINE)
    if match is None or "assets/.godot/imported/" + match.group(1) != mantis_scenes[0]:
        raise SystemExit("Base 1 import metadata does not point to the packaged Base 1 scene")

    alternate_assets = sorted(
        name for name in names
        if "mantis_latest" in name.lower()
        or "mantis_detailed" in name.lower()
        or "mantis_rigged" in name.lower()
    )
    if alternate_assets:
        raise SystemExit(f"Alternate mantis assets are still packaged: {alternate_assets}")

print("APK package check passed: Base 1 (V7) is the only mantis scene.")
