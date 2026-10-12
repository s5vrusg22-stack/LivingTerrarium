from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / "scripts" / "main.gd").read_text(encoding="utf-8")
CRAB = (ROOT / "scripts" / "hermit_crab_system.gd").read_text(encoding="utf-8")

required_main = [
    'preload("res://scripts/hermit_crab_system.gd")',
    'species_selector.add_item("육지소라게 무리 · 모래 수조")',
    '"mantis", "fish", "crayfish", "butterfly", "hermit_crab"',
    "hermit_crab_system.visible = viewing_hermit_crab",
    'hermit_crab_system.call("simulate", dt)',
    'hermit_crab_system.call("focus_position")',
    'hermit_crab_system.call("activity_status")',
    'hermit_crab_controls.visible = viewing_hermit_crab',
    'environment_root.visible = current_species == "mantis"',
]
required_crab = [
    "const MAX_CRABS := 6",
    "func simulate(delta: float)",
    "func encourage_activity()",
    "func add_crab() -> bool",
    "func add_shell() -> bool",
    "func refill_water()",
    "func change_humidity(amount: float)",
    "func change_temperature(amount: float)",
    "func water_percent() -> int",
    '"CrabSpiralShell"',
    '"ShadedRockHide"',
    '"FreshWaterDish"',
    '"SaltWaterDish"',
    '\"WalkingLeg_%s_%d\"',
    'FastNoiseLite.new()',
    'func _create_glass_panels()',
    '"RaisedCarapacePlate"',
    '"ApertureLip"',
    '"ApertureShadow"',
    '"ChelipedPalm"',
    '"WalkingLegJoint"',
    '"BifidAntenna_%s"',
    '"WaterBowlInnerBasin"',
    'surface.position.y = FLOOR_Y + 0.0235 + water_level * 0.037',
    '"물 마시는 중 %d마리"',
]
missing = [item for item in required_main if item not in MAIN]
missing += [item for item in required_crab if item not in CRAB]
assert not missing, f"Missing hermit crab integration: {missing}"
assert (ROOT / "scripts" / "hermit_crab_system.gd").is_file()
print("v5.1 hermit crab menu and habitat checks passed")

