import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/domain/highlight_group.dart';
import 'package:vivanaut/features/my_cage/domain/highlight_night_policy.dart';
import 'package:vivanaut/features/my_cage/domain/highlight_publication.dart';
import 'package:vivanaut/features/my_cage/domain/nightly_highlight.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';

ProviderContainer _container(List<NightlyHighlight> highlights) {
  final container = ProviderContainer(
    overrides: [
      highlightGroupsProvider.overrideWith(
        (ref) async => groupByDay(highlights),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  // 정책 v2(2026-09-19): 공개 시각 = 밤이 시작한 날 D의 D+2일 08:00 KST.
  // 9/13 밤 묶음은 9/15 08:00 KST(=9/14 23:00 UTC)에 올라온 것으로 본다.
  test('공개 시각이 없으면 D+2일 08:00 KST를 올라온 시각으로 제공한다', () async {
    final h = NightlyHighlight(
      clipId: 'a',
      startedAt: DateTime.utc(2026, 9, 13, 15).toLocal(),
      tier: 'featured',
      dayKey: '2026-09-13',
    );
    // 실제 provider 체인에서는 applyNightPolicy가 publication을 붙여 준다.
    final group = groupByDay(applyNightPolicy([h], DateTime.utc(2026, 9, 20)));
    final container = ProviderContainer(overrides: [
      highlightGroupsProvider.overrideWith((ref) async => group),
      highlightClockProvider.overrideWithValue(() => DateTime.utc(2026, 9, 20)),
    ]);
    addTearDown(container.dispose);
    expect(
      await container.read(latestHighlightAtProvider.future),
      DateTime.utc(2026, 9, 14, 23).toLocal(),
    );
  });

  test('서버 공개 시각이 있으면 그 값을 우선한다', () async {
    final published = DateTime(2026, 9, 14, 9, 30);
    final highlight = NightlyHighlight(
      clipId: 'p',
      startedAt: DateTime(2026, 9, 13, 23),
      tier: 'featured',
      dayKey: '2026-09-13',
      publication: HighlightPublication(
        batchId: 'b1',
        captureStart: DateTime(2026, 9, 11, 22),
        captureEnd: DateTime(2026, 9, 14, 6),
        publishedAt: published,
        status: 'ready',
      ),
    );

    expect(
      await _container([highlight]).read(latestHighlightAtProvider.future),
      published,
    );
  });

  test('하이라이트가 없으면 null', () async {
    expect(await _container([]).read(latestHighlightAtProvider.future), isNull);
  });
}
