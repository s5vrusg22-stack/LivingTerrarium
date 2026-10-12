"""Check the newest mantis visuals are integrated into the full six-species app."""
import json
import struct
from pathlib import Path

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
model_path = root / "assets/models/mantis_v7_animated.glb"
assert model_path.is_file()
data = model_path.read_bytes()
assert data[:4] == b"glTF" and struct.unpack_from("<I", data, 4)[0] == 2
length, kind = struct.unpack_from("<I4s", data, 12)
assert kind == b"JSON"
document = json.loads(data[20:20 + length])
nodes = {node.get("name", "") for node in document.get("nodes", [])}
assert {"Abdomen", "Pronotum", "Thorax", "Head", "Wing_L", "Wing_R", "Raptor_L_Femur", "Raptor_L_Tibia", "Raptor_R_Femur", "Raptor_R_Tibia"} <= nodes
clips = {animation.get("name", "").upper() for animation in document.get("animations", [])}
assert {"IDLE", "WALK", "ALERT", "STRIKE", "GROOM", "FEED"} <= clips

for photo in ("mantis_side_photo.png", "mantis_dorsal_photo.png"):
    image = root / "assets/photo_cutouts" / photo
    assert image.is_file() and image.stat().st_size > 10_000
assert all((root / "assets/photo_cutouts/source" / name).is_file() for name in ("1000157339.jpg", "1000157366.jpg"))

for marker in (
    'preload("res://assets/models/mantis_v7_animated.glb")',
    "var use_latest_mantis_visual := false",
    "latest_mantis_visual = imported as Node3D",
    "func _play_latest_mantis_clip(clip: String)",
    '"HUNT": "STRIKE"',
    '"CLIMB": "WALK"',
    '"DEFEND": "ALERT"',
    "photo_visual_dorsal.visible = use_photo_visual and use_dorsal",
    'current_species = ["mantis", "fish", "crayfish", "butterfly", "hermit_crab", "stream_salamander"][index]',
):
    assert marker in main, marker

for script in ("aquarium_system.gd", "hermit_crab_system.gd", "stream_valley_system.gd", "butterfly_system.gd"):
    assert (root / "scripts" / script).is_file()

print("v5.3 merge check passed: latest V7 mantis, two applied photo cutouts, animation aliases, and all six species")
