# Living Terrarium 3D v2.9 — skin weights and distal-foot IK

## 40 integrated steps

1. 원본 GLB 헤더 검증
2. GLB JSON/BIN 청크 해석
3. 기존 스킨 관절 목록 확인
4. 기존 역바인드 행렬 읽기
5. 기존 메시 노드 변환 보존
6. 좌측 앞다리 체인 확인
7. 좌측 중간다리 체인 확인
8. 좌측 뒷다리 체인 확인
9. 우측 앞다리 체인 확인
10. 우측 중간다리 체인 확인
11. 우측 뒷다리 체인 확인
12. 여섯 다리 원위부 방향 계산
13. 여섯 발끝 위치 산정
14. 여섯 발끝 관절 노드 생성
15. 발끝 부모를 경절로 연결
16. 발끝 국소 바인드 행렬 계산
17. 발끝 역바인드 행렬 추가
18. 스킨 관절 인덱스 갱신
19. 기절 메시 정점 읽기
20. 무릎 메시 정점 읽기
21. 경절 메시 정점 읽기
22. 메시 로컬→월드 좌표 변환
23. 상부 관절선에 대한 투영
24. 하부 관절선에 대한 투영
25. 정점별 최근접 관절선 선택
26. 상부 구간의 연속 가중치
27. 하부 구간의 연속 가중치
28. 무릎 주변 가중치 안정화
29. 가중치 합 1 정규화
30. 정점 JOINTS_0 접근자 재생성
31. 정점 WEIGHTS_0 접근자 재생성
32. 기존 비보행 메시 가중치 유지
33. GLB 바이너리 청크 재작성
34. 발끝 관절을 IK 체인에 추가
35. 3개 회전 관절 CCD 순서 적용
36. CCD 반복 횟수 확대
37. 발끝 도달 거리 제한 갱신
38. 발 접지 IK 블렌딩 보존
39. 구버전 관절 누락 시 대체 동작 유지
40. 자동 무결성 및 회귀 검사

## Asset changes
- 6 new `Rig_Foot_*` end-effector bones; 4-bone chain Coxa→Joint→Tibia→Foot.
- Reweighted 18 walking-leg primitives (1236 vertices) using continuous 2-bone segment blends, leaving other body parts rigid.
- CCD: 9 passes with ankle/knee/hip rotations and foot-endpoint tracking.
- The skin is an approximation based on existing procedural mesh geometry, **not hand-painted professional Blender weights**.

## Limitations
- Godot and Blender runtimes are unavailable here. Visual mesh deformation, imported animations, stability, collision and Android execution have NOT been verified.
- 3-joint CCD does not enforce anatomically calibrated hinge limits; further runtime tuning is required.
- This is not a production-certified full-body IK solution.
