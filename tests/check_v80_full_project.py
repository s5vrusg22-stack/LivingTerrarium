"""Regression checks for the recovered V8.3 landscape build and habitat set."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
presets = (root / "export_presets.cfg").read_text(encoding="utf-8")
hermit = (root / "scripts/hermit_crab_system.gd").read_text(encoding="utf-8")
salamander = (root / "scripts/stream_valley_system.gd").read_text(encoding="utf-8")

# Five times the V8 enclosure volume, with the new interior used by the walls,
# walking floor, foliage, branches, floor details, and camera-fit calculation.
assert "const HABITAT_LINEAR_SCALE := 1.71" in main
assert "const HABITAT_WIDTH := 9.6 * HABITAT_LINEAR_SCALE" in main
assert "const HABITAT_DEPTH := 6.8 * HABITAT_LINEAR_SCALE" in main
assert "const HABITAT_CEILING_Y := 3.45 * HABITAT_LINEAR_SCALE" in main
assert "const CAMERA_MAX_DISTANCE := 60.0" in main
assert "habitat_motion_root.scale = Vector3.ONE * HABITAT_LINEAR_SCALE" in main
assert "root.scale = Vector3(HABITAT_LINEAR_SCALE, 1.0, HABITAT_LINEAR_SCALE)" in main

# All six original habitats stay selectable in the built app.
assert 'species_selector.name = "SpeciesQuickSelect"' in main
species_match = re.search(r'current_species = \[(.*?)\]\[index\]', main, re.S)
assert species_match
species = re.findall(r'"([a-z_]+)"', species_match.group(1))
assert species == ["mantis", "fish", "crayfish", "butterfly", "hermit_crab", "stream_salamander"]
assert all(label in main for label in (
    'species_selector.add_item("사마귀 · 열대 식물 사육장")',
    'species_selector.add_item("열대어 무리 · 수족관")',
    'species_selector.add_item("가재 · 바위 틈 굴 수조")',
    'species_selector.add_item("호랑나비 · 꽃밭 온실")',
    'species_selector.add_item("육지소라게 무리 · 모래 수조")',
    'species_selector.add_item("알록달록 도롱뇽 · 계곡 개울")',
))

# Camera gestures are handled before Control UI consumes the pointer event.
assert "func _input(event: InputEvent) -> void:" in main
assert "camera_mouse_dragging = event.pressed and not editing and not _is_ui_hit(event.position)" in main
assert "camera_touch_points.size() == 2" in main
assert "func _ui_tree_hit(parent: Control, position: Vector2) -> bool:" in main
assert 'camera_hint.text = "드래그: 자유 회전 · 두 손가락: 확대/축소"' in main
assert "window/handheld/orientation=0" in project
assert "input_devices/pointing/emulate_mouse_from_touch=false" in project

# Dense, batched plants remain animated and the mantis palette is darker olive.
assert "for i in range(300):" in main
assert "var leaf_count := rng.randi_range(10, 15) if canopy_plant else rng.randi_range(7, 11)" in main
assert "leaf_tool.append_from(leaf_mesh, 0, leaf_transform)" in main
assert "leaf_cluster.name = \"DenseLeafCanopy\"" in main
assert "mat.albedo_color = Color(0.43, 0.54, 0.26)" in main
assert "var use_latest_mantis_visual := false" in main

# The larger land-crab tank has higher-detail shells; the salamander valley is
# enclosed as a glass aquarium. Both habitats scale from exact linear factors.
assert "const HERMIT_TANK_LINEAR_SCALE := 2.714" in main
assert "const SALAMANDER_TANK_LINEAR_SCALE := 3.107" in main
assert 'hermit_crab_system.scale = Vector3.ONE * HERMIT_TANK_LINEAR_SCALE' in main
assert 'stream_salamander_system.scale = Vector3.ONE * SALAMANDER_TANK_LINEAR_SCALE' in main
assert "func _create_shell_texture() -> Texture2D:" in hermit
assert "for ridge_index in range(12):" in hermit
assert "for point_index in range(49):" in hermit
assert "for speck_index in range(52):" in hermit
assert 'func _create_aquarium_glass() -> void:' in salamander
assert 'FrontAquariumGlass' in salamander and 'RightAquariumGlass' in salamander

# Preserve V8's model, photographs, all species and the complete animation rig.
for name in (
    "aquarium_system.gd", "butterfly_system.gd", "hermit_crab_system.gd",
    "stream_valley_system.gd",
):
    assert (root / "scripts" / name).is_file()
assert (root / "assets/models/mantis_v7_animated.glb").is_file()
assert (root / "assets/models/mantis_rigged.glb").is_file()
assert (root / "assets/photo_cutouts/mantis_side_photo.png").is_file()
assert (root / "assets/photo_cutouts/mantis_dorsal_photo.png").is_file()

assert 'config/version="8.3.0"' in project
assert 'export_path="build/LivingTerrarium3D-v8.3-ARM64.apk"' in presets
assert "version/code=83" in presets and 'version/name="8.3.0"' in presets
print("V8.3 baseline passed: landscape, free camera, expanded habitats, detailed mantis and six species")
