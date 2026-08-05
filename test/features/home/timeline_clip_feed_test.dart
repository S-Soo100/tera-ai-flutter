import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/home/presentation/home_timeline_providers.dart';
import 'package:tera_ai/features/home/presentation/widgets/timeline_clip_feed.dart';
import 'package:tera_ai/features/my_cage/domain/motion_clip.dart';
import 'package:tera_ai/features/my_cage/presentation/my_cage_providers.dart';

MotionClip _c(String id, DateTime at, {String? action, double sec = 20}) =>
    MotionClip(
      id: id,
      cameraId: 'cam1',
      startedAt: at,
      durationSec: sec,
      action: action,
    );

Future<ProviderContainer> _pump(
    WidgetTester tester, List<MotionClip> clips) async {
  final c = ProviderContainer(overrides: [
    filteredTimelineClipsProvider.overrideWith((ref) async => clips),
    // 썸네일 조회는 네트워크라 테스트에서 항상 null(플레이스홀더)로 고정.
    motionThumbnailProvider.overrideWith((ref, id) async => null),
  ]);
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: Scaffold(body: TimelineClipFeed())),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('클립이 없으면 빈 상태 문구', (tester) async {
    await _pump(tester, const []);
    expect(find.byKey(TimelineClipFeed.emptyKey), findsOneWidget);
  });

  testWidgets('클립 개수만큼 행을 그린다', (tester) async {
    await _pump(tester, [
      _c('c1', DateTime(2026, 8, 5, 3, 12)),
      _c('c2', DateTime(2026, 8, 5, 1, 20)),
    ]);
    expect(find.byType(ClipFeedRow), findsNWidgets(2));
  });

  testWidgets('행에 시각과 녹화 길이가 보인다', (tester) async {
    await _pump(tester, [_c('c1', DateTime(2026, 8, 5, 3, 12, 0), sec: 200)]);
    expect(find.textContaining('03:12'), findsOneWidget);
    expect(find.textContaining('03m 20s'), findsOneWidget);
  });

  testWidgets('썸네일 탭 → 인라인 재생 대상이 설정된다 (화면 이동 아님)', (tester) async {
    final c = await _pump(tester, [_c('c1', DateTime(2026, 8, 5, 3, 12))]);
    await tester.tap(find.byType(ClipFeedRow).first);
    await tester.pumpAndSettle();
    expect(c.read(inlinePlayingClipProvider)?.id, 'c1');
  });

  group('formatClipDuration', () {
    test('200초 → 03m 20s', () {
      expect(formatClipDuration(200), '03m 20s');
    });

    test('15초 → 00m 15s', () {
      expect(formatClipDuration(15), '00m 15s');
    });
  });
}
