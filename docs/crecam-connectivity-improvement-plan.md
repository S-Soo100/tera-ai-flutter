# 크레캠 카메라 연결성 개선 (A~D) Implementation Plan

> **구현 방식 (CAOF):** Standard 트랙 — 메인이 task 단위로 직접 구현. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 크레캠 탭의 미리보기·연결 상태 표시를 실데이터 기준으로 정확하게 만들고, WebRTC 라이브 진입 시간을 구조적으로 단축하며, 남는 지연의 원인(앱 vs 펌웨어 vs NAT)을 계측으로 판별 가능하게 한다.

**Architecture:** ① 그리드 포스터의 데이터 소스를 죽은 `camera_clips`에서 실유입 중인 `motion_clips`로 교체(기존 `motionThumbnailProvider` presigned 흐름 재사용). ② 연결 상태는 `is_online`(DB) + `last_seen_at` 시효를 결합한 순수 함수 `cameraPresence`로 판정하고, 앱 복귀 시 재조회 + pull-to-refresh로 stale을 끊는다. ③ WebRTC는 config 세션 캐시 + renderer 병렬 init + ICE gathering 대기 단축(2s→1s, srflx 조기진행) + 504 자동 재시도 1회. ④ 단계별 소요 ms를 `[webrtc-timing]` 로그로 남긴다.

**Tech Stack:** Flutter + Riverpod(StateNotifier/StreamProvider) + Supabase(직결 쿼리·Realtime) + terra-api(presigned URL) + flutter_webrtc + cached_network_image + shimmer.

**진단 근거 (2026-07-19 DB 실측):**
- `camera_clips` 최근 7일 유입 0건 (최신 2026-07-07). P4 Cam 3는 0건. 실영상은 `motion_clips`로만 유입(카메라당 하루 99~232건) → 그리드 "미리보기 없음"/2주 전 포스터의 원인.
- `cameras.is_online`/`last_seen_at`은 정확(켜진 2대 true, last_seen 2~3분 전) → 상태 오표시는 앱측 stale(Realtime 소켓 사망 후 재조회 없음, pull-to-refresh 없음).
- WebRTC 직렬 지연: config HTTP → ICE gathering 고정 최대 2s → 서버가 펌웨어 answer 동기 대기(최대 15s) → long-poll trickle. TURN 없음(서버 `.env` 미설정 시 응답에서 빠짐 — APP_WEBRTC.md §4.1).

**계획 외 (백엔드 협의, 이 계획에 포함 안 함):**
- E. TURN 서버 배포(`WEBRTC_TURN_*`) — 외부망 연결 성공률의 결정타. Task 4의 계측 수치가 요청 근거가 된다.
- F. `GET /cameras/{id}/snapshot` 스냅샷 엔드포인트 — Task 1로 대체 가능, 우선순위 낮음.
- `camera_clips` 파이프라인 중단이 의도인지 백엔드 확인 (의도라면 `clip_repository.dart` 계열 정리는 별도 계획).

---

## File Structure

| 파일 | 작업 | 책임 |
|---|---|---|
| `lib/features/my_cage/data/motion_clip_repository.dart` | Modify | `latestByCamera()` 추가 (라벨 조인 없는 최신 1건) |
| `lib/features/my_cage/presentation/my_cage_providers.dart` | Modify | `latestClipProvider` 제거 → `latestMotionClipProvider` 추가, `webrtcConfigProvider` 추가 |
| `lib/features/my_cage/presentation/crecam_screen.dart` | Modify | 포스터를 motion_clips로, presence 기반 상태 표시, lifecycle 재조회, pull-to-refresh |
| `lib/features/my_cage/domain/camera_presence.dart` | Create | `CameraPresence` enum + `cameraPresence()` 순수 함수 |
| `lib/features/my_cage/presentation/webrtc_live_controller.dart` | Modify | config 캐시 사용, renderer 병렬 init, ICE 대기 단축, 504 자동 재시도, 계측 |
| `assets/l10n/ko.json` | Modify | `crecam_camera_stale` 키 추가 |
| `test/features/my_cage/camera_presence_test.dart` | Create | presence 판정 단위 테스트 (TDD) |

**TDD 예외 (사용자 승인 필요 항목):** Task 1의 `latestByCamera`는 로직 없는 Supabase 직결 쿼리(기존 repo 테스트도 seam 있는 집계만 커버), Task 3/4의 컨트롤러는 flutter_webrtc 네이티브 의존이라 단위 테스트 대신 **flutter analyze + Task 4 계측 로그 + 실기기 확인**으로 검증한다. 순수 로직인 Task 2의 presence 판정만 TDD로 간다.

---

### Task 1: 그리드 포스터를 motion_clips 최신 클립으로 전환 (A)

**Context (fresh 실행 폐쇄성):**
- Depends on: 없음
- Inputs: `motion_clips` 테이블(RLS 본인 카메라), 기존 `motionThumbnailProvider`(terra-api presigned, `my_cage_providers.dart:309`), `MotionClipCard`의 썸네일 렌더 패턴
- Outputs: `MotionClipRepository.latestByCamera()`, `latestMotionClipProvider`, crecam 그리드 `_CameraThumbnail`이 motion_clips 포스터 표시. `latestClipProvider` 삭제(사용처가 crecam 그리드 하나뿐)
- Must know: ① 클립은 `cameras.id`(UUID)로 연결 — `camera_id`(text, "p4cam-...") 아님. ② `listByCamera`는 behavior_logs 라벨 조인을 하므로 포스터용으로 쓰지 않는다(왕복 1회 낭비). ③ `motionThumbnailProvider`는 `String?` 반환 — 404(썸네일 없음)면 null → placeholder 폴백
- Acceptance: `flutter analyze` 에러 0. 실기기에서 온라인 카메라(P4 Cam 3 포함)에 최근 모션 썸네일 포스터가 뜬다 (기존: P4 Cam 3 항상 "미리보기 없음")

**Files:**
- Modify: `lib/features/my_cage/data/motion_clip_repository.dart` (`latestMotionAt` 아래)
- Modify: `lib/features/my_cage/presentation/my_cage_providers.dart:215-222` (`latestClipProvider` 교체)
- Modify: `lib/features/my_cage/presentation/crecam_screen.dart:250-296` (`_CameraThumbnail`)

- [ ] **Step 1: `latestByCamera` 추가** — `motion_clip_repository.dart`의 `latestMotionAt` 메서드 아래에:

```dart
  /// 이 카메라의 가장 최근 모션 클립 1건 (크레캠 그리드 포스터용). 없으면 null.
  /// 포스터에는 썸네일만 필요하므로 behavior_logs 라벨 조인 없이 조회한다.
  Future<MotionClip?> latestByCamera(String cameraId) async {
    final rows = await _supabase
        .from('motion_clips')
        .select()
        .eq('camera_id', cameraId)
        .order('started_at', ascending: false)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return MotionClip.fromJson(list.first as Map<String, dynamic>);
  }
```

- [ ] **Step 2: provider 교체** — `my_cage_providers.dart`의 `latestClipProvider`(215~222행 부근, "카메라별 가장 최근 클립 1건" 주석 블록 포함)를 삭제하고 같은 자리에:

```dart
/// 카메라별 가장 최근 모션 클립 1건 (크레캠 그리드 썸네일 포스터용). 없으면 null.
/// camera_clips 파이프라인은 2026-07-07 이후 유입이 끊겨(실영상은 motion_clips로만
/// 들어옴) motion_clips 기준으로 조회한다.
final latestMotionClipProvider = FutureProvider.autoDispose
    .family<MotionClip?, String>((ref, cameraId) async {
  return ref.watch(motionClipRepositoryProvider).latestByCamera(cameraId);
});
```

`import '../domain/motion_clip.dart';`가 파일 상단에 이미 있는지 확인, 없으면 추가. `Clip` import는 다른 provider(`clipFileUrlProvider` 등)가 아직 쓰므로 유지.

- [ ] **Step 3: `_CameraThumbnail` 교체** — `crecam_screen.dart`의 `_CameraThumbnail` build를 다음으로 교체:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!camera.isOnline) {
      return const _ThumbnailState(
        icon: Icons.videocam_off_rounded,
        labelKey: 'crecam_thumbnail_offline',
      );
    }

    // 클립은 cameras.id(UUID)로 연결됨 — camera.cameraId(text) 아님.
    final latest = ref.watch(latestMotionClipProvider(camera.id));
    return latest.when(
      loading: () => const SkeletonLoading(
        width: double.infinity,
        height: double.infinity,
      ),
      error: (_, __) => const _ThumbnailState(
        icon: Icons.videocam_rounded,
        labelKey: 'crecam_thumbnail_no_preview',
        online: true,
      ),
      data: (clip) {
        if (clip == null) {
          return const _ThumbnailState(
            icon: Icons.videocam_rounded,
            labelKey: 'crecam_thumbnail_no_preview',
            online: true,
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            _MotionClipPoster(clipId: clip.id),
            const Positioned(top: 8, left: 8, child: _OnlineDot()),
          ],
        );
      },
    );
  }
```

- [ ] **Step 4: `_MotionClipPoster` 위젯 추가** — `_CameraThumbnail` 클래스 바로 아래에 (렌더 패턴은 `motion_clip_card.dart`와 동일):

```dart
/// motion_clips 썸네일 포스터 (terra-api presigned). 없음(404→null)/실패 시
/// 온라인 톤 placeholder 폴백.
class _MotionClipPoster extends ConsumerWidget {
  const _MotionClipPoster({required this.clipId});
  final String clipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbAsync = ref.watch(motionThumbnailProvider(clipId));
    const noPreview = _ThumbnailState(
      icon: Icons.videocam_rounded,
      labelKey: 'crecam_thumbnail_no_preview',
      online: true,
    );
    return thumbAsync.when(
      data: (url) => url != null
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => const SkeletonLoading(
                width: double.infinity,
                height: double.infinity,
              ),
              errorWidget: (_, __, ___) => noPreview,
            )
          : noPreview,
      loading: () => const SkeletonLoading(
        width: double.infinity,
        height: double.infinity,
      ),
      error: (_, __) => noPreview,
    );
  }
}
```

- [ ] **Step 5: import 정리** — `crecam_screen.dart` 상단: `import 'package:cached_network_image/cached_network_image.dart';` 추가, `import 'widgets/clip_thumbnail.dart';` 삭제 (사용처가 없어짐).

- [ ] **Step 6: 검증**

Run: `flutter analyze`
Expected: `No issues found!` (에러 0)

Run: `flutter test`
Expected: 기존 테스트 전부 PASS (이 task는 기존 테스트 영향 없음)

- [ ] **Step 7: Commit**

```bash
git add lib/features/my_cage/data/motion_clip_repository.dart lib/features/my_cage/presentation/my_cage_providers.dart lib/features/my_cage/presentation/crecam_screen.dart
git commit -m "fix(my_cage): 크레캠 그리드 포스터를 motion_clips 최신 클립으로 전환 (camera_clips 유입 중단)"
```

---

### Task 2: 연결 상태 신뢰도 — presence 판정 + 복귀 재조회 + pull-to-refresh (B)

**Context (fresh 실행 폐쇄성):**
- Depends on: 없음 (Task 1과 독립 — 같은 파일 `crecam_screen.dart`를 수정하므로 순서대로 실행)
- Inputs: `TerraCamera.isOnline`/`lastSeenAt`(`domain/terra_camera.dart`), `camerasProvider`(StreamProvider + Realtime, `my_cage_providers.dart:90`), 기존 ko.json 키 `time_just_now`/`time_minutes_ago`/`time_hours_ago`/`time_days_ago`(271~274행)와 `crecam_camera_online`/`crecam_camera_offline`
- Outputs: `domain/camera_presence.dart`(순수 함수 + enum), presence 테스트, CrecamScreen에 lifecycle 재조회·RefreshIndicator·"온라인 · N분 전" 상태줄
- Must know: ① `camerasProvider`는 Realtime 채널 1개 의존 — 백그라운드에서 소켓이 죽으면 이벤트가 영영 안 온다. `ref.invalidate(camerasProvider)`가 재구독+재조회를 모두 수행한다(provider 재생성). ② `last_seen_at`은 UTC — 비교 전 `.toUtc()` 통일. ③ 하트비트는 1~3분 간격(실측 2~3분 전) → staleAfter 5분 = 약 2회 연속 누락 수준. ④ 하드코딩 색상 금지 — 새 코드는 `Theme.of(context).colorScheme.primary/secondary` 사용(기존 `0xFF2E7D32` 상수는 건드리지 않음)
- Acceptance: `flutter test test/features/my_cage/camera_presence_test.dart` 4건 PASS. `flutter analyze` 에러 0. 실기기: 카드에 "온라인 · 3분 전" 형태 표시, 당겨서 새로고침 동작, 앱 백그라운드→복귀 시 상태 갱신

**Files:**
- Create: `lib/features/my_cage/domain/camera_presence.dart`
- Create: `test/features/my_cage/camera_presence_test.dart`
- Modify: `lib/features/my_cage/presentation/crecam_screen.dart`
- Modify: `assets/l10n/ko.json:433` (`crecam_camera_offline` 아래)

- [ ] **Step 1: 실패하는 테스트 작성** — `test/features/my_cage/camera_presence_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/my_cage/domain/camera_presence.dart';

void main() {
  final now = DateTime.utc(2026, 7, 19, 12, 0);

  test('오프라인이면 last_seen과 무관하게 offline', () {
    expect(
      cameraPresence(isOnline: false, lastSeenAt: now, now: now),
      CameraPresence.offline,
    );
  });

  test('온라인 + last_seen 5분 이내면 online', () {
    expect(
      cameraPresence(
        isOnline: true,
        lastSeenAt: now.subtract(const Duration(minutes: 3)),
        now: now,
      ),
      CameraPresence.online,
    );
  });

  test('온라인이어도 last_seen 5분 초과면 stale', () {
    expect(
      cameraPresence(
        isOnline: true,
        lastSeenAt: now.subtract(const Duration(minutes: 6)),
        now: now,
      ),
      CameraPresence.stale,
    );
  });

  test('last_seen null이면 서버 판정(online)을 신뢰', () {
    expect(
      cameraPresence(isOnline: true, lastSeenAt: null, now: now),
      CameraPresence.online,
    );
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/my_cage/camera_presence_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'vivnanaut/features/my_cage/domain/camera_presence.dart'` (파일 없음)

- [ ] **Step 3: 최소 구현** — `lib/features/my_cage/domain/camera_presence.dart`:

```dart
/// 카메라 표시용 연결 상태. `cameras.is_online`(서버 판정)에 `last_seen_at`
/// 시효를 결합한다 — is_online만 믿으면 서버의 오프라인 판정 지연이나 앱측
/// Realtime 이벤트 소실 시 stale 표시가 남는다.
enum CameraPresence { online, stale, offline }

/// [staleAfter]: last_seen이 이보다 오래되면 online이어도 stale(응답 지연)로
/// 강등. 하트비트가 1~3분 간격이므로 5분 = 약 2회 연속 누락 수준.
CameraPresence cameraPresence({
  required bool isOnline,
  required DateTime? lastSeenAt,
  required DateTime now,
  Duration staleAfter = const Duration(minutes: 5),
}) {
  if (!isOnline) return CameraPresence.offline;
  if (lastSeenAt == null) return CameraPresence.online;
  final age = now.toUtc().difference(lastSeenAt.toUtc());
  return age > staleAfter ? CameraPresence.stale : CameraPresence.online;
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/features/my_cage/camera_presence_test.dart`
Expected: `All tests passed!` (4건)

- [ ] **Step 5: ko.json 키 추가** — `assets/l10n/ko.json`의 `"crecam_camera_offline": "오프라인",` 바로 아래에:

```json
  "crecam_camera_stale": "응답 지연",
```

- [ ] **Step 6: CrecamScreen lifecycle 재조회 + RefreshIndicator** — `_CrecamScreenState`를 다음으로 교체:

```dart
class _CrecamScreenState extends ConsumerState<CrecamScreen>
    with WidgetsBindingObserver {
  _CrecamView _view = _CrecamView.grid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 백그라운드에서 Realtime 소켓이 죽으면 이벤트가 다시 오지 않으므로,
  // 복귀 시 provider를 재생성(재구독+재조회)해 stale 상태를 끊는다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(camerasProvider);
    }
  }

  void _openPairing() {
    context.push('/crecam/cameras/pair');
  }

  Future<void> _refresh() async {
    ref.invalidate(camerasProvider);
    await ref.read(camerasProvider.future);
  }
```

기존 `build`의 `data:` 분기를 RefreshIndicator로 감싼다:

```dart
        data: (cameras) {
          if (cameras.isEmpty) {
            return _EmptyBody(onAdd: _openPairing);
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: _view == _CrecamView.grid
                ? _CameraGrid(
                    cameras: cameras,
                    onAddTap: _openPairing,
                  )
                : _CameraList(cameras: cameras),
          );
        },
```

`_CameraGrid`의 `GridView.builder`와 `_CameraList`의 `ListView.separated`에 각각 `physics: const AlwaysScrollableScrollPhysics(),` 추가 (항목이 화면보다 적어도 당겨서 새로고침이 되도록).

- [ ] **Step 7: 카드 상태줄을 presence 기반으로** — `crecam_screen.dart` 상단에 `import '../domain/camera_presence.dart';` 추가. `_CameraGridCard`의 상태 `Text`(224~231행 부근, `camera.isOnline ? ... : ...`)를 다음으로 교체:

```dart
                        Builder(builder: (context) {
                          final scheme = Theme.of(context).colorScheme;
                          final presence = cameraPresence(
                            isOnline: camera.isOnline,
                            lastSeenAt: camera.lastSeenAt,
                            now: DateTime.now(),
                          );
                          final (label, color) = switch (presence) {
                            CameraPresence.online => (
                                camera.lastSeenAt == null
                                    ? 'crecam_camera_online'.tr()
                                    : '${'crecam_camera_online'.tr()} · '
                                        '${_timeAgo(camera.lastSeenAt!)}',
                                scheme.primary,
                              ),
                            CameraPresence.stale => (
                                'crecam_camera_stale'.tr(),
                                scheme.secondary,
                              ),
                            CameraPresence.offline => (
                                'crecam_camera_offline'.tr(),
                                scheme.outline,
                              ),
                          };
                          return Text(
                            label,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: color),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        }),
```

파일 하단(최상위)에 상대 시각 헬퍼 추가 (community_screen.dart:207의 기존 패턴·기존 `time_*` 키 재사용):

```dart
/// last_seen 상대 시각 ("방금 전"/"N분 전"/...). 기존 time_* 키 재사용.
String _timeAgo(DateTime t) {
  final diff = DateTime.now().toUtc().difference(t.toUtc());
  if (diff.inMinutes < 1) return 'time_just_now'.tr();
  if (diff.inMinutes < 60) {
    return 'time_minutes_ago'.tr(namedArgs: {'n': '${diff.inMinutes}'});
  }
  if (diff.inHours < 24) {
    return 'time_hours_ago'.tr(namedArgs: {'n': '${diff.inHours}'});
  }
  return 'time_days_ago'.tr(namedArgs: {'n': '${diff.inDays}'});
}
```

- [ ] **Step 8: 리스트 뷰에도 동일 상태 반영** — `_CameraList`의 `ListTile`에 `subtitle`을 교체:

```dart
          subtitle: Text(
            camera.isOnline && camera.lastSeenAt != null
                ? '${camera.model ?? camera.cameraId} · '
                    '${_timeAgo(camera.lastSeenAt!)}'
                : (camera.model ?? camera.cameraId),
            style: Theme.of(context).textTheme.bodySmall,
          ),
```

- [ ] **Step 9: 검증**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: 전부 PASS (신규 4건 포함)

- [ ] **Step 10: Commit**

```bash
git add lib/features/my_cage/domain/camera_presence.dart test/features/my_cage/camera_presence_test.dart lib/features/my_cage/presentation/crecam_screen.dart assets/l10n/ko.json
git commit -m "feat(my_cage): 카메라 연결상태 presence 판정(last_seen 시효) + 복귀 재조회 + pull-to-refresh"
```

---

### Task 3: WebRTC 라이브 연결 체감 단축 (C)

**Context (fresh 실행 폐쇄성):**
- Depends on: 없음 (Task 4가 이 task의 코드 위에 계측을 얹으므로 Task 4보다 먼저)
- Inputs: `webrtc_live_controller.dart`(연결 시퀀스 전체), `webrtc_signaling_repository.dart`(`fetchConfig`/`sendOffer` — 504→`CameraUnresponsiveException`), `my_cage_providers.dart`의 `webrtcSignalingRepositoryProvider`
- Outputs: `webrtcConfigProvider`(세션 캐시), renderer 병렬 init, ICE gathering 대기 1s + srflx 조기진행, 504 자동 재시도 1회(`_autoRetried`), `retry()`/`_restart()` 분리
- Must know: ① 서버 offer 엔드포인트는 펌웨어 answer를 최대 15s **동기 대기** — 자동 재시도는 1회만(초과 시 사용자가 수동 retry). ② trickle 경로(POST /webrtc/ice + 큐 flush)가 이미 있으므로 gathering을 끝까지 안 기다려도 나머지 후보는 answer 후 전송된다 — 그래서 대기 단축이 안전. ③ srflx 후보가 잡히면 STUN 왕복이 끝난 것 → 더 기다릴 이유 없음(TURN 미배포라 relay 후보는 없음). ④ `_cleanup`은 `_active=false`로 만들므로 재시작 경로는 반드시 `_active=true` 복원 포함(`_restart`). ⑤ config 캐시에 에러가 박힐 수 있음 → 수동 `retry()`에서만 `ref.invalidate(webrtcConfigProvider)`. ⑥ renderer는 `!_active` 조기 리턴 시에도 dispose (native 누수 — 메모리 `project_video_player_controller_leak`과 동일 함정)
- Acceptance: `flutter analyze` 에러 0. 실기기: 재진입 시 "설정 수신 중" 단계가 즉시 통과(Task 4 로그로 config≈0ms 확인), 첫 진입 대비 스트림 표시까지 체감 단축. 504 시 사용자 조작 없이 1회 자동 재시도

**Files:**
- Modify: `lib/features/my_cage/presentation/my_cage_providers.dart` (`webrtcSignalingRepositoryProvider` 정의 아래)
- Modify: `lib/features/my_cage/presentation/webrtc_live_controller.dart`

- [ ] **Step 1: config 세션 캐시 provider** — `my_cage_providers.dart`, `webrtcSignalingRepositoryProvider` 정의 바로 아래에:

```dart
/// WebRTC ICE 설정 (terra-server GET /cameras/webrtc/config) — 세션 캐시.
/// 내용이 사실상 정적(iceServers)이라 라이브 진입마다 왕복하지 않는다.
/// 실패가 캐시되면 컨트롤러의 수동 retry()가 invalidate 후 재시도한다.
final webrtcConfigProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(webrtcSignalingRepositoryProvider).fetchConfig();
});
```

- [ ] **Step 2: 컨트롤러 필드 + retry/_restart 분리** — `webrtc_live_controller.dart`의 `_pendingCandidates` 필드 아래에 추가:

```dart
  // 504(카메라 무응답) 자동 재시도 1회 가드. 수동 retry()가 리셋한다.
  bool _autoRetried = false;

  // ICE gathering 대기 중 srflx 후보 감지용 probe (조기 진행).
  void Function(String raw)? _iceWaitProbe;
```

기존 `retry()`를 다음 둘로 교체:

```dart
  /// 수동 재시도 (실패 화면 버튼). 자동 재시도 가드와 config 캐시를 리셋한다.
  Future<void> retry() async {
    _autoRetried = false;
    ref.invalidate(webrtcConfigProvider);
    await _restart();
  }

  Future<void> _restart() async {
    await _cleanup(closeRemote: true);
    _active = true;
    _pendingCandidates.clear();
    state = const WebRtcLiveState(phase: WebRtcLivePhase.connectingConfig);
    await _start();
  }
```

`my_cage_providers.dart`의 `webrtcConfigProvider`를 쓰므로 컨트롤러 상단 import에 `import 'my_cage_providers.dart';`가 이미 있음(확인만).

- [ ] **Step 3: `_start`에 504 자동 재시도 1회** — 기존 `_start()`를 교체:

```dart
  Future<void> _start() async {
    try {
      await _doConnect();
    } on CameraUnresponsiveException {
      if (!_active) return;
      if (!_autoRetried) {
        // 펌웨어가 offer를 놓친 일시 무응답일 수 있어 1회만 자동 재시도.
        _autoRetried = true;
        await _restart();
        return;
      }
      state = const WebRtcLiveState(
        phase: WebRtcLivePhase.failed,
        errorKey: 'crecam_live_error_unresponsive',
      );
    } catch (_) {
      if (!_active) return;
      state = const WebRtcLiveState(
        phase: WebRtcLivePhase.failed,
        errorKey: 'crecam_live_error_failed',
      );
    }
  }
```

- [ ] **Step 4: config 캐시 사용 + renderer 병렬 init** — `_doConnect()`의 1~2단계(`fetchConfig` ~ `_renderer = renderer;`)를 교체:

```dart
    // 1+2. config(세션 캐시)와 renderer init을 병렬로
    final rendererFut = () async {
      final r = RTCVideoRenderer();
      await r.initialize();
      return r;
    }();
    Map<String, dynamic> cfg;
    try {
      cfg = await ref.read(webrtcConfigProvider.future);
    } catch (_) {
      await (await rendererFut).dispose(); // 실패 경로 native 누수 방지
      rethrow;
    }
    final renderer = await rendererFut;
    if (!_active) {
      await renderer.dispose();
      return;
    }
    _renderer = renderer;
```

- [ ] **Step 5: onIceCandidate에 probe 연결** — `_doConnect()`의 6단계 `pc.onIceCandidate` 핸들러에서 `if (raw == null || raw.isEmpty) return;` 바로 다음 줄에 추가:

```dart
      _iceWaitProbe?.call(raw);
```

- [ ] **Step 6: ICE gathering 대기 단축** — 9단계 호출을 `maxWaitMs: 1000`으로 바꾸고 주석 갱신:

```dart
    // 9. ICE gathering 대기 (최대 1초) — srflx 확보 시 조기 진행.
    //    나머지 후보는 answer 후 trickle(큐 flush + POST /ice)로 전송된다.
    await _waitForIceGathering(pc, maxWaitMs: 1000);
```

`_waitForIceGathering`을 교체:

```dart
  Future<void> _waitForIceGathering(
    RTCPeerConnection pc, {
    required int maxWaitMs,
  }) async {
    if (pc.iceGatheringState ==
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return;
    }
    final completer = Completer<void>();
    void finish() {
      if (!completer.isCompleted) completer.complete();
    }

    final timer = Timer(Duration(milliseconds: maxWaitMs), finish);
    // srflx(STUN 반사 주소)가 잡히면 공인망 후보 확보 완료 — TURN 미배포라
    // relay 후보는 없으므로 더 기다릴 이유가 없다.
    _iceWaitProbe = (raw) {
      if (raw.contains(' typ srflx')) finish();
    };
    pc.onIceGatheringState = (s) {
      if (s == RTCIceGatheringState.RTCIceGatheringStateComplete) finish();
    };
    await completer.future;
    _iceWaitProbe = null;
    timer.cancel();
  }
```

- [ ] **Step 7: 검증**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: 전부 PASS

- [ ] **Step 8: Commit**

```bash
git add lib/features/my_cage/presentation/my_cage_providers.dart lib/features/my_cage/presentation/webrtc_live_controller.dart
git commit -m "perf(my_cage): WebRTC 라이브 진입 단축 — config 세션캐시·renderer 병렬화·ICE 대기 1s(srflx 조기진행)·504 자동재시도 1회"
```

---

### Task 4: 연결 단계 계측 (D)

**Context (fresh 실행 폐쇄성):**
- Depends on: Task 3 (같은 파일의 `_doConnect`/`onConnectionState` 최종 형태 위에 얹음)
- Inputs: Task 3 완료된 `webrtc_live_controller.dart`
- Outputs: `[webrtc-timing]` debugPrint 로그 — config+renderer / offer 왕복(≒펌웨어 answer) / connected 까지 누적 ms, 실패 시 실패 단계·경과 ms
- Must know: 판별 기준 — **answer 구간이 크면 펌웨어(카메라) 문제, connected−answer 구간이 크면 ICE/NAT 문제(→TURN 배포 요청의 근거 수치)**. `debugPrint`는 release에서 무해(스트립되진 않지만 콘솔 없음)·`kDebugMode` 가드 불필요한 저빈도 로그
- Acceptance: `flutter analyze` 에러 0. 실기기 라이브 진입 시 콘솔에 `[webrtc-timing] cam=... config=..ms answer=..ms connected=..ms` 1줄 출력, 실패 시 `FAILED phase=...` 출력

**Files:**
- Modify: `lib/features/my_cage/presentation/webrtc_live_controller.dart`

- [ ] **Step 1: 계측 필드 추가** — `_iceWaitProbe` 필드 아래에:

```dart
  // 연결 단계 계측 (ms 누적): 느린 구간이 앱/펌웨어/NAT 중 어디인지 판별용.
  final Stopwatch _timing = Stopwatch();
  int? _msConfig; // config+renderer 준비 완료
  int? _msAnswer; // offer 전송 → answer 수신 (≒ 펌웨어 응답 시간 포함)
```

상단 import에 `import 'package:flutter/foundation.dart';` 추가.

- [ ] **Step 2: 마크 지점 삽입** — `_doConnect()` 첫 줄에:

```dart
    _timing
      ..reset()
      ..start();
```

Task 3 Step 4에서 넣은 `_renderer = renderer;` 다음 줄에:

```dart
    _msConfig = _timing.elapsedMilliseconds;
```

`_sessionId = offerResult.sessionId;` 다음 줄에:

```dart
    _msAnswer = _timing.elapsedMilliseconds;
```

- [ ] **Step 3: 성공/실패 로그** — `pc.onConnectionState`의 connected 분기(`this.state = this.state.copyWith(...)` 직전)에:

```dart
        debugPrint(
          '[webrtc-timing] cam=$cameraUuid config=${_msConfig}ms '
          'answer=${_msAnswer}ms connected=${_timing.elapsedMilliseconds}ms',
        );
```

`_start()`의 두 실패 대입 직전에 각각:

```dart
      debugPrint(
        '[webrtc-timing] cam=$cameraUuid FAILED(unresponsive) '
        'config=${_msConfig}ms at=${_timing.elapsedMilliseconds}ms',
      );
```

```dart
      debugPrint(
        '[webrtc-timing] cam=$cameraUuid FAILED phase=${state.phase} '
        'config=${_msConfig}ms answer=${_msAnswer}ms '
        'at=${_timing.elapsedMilliseconds}ms',
      );
```

- [ ] **Step 4: 검증**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/my_cage/presentation/webrtc_live_controller.dart
git commit -m "feat(my_cage): WebRTC 연결 단계 계측 로그([webrtc-timing]) — 펌웨어/NAT 병목 판별용"
```

---

### Task 5: 최종 검증 + 버전 bump

**Context (fresh 실행 폐쇄성):**
- Depends on: Task 1~4
- Inputs: 완료된 전체 변경, `pubspec.yaml:4`(`version: 0.20.1+35`), 버전 규칙(feat 포함 → minor bump + build+1, pre-push 훅이 lib 변경 무버전업 push 차단 — 메모리 `project_release_versioning`)
- Outputs: `version: 0.21.0+36`, 전체 검증 통과, 버전 커밋
- Must know: 실기기 확인 항목(사용자와 함께): ① 그리드에 모든 온라인 카메라 썸네일 포스터 ② "온라인 · N분 전" 표시 ③ pull-to-refresh ④ 백그라운드→복귀 갱신 ⑤ 라이브 진입 체감 + `[webrtc-timing]` 로그 수집(→ answer vs ICE 구간으로 백엔드 TURN 요청 근거 확보)
- Acceptance: `flutter analyze` 에러 0, `flutter test` 전부 PASS, `flutter build apk --debug` 성공, 버전 커밋 완료

- [ ] **Step 1: 전체 검증**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: 전부 PASS

Run: `flutter build apk --debug`
Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 2: 버전 bump** — `pubspec.yaml:4`:

```yaml
version: 0.21.0+36
```

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml
git commit -m "chore(release): 버전 v0.21.0+36"
```

- [ ] **Step 4: 실기기 확인 + 계측 수집** — 사용자와 함께 Must-know의 ①~⑤ 확인. `[webrtc-timing]` 수치가 answer 구간에 몰리면 펌웨어측 이슈로, connected−answer 구간에 몰리면 TURN 배포 요청(계획 외 E)으로 백엔드에 전달.
