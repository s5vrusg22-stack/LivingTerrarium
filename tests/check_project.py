from pathlib import Path
root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text()
assert (root / "project.godot").exists()
assert (root / "scenes/main.tscn").exists()
for name in ["_ready", "_create_mantis", "_create_ui", "_resize_ui", "_load_state", "_save_state", "_animate_mantis", "_place_at_screen"]:
    assert f"func {name}(" in main, name
assert '"version": 7' in main
assert "SAVE_SLOT_COUNT := 12" in main
assert "candidates.append_array([SAVE_PATH, BACKUP_PATH, V5_SAVE_PATH, V4_SAVE_PATH, PREVIOUS_SAVE_PATH, LEGACY_SAVE_PATH])" in main
assert "BACKUP_PATH" in main
assert "edit_touch_moved" in main
print("Static project structure checks passed (not a Godot runtime test).")
