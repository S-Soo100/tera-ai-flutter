# 2026-09-24 수정 요청 3건 — 현황 파악·기획

> 사용자 요청(2026-09-24): ① 사육장+카메라 동시 등록에서 "카메라 · 연결 실패"가 떴는데 뒤로 가면 카메라가 연결돼 있음 ② 영상은 "움직임이 처음 감지된 곳부터"가 아니라 처음부터 재생 ③ 북마크 추가 시 "커뮤니티에 추가할까요?" → 바로 그 영상으로 글쓰기.
> 상태: **기획 단계. 구현 전 사용자 합의 필요.**

---

## 1. 카메라 "연결 실패" 오표시 (사육장은 등록 완료)

### 현황 (코드 근거)

결과 화면은 `lib/features/my_cage/presentation/device_add_flow_screen.dart` `_results()`(767~887). 카메라 줄이 "연결 실패"가 되는 조건은 `DeviceAddOutcome.wifiFailed` 하나이고, 이것은 어댑터 영수증의 `retrySafe == true`에서만 나온다(`device_add_flow_controller.dart:306~316`).

`lib/features/my_cage/data/device_add_ble_adapter.dart` `provision()`:

| 경로 | 결과 | 화면 |
|---|---|---|
| `CONNECT` 뒤 펌웨어가 `WIFI_FAIL` 회신 | `retrySafe: true` (226) | 연결 실패 |
| `CONNECT` 뒤 **응답 없이 60초 경과·BLE 끊김·기타 예외** | catch: `retrySafe = wifiOnly \|\| !connectSent` (264~269) | **`wifiOnly`면 연결 실패**, 아니면 등록 확인 대기 |
| `WIFI_OK` | 성공 | 등록/연결 완료 |

`wifiOnly`는 **이미 이 계정에 등록된 카메라의 Wi-Fi 변경 경로**(`_existingCamera != null` → `_updateWifi`, controller 269~272)에서 참이다. 이 경로는 영수증이 `wifiConnected == false`면 **무조건 `wifiFailed`**로 분류한다(controller 447~455).

**뒤로가기의 동작:** X·시스템 back·"나중에 하기" 모두 `_home()` → `context.go('/home')`(controller/screen 198~200, 320~340, 400~404). 서버 삭제·unlink는 없다. 즉 뒤로 가서 카메라가 "연결돼 있는" 것은 뒤로가기가 무언가를 고친 게 아니라, **카메라는 실제로 Wi-Fi에 붙었는데 앱이 실패로 판정한 것**이다.

### 원인 가설 (우선순위순)

1. **이미 등록된 카메라 + `WIFI_OK` 유실.** 카메라 펌웨어는 Wi-Fi에 붙으면 재부팅/BLE 종료를 하는데(프로토콜 문서 R6: 재부팅 후 ~20초, 광고 ~3분 유지), `WIFI_OK` notify가 BLE 끊김에 묻히거나 60초 안에 오지 않으면 catch로 빠져 `wifiOnly`라 "연결 실패"가 된다. 실제로는 재부팅 뒤 NVS의 기존 `camera_id`로 접속 → `last_seen_at` 갱신 → 홈에서 온라인.
2. 펌웨어가 첫 시도에서 `WIFI_FAIL`을 주고 **스스로 재시도해 성공**하는 경우. 앱은 `WIFI_FAIL`을 최종으로 믿는다.
3. 신규 등록 경로(`NAME:` 미지원 구 펌웨어)는 "연결 실패"가 아니라 "등록 확인 대기"로 끝나므로 이번 스크린샷과는 다르다.

스크린샷의 "기존 기기와 연결" 버튼·사육장 등록 완료 조합은 1번과 정합한다. 어느 쪽이든 앱은 **BLE 회신만 믿고 서버 상태를 확인하지 않는다**는 것이 공통 결함이다. 다행히 같은 화면에 이미 `_watchReconnect`(`last_seen_at` 5초 폴링 × 90초, controller 465~497)가 있는데, `wifiConnected == true`일 때만 돈다.

### 기획

**원칙:** 카메라 결과는 BLE 회신이 아니라 **서버 `last_seen_at`으로 최종 판정**한다. BLE 회신은 "빨리 알려주는 힌트"로만 쓴다.

**유저 체험 (변경 후)**
- [화면] 사육장 "등록 완료" / 카메라 "**연결 확인 중…**"(shimmer 점) — 실패 버튼 없음, "나중에 하기"만.
- [반응] 최대 90초 안에 `last_seen_at`이 시작 시각 이후로 갱신되면 "연결 완료"로 바뀌고 체크 아이콘·"기존 기기와 연결" 버튼이 나온다.
- [반응] 90초가 지나도 안 붙으면 그때 "연결 실패" + "실패한 기기 다시 연결" 버튼. 펌웨어가 명시적으로 `WIFI_FAIL`을 준 경우도 **바로 실패로 확정하지 않고** 같은 확인을 거친다(가설 2 대응). 단 문구는 "비밀번호를 확인해 주세요" 힌트를 부제에 덧붙인다.
- [감정] "실패했다는데 되네?"라는 불신이 사라진다. 대신 최대 90초 기다림이 생기므로 "카메라가 다시 켜지는 중이에요(최대 1분 30초)" 부제로 이유를 밝힌다.

**적용 범위**
- 기존 카메라 Wi-Fi 변경 경로(`_updateWifi`): `wifiConnected == false`여도 `registeredId`가 있으므로 결과를 `wifiUpdated`+`reconnect: waiting`으로 두고 `_watchReconnect`를 돌린다. `missing`이 되면 `wifiFailed`로 전환(현재 `missing`은 "새 카메라로 등록" 버튼 — 그대로 유지하되 "다시 연결"도 같이 노출).
- 신규 등록 경로는 `hardwareId`가 없으면 `last_seen_at`을 볼 행이 없어 이번 범위 밖(구 펌웨어 `NAME:` 미지원 문제, 펌웨어 요청서 §2-3에 이미 있음).
- 사육장은 `devices` 행 확인 로직이 이미 있어 변경 없음.

**구현 파일 (예상 3개 + 테스트)**
- `device_add_flow_controller.dart` `_updateWifi`(447~455) — 실패 영수증도 waiting으로.
- `domain/device_add_flow.dart` — `CameraReconnect` 상태에 "실패 뒤 확인 중"을 구분할 필드(또는 `DeviceAddResult.bleHint`)를 추가해 문구 분기.
- `device_add_flow_screen.dart` `_result()`(978~993) — "연결 확인 중…" shimmer 줄, 90초 만료 뒤 실패 문구.
- ko.json: `device_add_camera_checking`, `device_add_camera_checking_hint`.
- 테스트: `device_add_flow_test.dart`에 "Wi-Fi 변경 실패 영수증 → last_seen 갱신 → wifiUpdated/online", "90초 만료 → wifiFailed" 2건. `device_add_flow_screen_test.dart`에 혼합 결과(사육장 등록·카메라 확인 중) 화면 1건.
- 진단: `[device-add]` 로그에 이미 `CONNECT -> …`/`ended: …`가 있으므로 실기기 재현 시 어느 가설인지 바로 갈린다. **구현 전에 S21+로 한 번 재현해 로그를 잡는 것을 권장**(가설 확정용, 10분).

**트랙:** Standard (기존 feature 수정, 3파일, 되돌리기 30분 내). 진단 먼저.

---

## 2. 영상 재생 시작 위치 — 처음부터

### 현황

- "움직임 직전부터" 재생은 **하이라이트 경로에서만** 일어난다. 서버(petcam-api)가 GME(게코 움직임 측정, `gme-motion-v1`) 결과로 `play_from_sec = max(0, first_moving_sec − 1.5)`를 내려주고, 앱은 첫 재생 전에 한 번 `seekTo` 한다(`lib/features/my_cage/domain/clip_playback.dart:12~17` `initialClipSeek`, `clip_playlist_player_screen.dart:316~332`, `motion_clip_player_screen.dart:131~145`). 도입 커밋 `e93da88`(2026-09-12). 기획 문서·사용자 결정 기록은 없다(계약을 그대로 받아 쓴 것).
- 값을 넘기는 곳: `highlights_screen.dart:479~502`(하이라이트 목록), `nightly_report_view.dart:225~227`(어젯밤 리포트 카드). **카메라 탭 그리드는 이미 0초부터** 재생한다(`clip_feed_slivers.dart:103`).
- "처음부터" 버튼(`crecam_player_from_start`, player 1072)은 중간 시작일 때만 보인다.
- **GME 감지 품질은 앱이 손댈 수 없다.** 이미 기록된 문제: 운영 GME 기준이 9/14에 멈춤(`docs/handoffs/2026-09-19-petcam-lab-highlight-policy-v2-request.md:6~15`), 9/17 밤 67클립 중 3개만 움직임 감지(`specs/2026-09-19-highlight-policy-v2-design.md:84~93`). 사용자의 "GME가 못 잡는다"는 체감과 일치한다.

### 기획

**결정 제안:** `play_from_sec`을 **앱에서 쓰지 않는다.** 하이라이트·리포트에서도 0초부터 재생. GME가 못 잡는 상태에서 잘못된 시작점으로 건너뛰면 "움직임을 놓친" 것처럼 보이는 것이 더 나쁘다.

**두 가지 수준 중 택일:**
- **A. 완전 제거(권장)** — `initialClipSeek`·`ClipPlaylistArgs.playFromSec`·`NightlyHighlight.playFromSec` 파싱·"처음부터" 버튼·관련 테스트 6개 파일 제거. 코드가 깨끗해지지만 GME가 정상화돼도 되돌리려면 커밋을 되살려야 한다.
- **B. 스위치로 끄기** — `highlights_screen.dart:499~502`·`nightly_report_view.dart:227`에서 값을 넘기지 않기만 한다(2줄). 로직·테스트는 남고 "처음부터" 버튼은 저절로 안 보인다. GME 회복 시 2줄로 복귀.

GME 상태가 서버 쪽에서 미해결이므로 **B를 권장**한다. `play_from_sec` 자체는 계약에 남으니 서버 쪽 변경 요청은 없다. petcam-lab에는 별도로 "GME 감지율 저하(9/17 67클립 중 3건)" 확인 요청만 붙인다(이미 9/19 요청서에 있음 — 회신 여부 확인).

**트랙:** Trivial(B) / Standard(A).

---

## 3. 북마크 저장 → "커뮤니티에 공유할까요?"

### 현황

- 북마크 추가는 `toggleClipBookmark`(`widgets/clip_memo_editor.dart:19~50`): 메모 다이얼로그 → `BookmarkController.setDesired(true)` → 저장 확정 시 토스트 `clip_bookmark_saved_toast`("북마크에 저장되었습니다"). 호출처는 세로 플레이어(`clip_playlist_player_screen.dart:551~553`)와 어젯밤 리포트 `FavoriteToggleButton`(`nightly_report_view.dart:266`). 구 플레이어(`motion_clip_player_screen.dart:224~250`)는 별도 경로·스낵바.
- 커뮤니티 글쓰기는 `/community-share`(북마크 목록에서 고르는 `ClipSelectScreen`) → `/community-share/caption`(`extra: ComposeDraft(FavoriteClip)`) → `ComposeScreen._publish`(`compose_screen.dart:137~180`). **북마크된 클립만 공유 가능**이 원칙(`docs/plans/2026-08-29-community-clip-feed.md:5`). 진입점은 커뮤니티 탭 FAB 하나(`community_screen.dart:137`).
- 카메라 탭·플레이어에서 커뮤니티로 가는 진입점은 없다. 기획서(Figma 확정안)에도 북마크↔커뮤니티 연계 언급은 없다 → **사용자 신규 결정 사항**.
- `community_share_no_favorites` 문구가 "★을 눌러보세요"로 옛 아이콘 기준(북마크 아이콘으로 바뀜) — 같이 고칠 것.

### 기획

**유저 체험**
- [조작] 플레이어에서 북마크 탭 → 메모 입력(기존) → 저장.
- [화면] 저장이 **실제로 끝난 뒤**(토스트 시점) 바텀 모달(`showVivaModal`): 제목 "커뮤니티에도 공유할까요?", 부제 "북마크한 영상으로 바로 글을 쓸 수 있어요", 버튼 [공유하기] / [나중에].
- [반응] 공유하기 → `context.push('/community-share/caption', extra: ComposeDraft(fav))` — 클립 선택 단계를 건너뛰고 바로 캡션 화면. 게시 후엔 기존대로 `/community`로 이동(플레이어는 스택에서 사라짐 — `go`이므로 확인 필요, 아래 결정 ③).
- [반응] 나중에 → 아무 일 없음(토스트만). 북마크 해제 시에는 묻지 않는다.
- [감정] "저장했는데 커뮤니티에 올리려면 또 탭을 옮겨야 하네"가 사라진다. 매번 묻는 게 귀찮을 수 있어 **"다시 묻지 않기" 체크**를 둘지가 결정 사항.

**구현 파일 (예상)**
- `widgets/clip_memo_editor.dart` `toggleClipBookmark` 47~49: 토스트 뒤 `showShareToCommunityPrompt(context, ref, clipId)` 호출. `FavoriteClip`은 `favoriteClipRepositoryProvider.listAll()`(또는 id 조회)에서 가져온다.
- 신규 `lib/features/community/presentation/widgets/share_after_bookmark_prompt.dart` — 모달 + 라우팅.
- `motion_clip_player_screen.dart` 구 경로도 같은 프롬프트로 통일(또는 이 경로를 `toggleClipBookmark`로 합치기 — 중복 제거).
- ko.json: `community_share_after_bookmark_title/body/confirm/later`, `community_share_no_favorites` 문구 정정.
- Hive `app_settings/share_prompt_dismissed`(체크 채택 시).
- 테스트: `clip_memo_controller_test.dart` 옆에 프롬프트 표시/라우팅 위젯 테스트 1~2건.

**결정 필요 ①** "다시 묻지 않기" 체크 — 둔다(권장, 매번 뜨면 피로) / 안 둔다.
**결정 필요 ②** 진입 형태 — 바텀 모달(권장, 결정이 명확) / 토스트에 "공유" 액션 버튼(가벼우나 3초 안에 눌러야 함).
**결정 필요 ③** 게시 후 복귀 — 현재 `go('/community')`(플레이어로 못 돌아옴) 유지 / 게시 후 `pop`으로 플레이어 복귀.

**트랙:** Standard (기존 두 feature 연결, 3~4파일).

---

## 진행 순서 제안

1. **2-B**(2줄, 즉시) → 2. **1**(S21+ 재현 로그 10분 → 구현) → 3. **3**(결정 ①~③ 확정 후).
각 건은 별도 worktree(`tools/worktree.sh new fix/…`)·별도 버전으로 병합한다.
