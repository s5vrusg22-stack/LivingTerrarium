"""Guard the recovered v8.3 model and six-habitat project baseline."""
from hashlib import sha256
from pathlib import Path

root = Path(__file__).resolve().parents[1]
model = root / "assets/models/mantis_rigged.glb"
assert sha256(model.read_bytes()).hexdigest() == (
    "8580a9c00936b436f121db546f5a758e5d306fa829e1b4198ec663ccc1e9a3c2"
)

project = (root / "project.godot").read_text(encoding="utf-8")
presets = (root / "export_presets.cfg").read_text(encoding="utf-8")
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
assert 'config/version="8.3.0"' in project
assert 'version/code=83' in presets and 'version/name="8.3.0"' in presets
assert 'export_path="build/LivingTerrarium3D-v8.3-ARM64.apk"' in presets
assert 'current_species = ["mantis", "fish", "crayfish", "butterfly", "hermit_crab", "stream_salamander"]' in main
for species_script in (
    "aquarium_system.gd",
    "butterfly_system.gd",
    "hermit_crab_system.gd",
    "stream_valley_system.gd",
):
    assert (root / "scripts" / species_script).is_file()

print("v8.3 baseline passed: exact recovered mantis model and all six habitats")
