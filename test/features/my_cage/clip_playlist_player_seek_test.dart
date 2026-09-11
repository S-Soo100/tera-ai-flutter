import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:vivnanaut/features/my_cage/data/favorite_clip_repository.dart';
import 'package:vivnanaut/features/my_cage/data/motion_clip_repository.dart';
import 'package:vivnanaut/features/my_cage/domain/favorite_clip.dart';
import 'package:vivnanaut/features/my_cage/domain/motion_clip.dart';
import 'package:vivnanaut/features/my_cage/presentation/clip_playlist_player_screen.dart';
import 'package:vivnanaut/features/my_cage/presentation/my_cage_providers.dart';

/// 재생 시작점(서버 play_from_sec) seek 검증 — 가짜 비디오 플랫폼으로
/// 초기화(duration 확보)까지 실제 흐름을 태우고 seek/play 호출을 기록한다.
///
/// ⚠️ pumpAndSettle 금지: 재생이 시작되면 position 폴링 타이머가 프레임을
/// 계속 만들어 settle이 끝나지 않는다. 유한 pump로만 진행한다.
class _FakeVideoPlatform extends VideoPlayerPlatform {
  /// 초기화 이벤트가 보고할 영상 길이(60초 고정 — 테스트 시나리오 기준).
  final Duration duration = const Duration(seconds: 60);
  final List<Duration> seeks = [];
  int playCount = 0;
  Duration _position = Duration.zero;

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose(int playerId) async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    // ⚠️ onCancel이 반드시 있어야 한다: 없으면 subscription.cancel()이
    // root zone의 공유 null future를 반환해 fake async 테스트 존에서 영영
    // 완료되지 않고, VideoPlayerController.dispose()가 그 await에 멈춘다
    // (다음 클립 전환 = 컨트롤러 교체 테스트가 이걸 밟는다).
    late final StreamController<VideoEvent> events;
    events = StreamController<VideoEvent>(
      onListen: () => events.add(VideoEvent(
        eventType: VideoEventType.initialized,
        duration: duration,
        size: const Size(1920, 1080),
      )),
      onCancel: () async {},
    );
    return events.stream;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> play(int playerId) async => playCount++;

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    seeks.add(position);
    _position = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async => _position;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.expand();
}

class _FakeFavoriteRepo implements FavoriteClipRepository {
  @override
  bool isFavorite(String clipId) => false;
  @override
  File? getLocalFile(String clipId) => null;
  @override
  FavoriteClip? getMeta(String clipId) => null;
  @override
  List<FavoriteClip> listByCamera(String cameraId) => const [];
  @override
  List<FavoriteClip> listAll() => const [];
  @override
  Future<void> add(MotionClip clip, String presignedUrl) async {}
  @override
  Future<String?> remove(String clipId) async => null;
  @override
  Future<void> syncFromCloud(MotionClipRepository motionRepo) async {}
}

MotionClip _clip(String id) => MotionClip(
      id: id,
      cameraId: 'cam-1',
      startedAt: DateTime(2026, 8, 28, 10, 21),
      durationSec: 60,
    );

Future<void> _pump(
  WidgetTester tester, {
  required String clipId,
  List<String>? playlist,
  Map<String, double> playFromSec = const {},
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        favoriteClipRepositoryProvider.overrideWithValue(_FakeFavoriteRepo()),
        motionClipProvider.overrideWith((ref, id) async => _clip(id)),
        motionClipUrlProvider
            .overrideWith((ref, id) async => 'https://example.com/$id.mp4'),
      ],
      child: MaterialApp(
        home: ClipPlaylistPlayerScreen(
          clipId: clipId,
          playlist: playlist,
          playFromSec: playFromSec,
        ),
      ),
    ),
  );
  // URL 발급 → createWithOptions → initialized 이벤트 → seek/play까지
  // 비동기 단계가 몇 번 있다. settle 대신 유한 pump.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// 위젯을 내려 컨트롤러/position 타이머를 정리한다(pending timer 방지).
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  late _FakeVideoPlatform platform;

  setUp(() {
    platform = _FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  testWidgets('playFromSec 8.8 · 영상 60초 → 초기 seek 8.8초 후 play',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await _pump(tester, clipId: 'a', playFromSec: {'a': 8.8});

    expect(platform.seeks, [const Duration(milliseconds: 8800)]);
    expect(platform.playCount, 1);
    // 중간 시작 클립 → "처음부터" 컨트롤 노출
    expect(
        find.byKey(ClipPlaylistPlayerScreen.fromStartKey), findsOneWidget);
    await _teardown(tester);
  });

  testWidgets('playFromSec 없음 → seek 없이 0초부터, "처음부터" 미노출',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await _pump(tester, clipId: 'a');

    expect(platform.seeks, isEmpty);
    expect(platform.playCount, 1);
    expect(find.byKey(ClipPlaylistPlayerScreen.fromStartKey), findsNothing);
    await _teardown(tester);
  });

  testWidgets('playFromSec 70 · 영상 60초 → seek 없음 (0초부터)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await _pump(tester, clipId: 'a', playFromSec: {'a': 70});

    expect(platform.seeks, isEmpty);
    expect(find.byKey(ClipPlaylistPlayerScreen.fromStartKey), findsNothing);
    await _teardown(tester);
  });

  testWidgets('"처음부터" 탭 → 0초로 seek 후 재생', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await _pump(tester, clipId: 'a', playFromSec: {'a': 8.8});

    await tester.tap(find.byKey(ClipPlaylistPlayerScreen.fromStartKey));
    await tester.pump(const Duration(milliseconds: 100));

    expect(platform.seeks.last, Duration.zero);
    await _teardown(tester);
  });

  testWidgets('시크바 썸 — 평소엔 숨기고 조작(드래그) 중에만 그린다',
      (tester) async {
    // 사용자 지시 2026-09-12: 재생 중 원형 커서 상시 노출 금지, 탭/드래그로
    // 재생 위치를 옮기는 동안만 표시(전 플레이어 공통 규칙).
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await _pump(tester, clipId: 'a');

    SliderThemeData sliderTheme() => tester
        .widget<SliderTheme>(find
            .ancestor(
                of: find.byType(Slider), matching: find.byType(SliderTheme))
            .first)
        .data;

    expect(sliderTheme().thumbShape, SliderComponentShape.noThumb);

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(Slider)));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump(const Duration(milliseconds: 50));
    expect(sliderTheme().thumbShape, isA<RoundSliderThumbShape>());

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 50));
    expect(sliderTheme().thumbShape, SliderComponentShape.noThumb);
    await _teardown(tester);
  });

  testWidgets('다음 클립으로 넘어가면 그 클립 값으로 다시 1회 seek',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await _pump(tester,
        clipId: 'a',
        playlist: ['a', 'b'],
        playFromSec: {'a': 8.8, 'b': 3});

    expect(platform.seeks, [const Duration(milliseconds: 8800)]);

    await tester.tap(find.byKey(ClipPlaylistPlayerScreen.nextArrowKey));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(platform.seeks, [
      const Duration(milliseconds: 8800),
      const Duration(seconds: 3),
    ]);
    expect(platform.playCount, 2);
    await _teardown(tester);
  });
}
