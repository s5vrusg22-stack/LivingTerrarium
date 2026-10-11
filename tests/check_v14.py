from pathlib import Path
root = Path(__file__).resolve().parents[1]
s = (root / "scripts/main.gd").read_text()
for needle in ("ThoraxArticulation", "ForelegElbow_", "ForelegTibia_", "foreleg_elbows[i].rotation.x", "foreleg_claws[i].rotation.x", "thorax_pivot.rotation.x"):
    assert needle in s, needle
assert s.count('foreleg_elbows.append(elbow)') == 1
assert s.count('foreleg_claws.append(claw)') == 1
print('v1.4 articulated joint static checks passed')
