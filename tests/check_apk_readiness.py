from pathlib import Path
import configparser
root=Path(__file__).resolve().parents[1]
checks={
 'Godot project':(root/'project.godot').exists(),
 'main scene':(root/'scenes/main.tscn').exists(),
 'Android export preset':(root/'export_presets.cfg').exists(),
 'GitHub workflow':(root/'.github/workflows/android.yml').exists(),
 'rigged GLB':(root/'assets/models/mantis_rigged.glb').exists(),
 'IK driver':(root/'scripts/rigged_pose_driver.gd').exists(),
}
exp=(root/'export_presets.cfg').read_text()
checks['Android preset name']='name="Android"' in exp
checks['ARM64 enabled']='architectures/arm64-v8a=true' in exp
checks['offline permission']='permissions/internet=false' in exp
for k,v in checks.items():print(('PASS' if v else 'FAIL'),k)
assert all(checks.values())
print('STATIC PREFLIGHT PASS — NOT AN APK BUILD OR ENGINE RUNTIME TEST')
