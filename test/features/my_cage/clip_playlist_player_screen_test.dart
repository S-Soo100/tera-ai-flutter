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
  testWidgets('재생목록 2~10개 — 페이지네이션 바가 목록 길이만큼 보인다',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await _pump(tester, clipId: 'b', playlist: ['a', 'b', 'c']);

    final pagination =
        find.byKey(ClipPlaylistPlayerScreen.paginationKey);
    expect(pagination, findsOneWidget);
    // 균등 바 3개
    final row = tester.widget<Row>(pagination);
    expect(row.children.whereType<Expanded>().length, 3);
  });

  testWidgets('재생목록 없음(단일 클립) — 페이지네이션을 그리지 않는다',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await _pump(tester, clipId: 'a');

    expect(find.byKey(ClipPlaylistPlayerScreen.paginationKey), findsNothing);
  });

  testWidgets('재생목록 10개 초과 — 페이지네이션을 그리지 않는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    final ids = List.generate(11, (i) => 'clip-$i');
    await _pump(tester, clipId: 'clip-0', playlist: ids);

    expect(find.byKey(ClipPlaylistPlayerScreen.paginationKey), findsNothing);
  });

  testWidgets('상단바 — 현재 클립 startedAt으로 날짜·시각을 그린다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await _pump(tester, clipId: 'b', playlist: ['a', 'b']);

    expect(find.text('2026. 08. 28'), findsOneWidget);
    // 오전/오후 라벨은 l10n 키 — 테스트엔 EasyLocalization이 없어 키가
    // 그대로 나오므로 시:분만 확인한다.
    expect(find.textContaining('10:21'), findsOneWidget);
  });
}
