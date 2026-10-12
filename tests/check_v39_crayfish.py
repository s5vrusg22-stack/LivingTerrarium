from pathlib import Path


root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text()
aquarium = (root / "scripts/aquarium_system.gd").read_text()

assert 'add_item("사마귀 · 열대 식물 사육장")' in main
assert 'add_item("열대어 무리 · 수족관")' in main
assert 'add_item("가재 · 바위 틈 굴 수조")' in main
assert 'current_species = ["mantis", "fish", "crayfish", "butterfly", "hermit_crab", "stream_salamander"][index]' in main
assert 'current_species in ["fish", "crayfish"]' in main
assert 'crayfish_controls.visible = viewing_crayfish' in main
assert 'aquarium_system.call("encourage_crayfish")' in main
assert 'aquarium_system.call("retreat_crayfish")' in main
assert 'aquarium_system.call("simulate", dt)' in main

for marker in [
    'burrow_root.name = "CrayfishRockCreviceBurrow"',
    'dark_entrance.name = "ShadowedBurrowOpening"',
    'crayfish_root.name = "FreshwaterCrayfish"',
    'plate.name = "AbdominalSegment_%02d" % i',
    'claw.name = "PincerArm_%s"',
    'leg.name = "WalkingLeg_%02d" % leg_index',
    'func encourage_crayfish() -> void:',
    'func retreat_crayfish() -> void:',
    'func crayfish_status() -> String:',
    'crayfish_state = "emerging"',
    'crayfish_state = "active"',
    'crayfish_state = "returning"',
    'crayfish_root.visible = false',
    'func _animate_crayfish(dt: float) -> void:',
]:
    assert marker in aquarium, marker

assert "README_v3.9.md" in (root / "README.md").read_text()
print("v3.9 crayfish integration passed: species selection, crevice burrow, detailed model, and shelter/activity cycle")
