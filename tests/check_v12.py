from pathlib import Path
root=Path(__file__).resolve().parents[1]
s=(root/'scripts/main.gd').read_text()
for name in ['IDLE','WALK','ALERT','GROOM','HUNT','STRIKE','SCAN','FEED','CLIMB','DEFEND']:
 assert '"'+name+'"' in s, name
for name in ['mantis_cuticle_albedo','mantis_eye_albedo','bark_albedo','substrate_albedo','stone_albedo']:
 assert (root/'assets/textures'/f'{name}.png').is_file(),name
print('v1.2 static asset/state checks passed')
