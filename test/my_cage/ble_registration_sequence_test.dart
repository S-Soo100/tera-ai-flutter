import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/data/ble_pairing_repository.dart';
import 'package:vivanaut/features/my_cage/domain/default_device_name.dart';

/// 기기 등록 시퀀스 (앱 요청서 2026-09-17).
/// 가짜 펌웨어: 각 명령에 계약대로 응답한다. [override]로 응답을 바꿔 끼운다
/// (빈 문자열 = 무응답).
({BlePairingRepository repo, List<String> sent}) _fakeDevice({
  String? Function(String cmd, int jwtReceived)? override,
}) {
  final repo = BlePairingRepository(
    ackTimeout: const Duration(milliseconds: 150),
  );
  final sent = <String>[];
  var jwtLen = 0;
  repo.debugWriteOverride = (text) async {
    sent.add(text);
    if (text.startsWith('JWT:')) jwtLen += text.length - 4;
    final custom = override?.call(text, jwtLen);
    if (custom != null) {
      if (custom.isNotEmpty) _later(() => repo.debugInjectTx(custom));
      return;
    }
    String? reply;
    if (text == 'UNPAIR') reply = 'UNPAIR_OK';
    if (text.startsWith('SSID:')) reply = 'SSID_OK';
    if (text.startsWith('PASS:')) reply = 'PASS_OK';
    if (text.startsWith('NAME:')) reply = 'NAME_OK';
    if (text.startsWith('JWT_BEGIN ')) reply = 'JWT_BEGIN_OK';
    if (text.startsWith('JWT:') && jwtLen >= 450) reply = 'JWT_OK $jwtLen';
    if (reply != null) _later(() => repo.debugInjectTx(reply!));
  };
  return (repo: repo, sent: sent);
}

void _later(void Function() f) => Future<void>.microtask(f);

final _jwt = 'a' * 450; // 200 + 200 + 50

void main() {
  test('등록 모드: UNPAIR → SSID → PASS → NAME → JWT_BEGIN → JWT×3 → CONNECT',
      () async {
    final d = _fakeDevice();
    await d.repo.sendWifiCredentials(
      ssid: 'home',
      password: 'pw',
      registration: BleRegistration(name: '사육장 1', jwt: _jwt),
    );
    expect(d.sent, [
      'UNPAIR',
      'SSID:home',
      'PASS:pw',
      'NAME:사육장 1',
      'JWT_BEGIN 450',
      'JWT:${'a' * 200}',
      'JWT:${'a' * 200}',
      'JWT:${'a' * 50}',
      'CONNECT',
    ]);
  });

  test('Wi-Fi 전용(카메라): 등록 명령 없이 SSID → PASS → CONNECT', () async {
    final d = _fakeDevice();
    await d.repo.sendWifiCredentials(ssid: 'home', password: 'pw');
    expect(d.sent, ['SSID:home', 'PASS:pw', 'CONNECT']);
  });

  test('UNPAIR 미지원 펌웨어(ERR:UNKNOWN_CMD)는 삼키고 계속 진행', () async {
    final d = _fakeDevice(
      override: (cmd, _) => cmd == 'UNPAIR' ? 'ERR:UNKNOWN_CMD' : null,
    );
    final events = <BlePairingEvent>[];
    final sub = d.repo.events.listen(events.add);
    await d.repo.sendWifiCredentials(
      ssid: 'home',
      password: 'pw',
      registration: BleRegistration(name: '사육장 1', jwt: _jwt),
    );
    await sub.cancel();
    expect(d.sent.last, 'CONNECT');
    expect(events.whereType<BlePairingErr>(), isEmpty);
  });

  test('UNPAIR 무응답이어도 시간 초과 후 계속 진행', () async {
    final d = _fakeDevice(override: (cmd, _) => cmd == 'UNPAIR' ? '' : null);
    await d.repo.sendWifiCredentials(
      ssid: 'home',
      password: 'pw',
      registration: BleRegistration(name: '사육장 1', jwt: _jwt),
    );
    expect(d.sent.last, 'CONNECT');
  });

  test('NAME_OK가 안 오면 CONNECT하지 않고 name 단계 예외', () async {
    final d = _fakeDevice(
      override: (cmd, _) => cmd.startsWith('NAME:') ? '' : null,
    );
    await expectLater(
      d.repo.sendWifiCredentials(
        ssid: 'home',
        password: 'pw',
        registration: BleRegistration(name: '사육장 1', jwt: _jwt),
      ),
      throwsA(isA<BleRegistrationException>()
          .having((e) => e.stage, 'stage', 'name')),
    );
    expect(d.sent, isNot(contains('CONNECT')));
  });

  test('JWT_OK 길이가 다르면 jwt 단계 예외', () async {
    final d = _fakeDevice(
      override: (cmd, len) =>
          cmd.startsWith('JWT:') && len >= 450 ? 'JWT_OK 400' : null,
    );
    await expectLater(
      d.repo.sendWifiCredentials(
        ssid: 'home',
        password: 'pw',
        registration: BleRegistration(name: '사육장 1', jwt: _jwt),
      ),
      throwsA(isA<BleRegistrationException>()
          .having((e) => e.stage, 'stage', 'jwt')),
    );
    expect(d.sent, isNot(contains('CONNECT')));
  });

  test('PAIR_OK / PAIR_FAIL 알림을 이벤트로 낸다', () async {
    final repo = BlePairingRepository();
    final events = <BlePairingEvent>[];
    final sub = repo.events.listen(events.add);
    repo.debugInjectTx('PAIR_OK dev-123');
    repo.debugInjectTx('PAIR_FAIL 401');
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect((events[0] as BlePairOk).deviceId, 'dev-123');
    expect((events[1] as BlePairFail).reason, '401');
  });

  group('nextDefaultDeviceName', () {
    test('첫 기기는 번호 1부터', () {
      expect(nextDefaultDeviceName('사육장', []), '사육장 1');
    });
    test('사용 중인 번호는 건너뛴다', () {
      expect(
        nextDefaultDeviceName('사육장', ['사육장 1', null, '내 사육장', '사육장 3']),
        '사육장 2',
      );
    });
  });
}
