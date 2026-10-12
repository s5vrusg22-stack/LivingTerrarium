import json
import struct
from pathlib import Path

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text()
generator = (root / "tools/generate_rigged_mantis_blender.py").read_text()
workflow = (root / ".github/workflows/android.yml").read_text()

stages = ["1령 약충", "2령 약충", "3령 약충", "4령 약충", "5령 약충", "6령 약충", "성체"]
stage_literal = "[" + ", ".join(f'"{stage}"' for stage in stages) + "]"
assert f"const LIFE_STAGES: Array[String] = {stage_literal}" in main
assert "NYMPH_SIZE_FACTORS: Array[float] = [0.23, 0.30, 0.40, 0.52, 0.67, 0.84]" in main
assert "NYMPH_WING_PAD_FACTORS: Array[float] = [0.34, 0.43, 0.54, 0.68, 0.83, 1.0]" in main
assert "func _is_juvenile()" in main and "func _life_stage_index()" in main
assert "var next_stage := mini(_life_stage_index() + 1, 6)" in main
assert "_is_juvenile() and life_age" in main and "molt_count < 6" in main
assert 'if saved_stage == "약충":' in main
assert "LIFE_STAGES[mini(saved_molt_count, 5)]" in main
assert 'if not _is_juvenile():' in main and '성충은 마지막 탈피를 마쳤습니다.' in main
assert "var pad_factor := NYMPH_WING_PAD_FACTORS[stage_index]" in main

# Confirm the edited Blender source emits the exact canonical rig contract
# consumed by the runtime fail-closed validator.
for modeling_detail in [
    "def triangular_head(",
    "def wing_blade(",
    "Abdominal pleurite",
    "Abdominal spiracle",
    "WingVeinDetail_",
    "Rig_Coxa_{letter}{index}",
    "Rig_ForeFemur_",
    "Rig_Antenna_",
    "('FLY',30,.64)",
]:
    assert modeling_detail in generator, modeling_detail
assert "for index,y in enumerate((-.13,.12,.32))" in generator
assert "Install Blender and rendering dependencies" in workflow
assert "tools/generate_rigged_mantis_blender.py" in workflow
assert "refs/heads/codex/mantis-l1-l6-apk-20261012" in workflow

glb_path = root / "assets/models/mantis_rigged.glb"
binary = glb_path.read_bytes()
assert binary[:4] == b"glTF"
declared_length = struct.unpack_from("<I", binary, 8)[0]
assert declared_length == len(binary)
json_length, json_type = struct.unpack_from("<II", binary, 12)
assert json_type == 0x4E4F534A
document = json.loads(binary[20:20 + json_length].decode("utf-8"))
nodes = document.get("nodes", [])
node_names = {node.get("name", "") for node in nodes}
joint_count = max((len(skin.get("joints", [])) for skin in document.get("skins", [])), default=0)
assert joint_count >= 61, joint_count
assert len(document.get("meshes", [])) >= 30
required_bones = ["Rig_Head", "Rig_Thorax"]
required_bones += [f"Rig_{part}_{side}{index}" for side in ["L", "R"] for index in range(3) for part in ["Coxa", "Joint", "Tibia", "Foot"]]
required_bones += [f"Rig_{part}_{side}" for side in ["L", "R"] for part in ["ForeFemur", "ForeTibia", "Antenna"]]
assert all(name in node_names for name in required_bones)
clips = {animation.get("name", "").upper() for animation in document.get("animations", [])}
expected_clips = {"IDLE", "WALK", "ALERT", "GROOM", "HUNT", "STRIKE", "SCAN", "FEED", "CLIMB", "DEFEND"}
assert expected_clips <= clips, expected_clips - clips
print(f"Growth-stage checks passed; canonical GLB has {joint_count} bones, {len(document['meshes'])} meshes, and {len(clips)} clips.")
