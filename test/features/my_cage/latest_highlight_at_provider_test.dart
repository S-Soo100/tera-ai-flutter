import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/domain/highlight_group.dart';
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
  // 서버에 공개 시각이 없으면 "촬영된 밤의 다음 날"을 올라온 날로 본다 —
  // 밤 촬영분은 07:00 경계 다음 날 아침에 묶여 올라온다(2026-09-19 사용자
  // 결정, 9/14 "촬영시각으로 대체 금지"를 카메라 탭 카드에 한해 대체).
  test('공개 시각이 없으면 촬영된 밤의 다음 날을 올라온 날로 제공한다', () async {
    final older = NightlyHighlight(
      clipId: 'older',
      startedAt: DateTime(2026, 9, 13, 23),
      tier: 'featured',
      dayKey: '2026-09-13',
    );
    final latest = NightlyHighlight(
      clipId: 'latest',
      startedAt: DateTime(2026, 9, 14, 1),
      tier: 'featured',
      dayKey: '2026-09-13',
    );

    expect(
      await _container([older, latest]).read(latestHighlightAtProvider.future),
      DateTime(2026, 9, 14),
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
