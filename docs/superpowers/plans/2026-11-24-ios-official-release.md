# iOS 정식 출시 준비 Implementation Plan

> **구현 방식 (CAOF):** Critical 트랙. 코드 task(1~3)는 Implementer(`flutter-dev`) 분리(GATE 4), 콘솔 작업(U0~U6)은 사용자가 하거나 사용자 확인 뒤 메인이 브라우저로 돕는다. Steps use checkbox (`- [ ]`) syntax for tracking.
> **검수:** `/검수` 1회(Codex + Claude) 반영본 — `2026-11-24-ios-official-release-review-final.md`.

**Goal:** 조직 팀 `XYNNB47RN3`(terraai Co.,Ltd.)으로 정식 번들 `com.vivanaut.app` "비바나트"를 iPhone 전용·대한민국·iOS 푸시 포함으로 **App Store 심사 제출 직전 상태**까지 만든다. 제출 클릭·출시는 이 계획 밖(후속 절).

**Architecture:** 가장 큰 미확인(App ID 등록 가능 여부)을 코드보다 먼저 판정한다(U0). main의 iOS 빌드 설정을 정식 값으로 고정하고 TestFlight도 정식 앱의 TestFlight로 일원화해, 빌드 때 값을 바꿔 끼우는 단계를 없앤다. `tools/testflight.sh`는 값을 바꾸지 않고 **검사**하며, 병합 전 브랜치도 빌드할 수 있게 `--ref`를 받고, dry-run에서도 App Store용 export까지 해 산출물의 서명·entitlements를 확인한다. 푸시는 2026-11-16 체크리스트(`docs/handoffs/2026-11-16-ios-push-setup-checklist.md`)를 따른다.

**Tech Stack:** Flutter iOS(Xcode 자동 서명), firebase_messaging, Supabase Edge Function(`dispatch-push`, Node 테스트), App Store Connect, Firebase 콘솔.

**Spec:** 없음 — 근거는 사용자 결정(2026-11-24: iPhone 전용, iOS 푸시 첫 출시 포함, 대한민국만), `docs/ops/apple-developer-account.md`, `docs/handoffs/2026-11-16-ios-push-setup-checklist.md`, `docs/ops/google-play-account.md`(스토어 메타데이터·심사 선례).

## 가정

- 확인:
  - 조직 전환 완료, 팀 ID `XYNNB47RN3` 유지(2026-11-24 멤버십 세부 사항).
  - pbxproj: **Runner 타깃** 설정 3벌(`249021D4…Profile`, `97C14706…Debug`, `97C14707…Release`)에 `DEVELOPMENT_TEAM = 8NDUMK7C65`, `PRODUCT_BUNDLE_IDENTIFIER = com.vivanaut.app`, 효과 없는 옛 브랜드 `INFOPLIST_KEY_CFBundleDisplayName = "Tera Ai"`. **프로젝트 레벨** 3벌(`249021D3`, `97C14703`, `97C14704`)에 `TARGETED_DEVICE_FAMILY = "1,2"`, `IPHONEOS_DEPLOYMENT_TARGET = 15.0`. `CODE_SIGN_ENTITLEMENTS` 없음.
  - `ios/Runner/`에 entitlements·`GoogleService-Info.plist` 없음, Info.plist에 `UIBackgroundModes` 없음. ATS는 `NSAllowsArbitraryLoads`와 `NSAllowsLocalNetworking`이 함께 있어 iOS 10+에서 전자는 **무시된다**(지금도 로컬 외 HTTP는 차단 상태).
  - 앱 iOS 푸시 코드는 준비 완료(0.182.0) — plist 없으면 꺼진 채 크래시 없음.
  - 앱 사용 중 표시: `DarwinInitializationSettings`에 표시 기본값을 끄는 설정이 없어 플러그인 기본값(배너·소리 true)으로 뜬다 → `showRemote`에 Darwin 설정을 더하는 코드 변경은 하지 않고 U5 실기기로 확인만 한다.
  - 알림 종류: `env.alert.triggered`·`safety.alert`(즉시 행동 필요), `safety.recovered`(회복 안내).
  - `buildFirebaseMessage`에 `apns` 블록 없음. Edge Function은 앱 팀 소유, 운영 배포는 사용자 승인 사항.
  - 심사 관련: 앱 안 회원 탈퇴·커뮤니티 신고·차단 있음, 소셜 로그인·인앱 결제 없음. 개인정보처리방침·계정 삭제 페이지 공개.
  - 552 업로드 경고는 SDK·dSYM뿐 — privacy manifest(ITMS-91053) 경고 없음.
- 미확인:
  - `com.vivanaut.app`을 팀 `XYNNB47RN3`에 등록할 수 있는지(다른 Apple 계정 arthurbaek@icloud.com의 무료 팀 `8NDUMK7C65` 점유 가능) → **U0**.
  - 조직 전환 뒤 App Store Connect 최신 계약 동의 필요 여부 → U0.
  - 운영 서버의 온습도 경보 발송 스위치(`PUSH_ENV_ALERTS_ENABLED`·허용 목록) 상태(메모리 `project_env_alerts_v4`: 서버 단계 켜기 남음) → U5에서 다른 알림 종류로 검증, 경보는 켜져 있을 때만.
  - 서버의 탈퇴 30일 삭제 작업이 실제로 도는지(`google-play-account.md` 13행 ⚠️) → U4 전 확인.
  - flutter_webrtc가 마이크 권한을 요청하는지(`NSMicrophoneUsageDescription` "필요할 수 있습니다" 문구 모호) → U4 전 확인.

## 선택지와 추천

1. **TestFlight 대상** — (A) 정식 `com.vivanaut.app`의 TestFlight로 일원화, 베타 앱 `com.vivanaut.beta`는 은퇴 **(추천)** / (B) 베타 유지, 빌드 때 팀·번들·plist 교체. A: Firebase 앱·plist·APNs 설정이 한 벌이 되고, 심사에 올릴 그 빌드를 테스터가 먼저 쓴다. 비용: 기존 베타 테스터는 정식 앱을 새로 설치. 부수효과: TestFlight 빌드도 업데이트 안내 대상이 되지만, TestFlight 빌드 번호는 스토어보다 크고 `min_build`는 스토어 빌드 이하로만 올리므로(운영 규칙 3) 강제 화면에 걸리지 않는다. **계획은 A로 쓴다.**
2. **Time Sensitive 알림** — (A) `env.alert.triggered`·`safety.alert`만 시간 민감 **(추천)** / (B) 모두 기본. A: 사용자가 시간 민감 알림을 허용해 두면 집중 모드에서도 표시된다(무음 스위치는 우회하지 않음). `safety.recovered`는 회복 안내라 기본. B를 고르면 Task 2의 entitlement 키와 Task 3의 `interruption-level`·해당 테스트를 뺀다.
3. **Xcode 기능 추가 방식** — (A) 사용자가 Xcode Signing & Capabilities에서 Push Notifications·Background Modes(Remote notifications)·Time Sensitive Notifications를 추가 **(추천)** / (B) Implementer가 `xcodeproj` gem 스크립트로 pbxproj 수정. A: entitlements 파일 생성·Runner 타깃 3벌 반영·App ID 기능 등록이 한 번에 되고 프로젝트 레벨에 잘못 넣는 실수가 없다.
4. **심사 계정** — (A) 테스트 사육장 1대·카메라 1대만 연결한 심사 전용 계정 **(추천)** / (B) Play처럼 운영 계정(기기 77대) 재사용. A: 검토자가 고객 기기를 제어할 위험 제거.
5. **ATS** — `NSAllowsArbitraryLoads` 제거 **(추천, Task 1에 포함)**: 이미 무시되는 키라 동작 변화가 없고 심사 질문 거리만 남긴다.

## 실패 시나리오

| 실패 | 대응 |
|---|---|
| U0에서 `com.vivanaut.app` 등록 거절(다른 팀 점유) | 코드 작업 시작 전에 멈춘다. 무료 팀은 포털 접근이 없으므로 Apple 지원(케이스 30000017939787 메일)에 해제 요청. 장기화되면 번들 변경을 사용자와 재결정 |
| ASC 계약 미동의로 새 앱 생성 불가 | U0에서 비즈니스 → 계약 동의(계정 소유자=사용자) |
| 팀만 바꾸고 Push 없는 App ID로 서명 | Task 1·2를 한 브랜치에서 끝내고 `--ref` dry-run 통과 뒤에만 병합 |
| plist `BUNDLE_ID` ≠ 번들 → 토큰 못 받음(조용한 실패) | Task 2 가드 테스트 + Task 3 export 산출물 검사 |
| APNs 키를 Sandbox 전용으로 생성 → TestFlight·스토어 수신 불가 | U2에서 "Sandbox & Production, Team scoped"로 생성 |
| `flutter build ipa`가 export 실패에도 0 종료 → 거짓 성공 | Task 3: dry-run도 `xcodebuild -exportArchive`(로컬 export)를 직접 돌리고 산출물 entitlements를 검사 |
| `apns` 블록 형식 오류 → iOS·Android 발송 실패 | Task 4 Node 테스트, 배포 뒤 Android 1건 회귀 확인, 실패 시 이전 버전 재배포 |
| 팀 교체 뒤 무료 팀으로 하던 로컬 실기기 실행이 깨짐 | Xcode에 bss.rol20 로그인 상태로 실행. CLAUDE.md에 적는다 |
| 심사 반려 2.1(하드웨어 확인 불가) | 심사 노트에 데모 계정 + **실제 iPhone에서 앱으로 기기를 페어링·제어하는 장면을 외부 촬영한 영상** |
| 심사 반려 1.2(UGC) | 신고 처리 절차(검토 기한)·차단·연락처를 심사 노트에 명시, 필터링 방식 사용자 확인 |
| 이름 "비바나트" 선점 | U3에서 부제 포함 이름을 사용자에게 확인 |

## 유저 체험 시뮬레이션

- **iPhone 사용자(출시 후):** App Store에서 "비바나트" 설치 → 이메일 로그인 → 사육장 기기 등록 직후 알림 권한 팝업에서 허용 → 서버가 알림을 보내면 잠금 화면에 소리와 함께 뜬다. 온습도 경보(서버 경보 발송이 켜진 뒤)는 "시간 민감"으로 와서, 사용자가 시간 민감 알림을 막지 않았다면 집중 모드에서도 보인다. 무음 스위치가 켜져 있으면 소리는 나지 않는다. 알림을 누르면 해당 화면으로 간다. 앱을 보고 있을 때 온 알림은 상단 배너 한 번.
- **iPad·Mac 사용자:** iPad에서는 iPhone 앱 확대 실행. Apple Silicon Mac·Vision Pro에는 배포하지 않는다(U4에서 끔).
- **기존 베타 테스터:** TestFlight로 "비바나트"(정식) 초대를 받아 새로 설치·로그인. "비바나트 베타"에는 새 빌드가 오지 않는다.
- **해외 사용자:** 검색되지 않는다.

## 근본 원인·전후 동작

없음 — 버그 수정이 아니다. 동작 변경: iOS 푸시 꺼짐 → 켜짐, iPad 네이티브 → iPhone 앱 확대 실행, TestFlight 대상 베타 → 정식.

## 검증 방법

- `flutter analyze` 에러 0, `flutter test test/build/ios_release_config_test.dart` 통과.
- `node --test 'supabase/functions/_shared/*.test.mjs'` 통과.
- `tools/testflight.sh --dry-run --ref docs/…브랜치` 통과: 산출물에서 `aps-environment = production`, `com.apple.developer.usernotifications.time-sensitive = true`, 앱 안 plist `BUNDLE_ID = com.vivanaut.app`.
- 실기기(U5, **사용자만 확인 가능**) — 체크리스트 §6 전체:
  1. 로그인 후 운영 `push_devices`에 `platform = 'ios'` 활성 행(메인이 조회, 읽기만).
  2. 앱 꺼짐·백그라운드에서 서버 푸시 수신(소리).
  3. 앱 사용 중 서버 푸시 → 배너 **한 번**.
  4. 시간 민감: 집중 모드 + 시간 민감 허용 → 경보 표시 / 시간 민감 끔 → 숨김(경보 발송이 켜진 계정일 때만, 아니면 "미확인"으로 보고).
  5. 앱 종료 상태에서 서버 푸시 탭 → 해당 화면, 로컬 알림(팬 타이머) 탭 → 해당 사육장.
  6. 로그아웃 → 행 비활성화(`deactivate_push_device`), 다른 계정 로그인 → 새 계정으로 재등록, 이전 계정 알림 안 옴.
- App Store Connect 제출 화면: 빌드 연결 후 필수 항목 경고 0.

## 사용자가 정할 것

1. 선택지 1·2·3·4 (추천: 모두 A).
2. U0 App ID 등록(Apple 계정에 식별자 생성) — 실행 직전 확인.
3. `dispatch-push` 운영 배포(Task 4) — 배포 직전 확인.
4. 커뮤니티 신고 처리 기한(예: 24시간 내 검토)과 필터링 방식 — 심사 노트에 쓸 사실.
5. 출시 방식(심사 제출 시): 추천 수동 출시.

## Global Constraints

- 팀 `XYNNB47RN3`, 번들 `com.vivanaut.app`, 표시 이름 `비바나트`(Info.plist `CFBundleDisplayName`).
- iPhone 전용(`TARGETED_DEVICE_FAMILY = 1`), 대한민국만, 무료, Mac·Vision Pro 배포 끔.
- `IPHONEOS_DEPLOYMENT_TARGET = 15.0` 유지.
- 비밀값(APNs .p8, 심사 계정 비밀번호)은 레포·슬랙·문서에 남기지 않는다. 입력은 사용자.
- `GoogleService-Info.plist`는 커밋한다(앱 식별 정보).
- 운영 DB·Edge Function 변경은 사용자 승인 뒤.
- 첫 커밋(Task 1)에서 pubspec 버전을 올리고(빌드 553 이상 필수, 빌드 설정 변경 → patch+1·build+1) `CHANGELOG.md` 한 릴리스 항목을 만든다. 이후 Task 커밋은 같은 항목에 덧붙인다.
- `FirebaseMessaging.setForegroundNotificationPresentationOptions`는 부르지 않는다(두 번 뜸).
- 건드리지 않는 것: Android 빌드·채널, `lib/`(이번 계획은 `lib/` 변경 없음), `AppDelegate.swift`, `update_policy.dart`, 옛 베타 ASC 앱(삭제하지 않음).

## Review Focus

1. **회복 알림이 시간 민감으로 가는지** — `safety.recovered`·`community.comment`는 `interruption-level` 없음. Task 4 테스트.
2. **Android 메시지가 바뀌는지** — `apns` 추가 뒤 `android` 블록 동일. Task 4 테스트.
3. **entitlements가 RunnerTests에 새는지** — `CODE_SIGN_ENTITLEMENTS`는 Runner 타깃 3벌에만. Task 2 테스트(설정 블록 단위 검사).
4. **스크립트가 정식이 아닌 main을 올리는지** — 팀·번들·기기군이 다르면 업로드 전에 멈춤. Task 3 Acceptance.
5. **앱 사용 중 알림 두 번** — U5-3.

---

## 콘솔 선행: U0 (코드 작업 전)

> **2026-11-27 U0-1 재시도: ✅ 등록 성공** — 팀 XYNNB47RN3에 `com.vivanaut.app` App ID 생성(기능 미설정). 번들 변경 없음, Task 1~3 진행 가능.
>
> **2026-11-24 U0-1 결과: 등록 거절** — `com.vivanaut.app`을 다른 Apple 계정(arthurbaek@icloud.com)의 무료 팀 `8NDUMK7C65`가 점유(이 Mac의 무료 팀 프로필, 만료 11-26). 실패 시나리오 1행대로 코드 작업 중단, Apple 지원 해제 요청 + 만료 뒤 재시도. 경과는 `docs/ops/apple-developer-account.md` 번들 표.


| 할 일 | 누가 | 완료 판정 |
|---|---|---|
| developer.apple.com → Identifiers → "+" App IDs → Explicit `com.vivanaut.app`, 설명 "Vivanaut", 기능 Push Notifications·Time Sensitive Notifications 체크 → 등록 | 사용자(메인이 화면 안내, 등록 직전 확인) | 등록 성공. 거절이면 실패 시나리오 1행 후 **중단** |
| App Store Connect → 비즈니스(계약): 최신 계약 동의·법인명 terraai Co.,Ltd. 표시 확인, 앱 목록에 `com.vivanaut.app` 앱이 이미 있는지 확인 | 사용자 | 계약 "활성", 중복 앱 없음 |
| Firebase 콘솔(Android와 같은 프로젝트) → iOS 앱 추가, 번들 `com.vivanaut.app`, 닉네임 "비바나트 iOS" → `GoogleService-Info.plist` 다운로드 | 사용자 | plist 확보(Task 2 입력) |

## 코드 Task

### Task 1: 정식 팀·iPhone 전용·규칙 문서 + 가드 테스트

> **✅ 2026-11-27 완료 — 커밋 `482280a9`.** 버전은 Task 4에서 이미 올린 0.187.0+553을 같은 릴리스로 유지하고 CHANGELOG 항목에 `### 변경`을 덧붙였다(아래 "patch+1, build+1"은 적용 안 함). Xcode 서명은 Task 3 dry-run에서 확인.

**Files:**
- Modify: `ios/Runner.xcodeproj/project.pbxproj`
- Modify: `ios/Runner/Info.plist` (`NSAllowsArbitraryLoads` 제거, `NSAllowsLocalNetworking` 유지)
- Create: `test/build/ios_release_config_test.dart`
- Modify: `CLAUDE.md`(명령 절 TestFlight 줄), `.claude/skills/testflight/SKILL.md`, `docs/ops/apple-developer-account.md`(번들 표·업로드 절차)
- Modify: `pubspec.yaml`(patch+1, build+1), `CHANGELOG.md`

**Context:**
- Depends on: U0 통과
- Produces: 가드 테스트 파일과 헬퍼 `String buildSettingsBlock(String pbx, String configId)` — 설정 id(`97C14706…` 등)로 `{ … }` 블록 문자열을 돌려준다. Task 2가 재사용.
- Must know: 팀·번들은 **Runner 타깃** 3벌(`249021D4217E4FDB00AE95B9`, `97C147061CF9000F007C117D`, `97C147071CF9000F007C117D`), 기기군은 **프로젝트 레벨** 3벌(`249021D3217E4FDB00AE95B9`, `97C147031CF9000F007C117D`, `97C147041CF9000F007C117D`). 규칙 문서 수정을 같은 커밋에 넣어 "XYNNB47RN3를 main에 넣지 않는다" 규칙과 코드가 충돌하는 중간 상태를 만들지 않는다.
- Acceptance: 테스트 PASS, `grep -c 8NDUMK7C65 …pbxproj` = 0, `grep -c "Tera Ai" …pbxproj` = 0.

- [ ] **Step 1: 테스트** — group `iOS 정식 출시 설정`:
  - `Runner 타깃 3벌: 정식 팀·번들` — 각 Runner 블록에 `DEVELOPMENT_TEAM = XYNNB47RN3;`·`PRODUCT_BUNDLE_IDENTIFIER = com.vivanaut.app;` 포함, 파일 전체에 `8NDUMK7C65`·`"Tera Ai"` 없음.
  - `프로젝트 레벨 3벌: iPhone 전용` — 각 블록에 `TARGETED_DEVICE_FAMILY = 1;`.
  - `ATS: 로컬 네트워크만 예외` — Info.plist에 `NSAllowsArbitraryLoads` 없음, `NSAllowsLocalNetworking` 있음.
- [ ] **Step 2:** FAIL 확인.
- [ ] **Step 3:** 값 교체, `INFOPLIST_KEY_CFBundleDisplayName = "Tera Ai";` 3줄 삭제, ATS 키 삭제. 규칙 문서: "main = 정식 값(XYNNB47RN3·com.vivanaut.app), TestFlight도 정식 앱(2026-11-24 사용자 결정). 로컬 실기기 실행은 Xcode에 bss.rol20 로그인 필요. `com.vivanaut.beta`는 은퇴(마지막 552)." 버전·CHANGELOG("변경: iOS 정식 앱 빌드 설정(iPhone 전용, 조직 팀)").
- [ ] **Step 4:** PASS, `flutter analyze` 0.
- [ ] **Step 5: Commit** `build(ios): 정식 팀·iPhone 전용으로 고정, TestFlight 규칙 갱신`

### Task 2: iOS 푸시 기능 — Xcode 기능·Firebase plist

> **✅ 2026-11-27 완료.** App ID에 Push·Time Sensitive 저장(포털), Firebase iOS 앱 "비바나트 iOS"(`1:204097603991:ios:d7a5516ed8a60a3d5e9cd2`) 등록·plist 확보. Xcode 작업 중 Location Push가 잘못 들어가고 plist 참조가 프로젝트 루트에 붙어 `ios/` 사본을 가리켜 바로잡았다 — 테스트에 "Runner 그룹 안·ios/ 사본 없음" 검사를 더했다.

**Files:**
- Create: `ios/Runner/Runner.entitlements` (Xcode가 생성)
- Create: `ios/Runner/GoogleService-Info.plist` (U0 파일 그대로)
- Modify: `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/Info.plist` (Xcode가 수정)
- Modify: `test/build/ios_release_config_test.dart`, `CHANGELOG.md`

**Context:**
- Depends on: Task 1
- Consumes: `buildSettingsBlock`
- Must know: 선택지 3-A — 사용자가 Xcode(Runner 타깃 → Signing & Capabilities, 팀 terraai Co.,Ltd.)에서 기능 3개 추가, plist를 Runner 그룹에 드래그(Copy items, Target = Runner). 메인은 결과 diff만 확인·테스트·커밋. `aps-environment`는 `development`로 생성되고 App Store export 때 production으로 바뀐다.
- Acceptance: 테스트 PASS + Task 3 dry-run 산출물 검사 통과.

- [ ] **Step 1: 테스트 추가**
  - `푸시 entitlements는 Runner에만` — Runner 3블록에 `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;`, RunnerTests 3블록(`331C8088…`, `331C8089…`, `331C808A…`)과 프로젝트 레벨 3블록에는 없음. entitlements 파일에 `aps-environment`, `com.apple.developer.usernotifications.time-sensitive`.
  - `원격 알림 백그라운드 모드` — Info.plist `UIBackgroundModes`에 `remote-notification`.
  - `Firebase plist가 정식 번들용이고 앱 리소스에 등록` — plist `BUNDLE_ID` = `com.vivanaut.app`, pbxproj에 `GoogleService-Info.plist in Resources`.
- [ ] **Step 2:** FAIL. **Step 3:** 사용자 Xcode 작업. **Step 4:** PASS.
- [ ] **Step 5: Commit** `build(ios): 푸시 기능·Firebase iOS 설정 추가` (CHANGELOG 같은 항목에 "추가: iOS 푸시 알림")

### Task 3: TestFlight 스크립트 — 검사형·`--ref`·export 산출물 검사

> **✅ 2026-11-27 완료 — 커밋 `b43ff082`.** Acceptance 3건 통과: 브랜치 업로드 시도 즉시 die / `--dry-run --ref origin/main` 팀 검사 die / `--dry-run --ref origin/feat/ios-official-release` 빌드·로컬 export·산출물 검사 통과(서명 팀 XYNNB47RN3, aps-environment production, time-sensitive true, Firebase BUNDLE_ID com.vivanaut.app). 실제 업로드는 ASC 앱 레코드(U3) 전이라 미실행.

**Files:**
- Modify: `tools/testflight.sh`, `.claude/skills/testflight/SKILL.md`

**Context:**
- Depends on: Task 1·2
- Must know: 지금 스크립트는 늘 `origin/main`을 빌드하고 sed로 값을 바꾼다. 바꿀 점은 세 가지. ① `--ref <ref>`(기본 `origin/main`) — 병합 전 브랜치 검증용, 업로드는 `origin/main`일 때만 허용(다른 ref로 업로드하려 하면 die). ② sed 교체를 지우고 검사로: Runner 팀·번들 각 3, `TARGETED_DEVICE_FAMILY = 1;` 3, 아니면 die. ③ dry-run도 `xcodebuild -exportArchive`를 `destination=export`(로컬)로 돌리고, 산출 `.ipa` 안 `Runner.app`에서 `codesign -d --entitlements :-`로 `aps-environment = production`·time-sensitive true, `GoogleService-Info.plist`의 `BUNDLE_ID`를 검사. 업로드 모드는 같은 검사 뒤 기존 `destination=upload`.
- Acceptance: `tools/testflight.sh --dry-run --ref origin/docs/…`(Task 1·2 브랜치) 통과 / `--ref origin/main`(병합 전 main) → 팀 검사에서 die / `--ref <브랜치>`로 업로드 시도 → die.

- [ ] **Step 1~3:** 위 ①②③ 구현. **Step 4:** Acceptance 3건 실행·출력 확인.
- [ ] **Step 5: Commit** `build(ios): TestFlight 스크립트를 정식 앱 검사형으로`

### Task 4: 서버 푸시 메시지에 `apns` 블록

**Files:**
- Modify: `supabase/functions/_shared/firebase-message.mjs`, `supabase/functions/_shared/firebase-message.test.mjs`

**Context:**
- Depends on: 없음(Task 1~3과 독립, 같은 브랜치)
- Produces: `export function usesTimeSensitive(kind)` — `kind === 'env.alert.triggered' || kind === 'safety.alert'`. `usesSafetyChannel`(Android 채널)과 분리.
- Must know: Android 블록 불변. 운영 배포는 사용자 승인 뒤 `docs/handoffs/2026-09-15-fcm-deployment-checklist.md` 절차.
- Acceptance: `node --test 'supabase/functions/_shared/*.test.mjs'` PASS (디렉터리 인자는 Node 22에서 MODULE_NOT_FOUND — 2026-11-24 구현 때 정정).

- [ ] **Step 1: 테스트**
  - `env.alert.triggered`·`safety.alert` → `message.apns` deep-equals `{ payload: { aps: { sound: 'default', 'interruption-level': 'time-sensitive' } } }`.
  - `safety.recovered`·`community.comment` → `message.apns` deep-equals `{ payload: { aps: { sound: 'default' } } }`.
  - 모든 경우 `message.android`가 기존 기대값과 같다.
- [ ] **Step 2:** FAIL. **Step 3:** 구현. **Step 4:** PASS.
- [x] **Step 1~5 완료 (2026-11-24)** — 49/49 통과, 버전 0.187.0+553·CHANGELOG를 이 커밋에서 만들었다(Task 1은 이 항목에 덧붙인다). 커밋 `38e85e34`.
- [ ] **Step 6 (사용자 승인 뒤):** `dispatch-push` 운영 배포 → Android 실기기 1건 수신 회귀 확인.

**병합:** Task 1~4를 한 브랜치에서 끝내고 Task 3 Acceptance(브랜치 dry-run) 통과 뒤 `tools/worktree.sh finish`.

---

## 콘솔 Task (병합 후)

| # | 할 일 | 누가 | 완료 판정 |
|---|---|---|---|
| U1 | 첫 업로드 `tools/testflight.sh`(사용자 요청 시) → ASC 처리·수출 규정 답(기존과 동일) | 메인 실행 | TestFlight에 빌드 처리 완료 |
| U2 | Apple Developer → Keys → APNs 키: **환경 Sandbox & Production, Team scoped** → .p8 보관(비밀번호 관리자) → Firebase 클라우드 메시징 → iOS 앱에 업로드(Key ID·팀 ID) | **사용자만**(비밀 키) | Firebase에 APNs 인증 키 표시 |
| U3 | App Store Connect → 새 앱: iOS, 이름 "비바나트", 한국어, 번들 `com.vivanaut.app`, SKU `vivanaut-app`, 전체 액세스 | 사용자 또는 메인(생성 직전 확인) | 앱 레코드·App Store ID |
| U4 | 스토어 정보 — Play 등록정보(ko) 텍스트 재사용, 부제·키워드, 카테고리 라이프스타일, 개인정보처리방침·지원 URL, 스크린샷 6.9"(1320×2868, 시뮬레이터), **앱 개인정보는 Apple 양식으로 새로 답한다**(데이터별 사용자 연결 여부·추적 없음·목적, Firebase·Supabase SDK 수집 포함), 연령 등급(사용자 생성 콘텐츠), 가격 무료, 대한민국만, **Mac·Vision Pro 배포 끔**, 심사 정보(영어 안내·심사 계정·외부 촬영 하드웨어 영상·신고 처리 절차) | 메인 입력·사용자 최종 저장 | 항목 저장(빌드 연결 전) |
| U5 | 내부 테스터 실기기 검증 1~6 (검증 방법 절) | 사용자 확인, 메인 DB 조회 | 6항목 결과 기록(미확인은 사유와 함께) |
| U6 | U1 빌드를 1.0 제출 버전에 연결 → 필수 경고 0 확인 | 메인·사용자 | **제출 직전 상태 = 목표 달성** |

순서: U0 → Task 1~4 → (브랜치 dry-run) → 병합 → U2 → U1 → U3 → U4 → U5 → U6. Task 4 운영 배포는 U5 전.

> **2026-11-27 순서 정정·진행:** 업로드(U1)는 App Store Connect 앱 레코드가 있어야 하므로 **U3를 U1 앞에** 둔다. ✅ U0~Task 4 병합(`6b267594`). ✅ **U3 완료** — 앱 "비바나트" 생성, Apple ID `6839900395`(생성 때 "사용자 액세스 설정을 저장할 수 없음" 경고가 떴지만 결과는 모든 사용자 접근 = 전체 액세스와 같음). ✅ **U2 완료(2026-11-27)** — APNs 키 `AMKCHP97MT`(Sandbox & Production, Team Scoped), Firebase 개발·프로덕션 두 칸 업로드. ✅ **Task 4 운영 배포(2026-11-27 14:28 KST)** — `dispatch-push` v13(11-02) → **v14**, 사용자 승인. 새로 나간 변경은 apns 블록(`38e85e34`)뿐(v13 배포 22:47이 직전 커밋 22:37 이후). `verify_jwt=false`는 config.toml 그대로. 남은 순서: U1 → U4 → U5 → U6. 출시 뒤 iOS 업데이트 안내 주소는 `https://apps.apple.com/app/id6839900395`.

## 후속 (이 계획 밖)

심사 제출 클릭(사용자) → 승인 → 수동 출시 → 운영 `app_release_policy` ios `store_url`(운영 DB, 승인) → 슬랙 공유. ITSAppUsesNonExemptEncryption 키로 업로드마다의 수출 규정 답 생략은 선택 과제.
