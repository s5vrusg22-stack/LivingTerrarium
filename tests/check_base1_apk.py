#!/usr/bin/env python3
"""Verify the exported APK packages Base 1 as its only mantis model."""
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
    scene_prefix = "assets/.godot/imported/base1.glb-"
    base1_scenes = sorted(
        name for name in names
        if name.startswith(scene_prefix) and name.endswith(".scn")
    )
    if len(base1_scenes) != 1:
        raise SystemExit(f"Expected exactly one imported Base 1 scene, found: {base1_scenes}")

    sidecar = "assets/assets/models/base1.glb.import"
    if sidecar not in names:
        raise SystemExit(f"Base 1 import metadata is missing: {sidecar}")

    metadata = apk.read(sidecar).decode("utf-8", errors="replace")
    match = re.search(r'^path="res://\.godot/imported/([^"]+\.scn)"$', metadata, re.MULTILINE)
    if match is None or "assets/.godot/imported/" + match.group(1) != base1_scenes[0]:
        raise SystemExit("Base 1 import metadata does not point to the packaged Base 1 scene")

    legacy_markers = (
        "mantis_v7_animated",
        "mantis_latest",
        "mantis_detailed",
        "mantis_rigged",
    )
    legacy_entries = sorted(
        name for name in names
        if any(marker in name.lower() for marker in legacy_markers)
    )
    if legacy_entries:
        raise SystemExit(f"Legacy mantis model entries are still packaged: {legacy_entries}")

print("APK package check passed: Base 1 is the only mantis model.")
