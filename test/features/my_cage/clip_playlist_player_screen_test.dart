import 'package:vivnanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivnanaut/features/my_cage/presentation/thumbnail_cache_providers.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/my_cage/data/favorite_clip_repository.dart';
import 'package:vivnanaut/features/my_cage/data/motion_clip_repository.dart';
import 'package:vivnanaut/features/my_cage/domain/favorite_clip.dart';
import 'package:vivnanaut/features/my_cage/domain/motion_clip.dart';
import 'package:vivnanaut/features/my_cage/presentation/clip_playlist_player_screen.dart';
import 'package:vivnanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivnanaut/features/my_cage/presentation/widgets/motion_clip_thumb.dart';

/// Hive/Supabase를 타지 않는 대역 — 즐겨찾기 없음, 로컬 파일 없음.
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
      durationSec: 12,
    );

Future<void> _pump(
  WidgetTester tester, {
  required String clipId,
  List<String>? playlist,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(null),
        motionThumbnailFileProvider.overrideWith((ref, key) async => null),
        favoriteClipRepositoryProvider.overrideWithValue(_FakeFavoriteRepo()),
        motionClipProvider.overrideWith((ref, id) async => _clip(id)),
        // 네트워크 없는 테스트 — URL 발급을 실패시켜 비디오는 에러 상태 UI로
        // 정착시킨다(스켈레톤 shimmer가 남으면 pumpAndSettle이 끝나지 않는다).
        motionClipUrlProvider.overrideWith(
            (ref, id) => Future<String>.error(Exception('offline test'))),
      ],
      child: MaterialApp(
        home: ClipPlaylistPlayerScreen(clipId: clipId, playlist: playlist),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('현재 영상은 필름스트립 중앙에 있고 이전·다음 화살표는 없다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await _pump(tester,
        clipId: 'c6', playlist: [for (var i = 1; i <= 11; i++) 'c$i']);

    final pagination = find.byKey(ClipPlaylistPlayerScreen.paginationKey);
    expect(pagination, findsOneWidget);
    final current = find.byWidgetPredicate(
        (widget) => widget is MotionClipThumb && widget.clipId == 'c6');
    expect(tester.getCenter(current).dx, closeTo(393 / 2, 0.5));
    expect(find.byKey(ClipPlaylistPlayerScreen.prevArrowKey), findsNothing);
    expect(find.byKey(ClipPlaylistPlayerScreen.nextArrowKey), findsNothing);
  });

  testWidgets('재생목록 없음(단일 클립) — 페이지네이션을 그리지 않는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await _pump(tester, clipId: 'a');

    expect(find.byKey(ClipPlaylistPlayerScreen.paginationKey), findsNothing);
  });

  testWidgets('긴 재생목록도 가로 썸네일 스트립으로 탐색한다', (tester) async {
    // 하루치 재생목록은 쉽게 10개를 넘는다 — 숨기는 대신 같은 자리(높이 4)에
    // 진행 바로 위치를 말한다(리뷰 2026-09-04).
    await _pump(tester,
        clipId: 'c1', playlist: [for (var i = 1; i <= 11; i++) 'c$i']);
    expect(find.byKey(ClipPlaylistPlayerScreen.paginationKey), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
        tester
            .widget<ListView>(
                find.byKey(ClipPlaylistPlayerScreen.paginationKey))
            .scrollDirection,
        Axis.horizontal);
  });

  testWidgets('썸네일을 누르면 영상이 바뀌고 선택 항목이 중앙으로 이동한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await _pump(tester,
        clipId: 'c6', playlist: [for (var i = 1; i <= 11; i++) 'c$i']);

    final target = find.byWidgetPredicate(
        (widget) => widget is MotionClipThumb && widget.clipId == 'c7');
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Semantics>(find.byKey(ClipPlaylistPlayerScreen.counterKey))
            .properties
            .label,
        '7 / 11');
    expect(tester.getCenter(target).dx, closeTo(393 / 2, 0.5));
  });

  testWidgets('필름스트립 드래그 중에는 영상을 유지하고 손을 떼면 한 번 이동한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await _pump(tester,
        clipId: 'c6', playlist: [for (var i = 1; i <= 11; i++) 'c$i']);

    final strip = find.byKey(ClipPlaylistPlayerScreen.paginationKey);
    final gesture = await tester.startGesture(tester.getCenter(strip));
    // 첫 이동은 Flutter의 가로 드래그 판정 거리로 소비된다. 손가락을 계속
    // 움직이는 실제 조작처럼 다음 프레임에서 한 썸네일 폭만큼 더 이동한다.
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-34, 0));
    await tester.pump();
    expect(
        tester
            .widget<Semantics>(find.byKey(ClipPlaylistPlayerScreen.counterKey))
            .properties
            .label,
        '6 / 11');

    await gesture.up();
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Semantics>(find.byKey(ClipPlaylistPlayerScreen.counterKey))
            .properties
            .label,
        '7 / 11');
  });

  testWidgets('위치 카운터 — "n / N"이 그려지고 이동하면 바뀐다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await _pump(tester, clipId: 'a', playlist: ['a', 'b', 'c']);
    expect(find.byKey(ClipPlaylistPlayerScreen.counterKey), findsOneWidget);
    expect(
        tester
            .widget<Semantics>(find.byKey(ClipPlaylistPlayerScreen.counterKey))
            .properties
            .label,
        '1 / 3');
    final second = find.byWidgetPredicate(
        (widget) => widget is MotionClipThumb && widget.clipId == 'b');
    await tester.tap(second);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Semantics>(find.byKey(ClipPlaylistPlayerScreen.counterKey))
            .properties
            .label,
        '2 / 3');
  });

  testWidgets('단일 클립 — 필름스트립·카운터를 그리지 않는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await _pump(tester, clipId: 'a');
    expect(find.byKey(ClipPlaylistPlayerScreen.paginationKey), findsNothing);
    expect(find.byKey(ClipPlaylistPlayerScreen.counterKey), findsNothing);
  });

  testWidgets('상단바 — 현재 클립 startedAt으로 날짜·시각을 그린다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await _pump(tester, clipId: 'b', playlist: ['a', 'b']);

    expect(find.text('2026. 08. 28'), findsOneWidget);
    // 시각은 공용 formatAmPmTime(전체 문구 l10n 키) — 테스트엔
    // EasyLocalization이 없어 namedArgs 미치환 키 원문이 나온다.
    expect(find.text('time_am_fmt'), findsOneWidget);
  });
}
