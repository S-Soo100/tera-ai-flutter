# 카메라 네트워크 신호 약함 안내 (`camera.weak_signal`) — 앱 기획

> 상태: 📝 **기획 — 사용자 결정 대기** (2026-11-14). 구현 없음.
> 원문: terra-server `docs/APP_CAMERA_WEAK_SIGNAL_2026-11-13.md` (서버 구현 완료·스위치 꺼짐), 서버 계획 `specs/stage-v-camera-weak-signal-notice.md`.
> Figma: Home 프레임 라이브 위 막대 "네트워크 신호가 약하니 점검해 주세요 / 더보기"(사용자 공유 캡처). 카메라 탭은 같은 자리에 초점 안내.
> 선례: 초점 안내 카메라 단위 `2026-11-11-camera-focus-notice-per-camera-design.md`.
> CAOF 트랙: **Standard** — 기존 초점 안내 막대·알림 저장소 확장(신규 feature 아님). 되돌리기 < 1시간.

## 1. 한 줄 요약

서버가 넣는 `camera.weak_signal` 미읽음 행을 초점 안내와 **같은 막대 자리**에 그 카메라에만 띄우고, 서버가 `read_at`을 채우면 저절로 내린다. 이 종류는 **알림함 목록·배지·"모두 읽음"에서 뺀다.**

## 2. 현재 구조 (확인)

| 항목 | 위치 | 비고 |
|---|---|---|
| 막대 위젯 | `my_cage/presentation/widgets/focus_notice_snack_bar.dart` | 홈 `TopFixedArea:60`·카메라 탭 `CameraLiveArea:285` 두 곳, 영상 보일 때만(`phase.hasVideo`) |
| 미읽음 구독 | `focus_notice_providers.dart` → `watchUnreadOfKind(userId, kind)` | Realtime stream `eq('kind')` 후 앱에서 `read_at == null` 거름 → **서버가 `read_at`을 채우면 UPDATE 이벤트로 목록에서 빠져 막대가 내려간다(구조상)** |
| 알림함 목록 | `NotificationRepository.watchNotifications` | kind 필터 없음 — 전부 보임, 미읽음 배지(`unreadNotificationCountProvider`)도 같은 목록 |
| 모두 읽음 | `SupabaseNotificationStore.markAllRead` | 사용자 미읽음 **전부** 읽음 → 지금도 초점 안내 막대까지 내린다 |
| 모르는 kind | `AppNotification.fromJson` | `category='other'`, `safeRoute='/notifications'` |
| 기존 Wi-Fi 약함 화면 안내 | `WeakWifiBannerView` (기기 상세 `/devices/camera/:id` 하나뿐) | `rssi ≤ −75` 서로 다른 heartbeat 4번 연속(≈1분), 닫기 전까지 유지, 로컬 판정 |

## 3. 유저 체험 시뮬레이션

1. 카메라가 공유기에서 멀어 10분 넘게 신호가 약하다(서버 판정).
2. 홈이나 카메라 탭에서 그 카메라 라이브가 보이면, 영상 위 막대에 **"네트워크 신호가 약하니 점검해 주세요 · 더보기"**. 다른 카메라 페이지로 넘기면 안 보인다. 푸시·알림함·배지에는 아무것도 없다.
3. 같은 카메라에 초점 안내도 있으면 막대는 **하나만**(우선순위 결정 D3). 앞의 것이 사라지면 다음 것이 그 자리에 뜬다.
4. 막대를 누르면 → 이동(결정 D2) + 이 카메라의 신호 안내 읽음 → 막대 사라짐. 서버는 **처음 뜬 시각부터 24시간** 동안 다시 넣지 않는다.
5. 누르지 않고 카메라를 공유기 쪽으로 옮겨 −70 이상이 되면 몇 초 안에 막대가 저절로 사라진다.
6. 알림함에서 "모두 읽음"을 눌러도 막대는 그대로다.

## 4. 설계

### 4.1 도메인 (`notification/domain/app_notification.dart`)
- `const cameraWeakSignalNotificationKind = 'camera.weak_signal';` 를 `knownNotificationKinds`에 추가.
- `const liveBarNotificationKinds = {cameraFocusNotificationKind, cameraWeakSignalNotificationKind};` — 막대 전용 종류.
- `const inboxHiddenNotificationKinds = {cameraWeakSignalNotificationKind};` — 알림함·배지·모두 읽음 제외(초점 안내 포함 여부는 D4).
- 카메라 지정: 지금 `focusCameraRefs`는 kind를 초점으로 고정 → `cameraRefs`로 일반화(두 kind 모두 `data.camera_id`/`device_id`). 서버 신호 안내는 `camera_id = cameras.id(uuid)`만 넣는다.

### 4.2 저장소
- `watchNotifications`: `inboxHiddenNotificationKinds` 행을 거른다 → 목록·미읽음 배지에서 빠짐.
- `markAllRead`: `.not('kind', 'in', inboxHidden)` 조건 추가 → "모두 읽음"이 막대를 내리지 않음.
- `watchUnreadOfKind` 그대로 재사용(종류마다 stream 1개, 계정당 행 적음).

### 4.3 provider (`focus_notice_providers.dart` → 종류 family로 일반화)
- `liveNoticesProvider.family(kind)` / `liveNoticeIdsByRefProvider.family(kind)` / `liveNoticeDismissedProvider`(키 = id라 종류 공용).
- `liveNoticeForCameraProvider.family(camera) → kind?` — 우선순위(D3)대로 보여 줄 종류 하나, 없으면 null.
- `dismissLiveNotices(ref, camera, kind)` — 지금 `dismissFocusNotices` 로직 그대로, 종류만 인자.
- 기존 이름(`focusNotice*`)은 테스트가 물고 있으니 이름 변경은 같은 커밋에서 테스트까지 함께(또는 typedef 별칭 없이 일괄 교체).

### 4.4 위젯
- `FocusNoticeSnackBar` → `LiveNoticeBar`(파일명 `live_notice_bar.dart`). 막대 모양·자리·`hasVideo` 조건은 그대로, 문구 키와 탭 동작만 종류별.
- 문구는 **앱 l10n 키**로 그린다(행의 `title`을 그리지 않음 — 초점 안내와 같은 방식, 서버 문구 오타·구 행에 영향 안 받음):
  - `camera_weak_signal_notice`: "네트워크 신호가 약하니 점검해 주세요"
  - 버튼은 기존 `camera_focus_notice_more`("더보기") 재사용 → 공용 키 `live_notice_more`로 옮김.
- 기기 상세의 `WeakWifiBannerView`는 손대지 않는다(D1 추천안 기준).

### 4.5 알림함 진입
- 알림함에서 빠지므로 `notification_center_screen`의 열기 분기는 추가하지 않는다. 다만 구 앱이 남긴 행·누락 대비로 이 종류를 열면 해당 카메라 상세로 가는 분기를 넣을지 → 넣지 않는다(목록에 안 나오므로 도달 불가).

## 5. 선택지와 추천 — **사용자가 정할 것**

| # | 결정 | 선택지 | 추천 |
|---|---|---|---|
| **D1** | 기존 기기 상세 Wi-Fi 약함 배너(앱 1분 판정)와의 관계 (서버 질문 2) | A. 둘 다 유지 / B. 기기 상세 배너 제거, 서버 막대로 일원화 | **A** — 자리가 다르다(상세 페이지 vs 라이브 위 막대)라 화면에서 겹치지 않음. 상세 배너는 "지금 약함"(설치 위치 조정할 때 즉시 확인용), 막대는 "10분 넘게 약함" 알림이라 역할이 다름 |
| **D2** | 막대 "더보기" 누르면 어디로 | A. 그 카메라 **기기 상세**(`/devices/camera/:id` — Wi-Fi 약함 배너·[Wi-Fi 바꾸기]·재시작이 있는 곳) / B. 초점 안내와 같은 세로 확대 라이브 / C. 설명 시트(서버 `body` 문구 + [Wi-Fi 바꾸기]) | **A** — 사용자가 할 일(위치 확인·Wi-Fi 바꾸기·재시작)이 다 거기 있다. C는 Figma에 없는 화면이라 디자인 확인 필요 |
| **D3** | 같은 카메라에 초점·신호 안내가 동시에 미읽음일 때 (서버 질문 6) | A. **신호 먼저** / B. 초점 먼저 / C. 두 줄 쌓기 | **A** — 신호 약함은 지금 상태이고 회복하면 저절로 사라져 뒤의 초점 안내가 이어 뜬다. 초점 안내는 1회성이라 늦게 봐도 손해가 적고, 신호가 약하면 영상 품질 탓에 초점 판단도 흐려진다. C는 영상을 너무 가림 |
| **D4** | 초점 안내도 알림함에서 뺄까 | A. 신호만 뺀다(이번 범위) / B. 초점도 뺀다 | **A** — 초점 안내 알림함 진입은 11-11에 일부러 만든 동작. 단 "모두 읽음"이 초점 막대를 내리는 지금 동작은 그대로 둘지 같이 정해야 함 → 추천: 그대로 둠(범위 밖) |
| **D5** | `body` 문구 (서버 질문 4) | 서버안 유지 / 변경 | **서버안 유지** — 막대는 `title`도 안 쓰고 앱 l10n으로 그린다. `body`는 구 앱 알림함에서만 보이므로 서버안("공유기와 카메라 사이 거리나 장애물을 확인해 주세요")으로 충분 |

## 6. 가정

- 확인:
  - Realtime stream은 UPDATE 이벤트로 행을 갱신하고 앱이 `read_at`을 다시 거른다(`watchUnreadOfKind`) → 서버 읽음 처리로 막대가 내려간다(구조).
  - 막대는 영상이 보일 때만 그린다 → 신호가 너무 약해 라이브가 실패 화면이면 막대도 안 보인다(실패 화면 자체가 안내를 함).
  - 모르는 kind는 알림함에 `category='other'`로 보이고 라우트는 `/notifications`(구 앱 질문 5 = 맞음, 미읽음 배지에도 1 잡힘).
- 미확인:
  - 서버가 `read_at`을 채웠을 때 실기기 막대가 실제로 내려가는지 → 검증 3.
  - 구 앱(0.177.4 이하)에서 신호 안내가 알림함·배지에 쌓이는 정도 — 24시간 1회·회복 시 서버 읽음이라 배지는 회복되면 꺼짐.

## 7. 실패 시나리오

| 상황 | 결과 | 대응 |
|---|---|---|
| 앱 업데이트 전 서버 켬 | 구 앱 알림함에 "일반 알림" + 배지 | **앱 배포(스토어·APK·TestFlight) 뒤 서버 켜기**를 서버에 요청 |
| 신호 약해서 라이브가 실패 화면 | 막대 안 보임 | 의도된 동작(실패 화면 문구가 대신). 서버에 알림 |
| `data.camera_id` 누락 행 | 어느 카메라에도 안 뜸, 알림함에서도 빠짐 → 사실상 안 보임 | 서버 계약상 항상 넣음. 디버그 로그로 확인 |
| 읽음 저장 실패 | 숨김 해제돼 막대 다시 보임 | 기존 `dismissFocusNotices`와 동일 |
| 계정 전환 | 숨김 집합 초기화 | 기존 3층 격리 그대로 |
| 신호 + 초점 동시 | 하나만(D3) | 우선순위 테스트 |

## 8. 검증 방법

1. `flutter test test/features/notification/ test/features/my_cage/focus_notice_snack_bar_test.dart`(이름 변경 시 새 파일) — 추가 테스트:
   - 신호 안내는 그 카메라(uuid)에만, 다른 카메라 없음
   - 둘 다 미읽음이면 D3 순서, 앞의 것이 읽음되면 다음 것
   - `read_at`이 채워진 행이 stream에 오면 막대 사라짐
   - `watchNotifications`·미읽음 배지에서 신호 안내 제외
   - `markAllRead`가 신호 안내 kind를 제외하는 쿼리를 보냄
2. `flutter analyze` 0, `test/design/text_scale_overflow_test.dart` 통과(문구가 초점 안내보다 김 — 1.3배·상한에서 2줄 말줄임 확인).
3. 서버 협업 확인(서버 문서 §4-2): 테스트 계정 카메라에 행 1건 수동 INSERT → 그 카메라만 막대 → `read_at` UPDATE → 막대 내려감. **사용자만 확인 가능(실기기 화면)** — 넣을 계정·카메라는 사용자가 지정.
4. 수치 검수: Figma Home 막대 vs 앱 캡처(글자 16/28, 좌우 12, 막대 높이) — 초점 막대와 같은 컴포넌트라 문구 길이 차이만 확인.

## 9. 서버 회신 초안 (결정 확정 뒤 보냄)

1. 알림함 노출 → 앱이 이 kind를 알림함 목록·미읽음 배지·"모두 읽음"에서 뺍니다(0.178.0 예정). 서버 쪽 변경 없음.
2. 기존 화면 안내 → 겹치지 않습니다. 기존 1분 안내는 카메라 **기기 상세** 화면에만 있고, 새 막대는 홈·카메라 탭 라이브 위입니다. 둘 다 둡니다. (D1)
3. 서버 읽음 → 구조상 내려갑니다(미읽음 kind stream 구독, UPDATE 반영). 테스트 계정·카메라는 따로 알려 드리겠습니다.
4. `body`·`route` → 막대는 앱 문구로 그려 `title`·`body`를 쓰지 않습니다. `body`는 제안안 그대로 좋습니다. `route` `/crecam` 그대로.
5. 구버전 → 맞습니다. 알림함에 "일반 알림"으로 보이고 미읽음 배지에도 잡힙니다. **앱 새 버전이 배포된 뒤 켜 주세요.**
6. 우선순위 → 신호 안내를 먼저, 사라지면 초점 안내를 띄웁니다. (D3)
- 추가: 신호가 너무 약해 라이브가 실패 화면이면 막대는 보이지 않습니다(영상이 보일 때만 그림).

## 10. 구현 범위 (승인 후)

- 수정: `app_notification.dart`, `notification_repository.dart`, `focus_notice_providers.dart`(→ 일반화), `focus_notice_snack_bar.dart`(→ `LiveNoticeBar`), `top_fixed_area.dart`, `camera_live_area.dart`, `assets/l10n/ko.json`, 관련 테스트 3개, `CHANGELOG.md`, `pubspec.yaml`(feat → 0.178.0).
- 안 건드림: `WeakWifiBannerView`·`sys_health*`, 알림함 열기 분기, 푸시 처리, 서버.
