from pathlib import Path

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text()
workflow = (root / ".github/workflows/android.yml").read_text()

# Pin the canonical imported rig and fail closed when the contract is not met.
assert 'const LATEST_MODEL_LOCK := "res://assets/models/mantis_rigged.glb"' in main
assert 'preload("res://assets/models/mantis_rigged.glb")' in main
assert all(x in main for x in ["LATEST_MODEL_MIN_BONES := 61", "LATEST_MODEL_MIN_CLIPS := 10", "LATEST_MODEL_MIN_MESHES := 30"])
assert 'LATEST_MODEL_REQUIRED_CLIPS: Array[String] = ["IDLE", "WALK", "ALERT", "GROOM", "HUNT", "STRIKE", "SCAN", "FEED", "CLIMB", "DEFEND"]' in main
assert "func _has_latest_model_bones(" in main and "required_bones_present" in main
assert "LATEST_MANTIS_SCENE.resource_path == LATEST_MODEL_LOCK" in main
assert "rigged_visual.visible = rigged_available" in main
assert "part.visible = false" in main
assert "구형 모델은 표시하지 않습니다" in main

# Keyboard and touch camera navigation can travel beyond the habitat bounds.
assert "CAMERA_MOVE_SPEED := 20.0" in main and "CAMERA_BOOST_MULTIPLIER := 4.0" in main
assert "CAMERA_MAX_DISTANCE := 240.0" in main
assert "camera_pan += movement.normalized() * speed * delta" in main
assert "CameraDirectionPad" in main and "camera_touch_directions" in main

# Saved terrariums independently retain their insect, stage, biome, and prey.
assert "SAVE_SLOT_COUNT := 12" in main
assert '"version": 7' in main
assert '"species": selected_species' in main and '"life_stage": life_stage' in main
assert '"biome": selected_biome' in main and '"prey": _prey_records()' in main
assert "func _slot_path(" in main and "func _switch_save_slot(" in main

# Expanded animal actions and the first juvenile rig profile.
for label in ["날아다니기", "사냥하기", "점프하기", "잎 뒷면에 거꾸로 매달리기", "탈피하기", "위협 자세", "다른 개체와 싸움 시연", "짝짓기 행동 시연"]:
    assert label in main, label
for action in ["_advance_manual_command", "_advance_social_display", "_consume_prey", "_create_juvenile_wing_buds", "_apply_life_stage"]:
    assert f"func {action}" in main, action
assert "NymphWingBud_" in main and 'part.visible = not is_juvenile' in main

# Expanded enclosure, feeder variety, and bark-surface foot placements.
assert "Vector3(11.2, 0.2, 8.2)" in main
assert 'humidity_stress_limit := 25.0 if selected_biome == "사막" else 40.0' in main
assert '치앙마이형 (Hierodula sp.)' in main
assert "const PREY_TYPES: Array[String]" in main
assert "func _prey_size(" in main and "func _prey_color(" in main
assert "step_cycle := fposmod(walking_phase / TAU" in main
assert "trunk_radius + 0.014 + step_lift" in main
assert "branches: [main, 'codex/**']" in workflow
assert "default: false" in workflow and "inputs.build_android" in workflow
print("v3.1 model lock, camera, commands, profile saves, juveniles, prey, biome, and climb checks passed")
