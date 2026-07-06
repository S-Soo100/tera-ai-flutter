# 비디오 기록 → motion_clips 전환 + 활동량(움직임) — S3 Implementation Plan

> **구현 방식 (CAOF):** Critical 트랙. 승인 후 flutter-dev가 task별 구현(GATE 4). Steps use checkbox (`- [ ]`).

**Goal:** 크레캠 세부캠의 "비디오 기록"을 빈 `camera_clips`(앱계정 0건) → 실제 영상 `motion_clips`(2,558건, camera_id 직결)로 전환하고, 활동량 카드를 `motion_clips` 기반 **움직임 시간**만 표시한다. → 사용자가 겪던 "영상 없음"이 해결된다.

**Architecture:** 목록은 `motion_clips`를 **camera_id로 Supabase 직결**(RLS 본인 것, enclosure 배정과 독립). 재생은 terra-api `GET /clips/{id}/url` → `VideoPlayerController.networkUrl`(다운로드 캐시 불필요). 기존 `ClipPlayerScreen`/`ClipCard`/`ClipRepository`(camera_clips·petcam 전용)는 **건드리지 않고**, motion 전용 모델/Repo/카드/재생화면을 신설한다(회귀 위험 격리). `camera_detail_screen`의 비디오/활동량 섹션만 새 Provider로 재배선한다.

**Tech Stack:** Flutter · Riverpod · supabase_flutter · video_player · http · go_router

**범위 밖(후속):** 행동분류 **태그 칩**(Supabase 분류 메타데이터 테이블 확정 후 `clip_id` 조인) · 썸네일(terra 썸네일 엔드포인트 확정 후) · 음수/식사 활동(behavior 연동 후) · 페이지네이션(현재 최신 50개).

---

## 결정 반영 (2026-07-06 사용자 대화)

- 활동량 = **움직임만**(음수/식사 제거). motion_clips `duration_sec` 합.
- 비디오 = motion_clips **미분류 그대로** 시간순 표시. 태그는 후속(분류 저장소 미확정 — "그대로 두고 Supabase 메타데이터 저장" 예정).
- 태그 UI 슬롯은 후속에 얇게 얹을 수 있게, 이번엔 카드에 태그 자리 주석만 남기고 실제 태그는 없음.

---

## File Structure

| 파일 | 작업 | 책임 |
|------|------|------|
| `lib/features/my_cage/domain/motion_clip.dart` | Create | `motion_clips` 행 매핑 |
| `test/features/my_cage/motion_clip_test.dart` | Create | `fromJson` 3케이스 |
| `lib/features/my_cage/data/motion_clip_repository.dart` | Create | `listByCamera`/`getPlaybackUrl`/`motionSeconds` |
| `lib/features/my_cage/presentation/my_cage_providers.dart` | Modify | motion Provider 4개 추가 |
| `lib/features/my_cage/presentation/widgets/motion_clip_card.dart` | Create | 카드(아이콘 placeholder + 시간/길이) |
| `lib/features/my_cage/presentation/motion_clip_player_screen.dart` | Create | networkUrl 재생 |
| `lib/core/router/app_router.dart` | Modify | `/crecam/motion-clips/:clipId` 라우트 |
| `lib/features/my_cage/presentation/camera_detail_screen.dart` | Modify | `_VideoLogSection`·`_SimpleActivityCard` 재배선 |

**테스트 전략:** `MotionClip.fromJson`만 TDD(순수). Repo/Provider/화면은 Supabase·HTTP 직결이라 무테스트 + `flutter analyze` + S5 통합검증(S1/S2와 동일 관례).

**참조 스키마(`motion_clips`):** `id`(uuid) · `camera_id`(uuid) · `started_at`(timestamptz) · `duration_sec`(float) · `r2_key` · `thumbnail_key` · `motion_score`(float) · `width`/`height`/`fps`. RLS: 본인 cameras의 클립만 SELECT.

---

## Task 1: MotionClip 도메인 모델 (TDD)

**Files:** Create `test/features/my_cage/motion_clip_test.dart` · Create `lib/features/my_cage/domain/motion_clip.dart`

- [ ] **Step 1: 실패 테스트**

`test/features/my_cage/motion_clip_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/my_cage/domain/motion_clip.dart';

void main() {
  group('MotionClip.fromJson', () {
    test('완전한 JSON → 매핑', () {
      final c = MotionClip.fromJson({
        'id': 'mc-1',
        'camera_id': 'cam-1',
        'started_at': '2026-07-06T00:49:58Z',
        'duration_sec': 30.7,
        'motion_score': 0.05,
        'thumbnail_key': 'terra-clips/x.jpg',
      });
      expect(c.id, 'mc-1');
      expect(c.cameraId, 'cam-1');
      expect(c.durationSec, closeTo(30.7, 0.001));
      expect(c.motionScore, closeTo(0.05, 0.001));
      expect(c.startedAt.isAtSameMomentAs(DateTime.utc(2026, 7, 6, 0, 49, 58)),
          isTrue);
    });

    test('nullable(motion_score, thumbnail_key) 누락 → null', () {
      final c = MotionClip.fromJson({
        'id': 'mc-2',
        'camera_id': 'cam-1',
        'started_at': '2026-07-06T00:00:00Z',
        'duration_sec': 10,
      });
      expect(c.motionScore, isNull);
      expect(c.thumbnailKey, isNull);
    });

    test('필수 누락 → 방어적 기본값', () {
      final c = MotionClip.fromJson(<String, dynamic>{});
      expect(c.id, '');
      expect(c.cameraId, '');
      expect(c.durationSec, 0);
      expect(c.startedAt, isA<DateTime>());
    });
  });
}
```

- [ ] **Step 2: 실행 → 실패 확인**

Run: `flutter test test/features/my_cage/motion_clip_test.dart`
Expected: 컴파일 실패(`MotionClip` 미정의).

- [ ] **Step 3: 구현**

`lib/features/my_cage/domain/motion_clip.dart`:
```dart
/// Supabase `motion_clips` 테이블 매핑 (terra-server P4 카메라 모션 클립).
///
/// 컬럼: id, camera_id, enclosure_id, owner_id, started_at, duration_sec,
///       r2_key, thumbnail_key, motion_score, width, height, fps, created_at.
/// 재생 URL은 terra-api GET /clips/{id}/url 로 별도 발급(여기 담지 않음).
class MotionClip {
  final String id;
  final String cameraId;
  final DateTime startedAt;
  final double durationSec;
  final double? motionScore;
  final String? thumbnailKey;

  const MotionClip({
    required this.id,
    required this.cameraId,
    required this.startedAt,
    required this.durationSec,
    this.motionScore,
    this.thumbnailKey,
  });

  factory MotionClip.fromJson(Map<String, dynamic> j) {
    return MotionClip(
      id: j['id'] as String? ?? '',
      cameraId: j['camera_id'] as String? ?? '',
      startedAt: j['started_at'] != null
          ? DateTime.tryParse(j['started_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      durationSec: (j['duration_sec'] as num?)?.toDouble() ?? 0,
      motionScore: (j['motion_score'] as num?)?.toDouble(),
      thumbnailKey: j['thumbnail_key'] as String?,
    );
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/features/my_cage/motion_clip_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: analyze + 커밋**

Run: `flutter analyze lib/features/my_cage/domain/motion_clip.dart test/features/my_cage/motion_clip_test.dart`
```bash
git add lib/features/my_cage/domain/motion_clip.dart test/features/my_cage/motion_clip_test.dart
git commit -m "feat(my_cage): MotionClip 도메인 모델 + fromJson 테스트 (S3)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: MotionClipRepository + Provider

**Files:** Create `data/motion_clip_repository.dart` · Modify `my_cage_providers.dart`

- [ ] **Step 1: Repository 구현**

`lib/features/my_cage/data/motion_clip_repository.dart`:
```dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/motion_clip.dart';
import 'camera_exceptions.dart';

/// terra-server `motion_clips` 접근. 목록은 Supabase 직결(RLS 본인 것),
/// 재생 URL은 terra-api(R2 presigned).
class MotionClipRepository {
  final SupabaseClient _supabase;
  final String _terraApiUrl;
  final Future<String?> Function() _tokenProvider;

  MotionClipRepository({
    required SupabaseClient supabase,
    required String terraApiUrl,
    required Future<String?> Function() tokenProvider,
  })  : _supabase = supabase,
        _terraApiUrl = terraApiUrl,
        _tokenProvider = tokenProvider;

  /// 카메라의 모션 클립 목록 (최신순). RLS로 본인 카메라 것만 반환.
  Future<List<MotionClip>> listByCamera(String cameraId,
      {int limit = 50}) async {
    final rows = await _supabase
        .from('motion_clips')
        .select()
        .eq('camera_id', cameraId)
        .order('started_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => MotionClip.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// 재생용 presigned URL (terra-api GET /clips/{id}/url). TTL 1h.
  Future<String> getPlaybackUrl(String clipId) async {
    final token = await _tokenProvider();
    final resp = await http.get(
      Uri.parse('$_terraApiUrl/clips/$clipId/url'),
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return body['url'] as String;
    }
    throw BackendException(resp.statusCode, resp.body);
  }

  /// 구간 [from, to) 의 움직임 시간(초) = motion_clips duration_sec 합.
  Future<int> motionSeconds(
      String cameraId, DateTime from, DateTime to) async {
    final rows = await _supabase
        .from('motion_clips')
        .select('duration_sec')
        .eq('camera_id', cameraId)
        .gte('started_at', from.toUtc().toIso8601String())
        .lt('started_at', to.toUtc().toIso8601String())
        .limit(5000);
    var sec = 0.0;
    for (final r in rows as List) {
      sec += ((r as Map<String, dynamic>)['duration_sec'] as num?)
              ?.toDouble() ??
          0;
    }
    return sec.round();
  }
}
```
> `BackendException`은 `camera_exceptions.dart`에 이미 존재(ClipRepository가 사용). Read로 시그니처(`BackendException(int statusCode, String detail)`) 확인 후 맞춰라. 다르면 그에 맞게.

- [ ] **Step 2: Provider 추가**

`my_cage_providers.dart` import 블록에 추가:
```dart
import '../../../core/config/env_config.dart';
import '../data/motion_clip_repository.dart';
import '../domain/cage_activity.dart';
import '../domain/motion_clip.dart';
```
> `env_config.dart`·`cage_activity.dart`가 이미 import돼 있으면 중복 추가하지 마라(먼저 Read로 확인). `EnvConfig`는 clipRepositoryProvider가 이미 쓰므로 대개 존재.

`clipRepositoryProvider` 정의 아래(Repository Provider 구역)에 추가:
```dart
final motionClipRepositoryProvider = Provider<MotionClipRepository>((ref) {
  return MotionClipRepository(
    supabase: ref.watch(_supabaseClientProvider),
    terraApiUrl: EnvConfig.terraServerUrl,
    tokenProvider: ref.watch(_tokenProviderProvider),
  );
});
```
그리고 공개 FutureProvider 구역(파일 하단, 캐시 Repository Provider 위)에 추가:
```dart
// ── 모션 클립 (motion_clips, S3) ────────────────────────────────────────────────

/// 카메라의 모션 클립 목록 (최신 50개, camera_id 직결).
final motionClipsProvider = FutureProvider.autoDispose
    .family<List<MotionClip>, String>((ref, cameraId) async {
  return ref.watch(motionClipRepositoryProvider).listByCamera(cameraId);
});

/// 모션 클립 재생 presigned URL. 재생 화면이 await, 만료 시 refresh.
final motionClipUrlProvider =
    FutureProvider.autoDispose.family<String, String>((ref, clipId) async {
  return ref.watch(motionClipRepositoryProvider).getPlaybackUrl(clipId);
});

/// family 키: cameraId + range. 움직임 시간(초).
typedef MotionActivityKey = ({String cameraId, ActivityRange range});

/// 활동량(움직임 초) — motion_clips duration 합. 하루 경계는 오전 7시
/// (activityRangeBounds 재사용). now는 실행 시각.
final motionActivityProvider =
    FutureProvider.autoDispose.family<int, MotionActivityKey>((ref, key) async {
  final bounds = activityRangeBounds(key.range, DateTime.now());
  return ref
      .watch(motionClipRepositoryProvider)
      .motionSeconds(key.cameraId, bounds.start, bounds.end);
});
```

- [ ] **Step 3: analyze + 커밋**

Run: `flutter analyze lib/features/my_cage/data/motion_clip_repository.dart lib/features/my_cage/presentation/my_cage_providers.dart`
```bash
git add lib/features/my_cage/data/motion_clip_repository.dart lib/features/my_cage/presentation/my_cage_providers.dart
git commit -m "feat(my_cage): MotionClipRepository + motion Provider (list/url/activity) (S3)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: MotionClipCard + 재생 화면 + 라우트

**Files:** Create `widgets/motion_clip_card.dart` · Create `motion_clip_player_screen.dart` · Modify `app_router.dart`

- [ ] **Step 1: MotionClipCard**

`lib/features/my_cage/presentation/widgets/motion_clip_card.dart`:
```dart
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/motion_clip.dart';

/// 모션 클립 그리드 카드. 썸네일 엔드포인트 미확정이라 아이콘 placeholder.
/// (후속: thumbnail_key presigned 확정 시 상단 영역 교체.)
/// (후속: 분류 태그 확정 시 하단 Row에 태그 칩 추가.)
class MotionClipCard extends StatelessWidget {
  const MotionClipCard({super.key, required this.clip, required this.onTap});

  final MotionClip clip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final timeLabel =
        DateFormat('MM.dd HH:mm').format(clip.startedAt.toLocal());
    final durationLabel = 'clip_duration_seconds'.tr(
      namedArgs: {'seconds': clip.durationSec.round().toString()},
    );

    return Card(
      clipBehavior: ui.Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: cs.surfaceContainerHighest,
                child: Icon(
                  Icons.videocam_outlined,
                  color: cs.onSurface.withValues(alpha: 0.3),
                  size: 32,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(timeLabel,
                        style: theme.textTheme.bodySmall),
                  ),
                  Text(
                    durationLabel,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: MotionClipPlayerScreen**

`lib/features/my_cage/presentation/motion_clip_player_screen.dart`:
```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_styles.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import 'my_cage_providers.dart';

/// motion_clips 재생. terra-api presigned URL을 networkUrl로 직접 재생
/// (camera_clips 전용 ClipPlayerScreen과 분리 — 캐시/behavior 없음).
class MotionClipPlayerScreen extends ConsumerStatefulWidget {
  const MotionClipPlayerScreen({super.key, required this.clipId});
  final String clipId;

  @override
  ConsumerState<MotionClipPlayerScreen> createState() =>
      _MotionClipPlayerScreenState();
}

class _MotionClipPlayerScreenState
    extends ConsumerState<MotionClipPlayerScreen> {
  VideoPlayerController? _controller;
  String? _error;
  bool _initialized = false;
  bool _didRetry = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init({bool isRetry = false}) async {
    try {
      if (isRetry) ref.invalidate(motionClipUrlProvider(widget.clipId));
      final url = await ref.read(motionClipUrlProvider(widget.clipId).future);
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initialized = true;
      });
      controller.play();
    } catch (e) {
      if (!isRetry && mounted) {
        _didRetry = true;
        await _init(isRetry: true);
        return;
      }
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: AppStyles.pagePadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    color: Theme.of(context).colorScheme.error, size: 48),
                const SizedBox(height: AppStyles.spacing12),
                Text('error_generic'.tr(),
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      backgroundColor: Colors.black,
      body: Center(
        child: !_initialized
            ? const AspectRatio(
                aspectRatio: 16 / 9,
                child: SkeletonLoading(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 0),
              )
            : AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_controller!),
                    VideoProgressIndicator(_controller!, allowScrubbing: true),
                    _PlayPauseButton(controller: _controller!),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PlayPauseButton extends StatefulWidget {
  const _PlayPauseButton({required this.controller});
  final VideoPlayerController controller;

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = widget.controller.value.isPlaying;
    return IconButton(
      iconSize: 48,
      icon: Icon(playing ? Icons.pause_circle : Icons.play_circle,
          color: Colors.white70),
      onPressed: () =>
          playing ? widget.controller.pause() : widget.controller.play(),
    );
  }
}
```

- [ ] **Step 3: 라우트 등록**

`app_router.dart` import에 추가:
```dart
import '../../features/my_cage/presentation/motion_clip_player_screen.dart';
```
`/crecam` 하위 routes에서 `clips/:clipId`(현재 line 152-158) 형제로 추가:
```dart
                  GoRoute(
                    path: 'motion-clips/:clipId',
                    builder: (context, state) {
                      final id = state.pathParameters['clipId']!;
                      return MotionClipPlayerScreen(clipId: id);
                    },
                  ),
```

- [ ] **Step 4: analyze**

Run: `flutter analyze lib/features/my_cage/presentation/widgets/motion_clip_card.dart lib/features/my_cage/presentation/motion_clip_player_screen.dart lib/core/router/app_router.dart`
Expected: `No issues found!`
> 커밋은 Task 4와 함께(카드/재생은 Task 4의 재배선에서 실사용).

---

## Task 4: camera_detail_screen 재배선

**Files:** Modify `camera_detail_screen.dart`

- [ ] **Step 1: import + provider 정의 교체**

`camera_detail_screen.dart` 상단에 추가:
```dart
import '../domain/motion_clip.dart';
import 'widgets/motion_clip_card.dart';
```
`_cameraClipsProvider`(현재 line 35-40)를 **삭제**하고 아래로 교체:
```dart
final _motionClipsProvider = FutureProvider.autoDispose
    .family<List<MotionClip>, String>((ref, cameraId) async {
  return ref.watch(motionClipsProvider(cameraId));
});
```
> 실은 `motionClipsProvider`를 직접 써도 되지만, 파일 로컬 별칭으로 감싸 기존 호출부 변경을 최소화한다. (별칭이 불필요하면 `motionClipsProvider`를 직접 watch해도 됨 — 구현자 판단.)

`_cageActivityProvider`(현재 line 47-54)를 **삭제**하고 교체:
```dart
final _cageActivityProvider = FutureProvider.autoDispose
    .family<int, ({String cameraId, ActivityRange range})>((ref, key) async {
  return ref
      .watch(motionActivityProvider((cameraId: key.cameraId, range: key.range)));
});
```
> 반환 타입이 `CageActivity` → `int`(움직임 초)로 바뀐다. 아래 Step 3에서 소비부를 맞춘다.

- [ ] **Step 2: _VideoLogSection 재배선**

`_VideoLogSection.build`(현재 line 543-586)에서:
- `ref.watch(_cameraClipsProvider(cameraId))` → `ref.watch(_motionClipsProvider(cameraId))`
- `data: (clips) { ... }` 내부의 `ClipCard(clip: c, onTap: () => context.push('/crecam/clips/${c.id}'))` →
  `MotionClipCard(clip: c, onTap: () => context.push('/crecam/motion-clips/${c.id}'))`
- 주석(line 565-567)은 "미분류 motion_clips 전체를 시간순 표시(태그는 분류 저장소 확정 후 후속)"로 갱신.
- 나머지(빈 상태 `camera_detail_clips_empty`, 스켈레톤, 에러 InlineRetry, GridView 구성)는 그대로. `clips` 타입이 `List<MotionClip>`으로 바뀌는 것만 반영.

- [ ] **Step 3: _SimpleActivityCard 움직임만**

`_SimpleActivityCard.build`(현재 line 307-364)에서 `activityAsync`가 이제 `AsyncValue<int>`다. `data:` 콜백 교체:
```dart
            data: (seconds) => _statsRow(motion: _formatMotion(seconds)),
```
그리고 `_statsRow`(현재 line 367-403)를 **움직임 1박스**로 교체:
```dart
  Widget _statsRow({String motion = '', bool loading = false}) {
    return _ActivityStatBox(
      label: 'crecam_detail_stat_motion'.tr(),
      value: motion,
      valueColor: const Color(0xFF222222),
      loading: loading,
    );
  }
```
> `_ActivityStatBox`·`_formatMotion`은 그대로 재사용. `crecam_detail_stat_drinking`/`_feeding` 키는 미사용이 되지만 ko.json에서 삭제하지 않는다(후속 복원 대비). `loading:` 호출부(line 349)는 `_statsRow(loading: true)` 그대로 동작.

- [ ] **Step 4: 전체 analyze**

Run: `flutter analyze`
Expected: 신규/수정 파일 이슈 0(에러 0). 기존 info(morph_calc 등)는 무관.
> `Clip`/`ClipCard`/`clipRepositoryProvider` import가 이 파일에서 더 이상 안 쓰이면 미사용 import 경고가 날 수 있다 — 그 경우만 해당 import 정리(behavior/clip 관련이 다른 곳에서 쓰이면 유지).

- [ ] **Step 5: 회귀 테스트**

Run: `flutter test`
Expected: motion_clip_test + 기존(enclosure_test, cage_activity_test 등) 전부 PASS.

- [ ] **Step 6: 커밋 (Task 3+4)**

```bash
git add lib/features/my_cage/presentation/widgets/motion_clip_card.dart \
        lib/features/my_cage/presentation/motion_clip_player_screen.dart \
        lib/core/router/app_router.dart \
        lib/features/my_cage/presentation/camera_detail_screen.dart
git commit -m "feat(my_cage): 비디오 기록 motion_clips 전환 + 재생 + 활동량(움직임) (S3)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## 완료 후 (push 전)

- **버전 bump**: feature → `0.6.0+13` → `0.7.0+14`.
- **S5 통합검증**: leegawnhun 로그인 → P4 Cam 상세 → 비디오 기록에 최신순 클립(수백 건) 표시·탭 재생 확인 · 활동량 "움직임 Xh Ym" 확인.
- **다음**: S4(온습도 enclosure 매칭 — `_LiveEnvBadge`를 카메라 소속 사육세트의 사육장 모듈 telemetry로).

---

## Self-Review

**1. Spec 커버리지:** 비디오→motion_clips(Task 2 repo + Task 4 재배선) · 재생(Task 3) · 활동량 움직임만(Task 4 Step 3). 태그/썸네일/음수·식사는 범위 밖 명시 — gap 아님.

**2. Placeholder 스캔:** 실제 코드만. 카드 썸네일은 "의도된 아이콘 placeholder"(엔드포인트 미확정, 주석으로 후속 표시) — TODO 방치가 아니라 스코프 결정.

**3. 타입 일관성:**
- `MotionClip{id,cameraId,startedAt,durationSec,motionScore?,thumbnailKey?}` — Task 1 정의 = Task 2 fromJson = Task 3 카드(`clip.startedAt`/`durationSec`) = Task 4 목록 타입 일치.
- `MotionClipRepository{listByCamera→List<MotionClip>, getPlaybackUrl→String, motionSeconds→int}` — Task 2 정의 = Provider 소비 일치.
- `motionClipsProvider`(→List<MotionClip>)·`motionClipUrlProvider`(→String)·`motionActivityProvider`(→int) — Task 2 정의 = Task 3 재생(`motionClipUrlProvider`) = Task 4(`_motionClipsProvider`/`_cageActivityProvider` 별칭) 일치.
- `_cageActivityProvider` 반환 `CageActivity`→`int` 변경 = `_SimpleActivityCard` data 콜백 `(seconds)` = `_formatMotion(int)` 일치. drinking/feeding 제거로 미사용 파라미터 없음.
- `activityRangeBounds`/`ActivityRange`(cage_activity.dart) 재사용 — 시그니처 기존과 동일.
- `BackendException(int, String)` — camera_exceptions.dart 기존 정의 확인 필요(Task 2 Step 1 주석).

**주의(구현자):**
- `camera_detail_screen`에서 `_cameraClipsProvider`/`_cageActivityProvider`를 지우면 `Clip`/`ClipCard`/`ClipRepository.getActivity` 참조가 사라진다 — 미사용 import만 정리(단 같은 파일의 `_LiveEnvBadge`/behavior 등 다른 참조는 유지).
- 재생 401/만료는 `_init(isRetry:true)`에서 url provider invalidate 후 1회 재시도(코드 포함). 계속 실패면 에러 화면.
- 활동량 `motionSeconds`의 `limit(5000)`은 안전상한(하루 클립 수백 가정). 초과 시 과소집계 가능하나 정상범위 밖.
