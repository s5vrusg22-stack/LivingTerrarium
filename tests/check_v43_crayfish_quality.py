from pathlib import Path


root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text()
aquarium = (root / "scripts/aquarium_system.gd").read_text()

for marker in [
    "crayfish_root.scale = Vector3.ONE * 1.30",
    "Color(0.025, 0.22, 0.69)",
    "Color(0.075, 0.47, 0.96)",
    '"CarapaceSpeckle_%s_%02d"',
    '"GillCover_%s"',
    '"PincerPalm"',
    '"PalmDorsalRidge"',
    '"PalmSpine_%02d"',
    "for tooth in range(4):",
    "mesh.radial_segments = 20",
    "mesh.rings = 12",
]:
    assert marker in aquarium, marker

assert 'orbit_distance = minf(orbit_distance, 7.4)' in main
assert 'Vector3(-0.62, -0.16, -0.28)' in main
assert "README_v4.3.md" in (root / "README.md").read_text()
print("v4.3 crayfish quality passed: larger blue model, sculpted shell details, oversized toothed claws, and closer framing")
