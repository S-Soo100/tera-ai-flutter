import 'package:vivanaut/features/my_cage/data/highlight_banner_store.dart';
import 'package:vivanaut/features/my_cage/domain/highlight_group.dart';
import 'package:vivanaut/features/my_cage/domain/highlight_publication.dart';
import 'package:vivanaut/features/my_cage/domain/nightly_highlight.dart';

/// 하이라이트 레이아웃·캡처 테스트 공용 픽스처(P12, Figma 1081:5235).
class FakeHighlightBannerStore implements HighlightBannerStore {
  FakeHighlightBannerStore([this.value]);
  String? value;

  @override
  String? load(String? ownerId) => value;

  @override
  Future<void> save(String? ownerId, String groupKey) async {
    value = groupKey;
  }
}

NightlyHighlight fixtureHighlight(
  String id,
  DateTime at, {
  required String dayKey,
  required int rank,
  DateTime? captureStart,
  DateTime? captureEnd,
}) =>
    NightlyHighlight(
      clipId: id,
      cameraId: 'cam',
      publication: captureStart == null || captureEnd == null
          ? null
          : HighlightPublication(
              batchId: dayKey,
              status: 'ready',
              captureStart: captureStart,
              captureEnd: captureEnd,
              publishedAt: captureEnd.add(const Duration(hours: 1))),
      startedAt: at,
      source: 'rule',
      reason: '움직임 3.0초',
      tier: 'featured',
      dayKey: dayKey,
      playFromSec: null,
      episodeRank: rank,
      episodeClipCount: 4,
      episodeActivitySec: 42,
    );

/// Figma 1081:5235 — "2026. 8. 28 - 8. 31" 배치 2묶음, 각 대표 6장(2줄).
List<DayHighlightGroup> figmaHighlightGroups() {
  final start = DateTime(2026, 8, 28, 22);
  final end = DateTime(2026, 8, 31, 6);
  return groupByDay([
    for (final (g, dayKey) in ['2026-08-31', '2026-08-30'].indexed)
      for (var i = 1; i <= 6; i++)
        fixtureHighlight('g${g}c$i', DateTime(2026, 8, 30 + g, 20 + i % 4, i),
            dayKey: dayKey, rank: i, captureStart: start, captureEnd: end),
  ]);
}
