from pathlib import Path

root = Path(__file__).resolve().parents[1]
main = (root / "scripts" / "main.gd").read_text(encoding="utf-8")
habitat = (root / "scripts" / "stream_valley_system.gd").read_text(encoding="utf-8")
readme = (root / "README.md").read_text(encoding="utf-8")

for item in (
    'preload("res://scripts/stream_valley_system.gd")',
    'species_selector.add_item("알록달록 도롱뇽 · 계곡 개울")',
    '"mantis", "fish", "crayfish", "butterfly", "hermit_crab", "stream_salamander"',
    "stream_salamander_system.visible = viewing_stream_salamander",
    "stream_salamander_controls.visible = viewing_stream_salamander",
    'stream_salamander_system.call("simulate", dt)',
    'stream_salamander_system.call("focus_position")',
    'stream_salamander_system.call("activity_status")',
):
    assert item in main, f"missing main integration: {item}"

for method in (
    "simulate", "add_salamander", "encourage_activity", "retreat_to_hide",
    "toggle_flow", "change_temperature", "change_humidity", "salamander_count",
    "activity_status", "focus_position",
):
    assert f"func {method}(" in habitat, f"missing habitat behavior: {method}"

for feature in (
    '"ClearCreekWater"', '"MoistRockCreviceHide"', '"FernFiddlehead"', '"CoolCreekMist"',
    '"IrregularBrightSkinPatch"', '"FlexingTaperedTail"', '"Leg_%s_%d"',
    '"SmoothTaperedTrunk"', "func _tapered_tube_mesh(",
    'Color(1.00, 0.72, 0.10)', 'Color(1.00, 0.39, 0.08)',
    '"젖은 바위 탐색"', '"바위틈에 숨음"',
):
    assert feature in habitat, f"missing valley/model feature: {feature}"

for control in (
    "도롱뇽 한 마리 추가", "젖은 바위 탐색 유도", "바위틈에 숨기",
    "개울 물살 켜기 / 끄기", "분무 +5%", "도롱뇽 가까이 보기", "계곡 전체 보기",
):
    assert control in main, f"missing management control: {control}"

assert "README_v5.2.md" in readme
assert "const SALAMANDER_LIMIT := 6" in habitat
assert "func _update_mist()" in habitat
print("v5.2 stream valley salamander menu and habitat checks passed")
