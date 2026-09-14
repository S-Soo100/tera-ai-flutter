import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/my_cage/domain/highlight_group.dart';
import 'package:vivnanaut/features/my_cage/domain/nightly_highlight.dart';
import 'package:vivnanaut/features/my_cage/presentation/my_cage_providers.dart';

void main() {
  test('공개 메타가 없어도 상세에 있는 최신 하이라이트 시각을 제공한다', () async {
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
      latest.startedAt,
    );
  });
}
