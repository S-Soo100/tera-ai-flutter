import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/my_cage/domain/highlight_group.dart';
import 'package:vivnanaut/features/my_cage/domain/nightly_highlight.dart';
import 'package:vivnanaut/features/my_cage/presentation/my_cage_providers.dart';

void main() {
  test('오늘 새벽 영상도 개별 촬영시각 대신 밤 묶음 날짜를 제공한다', () async {
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
    final container = ProviderContainer(
      overrides: [
        highlightGroupsProvider.overrideWith(
          (ref) async => groupByDay([older, latest]),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(latestHighlightAtProvider.future),
      DateTime(2026, 9, 13),
    );
  });
}
