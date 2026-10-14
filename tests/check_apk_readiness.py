from pathlib import Path
root = Path(__file__).resolve().parents[1]
models = root / "assets/models"
checks={
 'Godot project':(root/'project.godot').exists(),
 'main scene':(root/'scenes/main.tscn').exists(),
 'Android export preset':(root/'export_presets.cfg').exists(),
 'GitHub workflow':(root/'.github/workflows/android.yml').exists(),
 'canonical Base 1 GLB':(models/'base1.glb').exists(),
 'old V7 filename removed':not (models/'mantis_v7_animated.glb').exists(),
 'obsolete alternate GLBs removed':all(not (models/name).exists() for name in ('mantis_latest.glb','mantis_detailed.glb','mantis_rigged.glb')),
 'Base 1 import metadata':(models/'base1.glb.import').exists(),
 'IK driver':(root/'scripts/rigged_pose_driver.gd').exists(),
}
main=(root/'scripts/main.gd').read_text()
checks['Base 1 selected by default']='var use_base1_mantis_visual := true' in main
checks['Base 1 node name']='base1_mantis_visual.name = "Base1"' in main
checks['old model path absent']='mantis_v7_animated.glb' not in main and 'mantis_latest.glb' not in main
exp=(root/'export_presets.cfg').read_text()
checks['Android preset name']='name="Android"' in exp
checks['APK version 1']='version/name="1.0.0"' in exp
checks['ARM64 enabled']='architectures/arm64-v8a=true' in exp
checks['offline permission']='permissions/internet=false' in exp
for k,v in checks.items():print(('PASS' if v else 'FAIL'),k)
assert all(checks.values())
print('STATIC PREFLIGHT PASS — NOT AN APK BUILD OR ENGINE RUNTIME TEST')
