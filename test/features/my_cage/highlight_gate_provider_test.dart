import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/my_cage/data/highlight_repository.dart';
import 'package:vivanaut/features/my_cage/domain/nightly_highlight.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_visibility_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';

// 저장소 가짜는 highlight_camera_scope_provider_test.dart와 같은 방식(SOT).
class _Repo extends HighlightRepository {
  _Repo(this.items)
      : super(
          baseUrl: 'https://api.example',
          tokenProvider: () async => null,
          client: MockClient((_) async => throw UnimplementedError()),
        );
  final List<NightlyHighlight> items;

  @override
  Future<List<NightlyHighlight>> listFeatured({
    required String cameraId,
    int days = HighlightRepository.defaultFeaturedDays,
    String tier = 'all',
  }) async =>
      items;
}

NightlyHighlight _h(String id, String dayKey, DateTime utc) => NightlyHighlight(
    clipId: id,
    cameraId: 'cam',
    startedAt: utc.toLocal(),
    tier: 'featured',
    dayKey: dayKey,
    episodeRank: 1);

ProviderContainer _container(DateTime nowUtc) {
  final container = ProviderContainer(overrides: [
    currentUserProvider.overrideWith((ref) => null),
    selectedCrecamCameraProvider.overrideWith((ref) => 'cam'),
    hiddenClipIdsProvider.overrideWith((ref) async => <String>{}),
    highlightClockProvider.overrideWithValue(() => nowUtc),
    highlightRepositoryProvider.overrideWithValue(_Repo([
      _h('old', '2026-08-15', DateTime.utc(2026, 8, 15, 15)),
      _h('new', '2026-08-16', DateTime.utc(2026, 8, 16, 15)),
    ])),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('8/18 08:00 KST 전에는 8/16 밤 묶음이 보이지 않는다', () async {
    final groups = await _container(DateTime.utc(2026, 8, 17, 22))
        .read(highlightGroupsProvider.future);
    expect(groups.map((g) => g.dayKey), ['2026-08-15']);
  });

  test('8/18 08:00 KST부터 8/16 밤 묶음이 보인다', () async {
    final groups = await _container(DateTime.utc(2026, 8, 17, 23))
        .read(highlightGroupsProvider.future);
    expect(groups.map((g) => g.dayKey), ['2026-08-16', '2026-08-15']);
  });
}
