# 교차 검수 결과 (Codex + Claude) — iOS 정식 출시 준비 계획

대상: `2026-11-24-ios-official-release.md` 초안(커밋 `f36469ef`). 반영본은 같은 파일.

## 요약
- Codex 18건, Claude 24건(4렌즈) / 공통 지적 6건. 모두 반영 또는 판단 기록.

## 🔴 2모델 공통 — 수정함
1. **브랜치 dry-run 불가** — `testflight.sh`가 늘 `origin/main`을 빌드해 "병합 전 U1 dry-run"이 성립하지 않음 → Task 3에 `--ref` 추가, 업로드는 `origin/main`만.
2. **APNs 키 환경·범위 누락** → U2에 "Sandbox & Production, Team scoped".
3. **실기기 검증 범위 부족**(토큰 등록 행·로그아웃 비활성·계정 전환) → 검증 방법 1~6으로 확장(체크리스트 §6 전체).
4. **Time Sensitive 분류** — `usesSafetyChannel` 재사용 시 `safety.recovered`까지 시간 민감 → `usesTimeSensitive`(경보·safety.alert만) 분리.
5. **Mac·Vision Pro 배포 기본 켜짐** → U4에서 끔.
6. **dry-run이 배포 서명을 검증하지 못함**(export 없음, Flutter 0 종료) → dry-run도 로컬 export 후 entitlements·plist 검사.

## 🟡 단독 지적 — 판단
| 출처 | 지적 | 판단 |
|---|---|---|
| Claude | App ID 등록 가능 여부를 맨 마지막에 확인 | **채택** — U0로 코드 전에 판정 |
| Claude | 기기군 설정은 Runner가 아니라 프로젝트 레벨, entitlements를 그 패턴으로 넣으면 RunnerTests로 샘 | **채택** — pbxproj에서 확인(설정 id 명시), 블록 단위 테스트 |
| Claude | CHANGELOG가 Task 3에만, 규칙 수정이 Task 5에만 | **채택** — 첫 커밋에서 버전·CHANGELOG·규칙 문서 |
| Claude | 옛 브랜드 `INFOPLIST_KEY_CFBundleDisplayName = "Tera Ai"` 3줄 | **채택** — 확인, Task 1에서 삭제 |
| Claude | `showRemote` Darwin 설정 Task는 플러그인 기본값(표시 true) 때문에 불필요 | **채택** — 초기화에 표시 끄는 설정 없음 확인, Task 삭제·U5-3으로 확인. `lib/` 변경 0 |
| Claude | Xcode 기능 추가는 사용자가 GUI로 하는 편이 짧고 안전 | **채택** — 선택지 3-A |
| Claude | 일원화 시 TestFlight 빌드가 업데이트 정책 대상 | **채택(기록)** — 빌드 번호가 스토어보다 크고 min_build 운영 규칙상 영향 없음을 선택지 1에 적음 |
| Claude | 옛 무료 팀 App ID는 포털에서 못 지움 | **채택** — 실패 대응을 Apple 지원으로 |
| Claude | ITSAppUsesNonExemptEncryption로 수동 단계 제거 | **보류** — 후속 선택 과제 |
| Claude | 가드 테스트·스크립트 검사 중복 | **기각** — 테스트는 커밋 시점, 스크립트는 업로드 시점 관문이라 둘 다 둔다 |
| Codex | ASC 최신 계약 동의 미확인 | **채택** — U0 |
| Codex | U5 "제출 경고 0"은 빌드 전 불가 | **채택** — U4(저장)와 U6(빌드 연결·경고 0) 분리 |
| Codex | 온도 경보 서버 스위치·허용 목록 미확인 | **채택** — 미확인에 기록, 다른 알림 종류로 검증, 경보는 켜진 경우만 |
| Codex | UGC 1.2: 필터링·신고 대응 기한·연락처 | **채택** — 사용자가 정할 것 4, 심사 노트 |
| Codex | 탈퇴 30일 삭제 작업 실제 동작 | **채택(미확인 기록)** — U4 전 확인 |
| Codex | 하드웨어 영상은 실기기 외부 촬영 | **채택** |
| Codex | privacy manifest 검증 | **부분 채택** — 552 업로드에 ITMS-91053 경고 없음을 근거로 기록, 별도 Task 없음 |
| Codex | Time Sensitive는 사용자 설정·무음 스위치에 좌우 | **채택** — 유저 체험·검증 4 수정 |
| Codex | B 선택 시 제외 범위 | **채택** — 선택지 2에 명시 |
| Codex | 앱 개인정보는 Play 답 재사용 불가 | **채택** — U4 "Apple 양식으로 새로" |
| Codex | ATS: `NSAllowsLocalNetworking`이 있어 `NSAllowsArbitraryLoads`는 이미 무시됨 | **채택** — 초안의 보류 근거가 틀렸음, Task 1에서 제거 |
| Codex | 완료 범위가 출시·DB·슬랙까지 확장 | **채택** — 목표 = 제출 직전, 나머지는 후속 절 |
| Claude | `NSMicrophoneUsageDescription` 모호 | **채택(미확인 기록)** — U4 전 확인 |

## 💡 직관 질문 답변
- **빼도 되는 것:** iOS 앱 사용 중 표시 코드 변경(삭제함). 남는 `lib/` 변경 없음.
- **최대 리스크:** `com.vivanaut.app` App ID를 팀 XYNNB47RN3에 등록 못 하는 경우 → U0로 가장 먼저 판정.
- **우선 확인:** U0(App ID 등록·ASC 계약·Firebase plist) → 그다음 `--ref` dry-run.
