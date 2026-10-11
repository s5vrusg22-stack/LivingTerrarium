# Living Terrarium 3D v2.1 — Blender 관절 리깅 모델 제작 파이프라인

## 포함된 구현

`tools/generate_rigged_mantis_blender.py`는 Blender 4.x에서 실행하는 **완전한 생성 스크립트**입니다. 3D 메시와 Armature를 만들고 각 메시의 정점 그룹에 대응 관절 가중치를 부여합니다. 가슴, 머리, 복부, 좌우 여섯 보행 다리(각 4관절), 좌우 포획 앞다리(각 4관절), 더듬이(각 3관절)를 생성합니다. 복부 마디, 날개 덮개, 날개맥, 겹눈, 홑눈, 앞다리 가시를 추가하고 6개 애니메이션(Idle, Walk, Alert, Strike, Groom, Feed)을 키프레임으로 생성합니다.

### 생성 방법

프로젝트 루트에서 Blender 4.x 설치 후:

```bash
blender -b --python tools/generate_rigged_mantis_blender.py
```

성공 시 `assets/models/mantis_rigged.blend`(편집 가능한 Blender 원본) 및 `assets/models/mantis_rigged.glb`(Godot 임포트용)가 생성됩니다. Blender 버전에 따라 glTF 애니메이션 내보내기 옵션을 조정해야 할 수 있습니다.

### Godot 통합 주의

현재 게임의 사마귀는 `scripts/main.gd`의 절차적 모델 및 IK를 사용합니다. 생성되는 GLB는 **아직 기존 게임 캐릭터를 자동으로 대체하지 않습니다**. 모델을 임포트한 후 게임의 이동, 사냥 AI, 발 접지 IK를 Armature 본 이름에 연결하는 후속 작업이 필요합니다. 리깅 스크립트에서 사용하는 축은 Blender Z-up이고, 게임 모델의 축과 조정이 필요합니다.

### 품질 및 검증 한계

이 모델은 관절과 해부학적 실루엣을 갖춘 **절차적 모델**이며, 사진 측량이나 수작업 조각으로 제작한 극사실주의 고품질 모델은 아닙니다. 이 작업 환경에 Blender 실행 파일이 없어 `.blend`/`.glb` 생성과 Blender 실행 검증은 **실시하지 못했습니다**. 파이썬 구문 검사 및 프로젝트 정적 검사만 수행했습니다. 완성된 `.blend`나 리깅된 `.glb`가 ZIP에 들어 있다고 오해하지 마세요.
