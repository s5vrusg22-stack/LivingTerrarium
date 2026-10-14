from pathlib import Path
root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text()
assert (root / "project.godot").exists()
assert (root / "scenes/main.tscn").exists()
for name in ["_ready", "_create_mantis", "_create_ui", "_resize_ui", "_load_state", "_save_state", "_animate_mantis", "_place_at_screen"]:
    assert f"func {name}(" in main, name
assert '"version": 8' in main
assert "BACKUP_PATH" in main
assert "MANTIS_COLLECTION_PATH" in main
assert "_save_current_mantis_profile" in main
assert "edit_touch_moved" in main
print("Static project structure checks passed (not a Godot runtime test).")
