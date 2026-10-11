# Living Terrarium 3D v2.2 — 실제 3D 모델 생성

## 이번에 생성한 파일

- `assets/models/mantis_detailed.glb`: 실제 glTF 2.0 바이너리 모델. 사마귀 몸통, 머리, 겹눈, 복부판, 보행 다리, 포획 다리, 가시, 날개, 더듬이를 메시로 생성. Blender 없이 Python trimesh로 생성함.
- `scenes/mantis_model_preview.tscn`: Godot에서 모델을 불러오는 독립 장면.
- `tools/generate_rigged_mantis_blender.py`: 이전 버전의 Blender Armature 및 애니메이션 생성 스크립트 유지.

## 정확한 구현 범위

이 GLB는 **실제 생성한 3D 메시**이지만 **스켈레톤/스킨/키프레임이 없는 정적 모델**입니다. 게임 본편은 기존 절차적 사마귀와 보행 IK를 계속 사용합니다. 새 GLB는 모델 자산 및 독립 장면에 연결되어 있으며, 기존 AI 캐릭터를 교체하거나 애니메이션이 적용되지는 않았습니다.

Blender 실행 파일이 없어 Blender 리깅 스크립트 실행, `.blend` 생성 및 애니메이션 GLB 내보내기는 검증하지 못했습니다. Godot 실행 파일도 없어 장면 임포트 검증 및 APK 생성은 수행하지 못했습니다.

## 검증

Python trimesh로 GLB 재로드 및 메시 검사, ZIP 무결성 검사, 기존 정적 테스트를 수행했습니다. 모델은 해부학적 요소가 구분되는 절차적 형상으로, 사진 수준의 고품질 스캔 모델은 아닙니다.
