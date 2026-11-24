# iOS 정식 출시 준비 Implementation Plan

> **구현 방식 (CAOF):** 이 계획을 task 단위로 구현한다. Critical 트랙 — 코드 task(1~5)는 Implementer(`flutter-dev`) 분리(GATE 4), 콘솔 작업(U1~U7)은 사용자가 하거나 사용자 확인 뒤 메인이 브라우저로 돕는다. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 조직 팀 `XYNNB47RN3`(terraai Co.,Ltd.)으로 정식 번들 `com.vivanaut.app` "비바나트"를 iPhone 전용·대한민국·iOS 푸시 포함으로 App Store 심사에 제출할 수 있게 만든다.

**Architecture:** main의 iOS 빌드 설정을 정식 값(팀·번들)으로 고정하고, TestFlight도 정식 앱의 TestFlight로 일원화해 빌드 때 값을 바꿔 끼우는 단계를 없앤다. 푸시는 2026-11-16 체크리스트(`docs/handoffs/2026-11-16-ios-push-setup-checklist.md`)대로 Firebase iOS 앱·APNs 키·entitlements·서버 `apns` 블록을 더한다. 콘솔 작업은 Play 출시 때 정한 값(`docs/ops/google-play-account.md`)을 그대로 옮긴다.

**Tech Stack:** Flutter iOS(Xcode 자동 서명), firebase_messaging, flutter_local_notifications, Supabase Edge Function(`dispatch-push`, Node 테스트), App Store Connect, Firebase 콘솔.

**Spec:** 없음 — 근거는 사용자 결정(2026-11-24: iPhone 전용, iOS 푸시 첫 출시 포함, 대한민국만 배포), `docs/ops/apple-developer-account.md`(조직 전환 완료), `docs/handoffs/2026-11-16-ios-push-setup-checklist.md`, `docs/ops/google-play-account.md`(스토어 메타데이터·심사 계정 선례).

## 가정

- 확인:
  - 조직 전환 완료, 팀 ID `XYNNB47RN3` 유지(2026-11-24 멤버십 세부 사항 화면).
  - main `ios/Runner.xcodeproj/project.pbxproj`: `DEVELOPMENT_TEAM = 8NDUMK7C65` ×3, `PRODUCT_BUNDLE_IDENTIFIER = com.vivanaut.app` ×3, `TARGETED_DEVICE_FAMILY = "1,2"` ×3, `IPHONEOS_DEPLOYMENT_TARGET = 15.0`, `CODE_SIGN_ENTITLEMENTS` 없음.
  - `ios/Runner/`에 entitlements·`GoogleService-Info.plist` 없음, Info.plist에 `UIBackgroundModes` 없음.
  - 앱 코드는 iOS 푸시 준비 완료(0.182.0, `push_messaging_service.dart`) — plist가 없으면 꺼진 채 크래시 없음(2026-11-18 시뮬레이터).
  - `LocalNotifications.showRemote`(`lib/shared/services/local_notifications.dart:125`)는 Android 설정만 넘긴다.
  - `supabase/functions/_shared/firebase-message.mjs` `buildFirebaseMessage`에 `apns` 블록 없음. Edge Function은 앱 팀 소유(`docs/fcm-notification-work-split.md`), 운영 배포는 사용자 승인 사항.
  - 심사 요건: 앱 안 회원 탈퇴(`withdraw_screen.dart`)·커뮤니티 신고·차단(`blocked_users_screen.dart`) 있음, 소셜 로그인 없음(Sign in with Apple 의무 없음), 인앱 결제 없음.
  - 개인정보처리방침 https://www.vivanaut.co.kr/privacy, 계정 삭제 https://www.vivanaut.co.kr/account-deletion 공개.
  - `xcodeproj` gem 1.27.0 설치됨(pbxproj 파일 등록에 쓸 수 있음).
- 미확인:
  - `com.vivanaut.app` App ID를 팀 `XYNNB47RN3`에 등록할 수 있는지(옛 무료 팀 `8NDUMK7C65`가 잡고 있을 수 있음) → U1에서 판정.
  - App Store 이름 "비바나트" 사용 가능 여부 → U4.
  - Time Sensitive 알림 기능을 자동 서명이 App ID에 켜 주는지 → Task 2 dry-run.
  - 앱 종료 상태에서 푸시 탭 → 이동(실기기 미확인, 메모리 `project_app_update_and_push_route`) → U6.

## 선택지와 추천

1. **TestFlight 대상 번들** — (A) 정식 `com.vivanaut.app`의 TestFlight로 일원화, 베타 앱 `com.vivanaut.beta`는 은퇴 **(추천)** / (B) 베타 앱 유지, 빌드 때 팀·번들·plist를 바꿔 끼움. A 이유: 체크리스트 §2의 번들별 plist 교체·Firebase 앱 2개·APNs 설정 2벌이 사라지고, 심사에 올릴 바로 그 빌드를 테스터가 먼저 쓴다. 비용: 기존 베타 테스터가 "비바나트" 앱을 TestFlight에서 새로 설치해야 한다. **이 계획은 A로 쓴다** — B를 고르면 Task 5가 체크리스트 §2 설계로 바뀐다.
2. **안전 알림 Time Sensitive** — (A) `env.alert.triggered`·`safety.*`만 `interruption-level: time-sensitive`(집중 모드에서도 표시) **(추천)** / (B) 모두 기본. A 이유: 과열·저온 경보를 집중 모드 때문에 놓치면 폐사로 이어진다. Apple이 허용하는 용도(즉시 행동이 필요한 알림). 비용: entitlement 1개.
3. **심사 계정** — (A) 테스트 사육장 1대·카메라 1대만 연결한 심사 전용 계정 **(추천)** / (B) Play처럼 운영 계정(기기 77대 연결) 재사용. A 이유: 검토자가 실제 고객 기기를 제어할 위험 제거(`google-play-account.md` 119행 권고). 비용: 테스트 기기 1세트를 심사 기간 동안 켜 두어야 함.
4. **ATS `NSAllowsArbitraryLoads = true`** — 이번 계획에서 건드리지 않는다. `.env`에 `http://` 주소가 없어 빼도 될 가능성이 높지만, 커뮤니티·개체 사진의 `http://` URL이 깨질 수 있고 심사 필수 요건이 아니다. 별도 작업으로 남긴다.

## 실패 시나리오

| 실패 | 대응 |
|---|---|
| U1에서 `com.vivanaut.app`이 "다른 팀이 사용 중"으로 등록 거절 | 옛 무료 팀(arthurbaek, Xcode 개인 팀)에서 App ID를 지울 수 있는지 확인 → 안 되면 Apple 지원(케이스 30000017939787 같은 메일)에 해제 요청. 그동안 Task 1~5는 main에 넣지 않고 브랜치에 둔다 |
| 팀만 바꾸고 Push 기능 없는 App ID로 서명 → 빌드 실패 | Task 1·2를 같은 병합 단위로 묶고 `--dry-run` 통과 뒤에만 main 병합 |
| `GoogleService-Info.plist`의 `BUNDLE_ID`가 번들과 다름 → 토큰 못 받음(조용한 실패) | Task 2 가드 테스트 + testflight.sh archive 검사 |
| APNs 키 미업로드 → FCM이 iOS로 못 보냄 | U3 완료를 U6 실기기 확인 전 조건으로 |
| `apns` 블록 형식 오류 → iOS·Android 모두 발송 실패 | Task 4 Node 테스트, 배포 뒤 운영 1건 수신 확인, 실패 시 이전 버전 재배포 |
| 팀 교체 뒤 arthurbaek 무료 팀으로 하던 로컬 실기기 실행이 깨짐 | Xcode에 bss.rol20 로그인 상태로 실행(기기는 자동 등록). CLAUDE.md에 적는다 |
| 기존 베타 테스터가 업데이트를 못 받음 | 전환 공지(슬랙·테스터 안내)와 정식 앱 TestFlight 초대 |
| 심사 반려 2.1(하드웨어 기능 확인 불가) | 심사 노트에 기기 연결 데모 계정 + 기기 동작 영상 링크를 처음부터 넣는다 |
| 이름 "비바나트" 선점 | U4에서 "비바나트 - 파충류 사육" 같은 부제 포함 이름을 사용자에게 확인 |

## 유저 체험 시뮬레이션

- **iPhone 사용자(출시 후):** App Store에서 "비바나트"를 찾아 설치 → 이메일로 로그인 → 사육장 기기 등록 결과 직후 알림 권한 팝업에서 허용 → 사육장 온도가 안심존을 벗어나면 잠금 화면에 소리와 함께 "온도 경보" 알림이 뜬다. 집중 모드여도 이 경보는 "시간 민감" 표시와 함께 뜬다. 알림을 누르면 해당 사육장 화면으로 간다. 앱을 보고 있을 때 온 알림도 상단 배너로 뜬다(한 번만).
- **iPad 사용자:** App Store에서 iPhone 앱으로 표시되고 확대 모드로 실행된다(iPad 전용 레이아웃 없음).
- **기존 베타 테스터:** TestFlight에 "비바나트"(정식) 초대가 오고, 설치하면 다시 로그인한다. 옛 "비바나트 베타"는 더 이상 새 빌드가 오지 않는다.
- **해외 사용자:** App Store에서 검색되지 않는다(대한민국만).

## 근본 원인·전후 동작

없음 — 버그 수정이 아니다. 동작 변경: iOS 푸시 꺼짐 → 켜짐, iPad 네이티브 → iPhone 앱 확대 실행, TestFlight 대상 앱 베타 → 정식.

## 검증 방법

- `flutter analyze` 에러 0.
- `flutter test test/build/ios_release_config_test.dart test/features/notification/local_notifications_test.dart` 통과.
- `node --test supabase/functions/_shared/firebase-message.test.mjs` 통과.
- `tools/testflight.sh --dry-run` 통과(서명·App ID·entitlements·plist 검사 포함) — U1을 겸한다.
- 실기기(TestFlight, U6): ① 서버 푸시 수신(앱 꺼짐·백그라운드) ② 앱 사용 중 배너 한 번 ③ 안전 알림이 집중 모드에서 표시 ④ 앱 종료 상태에서 알림 탭 → 해당 화면. **사용자만 확인 가능.**
- App Store Connect 제출 화면의 필수 항목 경고 0.

## 사용자가 정할 것

1. TestFlight 일원화(선택지 1-A) — 추천 A.
2. 안전 알림 Time Sensitive(선택지 2-A) — 추천 A.
3. 심사 계정(선택지 3-A) — 추천 A. A면 테스트 사육장·카메라 1세트와 계정 생성은 사용자가 준비(비밀번호는 사용자 입력).
4. U1 dry-run이 Apple 계정에 App ID를 만든다 — 실행 직전에 한 번 더 확인.
5. `dispatch-push` 운영 배포(Task 4) — 배포 직전 확인.
6. 심사 제출 버튼, 출시 방식(승인 즉시 출시 / 수동 출시) — 추천: 수동 출시(승인 뒤 iOS `app_release_policy` 행 준비와 맞춰 공개).

## Global Constraints

- 팀 ID `XYNNB47RN3`, 번들 `com.vivanaut.app`, 표시 이름 `비바나트`(Info.plist `CFBundleDisplayName` 그대로).
- 기기: iPhone 전용(`TARGETED_DEVICE_FAMILY = 1`). 배포 국가: 대한민국만. 가격: 무료.
- `IPHONEOS_DEPLOYMENT_TARGET = 15.0` 유지.
- 비밀값(APNs .p8, 심사 계정 비밀번호)은 레포·슬랙·문서에 남기지 않는다. 입력은 사용자가 한다.
- `GoogleService-Info.plist`는 앱 식별 정보라 커밋한다(`android/app/google-services.json`과 같음).
- 운영 DB·Edge Function 변경은 사용자 승인 뒤.
- `lib/` 변경이 있는 병합은 pubspec 버전 올림 + `CHANGELOG.md` 한글 항목(같은 커밋).
- `FirebaseMessaging.setForegroundNotificationPresentationOptions`는 부르지 않는다(두 번 뜸 — 체크리스트 §5).
- 건드리지 않는 것: Android 빌드·알림 채널, `push_messaging_service.dart` 토큰 로직, `AppDelegate.swift`의 알림 delegate, ATS 설정, `update_policy.dart`(`kUpdateTargetPackage`는 이미 `com.vivanaut.app`), 옛 베타 App Store Connect 앱 삭제(남겨 둔다).

## Review Focus

1. **앱 사용 중 알림이 두 번 뜨는지** — iOS 포그라운드에서 서버 푸시 1건 → 배너 1개. Task 3 Acceptance + U6 ②.
2. **안전이 아닌 알림이 Time Sensitive로 가는지** — 일반 알림(`kind = 'community.comment'` 등)은 `interruption-level` 없음. Task 4 테스트에 고정.
3. **Android 메시지가 바뀌지 않는지** — `apns` 추가 뒤 `android` 블록 동일. Task 4 테스트에 고정.
4. **TestFlight 스크립트가 main 값이 정식이 아닐 때 그냥 올리는지** — 팀·번들·기기군이 다르면 업로드 전에 멈춘다. Task 5 검사에 고정.

---

## 코드 Task

### Task 1: iOS 빌드 설정을 정식 팀·iPhone 전용으로 + 설정 가드 테스트

**Files:**
- Modify: `ios/Runner.xcodeproj/project.pbxproj` (Runner 타깃 Debug/Release/Profile 3벌)
- Create: `test/build/ios_release_config_test.dart`

**Context:**
- Depends on: 없음 (단, main 병합은 Task 2와 함께 — 실패 시나리오 2행)
- Produces: 가드 테스트 파일 — Task 2가 같은 파일에 케이스를 더한다.
- Must know: pbxproj는 문자열로 읽어 개수를 센다(파서 도입 안 함). RunnerTests 타깃의 번들 `com.vivanaut.app.RunnerTests`는 그대로.
- Acceptance: `flutter test test/build/ios_release_config_test.dart` PASS, `grep -c 8NDUMK7C65 ios/Runner.xcodeproj/project.pbxproj` = 0.

- [ ] **Step 1: 실패하는 테스트** — `ios_release_config_test.dart`, group `iOS 정식 출시 설정`:
  - `test('Runner 3벌 모두 정식 팀')`: `'DEVELOPMENT_TEAM = XYNNB47RN3;'` 개수 == 3, `'8NDUMK7C65'` 개수 == 0.
  - `test('Runner 3벌 모두 정식 번들')`: `'PRODUCT_BUNDLE_IDENTIFIER = com.vivanaut.app;'` 개수 == 3.
  - `test('iPhone 전용')`: `'TARGETED_DEVICE_FAMILY = 1;'` 개수 == 3, `'TARGETED_DEVICE_FAMILY = "1,2";'` 개수 == 0.
- [ ] **Step 2:** `flutter test test/build/ios_release_config_test.dart` → 팀·기기군 2건 FAIL.
- [ ] **Step 3:** pbxproj에서 `DEVELOPMENT_TEAM = 8NDUMK7C65;` → `XYNNB47RN3;`(3곳), `TARGETED_DEVICE_FAMILY = "1,2";` → `1;`(3곳).
- [ ] **Step 4:** 같은 테스트 PASS.
- [ ] **Step 5: Commit** `build(ios): 정식 팀 XYNNB47RN3·iPhone 전용으로 고정`

### Task 2: iOS 푸시 기능 — entitlements·백그라운드 모드·Firebase plist

**Files:**
- Create: `ios/Runner/Runner.entitlements`
- Create: `ios/Runner/GoogleService-Info.plist` (U2에서 받은 파일 그대로)
- Modify: `ios/Runner.xcodeproj/project.pbxproj` (`CODE_SIGN_ENTITLEMENTS` 3벌, plist 파일 참조·Runner 그룹·Copy Bundle Resources)
- Modify: `ios/Runner/Info.plist`
- Modify: `test/build/ios_release_config_test.dart`

**Context:**
- Depends on: Task 1, U2(plist 파일)
- Must know: Xcode는 pbxproj에 등록된 파일만 앱에 넣는다 — 파일 복사만으로는 빌드에 안 들어간다. 등록은 Xcode GUI 또는 `xcodeproj` gem 스크립트(1회용, 커밋하지 않음). entitlements의 `aps-environment`는 `development`로 두면 App Store 내보내기 때 자동으로 production이 된다.
- Acceptance: 가드 테스트 PASS + `tools/testflight.sh --dry-run`(Task 5 이후) 통과 + archive 안 `Runner.app/GoogleService-Info.plist`의 `BUNDLE_ID` = `com.vivanaut.app`.

- [ ] **Step 1: 테스트 추가** (같은 group):
  - `test('푸시 entitlements 연결')`: pbxproj에 `'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'` 개수 == 3. entitlements 파일에 `<key>aps-environment</key>`와 `<key>com.apple.developer.usernotifications.time-sensitive</key>` 포함.
  - `test('원격 알림 백그라운드 모드')`: Info.plist에 `<key>UIBackgroundModes</key>` 다음 배열에 `<string>remote-notification</string>` 포함.
  - `test('Firebase plist가 정식 번들용이고 앱에 들어간다')`: `ios/Runner/GoogleService-Info.plist`의 `BUNDLE_ID` 값 == `com.vivanaut.app`(문자열에서 `<key>BUNDLE_ID</key>` 다음 `<string>` 추출), pbxproj에 `'GoogleService-Info.plist in Resources'` 포함.
- [ ] **Step 2:** FAIL 확인.
- [ ] **Step 3:** 선언 전문 —

`ios/Runner/Runner.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyLists/PLIST-1.0.dtd">
<plist version="1.0">
<dict>
	<key>aps-environment</key>
	<string>development</string>
	<key>com.apple.developer.usernotifications.time-sensitive</key>
	<true/>
</dict>
</plist>
```
Info.plist에 추가: `UIBackgroundModes` = [`remote-notification`]. pbxproj Runner 3벌에 `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;`. plist를 Runner 그룹·Runner 타깃 리소스로 등록.
- [ ] **Step 4:** PASS.
- [ ] **Step 5: Commit** `build(ios): 푸시 entitlements·원격 알림 모드·Firebase iOS 설정 추가`

### Task 3: 앱 사용 중 서버 푸시의 iOS 표시 설정

**Files:**
- Modify: `lib/shared/services/local_notifications.dart:125-145`
- Modify: `test/features/notification/local_notifications_test.dart`
- Modify: `pubspec.yaml`(minor+build), `CHANGELOG.md`

**Context:**
- Depends on: 없음
- Produces: `NotificationDetails remoteNotificationDetails({required bool safety})` (같은 파일 top-level) — `showRemote`가 이것을 쓴다.
- Must know: 기존 Android 값(채널 id·이름 키·중요도·우선순위)은 그대로 옮긴다. 팬 타이머·예약 알림이 이미 `DarwinNotificationDetails(presentBanner: true, presentSound: true)`를 쓴다 — 같은 모양.
- Acceptance: 아래 테스트 PASS, 기존 `showRemote` 테스트(채널 `vivanaut_safety`) PASS.

- [ ] **Step 1: 테스트** `test('원격 알림 iOS 표시 — 안전만 시간 민감')`:
  - `remoteNotificationDetails(safety: true).iOS` → `presentAlert/presentBanner/presentList/presentSound == true`, `interruptionLevel == InterruptionLevel.timeSensitive`.
  - `remoteNotificationDetails(safety: false).iOS!.interruptionLevel == InterruptionLevel.active`.
  - `.android!.channelId` == `'vivanaut_safety'` / `'vivanaut_default'`.
- [ ] **Step 2:** FAIL(함수 없음).
- [ ] **Step 3:** 함수 구현, `showRemote`의 `notificationDetails:`를 `remoteNotificationDetails(safety: safety)`로.
- [ ] **Step 4:** `flutter test test/features/notification/` PASS, `flutter analyze` 0.
- [ ] **Step 5: Commit** — pubspec minor+1·build+1, CHANGELOG "추가: iOS 푸시 알림(온습도 경보는 집중 모드에서도 표시)…" 단, 푸시가 실제로 켜지는 것은 Task 2·U3 이후이므로 CHANGELOG 문장은 "iOS 정식 앱에서 푸시 알림 지원"으로 Task 2와 같은 릴리스 항목에 둔다.

### Task 4: 서버 푸시 메시지에 `apns` 블록

**Files:**
- Modify: `supabase/functions/_shared/firebase-message.mjs` (`buildFirebaseMessage`)
- Modify: `supabase/functions/_shared/firebase-message.test.mjs`

**Context:**
- Depends on: 없음
- Must know: Android 블록은 바꾸지 않는다. `usesSafetyChannel(kind)`를 그대로 재사용. 운영 배포(`dispatch-push`)는 사용자 승인 뒤 `docs/handoffs/2026-09-15-fcm-deployment-checklist.md` 절차로.
- Acceptance: `node --test supabase/functions/_shared/` PASS.

- [ ] **Step 1: 테스트**
  - `kind = 'env.alert.triggered'` → `message.apns` deep-equals `{ headers: { 'apns-priority': '10' }, payload: { aps: { sound: 'default', 'interruption-level': 'time-sensitive' } } }`.
  - `kind = 'community.comment'` → `message.apns.payload.aps` deep-equals `{ sound: 'default' }` (interruption-level 키 없음).
  - 두 경우 모두 `message.android`가 기존 기대값과 같다.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** `apns` 블록 추가(위 값 그대로).
- [ ] **Step 4:** PASS.
- [ ] **Step 5: Commit** `feat(push): iOS 알림 소리·안전 알림 시간 민감(apns)`
- [ ] **Step 6 (사용자 승인 뒤):** `dispatch-push` 운영 배포 → Android 실기기 1건 수신으로 회귀 확인.

### Task 5: TestFlight 파이프라인을 정식 앱으로 일원화 + 규칙 문서

**Files:**
- Modify: `tools/testflight.sh`
- Modify: `.claude/skills/testflight/SKILL.md`
- Modify: `CLAUDE.md` (명령 절 TestFlight 줄)
- Modify: `docs/ops/apple-developer-account.md` (번들 ID·앱 표, 업로드 절차)

**Context:**
- Depends on: Task 1·2
- Must know: 스크립트는 더 이상 sed로 값을 바꾸지 않는다 — main 값을 **검사만** 한다. 기존 안전장치(임시 작업 공간, `.env` 링크, cleanup, 로그, archive 번들 검사)는 유지.
- Acceptance: main이 정식 값이면 `--dry-run` 통과. pbxproj를 일부러 `8NDUMK7C65`로 바꾼 임시 공간에서는 "main의 팀 ID가 XYNNB47RN3가 아닙니다"로 멈춘다(수동 확인 1회).

- [ ] **Step 1:** 스크립트 머리: `TEAM_ID=XYNNB47RN3`, `BUNDLE_ID=com.vivanaut.app` 상수(환경변수 덮어쓰기 제거). sed 교체 블록을 검사 블록으로: 팀 3·번들 3·`TARGETED_DEVICE_FAMILY = 1;` 3이 아니면 `die`.
- [ ] **Step 2:** archive 검사 뒤 `Runner.app/GoogleService-Info.plist`의 `BUNDLE_ID`가 `$BUNDLE_ID`가 아니면 `die`.
- [ ] **Step 3:** 주석·완료 문구에서 "베타" 표현을 "정식 앱 TestFlight"로.
- [ ] **Step 4:** SKILL.md·CLAUDE.md·SOT 문서: "베타 값을 빌드 때만 바꾼다 / main에 넣지 않는다" 규칙을 "main이 정식 값(XYNNB47RN3·com.vivanaut.app)이고 TestFlight도 정식 앱으로 올린다(2026-11-24 사용자 결정)"로 교체. 로컬 실기기 실행은 Xcode에 bss.rol20 로그인 필요라고 적는다. 베타 앱 `com.vivanaut.beta`는 "은퇴 — 마지막 552"로 표기.
- [ ] **Step 5: Commit** `build(ios): TestFlight를 정식 앱으로 일원화`

**병합:** Task 1~5를 한 브랜치에서 끝내고, U1(dry-run) 통과 뒤 `tools/worktree.sh finish`. 버전은 Task 3에서 올린 값.

---

## 콘솔 Task (U)

| # | 할 일 | 누가 | 완료 판정 |
|---|---|---|---|
| U1 | `tools/testflight.sh --dry-run` — 자동 서명이 팀 `XYNNB47RN3`에 App ID `com.vivanaut.app`(Push·Time Sensitive)을 만든다 | 메인(실행 직전 사용자 확인) | 빌드 성공. 실패 시 실패 시나리오 1행 |
| U2 | Firebase 콘솔(Android와 같은 프로젝트) → iOS 앱 추가, 번들 `com.vivanaut.app`, 앱 닉네임 "비바나트 iOS" → `GoogleService-Info.plist` 다운로드 → Task 2 | 사용자(메인이 화면 안내) | plist 파일 확보 |
| U3 | Apple Developer → Keys → APNs 키(.p8) 생성·보관(비밀번호 관리자) → Firebase 클라우드 메시징 → iOS 앱에 업로드(Key ID·팀 ID) | **사용자만**(비밀 키) | Firebase에 APNs 인증 키 표시 |
| U4 | App Store Connect → 새 앱: iOS, 이름 "비바나트", 기본 언어 한국어, 번들 `com.vivanaut.app`, SKU `vivanaut-app`, 전체 액세스 | 사용자 또는 메인(생성 직전 확인) | 앱 레코드 생성, App Store ID 확보 |
| U5 | 스토어 정보: Play 등록정보(ko) 텍스트 재사용, 부제·키워드, 카테고리 라이프스타일, 개인정보처리방침·지원 URL(vivanaut.co.kr), 스크린샷 6.9"(iPhone Pro Max 시뮬레이터 1320×2868), 앱 개인정보(Play 데이터 보안 답 대응), 연령 등급(사용자 생성 콘텐츠·신고·차단), 가격 무료, 배포 대한민국만, 심사 정보(영어 안내 + 심사 계정 + 기기 동작 영상 링크), 수출 규정 답 기존과 동일 | 메인 입력·사용자 최종 저장 | 제출 화면 필수 경고 0 |
| U6 | 첫 빌드 업로드(`tools/testflight.sh`, 사용자 요청 시) → 내부 테스터로 실기기 확인 ①~④ | 사용자 확인 | 검증 방법의 실기기 4항목 통과 |
| U7 | 심사 제출(수동 출시) → 승인 뒤 출시 → 운영 `app_release_policy` ios `store_url` 채움(운영 DB, 사용자 승인) → 슬랙 공유 | 사용자 클릭·승인 | App Store 공개 |

순서: U2 → Task 1~5 → U1 → (U3 병행) → U4 → U5 → U6 → U7. Task 4 운영 배포는 U6 전에.
