# 플레이어·북마크·하이라이트 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 세로 기본 확대보기와 Figma 조작계, 무토스트 북마크, 실제 재생 시작 기준의 하이라이트 읽음을 구현한다.

**Architecture:** 재생 소스/배치 정보를 typed route args로 전달하고 방향 전환은 영상 controller와 분리한다. 북마크와 읽음 저장은 계정에 귀속된 Repository/Provider로 관리해 화면 종료 뒤에도 올바른 상태를 보존한다.

**Tech Stack:** Flutter, Riverpod, GoRouter, video_player, flutter_webrtc, Hive, 기존 favorite/highlight Repository.

**Spec:** [승인 설계 §5·6](2026-09-13-app-design-review.md), [통합 계획](2026-09-14-app-implementation-plan.md).

## Global Constraints

- 통합 계획의 Global Constraints 적용. 세로 기본이며 명시 버튼으로만 가로. 화면 방향과 카메라 `rotate_180` 하드웨어 설정을 혼용하지 않는다.
- 하이라이트 확인은 **실제 재생 시작 시**. `playFromSec` 시크나 `play()` 호출 성공은 실제 재생의 증거가 아니다.
- 북마크 정상 흐름에 저장중/성공/해제 토스트 없음. 실패를 성공으로 숨기지 않는다.
- P3는 G0 공개 배치 계약 확인 뒤 실제 API에 연결한다. 기존 촬영시각 기반 묶음 ID를 새 공개 배치로 위장하지 않는다.

## P1: 세로/가로 레이아웃과 재생 소스

**Files — 생성:** `lib/features/my_cage/domain/clip_playlist_args.dart`, `lib/features/my_cage/presentation/player_view_providers.dart`, `test/features/my_cage/player_orientation_test.dart`. 수정: `lib/features/my_cage/presentation/{camera_live_fullscreen_screen,clip_playlist_player_screen,crecam_screen,highlights_screen,bookmarks_screen}.dart`, `lib/core/router/app_router.dart`, `test/features/my_cage/{clip_playlist_player_screen,clip_playlist_player_seek,crecam_home}_test.dart`. 조작계가 커지면 생성: `lib/features/my_cage/presentation/widgets/clip_player_controls.dart`.

**Interface:** 기존 `ClipPlaylistArgs`를 domain으로 이동한다. 기존 `playlist`/`playFromSec`와 생성자 기본값을 유지하고 `ClipPlaybackSource { hour, highlight, bookmark, single }`, `source`, `cameraId?`, `hourStart?`, `hourEndExclusive?`, `highlightBatchId?`를 추가한다. GoRouter는 기존 List<String> extra도 계속 읽는다. 하이라이트 배치 정보는 P3에서만 채운다.

- [ ] 기존 가짜 video platform을 활용해 SystemChrome 채널 호출·controller create/dispose 횟수·clipId/position/speed/paused를 기록한다. 방향 테스트는 다음 순서를 검증한다.

```text
진입 → portraitUp, 기기만 회전 → 가로 요청 없음
가로 버튼 → landscapeLeft/right 허용, controller 재생성 0회
세로 복귀 → 동일 clip/position/speed/paused
가로에서 닫기·뒤로가기 → portraitUp 및 원래 SystemUiMode 복원
가로 버튼 → 카메라 PATCH rotate_180 호출 0회
```

- [ ] `flutter test test/features/my_cage/player_orientation_test.dart`로 기존 라이브 가로 강제/클립 회전 부재가 실패하는지 확인한다. 가짜 플레이어의 position이 실제 진행하도록 확장하되 재생 테스트에서 pumpAndSettle을 쓰지 않고 유한 시간 pump를 사용한다.
- [ ] 방향을 Riverpod route-scoped 상태로 만들고 진입/전환/종료 시 SystemChrome을 적용한다. dispose 중 늦게 완료된 가로 요청이 다음 화면을 돌리지 않도록 명령 순서/route 생존을 관리한다. live controller family는 기존 세션을 공유한다. iOS/Android의 허용 orientation 설정도 확인한다.
- [ ] Figma `941:1834/1928/2062`의 세로/가로·컨트롤 숨김 상태를 구성한다. 아래 이전/다음, 다운로드→공유→북마크, 썸네일 스트립, 시크 핸들을 적용하고 A1 SVG 매핑을 사용한다. 영상 fit/ratio·safe area를 유지한다. 라이브에 녹화용 시크/배속/목록을 넣지 않는다.
- [ ] 단일 탭=컨트롤 표시 전환, 좌/우 더블 탭=10초 이동, 좌/우 스와이프 및 버튼=이전/다음으로 구현한다. 시크는 0~duration으로 clamp한다. auto-next는 source==highlight에서만 실행하고 일반 시간대/북마크는 종료 상태를 유지한다. 슬라이더/썸네일 스크롤과 제스처 경합을 테스트한다.
- [ ] 시간대에서 진입하면 C1 `listPage`에 해당 hour 범위를 넘겨 나머지 페이지를 이어 조회한다. feed에 로드된 일부 ID만 전체 시간대로 오인하지 않는다. 아직 끝까지 모르는 총 개수를 확정 숫자로 표기하지 않고 hasMore를 반영한다. 빠른 이전/다음 전환에서는 늦게 로드된 이전 controller를 폐기한다.
- [ ] 삭제 아이콘의 진입 문맥을 대조한다. 기존 북마크 해제는 P2 경로로 연결한다. 일반 영상 원본 삭제 계약이 없으면 새 삭제 API를 만들지 않고 차이 보고에 미배선 이유를 명시한다.
- [ ] orientation/playlist/seek/home 테스트와 analyze를 실행한다. 실제 iOS/Android 회전 왕복·백그라운드·live 재연결 횟수를 확인하고 `feat: add portrait-first fullscreen player controls` 커밋.

## P2: 클립별 조용한 북마크 작업

**Files — 생성:** `lib/features/my_cage/presentation/bookmark_controller.dart`, `test/features/my_cage/bookmark_controller_test.dart`, `test/features/my_cage/favorite_clip_owner_test.dart`. 수정: `lib/features/my_cage/data/favorite_clip_repository.dart`, `lib/features/my_cage/presentation/clip_playlist_player_screen.dart`, `lib/features/my_cage/presentation/my_cage_providers.dart`, `assets/l10n/ko.json`.

**Interface:** `bookmarkControllerProvider`는 `(ownerId, clipId)` family. `BookmarkState`는 `desired`, `persisted`, `saving`, `error`를 가진다. controller `setDesired(bool value) → void`, `retry() → void`. 작업 동안 keepAlive로 route 종료와 수명을 분리하고 계정 종료 시 저장 반영을 차단한다.

- [ ] Repository fake의 add/remove를 Completer로 제어해 아래 시나리오를 테스트한다. 상태 변화뿐 아니라 최종 로컬 metadata/파일/서버 호출의 owner를 확인한다.

```text
추가 → 즉시 desired=true, 저장중/성공 SnackBar 0개, 재생 계속
추가 진행 중 해제 → 추가 완료 후 삭제, 최종 persisted=false
추가 진행 중 해제 후 추가 → 최종 persisted=true, 순서 역전 없음
다른 clipId 북마크 → 첫 clipId 작업에 막히지 않음
화면 pop → 같은 owner 작업 완료, 북마크 목록 갱신
저장 실패 → 제한 재시도 후 persisted로 복구, inline retry
다운로드 중 계정 A→B → B 소유 파일/metadata/요청으로 기록하지 않음
```

- [ ] `flutter test test/features/my_cage/bookmark_controller_test.dart test/features/my_cage/favorite_clip_owner_test.dart`에서 실패를 확인한다. fake clock으로 일시 네트워크 실패 2회 재시도(1초, 3초)를 검증하고 인증/권한/없는 원본은 즉시 최종 오류로 처리한다.
- [ ] controller는 desired를 즉시 갱신하고 한 clip 작업을 직렬화한다. 저장 완료마다 desired와 persisted가 다르면 다음 add/remove를 실행한다. 최종 실패는 persisted로 복원하고 조용한 inline 재시도 상태를 노출한다. 공용 `_busy`에서 북마크를 분리하고 다운로드/공유 정책은 유지한다.
- [ ] Repository에서 ownerId를 await 전에 캡처한다. add/remove 모두 metadata 소유권을 검사하고 파일 경로를 owner 기준으로 격리한다. 각 비동기 완료 뒤 세션이 바뀌었으면 임시 파일을 정리하고 새 계정 metadata를 쓰지 않는다. 기존 즐겨찾기 파일은 소유자가 확인된 항목만 이관하고 정상 사용자 저장을 유실시키지 않는다.
- [ ] 기존 cloud best-effort 동기화와 로컬 영구 저장 계약을 대조한다. 로컬 파일 저장 실패와 cloud sync 지연을 구별해 이미 보관한 영상을 임의 삭제하지 않는다. 기존 동기화가 실패 복구를 보장하지 못하면 owner별 재시도 상태를 Repository에 저장하고 계정 재진입 때 동기화한다.
- [ ] 북마크 관련 테스트와 playlist 테스트/analyze를 실행한다. 화면 pop/앱 재시작/계정 변경·느린 다운로드에서 검증하고 `fix: save bookmarks silently with per-clip state` 커밋.

## P3: 공개 배치·NewHighlight·실제 재생 읽음

**Files — 생성:** `lib/features/my_cage/domain/highlight_batch.dart`, `lib/features/my_cage/domain/playback_start_tracker.dart`, `lib/features/my_cage/presentation/highlight_read_providers.dart`, `test/features/my_cage/{highlight_batch,playback_start_tracker,highlight_read_store}_test.dart`. 수정: `lib/features/my_cage/data/{highlight_repository,highlight_banner_store}.dart`, `lib/features/my_cage/presentation/{highlights_screen,highlights_controller,clip_playlist_player_screen,my_cage_providers,crecam_screen}.dart`, `lib/features/my_cage/domain/highlight_group.dart`, `test/features/my_cage/{highlights_screen,highlight_repository,clip_playlist_player_seek}_test.dart`, `assets/l10n/ko.json`.

**Interface:** `HighlightBatch`는 G0의 확정 응답을 파싱해 `id`, `cameraId`, `captureStart`, `captureEnd`, `publishedAt`, `isReady`, `List<NightlyHighlight> clips`를 노출한다. Repository의 공개 배치 조회 메서드 이름은 `listPublishedBatches(String cameraId)`로 두되 URL/직렬화 필드는 G0에서 검증한 실제 계약만 사용한다.

읽음 저장 키는 `(ownerId, cameraId, batchId)`. 기존 store를 확장해 `readAt`과 `dismissedAt`을 각각 저장/조회한다. 레거시 owner-only 최신촬영시각 dismiss 값은 특정 배치의 readAt으로 자동 이관하지 않는다.

- [ ] 계약 fixture로 ready+클립 있음만 도착 대상, ready 지연/빈 밤은 카드 없음, 동일 batch의 대표 교체는 기존 read 유지, 다른 camera/owner 격리를 테스트한다. 재생 읽음 추적기에 아래 동작 테스트를 먼저 추가한다.

```text
initialized=true, position=18초(playFromSec 시크), playing=false → unread
play() 호출 완료, position=18초 고정/buffering → unread
playing=true, buffering=false, seeking=false, position 18→18.1초 → read 1회
명시 시크 18→28초만 이동 → unread, 이후 자연 재생 진행 때 read
뒤로가기 전 로드 실패 → unread
같은 묶음의 다른 대표 영상 실제 재생 → 같은 batch read
```

- [ ] `flutter test test/features/my_cage/playback_start_tracker_test.dart test/features/my_cage/highlight_batch_test.dart test/features/my_cage/highlight_read_store_test.dart`에서 미구현 실패를 확인한다.
- [ ] `PlaybackStartTracker`를 클립 세대별 순수 상태 추적기로 구현한다. 인터페이스는 `observe({required Duration position, required bool initialized, required bool playing, required bool buffering, required bool seeking}) → bool`이며 최초 자연 재생 진행 때 한 번 true를 반환한다. seek 시작/완료는 baseline을 재설정한다. 지원 플랫폼의 실제 첫 영상 프레임/진행 이벤트로 뒷받침하고 정지된 양수 position만으로 판정하지 않는다.
- [ ] 플레이어 args에 batchId/cameraId/source를 전달하고 tracker true일 때 현재 owner와 clip 세대를 검증한 후 readAt을 영속 저장한다. 로컬 저장 직후 banner Provider를 갱신한다. 로컬 읽음 저장 실패는 재시도하고 존재하지 않는 성공 저장을 가정하지 않는다. 다중 기기 sync는 G0에서 지원하기로 확정된 경우에만 연결한다.
- [ ] 표시 후보는 모든 묶음 중 **가장 최근 공개된 배치**를 먼저 고른 뒤 read/dismiss 여부로 카드 노출을 판정한다. unread 목록을 먼저 거르고 최신을 고르면 오래된 카드가 연속 등장하므로 그렇게 구현하지 않는다. X는 dismissedAt만 기록한다.
- [ ] Figma `945:4331` NewHighlight의 radius12, padding20, 닫기44×44, 썸네일 스택/문구를 적용한다. 날짜는 실제 captureStart/end로 표시하고 C2 업데이트 문구에는 publishedAt을 준다. 목록 진입/초기화/오류에는 카드가 사라지지 않아야 한다.
- [ ] 위 테스트와 `flutter test test/features/my_cage/highlights_screen_test.dart test/features/my_cage/highlight_repository_test.dart test/features/my_cage/clip_playlist_player_seek_test.dart`/analyze를 확인한다. 다음 날 준비 완료 fixture 및 실제 배치로 검증하고 `feat: mark delivered highlights read on playback start` 커밋.
