# 카메라(펫캠) 상세 페이지 UX 개편 — Implementation Plan

> **구현 방식 (CAOF):** Critical 트랙. 사용자 "승인" → Implementer(flutter-dev)가 task 단위로 구현(GATE 4). Steps use checkbox (`- [ ]`).
> 작성일: 2026-07-08 · 대상: `/crecam/cameras/:cameraId`(CameraDetailScreen) + `/crecam/motion-clips/:clipId`(MotionClipPlayerScreen)

**Goal:** 크레캠 상세의 영상 경험을 끌어올린다 — ① 실제 썸네일 표시 ② 기기(갤러리) 저장 + 공유 ③ 재생 워터마크 ④ 즐겨찾기(로컬 보관, 오프라인 재생) ⑤ 재생 시크(10초 앞뒤·시간표시).

**Architecture:** 실데이터 경로인 **motion_clips**(3,776건, terra-server)만 다룬다. camera_clips(petcam-lab) 경로(`ClipPlayerScreen`/`ClipRepository`)는 건드리지 않는다. #1 썸네일은 terra-api 썸네일 엔드포인트가 아직 없어 **클라이언트 첫 프레임 추출(video_thumbnail) + 디스크 캐시**로 하되, 소스를 `motionThumbnailProvider` 뒤로 추상화해 **나중에 백엔드 엔드포인트로 한 줄 스왑** 가능하게 둔다. #4 즐겨찾기는 **로컬 Hive 메타 + 앱 문서 디렉토리에 mp4 영구 보관**(캐시의 LRU와 분리)이라 URL 만료·R2 삭제와 무관하게 오프라인 재생된다.

**Tech Stack:** Flutter · Riverpod · video_player · **video_thumbnail(신규)** · **gal(신규)** · **share_plus(신규)** · Hive · path_provider · http · supabase_flutter · go_router

> **구현 편차(2026-07-08 구현 완료, 커밋 dc41eef…f71567f):**
> - `share_plus`는 계획의 `^10.1.4` → **`^13.2.0`**로 상향(불가피). `package_info_plus ^10.2.0`이 `win32 ^6.0.1`을 요구하는데 share_plus 10~12.x는 `win32 ^5.5.3`을 요구해 solving 충돌 → win32 6.x 지원 라인(13.x)으로. 그에 따라 `video_export_service.dart`의 공유 API를 `SharePlus.instance.share(ShareParams(files:[XFile(path)]))`로 사용(13.x에서 `Share.shareXFiles`는 deprecated).
> - 버전은 실제 현재값이 `0.13.0+23`이라 minor+1 → **`0.14.0+24`**.
> - `camera_detail_screen.dart`의 `favorite_clip.dart` import는 타입 직접참조가 없어 미사용 → 제거(Self-Review "미사용 import 정리" 반영).

**범위 밖(별도 핸드오프):**
- 🔗 **terra-api 썸네일 엔드포인트** `GET /clips/{id}/thumbnail/url` — `motion_clips.thumbnail_key`(100% 채워짐, 예 `terra-clips/clips/p4cam-79b5d844/…​.jpg`)를 재생 URL과 동일 로직으로 presign. 생기면 #1을 클라 추출→실제 썸네일로 스왑. (백엔드 개발자)
- 🔗 **클라우드 즐겨찾기 / R2 보존** — Supabase `clip_favorites(owner_id, clip_id, created_at)` + RLS, 즐겨찾기 클립 R2 만료삭제 제외. (백엔드 개발자)
- 🔗 **녹화 시 워터마크 각인** — 재생 오버레이가 아닌 파일 각인은 펌웨어/녹화 파이프라인에서. (캠 개발자)

---

## File Structure

| 파일 | 작업 | 책임 |
|------|------|------|
| `pubspec.yaml` | Modify | video_thumbnail·gal·share_plus 추가 |
| `ios/Runner/Info.plist` | Modify | 사진앱 저장 권한 설명(gal) |
| `android/app/src/main/AndroidManifest.xml` | Modify | 갤러리 저장 권한(gal, maxSdk 29) |
| `lib/features/my_cage/presentation/widgets/video_controls.dart` | Create | 공용 재생 컨트롤(진행바+시간+10초 앞뒤) — #5 |
| `test/features/my_cage/video_controls_format_test.dart` | Create | 시간 포맷 순수함수 TDD |
| `lib/features/my_cage/presentation/clip_player_screen.dart` | Modify | 내부 `_VideoControls` → 공용 `VideoControls`로 교체 |
| `lib/features/my_cage/presentation/widgets/video_watermark.dart` | Create | 우하단 워터마크 오버레이 — #3 |
| `lib/features/my_cage/data/motion_thumbnail_repository.dart` | Create | 클라 첫프레임 추출+캐시+동시성 제한 — #1 |
| `lib/features/my_cage/presentation/widgets/motion_clip_card.dart` | Modify | 아이콘 placeholder → 실제 썸네일 |
| `lib/features/my_cage/domain/favorite_clip.dart` (+`.g.dart`) | Create | 즐겨찾기 Hive 모델 — #4 |
| `lib/features/my_cage/data/favorite_clip_repository.dart` | Create | 로컬 메타+mp4 영구보관 — #4 |
| `lib/features/my_cage/data/motion_clip_repository.dart` | Modify | `getById` 추가(즐겨찾기 메타용) |
| `lib/features/my_cage/data/video_export_service.dart` | Create | 갤러리 저장 + 공유 — #2 |
| `lib/features/my_cage/presentation/my_cage_providers.dart` | Modify | 신규 provider 6개 |
| `lib/features/my_cage/presentation/motion_clip_player_screen.dart` | Modify(전면) | 컨트롤+워터마크+저장/공유/즐겨찾기+로컬우선재생 |
| `lib/features/my_cage/presentation/camera_detail_screen.dart` | Modify | `_VideoLogSection`에 [전체\|즐겨찾기] 토글+그리드 |
| `lib/main.dart` | Modify | `FavoriteClipRepository.init()` |
| `assets/l10n/ko.json` | Modify | 신규 문자열 키 |

**테스트 전략(S3 관례 계승):** 순수 로직만 TDD(`VideoControls` 시간 포맷). Repo/Service/화면은 native(gal/share/video_thumbnail)·IO·Supabase 직결이라 무테스트 + `flutter analyze` 에러 0 + 통합검증(마지막 섹션). Hive 모델은 어댑터 생성만 확인.

**Hive typeId:** 사용 중 = 0,1,2,3,4,5,6,10. **FavoriteClip = `11`**(자유).

---

## Task 0: 패키지 추가 + 플랫폼 권한

**Files:** Modify `pubspec.yaml`, `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: pubspec 의존성 추가**

`pubspec.yaml`의 dependencies에서 `video_player: ^2.9.2` 아래에 추가:
```yaml
  video_thumbnail: ^0.5.3
  gal: ^2.3.0
  share_plus: ^10.1.4
```

- [ ] **Step 2: pub get**

Run: `flutter pub get`
Expected: 3개 패키지 resolve 성공. (share_plus는 10.x 유지 — `Share.shareXFiles` API 사용. video_thumbnail `thumbnailFile`가 resolve된 버전에서 `XFile?` 반환이면 Task 3 코드에서 `.path`로 맞춰라.)

- [ ] **Step 3: iOS 사진앱 권한 설명**

`ios/Runner/Info.plist`의 `<dict>` 안에 추가(gal 저장용):
```xml
	<key>NSPhotoLibraryAddUsageDescription</key>
	<string>녹화 영상을 사진 앱에 저장하기 위해 사용됩니다.</string>
```

- [ ] **Step 4: Android 갤러리 저장 권한**

`android/app/src/main/AndroidManifest.xml`의 `<manifest>` 바로 아래(기존 permission들 곁)에 추가(gal, API29 이하 갤러리 저장용):
```xml
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29" />
```
> 이미 동일 라인이 있으면 중복 추가 금지(먼저 grep). API30+는 gal이 권한 없이 저장.

- [ ] **Step 5: analyze (아직 코드 변경 없음, resolve 확인)**

Run: `flutter analyze`
Expected: 신규 이슈 0. (커밋은 Task 1과 함께 — 패키지만 추가한 상태는 미사용 경고 없음.)

---

## Task 1: 공용 재생 컨트롤 `VideoControls` (#5, TDD)

**Files:** Create `widgets/video_controls.dart`, `test/features/my_cage/video_controls_format_test.dart` · Modify `clip_player_screen.dart`

- [ ] **Step 1: 실패 테스트 (시간 포맷 순수함수)**

`test/features/my_cage/video_controls_format_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/my_cage/presentation/widgets/video_controls.dart';

void main() {
  group('formatClipPosition', () {
    test('0초 → 0:00', () {
      expect(formatClipPosition(Duration.zero), '0:00');
    });
    test('9초 → 0:09 (초 2자리 패딩)', () {
      expect(formatClipPosition(const Duration(seconds: 9)), '0:09');
    });
    test('75초 → 1:15', () {
      expect(formatClipPosition(const Duration(seconds: 75)), '1:15');
    });
    test('600초 → 10:00', () {
      expect(formatClipPosition(const Duration(minutes: 10)), '10:00');
    });
  });
}
```

- [ ] **Step 2: 실행 → 실패 확인**

Run: `flutter test test/features/my_cage/video_controls_format_test.dart`
Expected: 컴파일 실패(`video_controls.dart`/`formatClipPosition` 미정의).

- [ ] **Step 3: 구현 (공용 위젯 + 순수함수)**

`lib/features/my_cage/presentation/widgets/video_controls.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_styles.dart';

/// `Duration` → `m:ss`(분:초, 초 2자리). 재생 시간 라벨용 순수함수.
String formatClipPosition(Duration d) {
  final m = d.inMinutes.remainder(60).toString();
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// 영상 재생 컨트롤 — 진행바(스크럽) + 현재/총 시간 + 10초 앞뒤 + 재생/일시정지.
/// ClipPlayerScreen·MotionClipPlayerScreen 공용.
class VideoControls extends StatefulWidget {
  const VideoControls({super.key, required this.controller});

  final VideoPlayerController controller;

  @override
  State<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<VideoControls> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final v = ctrl.value;
    final isPlaying = v.isPlaying;

    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.spacing8,
        vertical: AppStyles.spacing4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VideoProgressIndicator(
            ctrl,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: Theme.of(context).colorScheme.primary,
              bufferedColor: Colors.white30,
              backgroundColor: Colors.white12,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(formatClipPosition(v.position),
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              Text(formatClipPosition(v.duration),
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10, color: Colors.white),
                onPressed: () {
                  final pos = v.position - const Duration(seconds: 10);
                  ctrl.seekTo(pos < Duration.zero ? Duration.zero : pos);
                },
              ),
              IconButton(
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white, size: 36),
                onPressed: () => isPlaying ? ctrl.pause() : ctrl.play(),
              ),
              IconButton(
                icon: const Icon(Icons.forward_10, color: Colors.white),
                onPressed: () {
                  final pos = v.position + const Duration(seconds: 10);
                  final dur = v.duration;
                  ctrl.seekTo(pos > dur ? dur : pos);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/features/my_cage/video_controls_format_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: ClipPlayerScreen을 공용 위젯으로 교체 (DRY)**

`clip_player_screen.dart`:
1. import 추가: `import 'widgets/video_controls.dart';`
2. line 187 `_VideoControls(controller: _controller!)` → `VideoControls(controller: _controller!)`
3. 파일 하단의 private `class _VideoControls`와 `_VideoControlsState`(현재 line 240-326) **전체 삭제**.

- [ ] **Step 6: analyze + 커밋**

Run: `flutter analyze lib/features/my_cage/presentation/clip_player_screen.dart lib/features/my_cage/presentation/widgets/video_controls.dart`
Expected: `No issues found!`
```bash
git add lib/features/my_cage/presentation/widgets/video_controls.dart \
        test/features/my_cage/video_controls_format_test.dart \
        lib/features/my_cage/presentation/clip_player_screen.dart pubspec.yaml pubspec.lock \
        ios/Runner/Info.plist android/app/src/main/AndroidManifest.xml
git commit -m "feat(my_cage): 공용 VideoControls(시간표시+10초 시크) 추출 + 패키지 3종 추가

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: 워터마크 오버레이 `VideoWatermark` (#3)

**Files:** Create `widgets/video_watermark.dart`

- [ ] **Step 1: 위젯 구현**

`lib/features/my_cage/presentation/widgets/video_watermark.dart`:
```dart
import 'package:flutter/material.dart';

/// 영상 우하단 워터마크(반투명 로고 + 앱 이름). 재생 화면 Stack 오버레이 전용.
/// Stack의 직접 자식으로 배치해야 한다(Positioned).
class VideoWatermark extends StatelessWidget {
  const VideoWatermark({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 8,
      bottom: 8,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.6,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png', height: 18),
              const SizedBox(width: 4),
              const Text(
                'Tera AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```
> `assets/images/logo.png`는 pubspec `assets/images/`에 이미 포함됨. 실제 오버레이 배치는 Task 6에서.

- [ ] **Step 2: analyze**

Run: `flutter analyze lib/features/my_cage/presentation/widgets/video_watermark.dart`
Expected: `No issues found!`
> 커밋은 Task 6과 함께(플레이어에서 실사용).

---

## Task 3: 썸네일 — 클라 추출 + 캐시 (#1)

**Files:** Create `data/motion_thumbnail_repository.dart` · Modify `my_cage_providers.dart`, `widgets/motion_clip_card.dart`

- [ ] **Step 1: MotionThumbnailRepository**

`lib/features/my_cage/data/motion_thumbnail_repository.dart`:
```dart
import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// motion_clips 썸네일을 클라이언트에서 생성/캐시(임시 방식).
///
/// terra-api 썸네일 엔드포인트가 없어 presigned 영상 URL의 첫 프레임을 추출해
/// 앱 캐시(JPG)에 clipId로 저장한다. 백엔드에 `GET /clips/{id}/thumbnail/url`이
/// 생기면 이 클래스 대신 그 presigned URL을 쓰도록 [motionThumbnailProvider]만
/// 교체하면 된다.
///
/// 그리드가 카드 50개를 한 번에 빌드하므로 동시 추출을 [_maxConcurrent]개로 제한.
class MotionThumbnailRepository {
  static const _subdir = 'motion_thumbs';
  static const _maxConcurrent = 3;

  int _active = 0;
  final _waiters = <Completer<void>>[];
  final Map<String, Future<File?>> _inFlight = {};

  Future<Directory> _dir() async {
    final base = await getApplicationCacheDirectory();
    final d = Directory('${base.path}/$_subdir');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  /// 캐시된 썸네일 파일. 없으면 null.
  Future<File?> getCached(String clipId) async {
    final dir = await _dir();
    final f = File('${dir.path}/$clipId.jpg');
    return f.existsSync() ? f : null;
  }

  /// 캐시에 있으면 즉시 반환. 없으면 첫 프레임 추출→저장. 실패 시 null.
  Future<File?> getOrCreate(String clipId, String presignedUrl) async {
    final cached = await getCached(clipId);
    if (cached != null) return cached;

    final existing = _inFlight[clipId];
    if (existing != null) return existing;

    final future = _gen(clipId, presignedUrl);
    _inFlight[clipId] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(clipId);
    }
  }

  Future<File?> _gen(String clipId, String presignedUrl) async {
    await _acquire();
    try {
      final dir = await _dir();
      final path = await VideoThumbnail.thumbnailFile(
        video: presignedUrl,
        thumbnailPath: '${dir.path}/$clipId.jpg',
        imageFormat: ImageFormat.JPEG,
        maxWidth: 320,
        quality: 70,
      );
      // resolve된 video_thumbnail이 XFile?을 반환하면 `path?.path`로 맞춰라.
      if (path == null) return null;
      final f = File(path);
      return f.existsSync() ? f : null;
    } catch (_) {
      return null; // 추출 실패 → 카드가 아이콘 폴백
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_active < _maxConcurrent) {
      _active++;
      return;
    }
    final c = Completer<void>();
    _waiters.add(c);
    await c.future; // _release가 슬롯을 넘겨줌(active는 그대로)
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete(); // 대기자에게 슬롯 이양
    } else {
      _active--;
    }
  }
}
```

- [ ] **Step 2: Provider 2개 추가**

`my_cage_providers.dart` import 블록에 추가:
```dart
import 'dart:io';

import '../data/motion_thumbnail_repository.dart';
```
> `dart:io`가 이미 import돼 있으면 중복 금지(현재 없음 — 확인).

`// ── 캐시 Repository Provider ──` 구역 위, 모션 클립 구역 끝(현재 line 291 뒤)에 추가:
```dart
// ── 모션 클립 썸네일 (클라 추출, #1) ───────────────────────────────────────────
// 후속: terra-api GET /clips/{id}/thumbnail/url 확정 시, 아래 provider가
// getOrCreate 대신 presigned 썸네일 URL을 반환하도록 교체(카드는 그대로).

final motionThumbnailRepositoryProvider =
    Provider<MotionThumbnailRepository>((ref) => MotionThumbnailRepository());

/// 모션 클립 썸네일 파일(첫 프레임 추출+캐시). 없으면 null → 카드 아이콘 폴백.
final motionThumbnailProvider =
    FutureProvider.autoDispose.family<File?, String>((ref, clipId) async {
  final url = await ref.watch(motionClipUrlProvider(clipId).future);
  return ref.watch(motionThumbnailRepositoryProvider).getOrCreate(clipId, url);
});
```

- [ ] **Step 3: MotionClipCard 썸네일 배선**

`widgets/motion_clip_card.dart`를 아래로 교체(아이콘 placeholder → 실제 썸네일, `ConsumerWidget`화):
```dart
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_tag.dart';
import '../../../../shared/widgets/skeleton_loading.dart';
import '../../domain/clip_action.dart';
import '../../domain/motion_clip.dart';
import '../my_cage_providers.dart';

/// 모션 클립 그리드 카드. 상단은 클라 추출 썸네일(로딩=스켈레톤, 실패=아이콘).
/// (후속: 분류 태그 확정 시 하단 Row에 태그 칩 — clip.action 이미 반영됨.)
class MotionClipCard extends ConsumerWidget {
  const MotionClipCard({super.key, required this.clip, required this.onTap});

  final MotionClip clip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final timeLabel =
        DateFormat('MM.dd HH:mm').format(clip.startedAt.toLocal());
    final durationLabel = 'clip_duration_seconds'.tr(
      namedArgs: {'seconds': clip.durationSec.round().toString()},
    );
    final thumbAsync = ref.watch(motionThumbnailProvider(clip.id));

    return Card(
      clipBehavior: ui.Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: thumbAsync.when(
                data: (file) => file != null
                    ? Image.file(file,
                        fit: BoxFit.cover, width: double.infinity)
                    : _placeholder(cs),
                loading: () => const SkeletonLoading(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 0),
                error: (_, __) => _placeholder(cs),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child:
                        Text(timeLabel, style: theme.textTheme.bodySmall),
                  ),
                  AppTag(
                    label: clip.action == null
                        ? 'clip_action_unlabeled'.tr()
                        : clipActionKey(clip.action!).tr(),
                    color: clip.action == null ? cs.outline : cs.secondary,
                  ),
                  const SizedBox(width: 6),
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

  Widget _placeholder(ColorScheme cs) {
    return Container(
      color: cs.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.play_circle_outline,
          color: cs.onSurface.withValues(alpha: 0.35), size: 40),
    );
  }
}
```

- [ ] **Step 4: analyze + 커밋**

Run: `flutter analyze lib/features/my_cage/data/motion_thumbnail_repository.dart lib/features/my_cage/presentation/my_cage_providers.dart lib/features/my_cage/presentation/widgets/motion_clip_card.dart`
Expected: `No issues found!`
```bash
git add lib/features/my_cage/data/motion_thumbnail_repository.dart \
        lib/features/my_cage/presentation/my_cage_providers.dart \
        lib/features/my_cage/presentation/widgets/motion_clip_card.dart
git commit -m "feat(my_cage): 모션 클립 썸네일 클라 추출+캐시(video_thumbnail) — #1

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: 즐겨찾기 저장소 (#4, UI 제외)

**Files:** Create `domain/favorite_clip.dart`(+`.g.dart`), `data/favorite_clip_repository.dart` · Modify `data/motion_clip_repository.dart`, `my_cage_providers.dart`, `main.dart`

- [ ] **Step 1: FavoriteClip Hive 모델**

`lib/features/my_cage/domain/favorite_clip.dart`:
```dart
import 'package:hive/hive.dart';

part 'favorite_clip.g.dart';

/// 즐겨찾기한 모션 클립(로컬 보관). mp4는 [filePath]에 앱 문서 디렉토리로 영구
/// 저장되어 presigned URL 만료·R2 삭제와 무관하게 오프라인 재생된다.
@HiveType(typeId: 11)
class FavoriteClip extends HiveObject {
  @HiveField(0)
  final String clipId;
  @HiveField(1)
  final String cameraId;
  @HiveField(2)
  final DateTime startedAt;
  @HiveField(3)
  final double durationSec;
  @HiveField(4)
  final String filePath;
  @HiveField(5)
  final int sizeBytes;
  @HiveField(6)
  final DateTime favoritedAt;

  FavoriteClip({
    required this.clipId,
    required this.cameraId,
    required this.startedAt,
    required this.durationSec,
    required this.filePath,
    required this.sizeBytes,
    required this.favoritedAt,
  });
}
```

- [ ] **Step 2: 어댑터 생성 (build_runner)**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `favorite_clip.g.dart` 생성(`FavoriteClipAdapter`, typeId 11). 기존 어댑터 재생성돼도 무해.

- [ ] **Step 3: MotionClipRepository.getById 추가**

`data/motion_clip_repository.dart`의 `getPlaybackUrl` 메서드 아래에 추가:
```dart
  /// 단일 모션 클립 조회(즐겨찾기 메타용). 없으면 null. RLS 본인 것만.
  Future<MotionClip?> getById(String clipId) async {
    final rows = await _supabase
        .from('motion_clips')
        .select()
        .eq('id', clipId)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return MotionClip.fromJson(list.first as Map<String, dynamic>);
  }
```

- [ ] **Step 4: FavoriteClipRepository**

`lib/features/my_cage/data/favorite_clip_repository.dart`:
```dart
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/safe_hive.dart';
import '../domain/favorite_clip.dart';
import '../domain/motion_clip.dart';

/// 즐겨찾기 = 로컬 Hive 메타 + 앱 문서 디렉토리 mp4 영구보관(캐시 LRU와 분리).
/// main()에서 [init] 선 실행.
class FavoriteClipRepository {
  static const _boxName = 'favorite_clips';
  static const _subdir = 'favorite_clips';

  Box<FavoriteClip> get _box => Hive.box<FavoriteClip>(_boxName);

  static Future<void> init() async {
    Hive.registerAdapter(FavoriteClipAdapter());
    await openBoxSafely<FavoriteClip>(_boxName);
    final dir = await _favDir();
    if (!dir.existsSync()) dir.createSync(recursive: true);
  }

  static Future<Directory> _favDir() async {
    final base = await getApplicationDocumentsDirectory(); // 영구(캐시 아님)
    return Directory('${base.path}/$_subdir');
  }

  bool isFavorite(String clipId) => _box.containsKey(clipId);

  /// 카메라의 즐겨찾기 목록(최근 저장순).
  List<FavoriteClip> listByCamera(String cameraId) {
    return _box.values.where((f) => f.cameraId == cameraId).toList()
      ..sort((a, b) => b.favoritedAt.compareTo(a.favoritedAt));
  }

  /// 로컬 mp4 파일(오프라인 재생용). 없으면 null.
  File? getLocalFile(String clipId) {
    final meta = _box.get(clipId);
    if (meta == null) return null;
    final f = File(meta.filePath);
    return f.existsSync() ? f : null;
  }

  /// 즐겨찾기 추가 = presigned URL로 mp4 다운로드 → 문서 디렉토리 저장 → 메타 INSERT.
  Future<void> add(MotionClip clip, String presignedUrl) async {
    if (_box.containsKey(clip.id)) return;
    final resp = await http.get(Uri.parse(presignedUrl));
    if (resp.statusCode != 200) {
      throw Exception('favorite download failed: ${resp.statusCode}');
    }
    final bytes = resp.bodyBytes;
    final dir = await _favDir();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final path = '${dir.path}/${clip.id}.mp4';
    await File(path).writeAsBytes(bytes);
    await _box.put(
      clip.id,
      FavoriteClip(
        clipId: clip.id,
        cameraId: clip.cameraId,
        startedAt: clip.startedAt,
        durationSec: clip.durationSec,
        filePath: path,
        sizeBytes: bytes.length,
        favoritedAt: DateTime.now(),
      ),
    );
  }

  /// 즐겨찾기 해제 = 로컬 파일 삭제 + 메타 삭제. 해제된 클립의 cameraId 반환(목록 갱신용).
  Future<String?> remove(String clipId) async {
    final meta = _box.get(clipId);
    if (meta == null) return null;
    final cameraId = meta.cameraId;
    final f = File(meta.filePath);
    if (f.existsSync()) {
      try {
        await f.delete();
      } catch (_) {}
    }
    await meta.delete();
    return cameraId;
  }
}
```

- [ ] **Step 5: Provider 3개 추가**

`my_cage_providers.dart` import에 추가:
```dart
import '../data/favorite_clip_repository.dart';
import '../domain/favorite_clip.dart';
```
`// ── 캐시 Repository Provider ──` 구역(파일 하단 `videoCacheRepositoryProvider` 아래)에 추가:
```dart
// ── 즐겨찾기 (로컬, #4) ─────────────────────────────────────────────────────────

final favoriteClipRepositoryProvider =
    Provider<FavoriteClipRepository>((ref) => FavoriteClipRepository());

/// 카메라의 즐겨찾기 목록(로컬). add/remove 후 invalidate로 갱신.
final favoriteClipsProvider =
    Provider.autoDispose.family<List<FavoriteClip>, String>((ref, cameraId) {
  return ref.watch(favoriteClipRepositoryProvider).listByCamera(cameraId);
});

/// 특정 클립 즐겨찾기 여부. add/remove 후 invalidate.
final isFavoriteProvider =
    Provider.autoDispose.family<bool, String>((ref, clipId) {
  return ref.watch(favoriteClipRepositoryProvider).isFavorite(clipId);
});
```

- [ ] **Step 6: main.dart 초기화**

`main.dart` line 66 `await VideoCacheRepository.init();` **바로 아래**에 추가:
```dart
  await FavoriteClipRepository.init();
```
그리고 import에 `import 'features/my_cage/data/favorite_clip_repository.dart';` 추가(경로는 main.dart의 기존 import 스타일에 맞춰라).

- [ ] **Step 7: analyze + 커밋**

Run: `flutter analyze lib/features/my_cage/domain/favorite_clip.dart lib/features/my_cage/data/favorite_clip_repository.dart lib/features/my_cage/data/motion_clip_repository.dart lib/features/my_cage/presentation/my_cage_providers.dart lib/main.dart`
Expected: `No issues found!`
```bash
git add lib/features/my_cage/domain/favorite_clip.dart \
        lib/features/my_cage/domain/favorite_clip.g.dart \
        lib/features/my_cage/data/favorite_clip_repository.dart \
        lib/features/my_cage/data/motion_clip_repository.dart \
        lib/features/my_cage/presentation/my_cage_providers.dart lib/main.dart
git commit -m "feat(my_cage): 즐겨찾기 로컬 저장소(Hive+문서디렉토리 mp4 영구보관) — #4

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 저장 + 공유 서비스 (#2)

**Files:** Create `data/video_export_service.dart` · Modify `my_cage_providers.dart`

- [ ] **Step 1: VideoExportService**

`lib/features/my_cage/data/video_export_service.dart`:
```dart
import 'dart:io';

import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 영상 기기 저장(사진앱) + 공유. 로컬 파일이 있으면 재다운로드 없이 사용,
/// 없으면 presigned URL을 임시파일로 내려받아 처리.
class VideoExportService {
  Future<File> _resolveFile(
      String clipId, File? localFile, String? presignedUrl) async {
    if (localFile != null) return localFile;
    final resp = await http.get(Uri.parse(presignedUrl!));
    if (resp.statusCode != 200) {
      throw Exception('download failed: ${resp.statusCode}');
    }
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$clipId.mp4');
    await f.writeAsBytes(resp.bodyBytes);
    return f;
  }

  /// 사진앱(갤러리)에 저장. 권한 없으면 요청.
  Future<void> saveToGallery(String clipId,
      {File? localFile, String? presignedUrl}) async {
    final file = await _resolveFile(clipId, localFile, presignedUrl);
    if (!await Gal.hasAccess()) {
      await Gal.requestAccess();
    }
    await Gal.putVideo(file.path, album: 'Tera AI');
  }

  /// OS 공유 시트로 영상 공유.
  Future<void> share(String clipId,
      {File? localFile, String? presignedUrl}) async {
    final file = await _resolveFile(clipId, localFile, presignedUrl);
    await Share.shareXFiles([XFile(file.path)]);
  }
}
```
> resolve된 share_plus가 11.x라 `Share.shareXFiles`가 없으면 `SharePlus.instance.share(ShareParams(files: [XFile(file.path)]))`로 맞춰라. (Task 0에서 `^10.1.4`로 핀했으므로 10.x 유지 — `Share.shareXFiles` 정상.)

- [ ] **Step 2: Provider 추가**

`my_cage_providers.dart` import에 `import '../data/video_export_service.dart';` 추가. 즐겨찾기 구역 아래에:
```dart
final videoExportServiceProvider =
    Provider<VideoExportService>((ref) => VideoExportService());
```

- [ ] **Step 3: analyze**

Run: `flutter analyze lib/features/my_cage/data/video_export_service.dart lib/features/my_cage/presentation/my_cage_providers.dart`
Expected: `No issues found!`
> 커밋은 Task 6과 함께(플레이어에서 실사용).

---

## Task 6: MotionClipPlayerScreen 전면 개편 (#2·#3·#5 + #4 재생)

**Files:** Modify(전면) `motion_clip_player_screen.dart` · Modify `ko.json`

**동작:** 진입 시 즐겨찾기면 로컬 파일 재생(오프라인), 아니면 presigned URL. 영상 위 워터마크 오버레이 + 하단 공용 컨트롤. 앱바에 즐겨찾기(★)/저장(⬇)/공유(⤴).

- [ ] **Step 1: ko.json 키 추가**

`assets/l10n/ko.json`에 추가(`camera_detail_clips_empty` 근처):
```json
  "clip_save": "저장",
  "clip_share": "공유",
  "clip_saving": "저장 중…",
  "clip_saved_to_gallery": "사진 앱에 저장했어요",
  "clip_save_failed": "저장에 실패했어요",
  "clip_favorite_add": "즐겨찾기",
  "clip_favorite_saving": "즐겨찾기에 저장 중…",
  "clip_favorite_added": "즐겨찾기에 저장했어요",
  "clip_favorite_removed": "즐겨찾기에서 뺐어요",
```
> JSON 마지막 항목 콤마 유의(뒤에 다른 키가 오도록 배치).

- [ ] **Step 2: 파일 전면 교체**

`lib/features/my_cage/presentation/motion_clip_player_screen.dart` 전체를 아래로 교체:
```dart
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_styles.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/motion_clip.dart';
import 'my_cage_providers.dart';
import 'widgets/video_controls.dart';
import 'widgets/video_watermark.dart';

/// motion_clips 재생. 즐겨찾기면 로컬 파일(오프라인), 아니면 terra-api presigned URL.
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
  bool _busy = false; // 저장/공유/즐겨찾기 진행 중

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init({bool isRetry = false}) async {
    try {
      // 즐겨찾기(로컬 파일) 우선 — 오프라인 재생 가능
      final localFile =
          ref.read(favoriteClipRepositoryProvider).getLocalFile(widget.clipId);
      final VideoPlayerController controller;
      if (localFile != null) {
        controller = VideoPlayerController.file(localFile);
      } else {
        if (isRetry) ref.invalidate(motionClipUrlProvider(widget.clipId));
        final url = await ref.read(motionClipUrlProvider(widget.clipId).future);
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
      }
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

  /// 로컬 파일 있으면 그걸, 없으면 presigned URL을 확보해 저장/공유에 넘긴다.
  Future<({File? file, String? url})> _source() async {
    final f = ref.read(favoriteClipRepositoryProvider).getLocalFile(widget.clipId);
    if (f != null) return (file: f, url: null);
    final url = await ref.read(motionClipUrlProvider(widget.clipId).future);
    return (file: null, url: url);
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('clip_saving'.tr())));
    try {
      final src = await _source();
      await ref.read(videoExportServiceProvider).saveToGallery(
            widget.clipId,
            localFile: src.file,
            presignedUrl: src.url,
          );
      messenger.showSnackBar(
          SnackBar(content: Text('clip_saved_to_gallery'.tr())));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('clip_save_failed'.tr())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final src = await _source();
      await ref.read(videoExportServiceProvider).share(
            widget.clipId,
            localFile: src.file,
            presignedUrl: src.url,
          );
    } catch (_) {
      // 공유 취소/실패는 조용히 무시
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleFavorite(MotionClip? clip) async {
    if (_busy) return;
    setState(() => _busy = true);
    final repo = ref.read(favoriteClipRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (repo.isFavorite(widget.clipId)) {
        final cameraId = await repo.remove(widget.clipId);
        ref.invalidate(isFavoriteProvider(widget.clipId));
        if (cameraId != null) ref.invalidate(favoriteClipsProvider(cameraId));
        messenger.showSnackBar(
            SnackBar(content: Text('clip_favorite_removed'.tr())));
      } else {
        if (clip == null) return; // 오프라인 등 메타 없음 → 추가 불가
        messenger.showSnackBar(
            SnackBar(content: Text('clip_favorite_saving'.tr())));
        final url =
            await ref.read(motionClipUrlProvider(widget.clipId).future);
        await repo.add(clip, url);
        ref.invalidate(isFavoriteProvider(widget.clipId));
        ref.invalidate(favoriteClipsProvider(clip.cameraId));
        messenger.showSnackBar(
            SnackBar(content: Text('clip_favorite_added'.tr())));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('clip_save_failed'.tr())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

    final clip = ref.watch(motionClipProvider(widget.clipId)).valueOrNull;
    final isFav = ref.watch(isFavoriteProvider(widget.clipId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? Colors.redAccent : Colors.white),
            tooltip: 'clip_favorite_add'.tr(),
            onPressed: _busy ? null : () => _toggleFavorite(clip),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'clip_save'.tr(),
            onPressed: _busy ? null : _save,
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'clip_share'.tr(),
            onPressed: _busy ? null : _share,
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          if (!_initialized)
            const AspectRatio(
              aspectRatio: 16 / 9,
              child: SkeletonLoading(
                  width: double.infinity, height: double.infinity, borderRadius: 0),
            )
          else
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: Stack(
                children: [
                  Positioned.fill(child: VideoPlayer(_controller!)),
                  const VideoWatermark(),
                ],
              ),
            ),
          if (_initialized && _controller != null)
            VideoControls(controller: _controller!),
          const Spacer(),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: motionClipProvider 추가**

`my_cage_providers.dart` 모션 클립 구역(`motionClipUrlProvider` 아래)에 추가:
```dart
/// 단일 모션 클립 메타(즐겨찾기 추가·재생화면 제목용). 없으면 null.
final motionClipProvider =
    FutureProvider.autoDispose.family<MotionClip?, String>((ref, clipId) async {
  return ref.watch(motionClipRepositoryProvider).getById(clipId);
});
```

- [ ] **Step 4: analyze + 커밋 (Task 2·5·6 함께)**

Run: `flutter analyze`
Expected: 신규/수정 파일 이슈 0.
```bash
git add lib/features/my_cage/presentation/widgets/video_watermark.dart \
        lib/features/my_cage/data/video_export_service.dart \
        lib/features/my_cage/presentation/motion_clip_player_screen.dart \
        lib/features/my_cage/presentation/my_cage_providers.dart \
        assets/l10n/ko.json
git commit -m "feat(my_cage): 모션 재생화면 개편 — 시크·워터마크·갤러리저장·공유·즐겨찾기 — #2/#3/#5

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: 비디오 기록 [전체 | 즐겨찾기] 토글 (#4 UI)

**Files:** Modify `camera_detail_screen.dart`, `my_cage_providers.dart`, `ko.json`

**동작:** `_VideoLogSection` 상단에 [전체 | 즐겨찾기] 세그먼트. 전체=기존(motion_clips+필터바). 즐겨찾기=로컬 목록 그리드(필터바 숨김), 탭 시 로컬 재생.

- [ ] **Step 1: ko.json 키 추가**
```json
  "clip_tab_all": "전체",
  "clip_tab_favorites": "즐겨찾기",
  "clip_favorites_empty": "즐겨찾기한 영상이 없어요",
```

- [ ] **Step 2: 탭 상태 provider 추가**

`my_cage_providers.dart` 즐겨찾기 구역에 추가:
```dart
/// 비디오 기록 탭(false=전체, true=즐겨찾기). autoDispose — 화면 이탈 시 리셋.
final showFavoritesTabProvider = StateProvider.autoDispose<bool>((ref) => false);
```

- [ ] **Step 3: `_VideoLogSection` 개편**

`camera_detail_screen.dart` import에 추가:
```dart
import '../domain/favorite_clip.dart';
```
`_VideoLogSection.build`(현재 line 519-571)를 아래로 교체:
```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final showFav = ref.watch(showFavoritesTabProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'crecam_detail_video_log'.tr(),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            _VideoTabToggle(showFavorites: showFav),
          ],
        ),
        const SizedBox(height: 12),
        if (showFav)
          _FavoritesGrid(cameraId: cameraId)
        else ...[
          _FilterBar(cameraId: cameraId),
          const SizedBox(height: 12),
          if (kShowVerifyClip) ...[
            _VerifyClipsSection(ref: ref),
            const SizedBox(height: 12),
          ],
          _AllClipsGrid(cameraId: cameraId),
        ],
      ],
    );
  }
```
그리고 기존 `clipsAsync.when(...)` 그리드 로직을 새 private 위젯 `_AllClipsGrid`로 옮긴다(동일 로직 이동 — `_buildSkeletonList`/`_buildEmptyAction`/`_buildError`도 이 위젯의 메서드로). `_VideoLogSection`은 위 build만 남긴다.

`_AllClipsGrid`(기존 그리드 로직 그대로 이동):
```dart
class _AllClipsGrid extends ConsumerWidget {
  const _AllClipsGrid({required this.cameraId});
  final String cameraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(clipDayFilterProvider);
    final actionFilter = ref.watch(clipActionFilterProvider);
    final clipsAsync =
        ref.watch(motionClipsProvider((cameraId: cameraId, day: day)));
    return clipsAsync.when(
      loading: () => _buildSkeletonList(),
      error: (e, _) => _buildError(context, ref),
      data: (clips) {
        final filtered = actionFilter == null
            ? clips
            : clips
                .where((c) => actionFilter == 'unlabeled'
                    ? c.action == null
                    : c.action == actionFilter)
                .toList();
        if (filtered.isEmpty) return _buildEmptyAction(context);
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.15,
          children: filtered
              .map((c) => MotionClipCard(
                    clip: c,
                    onTap: () => context.push('/crecam/motion-clips/${c.id}'),
                  ))
              .toList(),
        );
      },
    );
  }

  // _buildSkeletonList / _buildEmptyAction / _buildError:
  // 기존 _VideoLogSection의 동일 메서드를 그대로 이 클래스로 옮긴다.
  // (_buildError의 invalidate 대상 motionClipsProvider 유지)
}
```
> `_buildSkeletonList`/`_buildEmptyAction`/`_buildError` 3개 메서드는 기존 코드(현재 line 573-629)를 **그대로** `_AllClipsGrid`로 이동. 시그니처·내용 변경 없음.

- [ ] **Step 4: 토글 + 즐겨찾기 그리드 위젯 추가**

`camera_detail_screen.dart` 하단(파일 끝, `_VerifyClipsSection` 뒤)에 추가:
```dart
/// [전체 | 즐겨찾기] 세그먼트 토글.
class _VideoTabToggle extends ConsumerWidget {
  const _VideoTabToggle({required this.showFavorites});
  final bool showFavorites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    Widget chip(String label, bool selected, bool value) {
      return GestureDetector(
        onTap: () =>
            ref.read(showFavoritesTabProvider.notifier).state = value,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 1))
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.outline,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          chip('clip_tab_all'.tr(), !showFavorites, false),
          chip('clip_tab_favorites'.tr(), showFavorites, true),
        ],
      ),
    );
  }
}

/// 즐겨찾기 그리드(로컬). 탭 시 로컬 파일 재생(모션 재생화면이 로컬 우선).
class _FavoritesGrid extends ConsumerWidget {
  const _FavoritesGrid({required this.cameraId});
  final String cameraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final favs = ref.watch(favoriteClipsProvider(cameraId));
    if (favs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text('clip_favorites_empty'.tr(),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline)),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.15,
      children: favs
          .map((f) => MotionClipCard(
                clip: MotionClip(
                  id: f.clipId,
                  cameraId: f.cameraId,
                  startedAt: f.startedAt,
                  durationSec: f.durationSec,
                ),
                onTap: () => context.push('/crecam/motion-clips/${f.clipId}'),
              ))
          .toList(),
    );
  }
}
```
> `_FavoritesGrid`의 `MotionClipCard`는 `motionThumbnailProvider`로 썸네일을 만드는데, 로컬 파일 경로가 아니라 presigned URL을 다시 받는다. 오프라인이면 썸네일은 아이콘 폴백(재생은 로컬로 정상). 이는 허용 — 후속에 즐겨찾기 저장 시 썸네일도 함께 캐싱하면 개선.
> `_FavoritesGrid`에서 `MotionClip`을 쓰므로 `import '../domain/motion_clip.dart';`가 필요(카드 import로 이미 있으면 재확인). Step 3에서 넣은 `favorite_clip.dart` import는 `favoriteClipsProvider` 반환 타입용.

- [ ] **Step 5: analyze + 커밋**

Run: `flutter analyze`
Expected: 이슈 0.
```bash
git add lib/features/my_cage/presentation/camera_detail_screen.dart \
        lib/features/my_cage/presentation/my_cage_providers.dart assets/l10n/ko.json
git commit -m "feat(my_cage): 비디오 기록 [전체|즐겨찾기] 토글 + 즐겨찾기 그리드 — #4 UI

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## 완료 후 (push 전)

- **버전 bump**: feature → `0.12.0+22` → `0.13.0+23` (pubspec). (pre-push 훅이 lib 변경 무버전업 push 차단 — 메모리 `project_release_versioning`.)
- **flutter test**: `video_controls_format_test`(4) + 기존 전체 PASS.
- **통합검증(leegawnhun 로그인, 실기기 권장 — gal/share/video_thumbnail는 native):**
  1. 크레캠 → P4 Cam 상세 → 비디오 기록 카드에 **실제 썸네일** 표시(첫 스크롤 shimmer→이미지, 재진입 즉시).
  2. 클립 탭 → 재생 화면에서 **10초 앞뒤·진행바 시크·시간표시** 동작, **우하단 워터마크** 확인.
  3. ⬇ → 사진앱 저장 확인(첫 실행 권한 팝업). ⤴ → 공유 시트.
  4. ★ → "즐겨찾기 저장" → 상세 [즐겨찾기] 탭에 모임 → **비행기모드**로 재생(로컬).
  5. ★ 해제 → 목록/로컬 파일 제거.

---

## Self-Review

**1. Spec 커버리지:**
- #1 썸네일 → Task 3(추출+캐시+카드). 스왑 seam 문서화.
- #2 저장 → Task 5(gal) + Task 6(⬇). #2 공유(사용자 "저장+공유" 선택) → Task 5(share_plus) + Task 6(⤴).
- #3 워터마크 → Task 2 + Task 6(오버레이). 파일 각인은 범위밖(캠 개발자 핸드오프) 명시.
- #4 즐겨찾기 → Task 4(저장소) + Task 6(★·로컬우선재생) + Task 7(탭·그리드). 클라우드 동기화는 범위밖(백엔드 핸드오프).
- #5 시크 → Task 1(VideoControls) + Task 6(적용).
- gap 없음.

**2. Placeholder 스캔:** 실제 코드/명령/기대출력만. "동일 로직 이동"(Task 7 `_AllClipsGrid`)은 기존 코드 이동 지시(내용 명시)라 placeholder 아님. video_thumbnail/share_plus API 버전 분기는 "resolve된 버전에 맞춰라"로 구체 대안 제시.

**3. 타입 일관성:**
- `MotionThumbnailRepository.getOrCreate(String,String)→Future<File?>` = `motionThumbnailProvider`(→`File?`) = 카드 `thumbAsync.when(data:(File? file))`. 일치.
- `FavoriteClip{clipId,cameraId,startedAt,durationSec,filePath,sizeBytes,favoritedAt}`(typeId 11) — Task 4 정의 = repo add/list = Task 7 `_FavoritesGrid`(`f.clipId`/`f.cameraId`/`f.startedAt`/`f.durationSec`) 일치.
- `FavoriteClipRepository{isFavorite→bool, listByCamera→List<FavoriteClip>, getLocalFile→File?, add(MotionClip,String)→Future, remove(String)→Future<String?>}` — 정의 = provider = 플레이어 소비 일치.
- `MotionClipRepository.getById(String)→Future<MotionClip?>` = `motionClipProvider`(→`MotionClip?`) = 플레이어 `.valueOrNull` 일치.
- `VideoExportService{saveToGallery/share(String,{File?,String?})}` — 정의 = 플레이어 `_save`/`_share`(`localFile`/`presignedUrl` named) 일치.
- `VideoControls(controller:)` + `formatClipPosition(Duration)→String` — Task 1 정의 = ClipPlayerScreen/MotionClipPlayerScreen 사용 일치.
- `showFavoritesTabProvider`(StateProvider<bool>) = `_VideoLogSection`/`_VideoTabToggle` 소비 일치.
- `MotionClip` 생성자 named required(id,cameraId,startedAt,durationSec) + optional(motionScore,thumbnailKey,action) — Task 7 `_FavoritesGrid`가 필수 4개만 넘김(optional 생략 OK, 기존 정의 확인됨).

**주의(구현자):**
- Task 7은 기존 `_VideoLogSection`의 그리드/헬퍼를 `_AllClipsGrid`로 **이동**하는 리팩터 — 로직 변경 없이 옮기고, 남은 `_VideoLogSection`은 새 build만. 미사용 import 정리.
- gal iOS는 Info.plist 권한 필수(Task 0 Step 3) — 없으면 저장 시 크래시.
- video_thumbnail은 presigned URL 접근마다 terra-api 호출 1회 발생(그리드 진입 시 비용). 캐시로 1회성이나, 백엔드 썸네일 엔드포인트로 스왑이 정공법(핸드오프).
- 즐겨찾기 그리드 썸네일은 온라인 의존(로컬 파일 기반 썸네일은 후속). 오프라인이면 아이콘 폴백 — 재생은 로컬로 정상.
```
