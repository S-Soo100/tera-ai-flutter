import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/network/auth_session.dart';
import 'package:vivanaut/core/network/terra_rest_client.dart';
import 'package:vivanaut/features/my_cage/data/temp_offset_repository.dart';
import 'package:vivanaut/shared/domain/env_thresholds.dart';

class _Session implements AuthSession {
  @override
  Future<String?> accessToken() async => 'token';

  @override
  Future<bool> recoverFromUnauthorized() async => false;
}

/// POST 호출을 기록하고 미리 정한 응답을 돌려준다.
class _FakeRest extends TerraRestClient {
  _FakeRest(this.response)
      : super(baseUrl: 'https://terra.test', session: _Session());

  final Object? response;
  (String, Map<String, dynamic>?)? lastPost;

  @override
  Future<Object?> post(String path, [Map<String, dynamic>? body]) async {
    lastPost = (path, body);
    return response;
  }
}

/// 온도 보정 기기 명령 — REST `POST /devices/{id}/commands` (계획 Task 2, G4).
void main() {
  test('보정 명령 본문·id 반환', () async {
    final fake = _FakeRest({'id': 'c1'});
    final repo = TempOffsetRepository(fake);
    expect(await repo.send('d1', const TempOffset(1.0)), 'c1');
    // 레코드 ==는 Map을 깊게 비교하지 않는다 — 칸별로 본다.
    expect(fake.lastPost?.$1, '/devices/d1/commands');
    expect(fake.lastPost?.$2, {
      'action': 'set_temp_offset',
      'payload': {'offset_c': 1.0}
    });
  });

  test('D1 임시: 끔은 offset_c 0', () async {
    final fake = _FakeRest({'id': 'c2'});
    await TempOffsetRepository(fake).send('d1', const TempOffset(0));
    expect(fake.lastPost?.$2, {
      'action': 'set_temp_offset',
      'payload': {'offset_c': 0.0}
    });
  });

  test('빼기 보정은 음수로 나간다', () async {
    final fake = _FakeRest({'id': 'c3'});
    await TempOffsetRepository(fake)
        .send('d1', TempOffset.of(subtract: true, magnitude: 1.5));
    expect(fake.lastPost?.$2?['payload'], {'offset_c': -1.5});
  });

  test('응답에 id가 없으면 null', () async {
    expect(
        await TempOffsetRepository(_FakeRest({}))
            .send('d1', const TempOffset(1)),
        isNull);
    expect(
        await TempOffsetRepository(_FakeRest(null))
            .send('d1', const TempOffset(1)),
        isNull);
    expect(
        await TempOffsetRepository(_FakeRest({'id': ''}))
            .send('d1', const TempOffset(1)),
        isNull);
  });

  test('REST 실패는 그대로 올린다', () async {
    final repo = TempOffsetRepository(_ThrowingRest());
    await expectLater(repo.send('d1', const TempOffset(1)),
        throwsA(isA<TerraRestException>()));
  });
}

class _ThrowingRest extends TerraRestClient {
  _ThrowingRest() : super(baseUrl: 'https://terra.test', session: _Session());

  @override
  Future<Object?> post(String path, [Map<String, dynamic>? body]) async =>
      throw const TerraRestException(404, 'not found');
}
