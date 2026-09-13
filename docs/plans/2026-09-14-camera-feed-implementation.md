# 카메라 목록·캐시 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 스크롤 튐을 진단·해결하고 전체 기간 영상을 안정적으로 이어 보며 캐시된 썸네일을 즉시 표시한다.

**Architecture:** 계정·cameraId·명시 기간을 값 동등성이 있는 조회키로 묶는다. 복합 커서 Repository와 이전 items를 유지하는 Riverpod controller를 지연 생성 목록에 연결하고 라이브 세션 수명은 별도로 보존한다.

**Tech Stack:** Flutter Slivers, Riverpod, Supabase/PostgREST, Hive, http, 기존 WebRTC controller.

**Spec:** [승인 설계 §4](2026-09-13-app-design-review.md), [통합 계획](2026-09-14-app-implementation-plan.md).

## Global Constraints

- 통합 계획의 Global Constraints 적용. 최초 전체 기간, 페이지 60개, 썸네일 캐시 200MB.
- 스크롤 문제의 목록 높이 축소 원인은 현재 가설이다. 진단 데이터 없이 확정하지 않는다.
- 일반 클립 전체 기간과 기존 하이라이트 API의 최대 31일 제약은 서로 다른 범위다.
- 새 목록은 기존 영상을 유지한 채 refreshing/loadingMore/error를 표시한다. live renderer/controller를 목록 셀 수명에 종속시키지 않는다.

## C0: 스크롤 튐 재현과 회귀 테스트

**Files — 수정:** `test/features/my_cage/crecam_home_test.dart`; 진단 시 `lib/features/my_cage/presentation/{crecam_screen,my_cage_providers}.dart`. 생성: `docs/design-audits/2026-09-14-camera-scroll-reproduction.md`.

- [ ] 기존 harness에 300개 클립, 카메라 stream 제어, refresh 호출 수, ScrollController offset 관찰을 추가한다. 인증토큰/URL 없이 cameras 이벤트·provider 전이·offset/maxScrollExtent·refresh 시작만 디버그 기록한다.
- [ ] 중간 위치에서 아래 세 경우를 각각 재현하고 발생 시각을 기록한다. 불필요한 상시 로그는 최종 코드에서 제거한다.

```text
1. 같은 cameraId의 online 등 속성 변경 → 목록 offset 및 높이 변화를 관찰
2. 탭 이탈/복귀·앱 resumed → 자동 갱신과 refresh 콜백을 구별
3. 위/아래 제스처와 live PageView 가로 제스처 → 최상단 아닌 refresh 발화 여부 확인
```

- [ ] `crecam_home_test.dart`에 “중간 스크롤 중 동일 카메라 이벤트가 와도 첫 보이는 clipId와 offset 유지” 테스트를 추가한다. offset은 레이아웃 반올림 오차 1px 이내, refresh 콜백 0회, live 연결 생성 횟수 증가 0회를 검증한다.
- [ ] `flutter test test/features/my_cage/crecam_home_test.dart`에서 실패 경로를 확인한다. 재현되지 않는 경로는 실패를 꾸며내지 않고 실기기 진단 결과를 기록한다. C2에서 수정할 원인 경로와 기준을 남긴다. 실패 테스트는 C2 해결 전 단독 커밋하지 않는다.

## C1: 명시 기간과 복합 커서 조회

**Files — 생성:** `lib/features/my_cage/domain/motion_clip_page.dart`, `lib/features/my_cage/domain/clip_feed_query.dart`, `test/features/my_cage/motion_clip_paging_test.dart`. 수정: `lib/features/my_cage/data/motion_clip_repository.dart`, `test/features/my_cage/motion_clip_repository_test.dart`.

**Interfaces — 새로 정의:**

```dart
typedef MotionClipCursor = ({DateTime startedAt, String id});
typedef MotionClipPage = ({List<MotionClip> items,
  MotionClipCursor? nextCursor, bool hasMore});
typedef ClipDateRange = ({DateTime start, DateTime endExclusive});
typedef ClipFeedQuery = ({String ownerId, String cameraId, ClipDateRange? range});
```

Repository 메서드: `Future<MotionClipPage> listPage(ClipFeedQuery query, {MotionClipCursor? before, int pageSize = 60})`. 기존 `ClipPage`는 구 `Clip` 모델용이므로 변경하거나 재사용하지 않는다. 날짜 range는 UI가 로컬 달력 날짜로 정규화하고 Repository에서 UTC로 전송한다.

- [ ] 테스트용 http client/Supabase 응답 fixture로 241개를 준비한다. 경계 60/61번째는 started_at이 같고 id가 다르게 한다. 각 요청의 order·limit·owner/camera 조건을 기록한다. 모든 페이지 결과 ID가 241개 고유하고 정렬 순서를 유지하는지 검증한다.
- [ ] 경계 조회의 조건을 아래처럼 고정하고 `flutter test test/features/my_cage/motion_clip_paging_test.dart`에서 기존 limit200 조회가 전체 건수 조건을 만족하지 못함을 확인한다.

```text
WHERE owner_id = query.ownerId AND camera_id = query.cameraId
  AND (range 없음 OR start <= started_at < endExclusive)
  AND (cursor 없음 OR started_at < cursor.startedAt
       OR (started_at = cursor.startedAt AND id < cursor.id))
ORDER BY started_at DESC, id DESC
LIMIT pageSize + 1
```

- [ ] Supabase 쿼리에 위 조건을 구현한다. ID는 실제 서버 타입/정렬을 사용하고 시간은 UTC ISO 형식으로 전달한다. RLS를 유지한다. 61개 중 60개만 반환하고 nextCursor는 마지막 반환 행에서 만든다. 마지막 페이지는 hasMore=false다. 라벨 조인과 기존 listByCamera 소비처는 유지한다.
- [ ] 기간 하루의 다음 자정 제외, 필터 없음의 날짜 제한 없음, 같은 timestamp 여러 페이지, 빈 결과·삭제된 경계 행·중복 응답 fixture를 검증한다. 서버에 합성 인덱스가 필요한지 실제 query plan/응답시간으로 확인해 G0 문서에 기록한다. 앱 저장소에 추측한 서버 migration을 만들지 않는다.
- [ ] paging/repository 테스트와 analyze 확인 후 `feat: page all camera clips with stable cursors` 커밋.

## C2: 위치가 유지되는 무한 목록·기간 UI·업데이트 문구

**Files — 생성:** `lib/features/my_cage/presentation/clip_feed_controller.dart`, `lib/features/my_cage/presentation/widgets/clip_feed_slivers.dart`, `lib/features/my_cage/domain/update_day_label.dart`, `test/features/my_cage/{clip_feed_controller,update_day_label}_test.dart`. 수정: `lib/features/my_cage/presentation/{crecam_screen,my_cage_providers}.dart`, `lib/features/my_cage/presentation/widgets/camera_live_area.dart`, `test/features/my_cage/crecam_home_test.dart`, `assets/l10n/ko.json`.

**Interface:** `clipFeedProvider`는 `ClipFeedQuery`를 키로 받는 family다. `ClipFeedState`는 `items`, `nextCursor`, `hasMore`, `initialLoading`, `refreshing`, `loadingMore`, `pageError`를 가진 불변 상태다. controller는 `loadMore()`/`refresh()`를 제공한다. 기간 Provider 값은 `ClipDateRange?`이며 null은 전체 기간이다. 조회 의존성은 ownerId/cameraId/range뿐이다.

- [ ] fake `listPage` 응답을 Completer로 제어해 추가 요청 중 items 유지, loadMore 연타 1회, pageError 뒤 같은 cursor 재시도, 계정/카메라/기간 전환 후 늦은 응답 무시를 테스트한다. 기존 C0 회귀 테스트도 실패 상태를 확인한다.
- [ ] controller를 구현한다. generation을 요청 시작에 캡처하고 결과 반영 전 동일 세대·mounted를 확인한다. 같은 ID는 dedup, 날짜/시간대 경계는 합친다. loadingMore이면 재진입 무시하고 마지막 페이지 이후 요청하지 않는다. 자동 갱신은 중간 목록 앞에 영상을 삽입하지 않는다.
- [ ] `SingleChildScrollView → Column`을 stable key가 있는 CustomScrollView/SliverList로 교체한다. 한 시간대의 수백 개 셀도 한꺼번에 만드는 SliverToBoxAdapter 큰 Column으로 옮기지 않는다. 날짜 헤더/시간 헤더/3열 row 단위로 lazy 생성한다. owner/camera/filter별 scroll 상태를 보관하고 로그아웃에 해제한다.
- [ ] 카메라 metadata 전체가 바뀌어도 feed가 재조회되지 않도록 선택 cameraId만 연결한다. live page의 renderer는 keepAlive 또는 별도 지속 mount로 보존하고 연결 controller의 생존을 테스트한다. refresh는 최상단 세로 당김만 허용하며 기존 내용을 비우지 않는다. 상단 왼쪽 LiveConnectionBadge만 제거한다.
- [ ] 기간 피커는 임시 선택 상태를 갖고 적용 시에만 Provider를 갱신한다. 취소는 유지, 전체 기간은 null, 오늘을 명시 선택해도 날짜 라벨이다. 필터 변경 시 해당 query의 목록/offset 정책을 적용한다. 자동 최근 날짜 해석 Provider는 카메라 목록 경로에서 제거하되 남은 소비처가 있는지 rg로 확인한다.
- [ ] 날짜 단위 함수를 추가한다. UTC 변환 전에 로컬 달력 구성요소를 비교하며 DST의 23/25시간 하루도 정확히 센다.

```dart
int calendarDaysAgo(DateTime timestamp, DateTime now) {
  final date = timestamp.toLocal();
  final today = now.toLocal();
  return DateTime.utc(today.year, today.month, today.day)
      .difference(DateTime.utc(date.year, date.month, date.day)).inDays;
}
```

문구는 0이하=업데이트 오늘, 1=업데이트 어제, 2이상=업데이트 N일 전을 l10n으로 처리한다. `23:59 → 다음 날 00:01`은 1일 테스트다. 북마크는 favoritedAt, 하이라이트는 P3의 publishedAt을 소비한다. P3 연결 전 startedAt을 publishedAt처럼 표시하지 않는다. 활동 분 문구는 이 한 줄에서 제거한다.

- [ ] controller·날짜·home 테스트를 실행한다: `flutter test test/features/my_cage/clip_feed_controller_test.dart test/features/my_cage/update_day_label_test.dart test/features/my_cage/crecam_home_test.dart`. 실기기 C0 시나리오와 200개 초과 탐색을 검증하고 analyze 후 `fix: preserve camera feed position during updates` 커밋. C0 테스트와 구조 교체는 이 독립 커밋에 포함한다.

## C3: 썸네일 파일 우선 캐시

**Files — 생성:** `lib/features/my_cage/data/thumbnail_cache_repository.dart`, `test/features/my_cage/thumbnail_cache_repository_test.dart`. 수정: `lib/features/my_cage/presentation/widgets/motion_clip_thumb.dart`, `lib/features/my_cage/presentation/my_cage_providers.dart`; 조사/재사용: `lib/features/my_cage/data/video_cache_repository.dart`의 주입 방식과 계정 정리 경로.

**Interface:** `ThumbnailCacheKey`는 ownerId/cameraId/clipId/version을 가진 값 객체. `ThumbnailCacheRepository.getFile(ThumbnailCacheKey key, {required Future<Uri?> Function() resolveUrl}) → Future<File?>`, `clearOwner(String ownerId) → Future<void>`. version은 변경 가능한 thumbnailKey 또는 서버 버전이며 미제공 시 교체 무효화 계약을 G0에 기록한다.

- [ ] 임시 디렉터리·가짜 다운로드를 주입해 아래 기대를 테스트한다. 상한은 테스트에서는 작은 값으로 주입해 byte 단위 eviction을 검증한다.

```text
캐시 파일+metadata 존재 → resolveUrl 0회, 네트워크 0회, 파일 반환
같은 키 3개 동시 요청 → resolveUrl/다운로드 각 1회
URL 만료+로컬 파일 유효 → 로컬 파일 표시
파일 유실/손상 → miss 처리, 재다운로드 가능
다른 owner의 같은 clipId → 파일 공유 안 함
로그아웃 중 다운로드 완료 → 이전 owner 데이터 재노출/재저장 안 함
총 바이트가 상한 초과 → 최근 사용 파일 보존, 오래된 파일부터 제거
```

- [ ] `flutter test test/features/my_cage/thumbnail_cache_repository_test.dart`로 미구현 실패 확인 후 cache-first 조회를 구현한다. 파일 존재 검사→hit 반환→miss 시만 resolveUrl/다운로드 순서다. inflight Map으로 중복을 합치고 임시 파일 다운로드→성공 시 rename/metadata 저장을 사용한다.
- [ ] 전용 Hive metadata에 크기·lastAccess·version·owner를 기록한다. 파일/metadata 불일치·용량 초과 단일 이미지·디스크 부족은 정리 후 안전하게 null/error로 반환해 fallback UI를 보인다. 404/인증 오류를 영구 실패 캐시로 저장하지 않는다. 200MB는 파일 개수가 아닌 실제 byte 합계 상한이다.
- [ ] MotionClipThumb는 캐시 Repository를 먼저 소비해 Image.file을 표시한다. 화면 및 다음 viewport 정도만 prefetch하고 기존 동시 발급 제한을 유지한다. 북마크 영구 영상과 mp4 캐시 파일/메타데이터를 공유하거나 함께 evict하지 않는다.
- [ ] 캐시 테스트와 crecam_home 테스트/analyze를 확인한다. 앱 재시작·오프라인 재방문·계정 전환을 실기기로 확인하고 `perf: load camera thumbnails from local cache first` 커밋.
