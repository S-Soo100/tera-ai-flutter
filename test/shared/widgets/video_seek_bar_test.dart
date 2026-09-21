import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/shared/widgets/video_seek_bar.dart';

/// 초기화만 보고하는 가짜 비디오 플랫폼(길이 60초).
class _FakeVideoPlatform extends VideoPlayerPlatform {
  @override
  Future<void> init() async {}
  @override
  Future<void> dispose(int playerId) async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    late final StreamController<VideoEvent> events;
    events = StreamController<VideoEvent>(
        onListen: () => events.add(VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(seconds: 60),
            size: const Size(1920, 1080))),
        onCancel: () async {});
    return events.stream;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Widget buildView(int playerId) => const SizedBox();
}

void main() {
  setUp(() => VideoPlayerPlatform.instance = _FakeVideoPlatform());

  Future<void> pump(WidgetTester tester, VideoPlayerController? controller,
      Future<void> Function(Duration) onSeek) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: Center(
                child: SizedBox(
                    width: 300,
                    height: 16,
                    child: VideoSeekBar(
                        controller: controller, onSeek: onSeek))))));
  }

  testWidgets('재생 중에는 원형 커서를 숨기고, 탭한 위치로 이동한다', (tester) async {
    final controller =
        VideoPlayerController.networkUrl(Uri.parse('https://example.com/a'));
    await controller.initialize();
    final seeks = <Duration>[];
    await pump(tester, controller, (d) async => seeks.add(d));
    final theme = SliderTheme.of(tester.element(find.byType(Slider)));
    expect(theme.thumbShape, SliderComponentShape.noThumb);
    await tester.tap(find.byType(Slider));
    await tester.pump();
    expect(seeks, isNotEmpty);
    expect(seeks.last.inSeconds, inInclusiveRange(25, 35));
    await tester.pumpWidget(const SizedBox());
    await controller.dispose();
  });

  testWidgets('컨트롤러가 없으면(로딩) 조작할 수 없다', (tester) async {
    await pump(tester, null, (_) async {});
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
  });
}
