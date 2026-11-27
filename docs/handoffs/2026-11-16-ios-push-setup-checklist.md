# iOS 푸시 켜기 체크리스트 (2026-11-16)

> 관련: [스토어 출시 준비 계획 §2.3](../superpowers/plans/2026-11-16-store-update-and-push-route.md) · [Apple 개발자 계정 SOT](../ops/apple-developer-account.md)
> 상태: **앱 코드는 준비됨(0.182.0), 설정은 아직 아무것도 안 함.** 아래를 다 하기 전까지 iOS 푸시는 꺼져 있다.
>
> ⚠️ **2026-11-27 갱신:** 이 문서의 베타 번들(`com.vivanaut.beta`)·sed 교체·`TESTFLIGHT_BUNDLE_ID` 전제는 더 이상 맞지 않는다. 정식 앱 일원화(2026-11-24 결정)에 따라 Firebase·Xcode 기능·스크립트 작업은 [iOS 정식 출시 계획](../superpowers/plans/2026-11-24-ios-official-release.md) Task 1~3에서 `com.vivanaut.app` 기준으로 끝냈다(plist는 `ios/Runner/`, 베타용 plist는 두지 않음). 남은 것은 APNs 키(U2)와 6절 실기기 확인이다.

## 0. 지금 코드가 하는 일

| 항목 | 동작 | 위치 |
|---|---|---|
| Firebase 초기화 | Android·iOS 둘 다 시도. iOS에 `GoogleService-Info.plist`가 없으면 예외로 끝나고 `Firebase.apps`가 비어 **푸시 전체가 꺼진다**(크래시 없음 — 2026-11-18 시뮬레이터 확인) | `lib/features/notification/data/push_messaging_service.dart` `initialize`·`supported` |
| 토큰 | iOS는 `getAPNSToken()`을 0.5초 간격 최대 3번 보고, 있으면 FCM 토큰을 받는다. 없으면 이번엔 등록하지 않고 다음 동기화(앱 복귀·토큰 갱신·로그인)에 다시 본다 | 같은 파일 `fetchPushToken` |
| 서버 등록 | `register_push_device`에 `p_platform` = `ios`/`android`(실행 플랫폼) | `push_device_repository.dart` `pushPlatformName` |
| 로컬 알림 탭 이동 | FCM과 무관하게 iOS에서도 동작(예약 → 그 사육장 예약 화면, 팬 타이머 → 그 사육장 홈) | `push_lifecycle_observer.dart`, `domain/local_tap_router.dart` |

**일부러 안 넣은 것:** `Runner.entitlements`(`aps-environment`)·Info.plist `UIBackgroundModes`·`GoogleService-Info.plist`. Push 기능이 없는 App ID로 자동 서명하면 TestFlight 빌드가 깨질 수 있어서다. 아래 2·3단계에서 한 번에 넣는다.

## 1. Firebase 콘솔 — iOS 앱 등록

- [ ] 기존 Firebase 프로젝트(Android `google-services.json`과 같은 프로젝트)에 **iOS 앱 추가**
  - 베타: 번들 ID `com.vivanaut.beta` (팀 `XYNNB47RN3`, 지금 TestFlight로 올리는 번들)
  - 정식: `com.vivanaut.app` — **법인 팀 준비 뒤**에 추가(App ID가 그 팀에 생긴 다음)
- [ ] 앱마다 `GoogleService-Info.plist`를 내려받는다. 파일 안 `BUNDLE_ID`가 번들과 같아야 한다 — 다르면 토큰을 못 받는다.
- [ ] Android처럼 저장소에 넣는다(`android/app/google-services.json`도 커밋돼 있다). 비밀 키가 아니라 앱 식별 정보다.

## 2. plist 배치와 `tools/testflight.sh`

Xcode는 `project.pbxproj`에 등록된 파일만 앱에 넣는다. 파일만 복사하면 빌드에 안 들어가고, 등록만 하고 파일이 없으면 빌드가 실패한다. 그래서 **Runner 자리에는 항상 파일이 있어야 하고, 번들에 맞는 것을 고르는 일은 스크립트가 한다.**

추천 배치:

| 파일 | 내용 | pbxproj 등록 |
|---|---|---|
| `ios/Runner/GoogleService-Info.plist` | 정식 `com.vivanaut.app`용(정식 앱 등록 전이면 우선 베타 파일을 두되 아래 검사로 막힌다) | **예** — Xcode에서 Runner 그룹에 추가, Target Membership = Runner(Copy Bundle Resources에 들어감) |
| `ios/firebase/beta/GoogleService-Info.plist` | 베타 `com.vivanaut.beta`용 | 아니오 |

`tools/testflight.sh` 바꿀 곳 (지금 스크립트는 plist를 전혀 다루지 않는다):

1. **번들 ID 교체 검사 바로 뒤**(63행 `번들 ID 교체 개수가 3이 아닙니다` 다음, 65행 `version=` 앞)에 베타 plist로 덮어쓰는 단계를 넣는다. 스크립트는 `origin/main`을 받은 임시 작업 공간(`$work`)에서만 바꾸므로 main에는 남지 않는다 — 지금 팀 ID·번들 ID를 바꾸는 방식과 같다.
   ```bash
   plist_src="$work/ios/firebase/beta/GoogleService-Info.plist"
   plist_dst="$work/ios/Runner/GoogleService-Info.plist"
   [ -f "$plist_src" ] || die "$plist_src 가 없습니다 — Firebase 콘솔에서 $BUNDLE_ID 앱의 plist를 받아 두세요."
   cp "$plist_src" "$plist_dst"
   plist_id="$(/usr/libexec/PlistBuddy -c 'Print :BUNDLE_ID' "$plist_dst")"
   [ "$plist_id" = "$BUNDLE_ID" ] || die "GoogleService-Info.plist 번들이 $plist_id 입니다 (기대값 $BUNDLE_ID)."
   ```
   `BUNDLE_ID`는 환경변수 `TESTFLIGHT_BUNDLE_ID`로 바뀔 수 있으니(16행) 경로를 번들별로 나누려면 `ios/firebase/$BUNDLE_ID/GoogleService-Info.plist`처럼 번들 이름을 폴더로 써도 된다.
2. **Archive 번들 검사 뒤**(71~72행 `built_id` 다음)에 앱 안에 plist가 실제로 들어갔는지 확인을 하나 더 두면 좋다.
   ```bash
   /usr/libexec/PlistBuddy -c 'Print :BUNDLE_ID' "$archive/Products/Applications/Runner.app/GoogleService-Info.plist" \
     | grep -qx "$BUNDLE_ID" || die "앱 안 GoogleService-Info.plist가 $BUNDLE_ID 용이 아닙니다."
   ```
3. 법인 팀으로 옮길 때는 스크립트 머리의 `TEAM_ID`·`BUNDLE_ID` 두 값만 바꾸는 지금 규칙에 plist 경로 하나가 더해진다는 점을 스크립트 주석에 적는다.

대안: pbxproj에 Run Script 단계를 넣어 `PRODUCT_BUNDLE_IDENTIFIER`로 plist를 골라 `${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/`에 복사하는 방법도 있다. 스크립트를 덜 고치지만 Xcode 빌드 단계가 늘어 눈에 덜 띈다 — 위 방식을 추천.

## 3. Apple — APNs 키와 Xcode 기능

- [ ] Apple Developer(팀 `XYNNB47RN3`) → Keys → **APNs 인증 키(.p8)** 생성. Key ID·Team ID를 적어 둔다. 키 파일은 한 번만 내려받을 수 있다 — 비밀번호 관리자 등 안전한 곳에 보관, 저장소에는 넣지 않는다.
- [ ] Firebase 콘솔 → 프로젝트 설정 → 클라우드 메시징 → iOS 앱(베타)에 .p8 업로드(Key ID·Team ID 입력). 정식 앱은 법인 팀 키로 따로.
- [ ] App ID `com.vivanaut.beta`에 **Push Notifications** 기능 켜기(Certificates, Identifiers & Profiles → Identifiers).
- [ ] Xcode → Runner 타깃 → Signing & Capabilities:
  - **Push Notifications** 추가 → `Runner/Runner.entitlements`(`aps-environment`)가 생기고 pbxproj `CODE_SIGN_ENTITLEMENTS`가 들어간다.
  - **Background Modes** 추가 → **Remote notifications** 체크 → Info.plist `UIBackgroundModes`에 `remote-notification`.
  - `tools/testflight.sh`는 팀·번들만 sed로 바꾸므로 entitlements는 그대로 따라간다. 이 변경 뒤 첫 빌드는 `--dry-run`으로 서명이 되는지 먼저 본다.

## 4. 서버 — 알림 모양

- [ ] `supabase/functions/_shared/firebase-message.mjs` `buildFirebaseMessage`에는 `android` 블록만 있고 **`apns` 블록이 없다.** `notification`(제목·본문)만으로 iOS에도 알림은 표시되지만, **소리·배지**는 `apns.payload.aps`(`sound: 'default'`, 필요하면 `badge`)가 있어야 한다. 안전 알림(`usesSafetyChannel`)은 `interruption-level: 'time-sensitive'`도 검토(앱에 Time Sensitive 기능 추가가 함께 필요).
- [ ] 서버 담당(이관훈님)에게 요청 — 앱 코드 변경은 필요 없다.

## 5. 앱 사용 중 표시 확인

- 앱이 열려 있을 때 받은 서버 푸시는 앱이 `LocalNotifications.showRemote`로 다시 띄운다. 이 함수는 Android 설정만 넘기고 **Darwin(iOS) 설정이 없다** — 플러그인 기본값(초기화 때의 표시 기본값)으로 뜨는지 실기기에서 확인한다. 안 뜨거나 소리가 없으면 `showRemote`에 `iOS: DarwinNotificationDetails(presentBanner: true, presentSound: true)`를 더한다(팬 타이머·예약 알림이 이미 이렇게 한다).
- `FirebaseMessaging.setForegroundNotificationPresentationOptions`는 부르지 않는다. 부르면 iOS가 한 번, 앱이 한 번 — **두 번 뜬다.**
- `ios/Runner/AppDelegate.swift`의 `UNUserNotificationCenter.current().delegate` 설정은 그대로 둔다(로컬 알림 탭 전달에 필요).

## 6. 확인 순서 (실기기 — 시뮬레이터는 APNs 실수신 불가)

1. [ ] `tools/testflight.sh --dry-run` — 서명·plist 검사 통과.
2. [ ] TestFlight 설치 → 로그인 → 알림 권한 허용 → Supabase `push_devices`에 `platform = 'ios'` 행이 생기는지(앱 시작 직후 APNs가 늦으면 한 번 백그라운드에 갔다 오면 등록된다).
3. [ ] 앱 **사용 중** 서버 푸시 수신 → 한 번만 표시되는지(5절).
4. [ ] 앱 **백그라운드**에서 수신 → 탭 → 알림 경로(`/env-detail` 등)로 이동, 온습도 이탈이면 그 사육장으로 홈 선택이 바뀌는지.
5. [ ] 앱 **종료 상태**에서 서버 푸시 탭 → 스플래시 뒤 해당 화면(`getInitialMessage`).
6. [ ] 로컬 알림(예약 시각·팬 타이머)을 **종료 상태**에서 탭 → 스플래시·로그인 확인 뒤 예약 화면/홈(`getNotificationAppLaunchDetails` — 시뮬레이터에서는 알림 센터 조작이 안 돼 미확인).
7. [ ] 로그아웃 → `deactivate_push_device`로 그 기기 행이 꺼지는지, 다른 계정 로그인 시 새 계정으로 등록되는지.
