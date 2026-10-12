from pathlib import Path

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text()
aquarium_path = root / "scripts/aquarium_system.gd"
assert aquarium_path.exists()
aquarium = aquarium_path.read_text()

assert 'preload("res://scripts/aquarium_system.gd")' in main
assert 'add_item("사마귀 · 열대 식물 사육장")' in main
assert 'add_item("열대어 무리 · 수족관")' in main
assert "_set_species_mode(0, false)" in main
assert 'current_species = ["mantis", "fish", "crayfish", "butterfly", "hermit_crab", "stream_salamander"][index]' in main
assert 'aquarium_system.call("simulate", dt)' in main
assert 'aquarium_system.call("add_fish")' in main
assert 'aquarium_system.call("remove_fish")' in main

required_features = [
    'name = "ClearAquariumWater"',
    'name = "WaterlineSurface"',
    'name = "AquariumGravel_%03d"',
    'name = "AquariumStone_%02d"',
    'name = "SubmersiblePowerFilter"',
    'name = "AquaticPlant_%02d"',
    'name = "NeonTetra_%02d"',
    'name = "OscillatingForkedTail"',
    'tail.rotation.y = sin(clock * 8.8',
    'func toggle_flow() -> bool:',
    'const STARTING_FISH := 12',
    'const FISH_LIMIT := 24',
]
for marker in required_features:
    assert marker in aquarium, marker

assert "README_v3.8.md" in (root / "README.md").read_text()
print("v3.8 aquarium integration passed: selectable habitats, water, filter flow, plants, stones, and animated fish schools")
