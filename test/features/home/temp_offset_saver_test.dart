// 온도 보정 저장기·실시간 방출 — 사용자 보정값 하나로 비교한다(계획
// docs/superpowers/plans/2026-11-05-temp-offset-user-contract.md Task 2).
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/config/feature_flags.dart';
import 'package:vivanaut/core/network/auth_session.dart';
import 'package:vivanaut/core/network/terra_rest_client.dart';
import 'package:vivanaut/features/home/presentation/temp_offset_providers.dart';
import 'package:vivanaut/features/my_cage/data/device_health_repository.dart'
    show RebootCommandState;
import 'package:vivanaut/features/my_cage/presentation/sys_health_controllers.dart'
    show commandRowProvider;
import 'package:vivanaut/shared/domain/env_thresholds.dart';

class _Session implements AuthSession {
  @override
  Future<String?> accessToken() async => 'token';

  @override
  Future<bool> recoverFromUnauthorized() async => false;
}

class _FakeRest extends TerraRestClient {
  _FakeRest() : super(baseUrl: 'https://terra.test', session: _Session());

  final List<Map<String, dynamic>?> posts = [];

  @override
  Future<Object?> post(String path, [Map<String, dynamic>? body]) async {
    posts.add(body);
    return {'id': 'c${posts.length}'};
  }
}

void main() {
  const id = 'd1';

  /// 저장기를 띄운다 — 기기 보정값은 [offsets]로, 명령 행은 [commands]로 흘린다.
  ({
    ProviderContainer container,
    StreamController<TempOffset?> offsets,
    StreamController<RebootCommandState?> commands,
    _FakeRest rest,
  }) setup({required bool userContract, required TempOffset? initial}) {
    final offsets = StreamController<TempOffset?>.broadcast();
    final commands = StreamController<RebootCommandState?>.broadcast();
    final rest = _FakeRest();
    Stream<TempOffset?> offsetStream() async* {
      yield initial;
      yield* offsets.stream;
    }

    final container = ProviderContainer(overrides: [
      tempOffsetUserContractProvider.overrideWithValue(userContract),
      terraRestClientProvider.overrideWithValue(rest),
      deviceOffsetProvider(id).overrideWith((ref) => offsetStream()),
      commandRowProvider.overrideWith((ref, _) => commands.stream),
    ]);
    addTearDown(() {
      container.dispose();
      offsets.close();
      commands.close();
    });
    container.listen(deviceOffsetProvider(id), (_, __) {});
    container.listen(tempOffsetSaveProvider(id), (_, __) {});
    return (
      container: container,
      offsets: offsets,
      commands: commands,
      rest: rest
    );
  }

  for (final userContract in [false, true]) {
    group(userContract ? '새 계약' : '옛 계약', () {
      test('기기가 사용자값 −2.0을 보고하면 saved', () async {
        final s =
            setup(userContract: userContract, initial: const TempOffset(0));
        await pumpEventQueue();
        final result = s.container
            .read(tempOffsetSaveProvider(id).notifier)
            .save(TempOffset.of(subtract: true, magnitude: 2));
        await pumpEventQueue();
        expect(s.container.read(tempOffsetSaveProvider(id)),
            const TempOffset(-2.0));
        expect(s.rest.posts.single?['payload'],
            userContract ? {'user_offset_c': -2.0} : {'offset_c': -3.5});
        // 다른 값 보고는 완료가 아니다.
        s.offsets.add(const TempOffset(-1.0));
        await pumpEventQueue();
        expect(s.container.read(tempOffsetSaveProvider(id)), isNotNull);
        s.offsets.add(const TempOffset(-2.0));
        expect(await result, TempOffsetSaveResult.saved);
        expect(s.container.read(tempOffsetSaveProvider(id)), isNull);
      });

      test('이미 같은 사용자값이면 보내지 않는다(0.1 단위 비교)', () async {
        final s =
            setup(userContract: userContract, initial: const TempOffset(-2.0));
        await pumpEventQueue();
        final result = await s.container
            .read(tempOffsetSaveProvider(id).notifier)
            .save(const TempOffset(-2.04));
        expect(result, TempOffsetSaveResult.unchanged);
        expect(s.rest.posts, isEmpty);
      });
    });
  }

  group('DeviceOffsetEmitter — 실시간 행', () {
    ({List<TempOffset?> seen, DeviceOffsetEmitter emitter}) make(
        bool userContract) {
      final controller = StreamController<TempOffset?>(sync: true);
      final seen = <TempOffset?>[];
      controller.stream.listen(seen.add);
      addTearDown(controller.close);
      return (
        seen: seen,
        emitter: DeviceOffsetEmitter(controller, userContract: userContract)
      );
    }

    test('같은 값의 행 두 번(생존 신호) → 방출 한 번', () {
      final m = make(true);
      m.emitter.onRow({'temp_offset_user_c': -2.0, 'last_seen_at': 'a'});
      m.emitter.onRow({'temp_offset_user_c': -2.0, 'last_seen_at': 'b'});
      expect(m.seen, [const TempOffset(-2.0)]);
    });

    test('계약 컬럼 키가 없는 행은 무시 — null로 덮지 않는다', () {
      final m = make(true);
      m.emitter.onRow({'temp_offset_user_c': -2.0});
      m.emitter.onRow({'temp_offset_c': -3.5});
      expect(m.seen, [const TempOffset(-2.0)]);
    });

    test('키가 있고 null이면 구 펌웨어(null) 방출', () {
      final m = make(true);
      m.emitter.onRow({'temp_offset_user_c': -2.0});
      m.emitter.onRow({'temp_offset_user_c': null});
      expect(m.seen, [const TempOffset(-2.0), null]);
    });

    test('옛 계약 — 합산값 행을 사용자값으로', () {
      final m = make(false);
      m.emitter.onRow({'temp_offset_c': -3.5, 'temp_offset_user_c': 9.0});
      m.emitter.onRow({'temp_offset_c': -3.5});
      expect(m.seen, [const TempOffset(-2.0)]);
    });

    test('첫 null도 한 번은 방출한다(조회 결과 없음)', () {
      final m = make(false);
      m.emitter.emit(null);
      m.emitter.emit(null);
      expect(m.seen, [null]);
    });
  });
}
