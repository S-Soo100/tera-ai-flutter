# 스토어 출시 준비 — 업데이트 안내 + 알림 눌러 이동 (2026-11-16)

> CAOF 트랙: **Critical** — 새 feature 폴더(`app_update`), 운영 DB 새 표·RLS, 라우터 redirect, iOS 푸시 경로.
> 작업 공간: `../tera-ai-flutter-store-update-push-route` (브랜치 `feat/store-update-push-route`, base `d96320a9`).
> 사용자 결정(2026-11-16): 버전 기준 = **Supabase 표** / 강도 = **강제+권장** / iOS 푸시 = **코드만 준비** / 로컬 알림 탭 = **해당 사육장 예약 화면(팬 타이머는 그 사육장 홈)**.
> 검수: Codex + Claude 교차 검수 반영(v2) — [`2026-11-16-store-update-and-push-route-review-final.md`](2026-11-16-store-update-and-push-route-review-final.md).

## 0. 현재 상태 (코드 확인)

| 항목 | 상태 | 근거 |
|---|---|---|
| 업데이트 안내 | 없음 | `min_version`·`latest` 류 코드·표 0건 |
| FCM 알림 탭 → 화면 이동 | **Android 구현됨** | `PushLifecycleController.open` — payload `route`와 DB `app_notifications.route`가 같을 때만 이동, 허용 목록 `sanitizeNotificationRoute` |
| 서버 route 부여 | 구현됨 | 최신 정의 `supabase/migrations/20261103000000_notification_env_alert_humid_cycle.sql` (`/crecam/highlights`, `/home/routines`, `/env-detail`, `/community-player/<uuid>`, 그 외 `/notifications`) |
| iOS 푸시 | **미설정** | `GoogleService-Info.plist`·entitlements·`UIBackgroundModes` 없음, `supported`가 Android 전용, 등록 `p_platform: 'android'` 고정(`push_device_repository.dart:31`) |
| 로컬 알림 탭 | **이동 없음** | 예약 알림 payload `sched:<deviceId>`, 팬 타이머 payload 없음. `_localTap`은 JSON만 처리하고, `onTap` 연결이 FCM 지원 기기에서만 된다(iOS는 연결 안 됨) |
| 직접 배포 APK | `com.vivanaut.app`, 로컬 키 서명 | `docs/ops/google-play-account.md` — Play 앱 서명 키를 이 키로 올리기·덮어쓰기 검증은 **대기** |

## 1. 유저 체험 시뮬레이션

**A. 강제 업데이트** — 운영자가 `min_build`를 530으로 올림. **이 기능이 들어간 빌드(예: 525) 이상** 사용자가 앱을 연다 → 스플래시가 끝나면 "업데이트가 필요해요" 화면(`/update-required`)으로만 간다. 뒤로가기는 앱을 닫을 뿐 다른 화면이 나오지 않는다. [업데이트] → 스토어. [다시 확인] → 표를 다시 읽어 풀렸으면 원래 흐름(홈·로그인)으로.
- 이 기능이 없는 옛 빌드(현재 고객 APK 0.174.8 등)에는 아무것도 안 뜬다. 그 사용자는 이 기능이 든 빌드를 한 번은 받아야 한다.

**B. 권장 업데이트** — `latest_build`만 530. 앱을 열면 확인 창 "새 버전이 나왔어요 / 0.179.0 · [나중에] [업데이트]". **[나중에] 버튼을 직접 누른 경우만** 같은 530에 대해 다시 안 뜬다. 바깥 탭·화면 전환으로 닫히면 기록하지 않는다(다음 실행에 다시 뜸). [업데이트]도 기록하지 않는다.

**C. 인터넷 없음·표 조회 실패** — 아무것도 안 뜬다. 이미 강제 화면이면 그대로 둔다(실패로 풀지 않음).

**D. 다시 확인하는 때** — 앱 시작 1회. 복귀(resume)는: 강제 화면이면 **매번**(운영자가 잘못 올린 값을 되돌리면 바로 풀린다), 아니면 마지막 확인에서 6시간 이상 지났을 때.

**E. 예약 시각 알림 탭** — 앱이 열리고(꺼져 있었으면 스플래시·로그인 확인 뒤) **먼저** 홈 선택을 그 사육장으로 바꾼 다음 **기기 예약 설정**(`/home/routines`)을 연다(다른 사육장 예약이 잠깐 보이지 않게). 그 사육장이 내 기기가 아니거나 목록을 못 읽으면 예약 화면이 아니라 **홈**으로 간다(엉뚱한 사육장 예약을 고치지 않게).

**F. 팬 타이머 종료 알림 탭** — 선택을 그 사육장으로 바꾸고 홈. 내 기기가 아니면 선택은 그대로 홈. 앱 업데이트 전에 이미 예약돼 있던 팬 알림은 앱을 열면 재동기화(`FanTimerResyncObserver`)로 새로 걸리며 그때 payload가 붙는다.

**G. 로그아웃 상태에서 알림 탭** — 로그인 화면. 로그인 후 홈 이동이 끝난 뒤(경로가 스플래시·로그인·가입이 아닐 때) 그 알림 화면으로 간다. 다른 계정이면 기기 선택은 무시(내 기기 목록에 없음). 강제 업데이트 중에는 탭을 **보관만** 하고 풀린 뒤 처리한다.

**H. iOS(설정 파일 없음)** — FCM은 지금처럼 꺼짐. 로컬 알림 탭 이동(E·F)은 iOS에서도 되게 한다 — **시뮬레이터로 실제 탭 도착 확인 필수**(미확인 가정). 정식 번들(`com.vivanaut.app`)이 아닌 베타(`com.vivanaut.beta`)는 업데이트 안내를 하지 않는다.

## 2. 설계

### 2.1 업데이트 안내 — 새 feature `lib/features/app_update/`

**DB (운영 Supabase, 새 표)** `supabase/migrations/20261116000000_app_release_policy.sql`
```
app_release_policy(
  platform text primary key check (platform in ('android','ios')),
  min_build int not null default 0,      -- 이보다 작으면 강제
  latest_build int not null default 0,   -- 이보다 작으면 권장
  latest_version text not null default '', -- 표시용 "0.179.0"
  store_url text,                        -- null이면 그 플랫폼은 안내 안 함
  updated_at timestamptz not null default now(),
  check (min_build >= 0 and min_build <= latest_build)
)
RLS on + SELECT 정책 1개(anon·authenticated, using true)
GRANT SELECT ON public.app_release_policy TO anon, authenticated   -- 프로젝트 관례(fcm_notifications.sql:155)
쓰기 정책·권한 없음 → 운영자 SQL 편집기만
시드: android(0,0,'','https://play.google.com/store/apps/details?id=com.vivanaut.app'), ios(0,0,'',null)
```
- 시드 0 → 적용해도 아무에게도 안 뜬다.
- 로그인 전에도 강제가 걸려야 해서 anon 읽기(비밀 정보 없음).
- 적용 후 확인: anon으로 SELECT 2행, INSERT·UPDATE 거부, check 위반 거부.

**비교 기준 = 빌드 번호(정수)** — `package_info_plus` `buildNumber`. 숫자로 못 읽으면 안내 없음. 직접 배포 APK의 versionCode가 pubspec build와 같은지(`--split-per-abi` 가산 여부) 구현 중 `aapt`로 확인.
**적용 대상** — Android는 패키지 `com.vivanaut.app`, iOS도 `com.vivanaut.app`일 때만(베타 번들 제외).

**파일**
| 파일 | 역할 |
|---|---|
| `domain/update_policy.dart` | `UpdatePolicy.fromJson` + `decideUpdate(currentBuild, policy, dismissedBuild) → none / recommended / required` 순수 함수 |
| `data/app_release_policy_repository.dart` | Supabase `maybeSingle`, 5초 timeout, 실패 null |
| `data/update_dismissal_store.dart` | Hive `app_settings/update_dismissed_build`(기기 단위 — 로그아웃 때 안 지움) |
| `presentation/app_update_providers.dart` | `appUpdateProvider`(StateNotifier: 상태 `none/recommended/required` + `check()`·마지막 확인 시각, §1-D 규칙). 실패는 이전 상태 유지 |
| `presentation/app_update_gate.dart` | `app.dart` builder에서 감싸는 위젯 — 첫 비-스플래시 경로에서 확인, `onResume` 규칙, recommended면 루트 Navigator로 권장 창 1회. required로 바뀌면 열린 권장 창을 닫는다 |
| `presentation/update_required_screen.dart` | `/update-required` 화면(Figma 밖 — 기존 토큰·`ManagementButton` 류, 문구 ko.json). [업데이트]·[다시 확인]. 스토어 열기 실패 시 한 줄 안내 |
| `core/router/app_router.dart` | **redirect**: required면 모든 경로 → `/update-required`(스플래시 제외), 아니면 `/update-required` → `/splash` 흐름 복귀. `refreshListenable`에 업데이트 상태 연결. `kPublicPaths`에 추가 |
| `shared/widgets/viva_modal.dart` | 취소 버튼을 눌렀는지 구분하는 반환(예: `showVivaModalChoice` → `confirm / cancel / dismissed`). 기존 `showVivaModal`은 그대로(호출처 무변경) |

- 강제 화면을 builder 덮개가 아니라 **라우트**로 둔 이유(검수 공통 지적): builder는 Navigator 바깥이라 뒤로가기가 덮개 아래 화면을 몰래 닫고, 포커스·TalkBack도 새어 나간다. 라우트면 redirect가 푸시 탭 이동·딥링크까지 막고, 뒤로가기는 앱 종료뿐.
- 문구: `latest_version`이 비면 버전 없이 "새 버전이 나왔어요".

### 2.2 로컬 알림 탭 이동

| 파일 | 변경 |
|---|---|
| `notification/domain/local_notification_target.dart` (신규) | `parseLocalNotificationPayload(String)` — `sched:<uuid>` → (예약, id), `fan:<uuid>` → (홈, id), JSON → 기존 FCM 경로, 그 외 null |
| `notification/domain/notification_open_target.dart` | `selectNotificationDevice`를 기기 id를 받는 함수로 일반화(기존 2곳은 `item.targetDeviceId`로 호출), **선택했는지(bool) 반환** — 예약은 false면 홈으로 |
| `shared/services/fan_timer_notification_service.dart` | 두 `zonedSchedule`에 `payload: 'fan:<deviceId>'` |
| `notification/presentation/push_lifecycle_observer.dart` | `onTap`·`deliverInitialTap()`을 FCM 지원 여부와 분리. 로컬 탭은 보관 → (로그인 사용자 있음 + 경로가 splash/login/signup/update-required 아님)일 때 처리. 처리 시 계정 id를 잡아 두고 기기 목록 조회 뒤 계정이 바뀌었으면 버림. 순서: 선택(최대 5초) → 이동 |

### 2.3 iOS 푸시 코드 준비 (설정 파일만 넣으면 켜지게)

| 파일 | 변경 |
|---|---|
| `push_messaging_service.dart` | `initialize`·`supported`를 Android+iOS로(iOS는 `Firebase.apps` 비어 있으면 꺼짐). iOS `getToken` 전 `getAPNSToken()`을 짧게 재시도(최대 3회), 없으면 null → 다음 동기화(복귀·토큰 갱신)에 재시도 |
| `push_device_repository.dart` | `p_platform`을 실행 플랫폼으로(`android`/`ios`) — 테스트 추가 |
| entitlements·`UIBackgroundModes` | **넣지 않는다**(Push 권한 없는 App ID로 자동 서명하면 TestFlight 빌드가 깨질 수 있음) → 체크리스트 |
| `docs/handoffs/2026-11-16-ios-push-setup-checklist.md` | Firebase 콘솔 iOS 앱·plist(번들별, testflight.sh 처리)·APNs 키·Xcode 기능 2개·서버 apns 블록(소리·배지 필요 시)·앱 사용 중 표시(`showRemote`에 Darwin 설정) 확인 |
- **먼저 확인(프로토타입)**: iOS 시뮬레이터에서 plist 없이 `Firebase.initializeApp()` 크래시 없음. 크래시면 Info.plist 플래그가 있을 때만 초기화로 바꾼다.

### 2.4 운영 문서 `docs/ops/app-update-policy.md`
1. **Play 서명 유지 검증(기존 APK 위 Play 업데이트 덮어쓰기) 완료 전에는 Android `min_build`를 올리지 않는다** — 서명이 다르면 업데이트가 설치되지 않아 사용자가 강제 화면에 갇힌다.
2. 스토어 심사 통과·배포 완료 확인 후 `latest_build`.
3. `min_build`는 스토어에 있는 빌드 이하로만. 잘못 올렸으면 값을 되돌리면 강제 화면 사용자는 [다시 확인]·복귀 즉시 풀린다.
4. iOS `store_url`은 App Store ID가 나온 뒤.
5. 직접 배포 APK 사용자는 이 기능이 든 빌드를 한 번 받아야 안내를 받는다.

## 3. 가정

| 가정 | 상태 |
|---|---|
| 스토어 빌드 번호 = pubspec build | Android 일반 빌드·testflight 확인. 직접 배포 APK의 split-per-abi 여부 **미확인** → aapt 확인 |
| iOS plist 없을 때 초기화가 Dart 예외로 끝남 | **미확인** → 시뮬레이터 |
| iOS에서 firebase_messaging과 함께 로컬 알림 탭 콜백 도착 | **미확인** → 시뮬레이터(실행 중·종료 상태) |
| `/home/routines`가 홈 선택 사육장 기준 | 확인(`routine_settings_screen.dart:653,680`) |
| 운영 DB 적용 방법 | `db push` 금지 → Supabase MCP `apply_migration`, **적용 직전 사용자 확인** |

## 4. 실패 시나리오
1. 배포 전에 `latest_build`를 올림 → 스토어에 새 버전 없음. 대응: 운영 순서, 시드 0.
2. `min_build`를 잘못 높게 → 전원 차단. 대응: 값만 되돌리면 [다시 확인]·복귀 즉시 해제(§1-D), check 제약.
3. 서명 검증 전 강제 → 직접 APK 사용자 갇힘. 대응: 운영 문서 1번.
4. 조회 실패 시 차단 → 오프라인 사용자 사용 불가. 대응: 실패 = 상태 유지/안내 없음.
5. 화면 전환으로 권장 창이 닫혀 "나중에"로 오기록 → 버튼 직접 탭만 기록.
6. 계정 전환 중 기기 목록 응답이 늦게 와 남의 선택을 덮음 → 계정 id 재확인 후 버림.
7. iOS Firebase native 크래시 → 시뮬레이터 확인 단계에서 잡고 플래그 방식.

## 5. 검증 방법 (구현 전 확정)
- 단위: `decideUpdate` 표(현재<min / min≤현재<latest / dismissed=latest / store_url null / 현재≥latest / 정책 null / 빌드 파싱 실패), 번들 제외, §1-D 재확인 규칙(fake clock), 조회 실패 시 상태 유지, `parseLocalNotificationPayload`, 일반화한 `selectNotificationDevice`(선택 여부 반환·timeout·계정 변경), `p_platform`.
- 라우터: required면 `/home`·`/home/routines`·`/community-player/…` 이동이 `/update-required`로, 풀리면 원래 흐름.
- 위젯: 권장 창 [나중에]만 기록·바깥 탭은 미기록, [업데이트]가 launcher 호출(주입), required 전환 시 권장 창 닫힘.
- 관찰자: FCM 미지원에서도 로컬 탭 처리, 로그인 전 보관 → 홈 이동 뒤 처리, 예약 탭 = 선택 후 이동, 남의 기기 = 홈, 강제 중 보관.
- DB: 적용 후 anon SELECT·쓰기 거부·check 확인.
- 기존: `test/features/notification/**`, `flutter analyze` 0, `flutter test` 전체.
- 실행: iOS 시뮬레이터(plist 없음 무크래시, 로컬 예약·팬 알림 탭 → 해당 화면, 실행 중·종료 상태), Android 디버그 빌드, 강제·권장 화면 캡처는 디버그 provider override로(운영 표 값은 시험용으로 올리지 않는다).
- 사용자만 확인 가능: 실제 스토어 페이지 열림, iOS 실푸시(체크리스트 후), Android 실기기 알림 탭(종료·백그라운드 상태).

## 6. 사용자가 정할 것
1. 계획 승인.
2. 운영 DB에 `app_release_policy` 표 생성(시드 0 — 아무에게도 안 뜸) 적용 승인.
3. 오프라인이면 강제 기준을 피할 수 있음 — **캐시하지 않는 것을 추천**(오프라인이면 어차피 업데이트를 못 받고, 캐시하면 잘못 올린 값이 오프라인 사용자에게 계속 남는다).
