# GitHub에서 APK 만들기

1. GitHub에서 새 저장소를 생성합니다(예: `living-terrarium-3d`).
2. ZIP을 압축 해제한 뒤 **LivingTerrarium3D_APK_build_ready 폴더 안의 파일과 폴더 전체**를 저장소의 최상위에 올립니다. `.github/workflows/android.yml`도 반드시 포함해야 합니다. GitHub 웹 업로드에서 숨김 폴더가 누락되면 workflow가 실행되지 않습니다.
3. `main` 브랜치에 커밋한 뒤 저장소의 **Actions → Build Android APK → Run workflow**를 누릅니다. 첫 업로드 시 push로 자동 실행될 수도 있습니다.
4. 빌드 작업의 녹색 체크를 확인한 후, 실행 기록 하단 **Artifacts → LivingTerrarium3D-debug-apk**를 내려받아 압축을 해제합니다.
5. `LivingTerrarium3D-debug.apk`를 갤럭시 휴대폰에 옮겨 실행합니다. 설치 시 '이 출처의 앱 허용'이 필요할 수 있습니다.
6. 빌드가 빨간색으로 실패하면 **실패한 단계 이름과 로그의 마지막 30~50줄**을 보내 주세요. 로그에 비밀번호나 개인 토큰이 있다면 가리고 보내 주세요.

## 상태
- 이 프로젝트에는 Godot 4.3 및 Android SDK를 클라우드에서 설치하는 GitHub Actions workflow가 포함되어 있습니다.
- 이번 환경에서는 Godot 실행 및 Android APK 생성이 불가능하여 실제 성공은 **미검증**입니다.
- 생성되는 것은 테스트용 debug APK이며 Google Play 배포용 release APK가 아닙니다.
