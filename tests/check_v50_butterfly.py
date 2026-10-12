from pathlib import Path

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
butterfly = (root / "scripts/butterfly_system.gd").read_text(encoding="utf-8")

assert 'preload("res://scripts/butterfly_system.gd")' in main
assert 'species_selector.add_item("호랑나비 · 꽃밭 온실")' in main
assert 'current_species = ["mantis", "fish", "crayfish", "butterfly", "hermit_crab", "stream_salamander"][index]' in main
assert 'butterfly_system.visible = viewing_butterfly' in main
assert 'environment_root.visible = current_species == "mantis"' in main
assert 'butterfly_system.call("simulate", dt)' in main
assert 'butterfly_system.call("focus_position")' in main
assert 'butterfly_controls.visible = viewing_butterfly' in main

for method in (
    "simulate", "encourage_flight", "add_butterfly", "add_flower",
    "refill_nectar", "toggle_daylight", "toggle_wind", "change_temperature",
    "butterfly_count", "flower_count", "nectar_percent", "activity_status",
    "focus_position",
):
    assert f"func {method}(" in butterfly, f"missing butterfly API: {method}"

assert "const BUTTERFLY_LIMIT := 8" in butterfly
assert "const FLOWER_LIMIT := 24" in butterfly
assert 'state = "흡밀"' in butterfly and 'state = "휴식"' in butterfly
assert 'state = "온도 대기"' in butterfly and 'state = "비행"' in butterfly
assert "pollination_count += 1" in butterfly
assert 'name = "ForewingMembrane"' in butterfly
assert 'else "HindwingMembrane"' in butterfly
assert "wing.rotation.z = flap * side" in butterfly

for label in ("나비 한 마리 추가", "나비 비행 유도", "꽃 한 송이 심기", "꽃꿀 보충", "낮 / 밤 전환", "산들바람 켜기 / 끄기"):
    assert label in main, f"missing butterfly control: {label}"

assert "README_v5.0.md" in (root / "README.md").read_text(encoding="utf-8")
print("v5.0 butterfly integration check passed")
