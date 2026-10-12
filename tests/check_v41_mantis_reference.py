from pathlib import Path

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text()
photo = root / "assets/reference/1000157363(3).jpg"
assert photo.is_file()

for marker in (
    'name = "MantisPhotoReferenceOverlay"',
    'name = "LatestUserMantisPhoto"',
    'texture = load("res://assets/reference/1000157363(3).jpg")',
    '"실물 사진과 구조 비교"',
    '"사진 속 사마귀 구조와 3D 모델 비교"',
    'detail_note.text = "이번 4.9 보완은 머리 앞면을 좁혀',
    "_show_reference_overlay()",
    "_hide_reference_overlay()",
    "앞다리 동작 다음",
):
    assert marker in main, marker

readme = (root / "README.md").read_text()
assert "README_v4.1.md" in readme
assert (root / "tests/check_v39_crayfish.py").is_file()
assert (root / "tests/check_v40_frontlegs.py").is_file()
print("v4.1 checks passed: latest user photo is shown in the structure comparison panel")
