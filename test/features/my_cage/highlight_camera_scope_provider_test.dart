import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/my_cage/data/highlight_repository.dart';
import 'package:vivanaut/features/my_cage/domain/nightly_highlight.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';

class _PendingHighlightRepository extends HighlightRepository {
  _PendingHighlightRepository()
      : super(
          baseUrl: 'https://api.example',
          tokenProvider: () async => null,
          client: MockClient((_) async => throw UnimplementedError()),
        );

  final requests = <String>[];
  final _pending = <String, List<Completer<List<NightlyHighlight>>>>{};

  @override
  Future<List<NightlyHighlight>> listFeatured({
    required String cameraId,
    int days = HighlightRepository.defaultFeaturedDays,
    String tier = 'all',
  }) {
    requests.add(cameraId);
    final completer = Completer<List<NightlyHighlight>>();
    _pending.putIfAbsent(cameraId, () => []).add(completer);
    return completer.future;
  }

  void completeNext(String cameraId, List<NightlyHighlight> highlights) {
    _pending[cameraId]!.removeAt(0).complete(highlights);
  }
}

NightlyHighlight _highlight(String clipId, String cameraId) => NightlyHighlight(
      clipId: clipId,
      cameraId: cameraId,
      startedAt: DateTime(2026, 9, 13, 23),
      tier: 'featured',
      dayKey: '2026-09-13',
      episodeRank: 1,
    );

ProviderContainer _container(
  _PendingHighlightRepository repository, {
  String? selectedCameraId,
}) {
  return ProviderContainer(
    overrides: [
      currentUserProvider.overrideWith((ref) => null),
      highlightRepositoryProvider.overrideWithValue(repository),
      selectedCrecamCameraProvider.overrideWith(
        (ref) => selectedCameraId,
      ),
    ],
  );
}

Future<void> _nextEventLoop() => Future<void>.delayed(Duration.zero);

void main() {
  test('선택 카메라가 없으면 요청하지 않고 빈 목록이다', () async {
    final repository = _PendingHighlightRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    expect(await container.read(highlightGroupsProvider.future), isEmpty);
    expect(repository.requests, isEmpty);
  });

  test('A→B→A 전환마다 이전 목록을 숨기고 마지막 카메라 결과만 남긴다', () async {
    final repository = _PendingHighlightRepository();
    final container = _container(repository, selectedCameraId: 'camera-a');
    addTearDown(container.dispose);
    final subscription = container.listen(
      highlightGroupsProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await _nextEventLoop();
    expect(repository.requests, ['camera-a']);

    container.read(selectedCrecamCameraProvider.notifier).state = 'camera-b';
    await _nextEventLoop();
    expect(repository.requests, ['camera-a', 'camera-b']);
    expect(container.read(highlightGroupsProvider).isLoading, isTrue);

    // 이미 선택 해제된 A의 늦은 응답은 현재 화면에 들어오면 안 된다.
    repository.completeNext(
      'camera-a',
      [_highlight('stale-a', 'camera-a')],
    );
    await _nextEventLoop();
    expect(container.read(highlightGroupsProvider).isLoading, isTrue);

    repository.completeNext(
      'camera-b',
      [_highlight('clip-b', 'camera-b')],
    );
    final bGroups = await container.read(highlightGroupsProvider.future);
    expect(bGroups.single.featured.single.clipId, 'clip-b');

    container.read(selectedCrecamCameraProvider.notifier).state = 'camera-a';
    await _nextEventLoop();
    expect(repository.requests, ['camera-a', 'camera-b', 'camera-a']);
    expect(container.read(highlightGroupsProvider).isLoading, isTrue);

    repository.completeNext(
      'camera-a',
      [_highlight('final-a', 'camera-a')],
    );
    final aGroups = await container.read(highlightGroupsProvider.future);
    expect(aGroups.single.featured.single.clipId, 'final-a');
    expect(
      aGroups.expand((group) => group.featured).map((item) => item.cameraId),
      everyElement('camera-a'),
    );
  });
}
