import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/network/auth_session.dart';
import 'package:vivanaut/core/network/terra_rest_client.dart';
import 'package:vivanaut/features/my_cage/data/device_settings_repository.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/device_settings.dart';
import 'package:vivanaut/shared/domain/env_thresholds.dart';

class _Session implements AuthSession {
  @override
  Future<String?> accessToken() async => 'token';

  @override
  Future<bool> recoverFromUnauthorized() async => false;
}

/// PATCH 호출을 기록하고 서버처럼 보낸 값을 되돌려 준다.
class _FakeRest extends TerraRestClient {
  _FakeRest() : super(baseUrl: 'https://terra.test', session: _Session());

  (String, Map<String, dynamic>)? lastPatch;

  @override
  Future<Object?> patch(String path, Map<String, dynamic> body) async {
    lastPatch = (path, body);
    return {'device_id': 'd1', ...body};
  }
}

/// v4 적정 MIN/MAX 저장·읽기 + `devices.temp_offset_c` (계획 Task 2).
void main() {
  const base = <String, dynamic>{'id': 'd1'};

  group('DeviceSettings MIN/MAX', () {
    test(
        'MIN/MAX 패치 본문',
        () => expect(
            DeviceSettings.patchBody(targetTempMin: 17.5, targetTempMax: 29),
            {'target_temp_min': 17.5, 'target_temp_max': 29.0}));
    test(
        '습도 MIN/MAX 패치 본문',
        () => expect(
            DeviceSettings.patchBody(targetHumidMin: 35, targetHumidMax: 85),
            {'target_humid_min': 35.0, 'target_humid_max': 85.0}));
    test('보낸 필드만 — 기존 단일 목표값 본문은 그대로', () {
      expect(
          DeviceSettings.patchBody(targetTempC: 24), {'target_temp_c': 24.0});
      expect(DeviceSettings.patchBody(), isEmpty);
    });
    test(
        'tempRange 디폴트',
        () => expect(const DeviceSettings(deviceId: 'd').tempRange,
            EnvRange.tempDefault));
    test(
        'humidRange 디폴트',
        () => expect(const DeviceSettings(deviceId: 'd').humidRange,
            EnvRange.humidDefault));
    test(
        'humidRange 저장값',
        () => expect(
            const DeviceSettings(
                    deviceId: 'd', targetHumidMin: 35, targetHumidMax: 85)
                .humidRange,
            const EnvRange(35, 85)));
    test('tempRange는 서버 값을 스텝에 맞춘다', () {
      final s = DeviceSettings.fromJson(
          {'device_id': 'd', 'target_temp_min': '18.3', 'target_temp_max': 40});
      expect(s.tempRange, const EnvRange(18.5, 29));
    });

    test('repository.patch는 MIN/MAX를 함께 보낸다', () async {
      final rest = _FakeRest();
      final saved = await DeviceSettingsRepository(rest)
          .patch('d1', targetTempMin: 17.5, targetTempMax: 29);
      // 레코드 ==는 Map을 깊게 비교하지 않는다 — 칸별로 본다.
      expect(rest.lastPatch?.$1, '/devices/d1/settings');
      expect(rest.lastPatch?.$2,
          {'target_temp_min': 17.5, 'target_temp_max': 29.0});
      expect(saved.tempRange, const EnvRange(17.5, 29));
    });
  });

  group('DeviceSettings 자동 토글 (계획 2026-11-05 Task 1)', () {
    test('설정 파싱 — 자동 토글', () {
      expect(
          DeviceSettings.fromJson({'device_id': 'd', 'auto_vent_enabled': true})
              .autoVentEnabled,
          isTrue);
      expect(
          DeviceSettings.fromJson({'device_id': 'd'}).autoMistEnabled, isFalse);
      expect(
          DeviceSettings.fromJson(
              {'device_id': 'd', 'auto_mist_enabled': 'true'}).autoMistEnabled,
          isFalse);
    });
    test(
        '패치 본문 — 자동 토글만',
        () => expect(DeviceSettings.patchBody(autoVentEnabled: false),
            {'auto_vent_enabled': false}));
    test(
        '패치 본문 — 두 자동 토글',
        () => expect(
            DeviceSettings.patchBody(
                autoVentEnabled: true, autoMistEnabled: false),
            {'auto_vent_enabled': true, 'auto_mist_enabled': false}));
    test('repository.patch는 자동 토글을 넘긴다', () async {
      final rest = _FakeRest();
      final saved = await DeviceSettingsRepository(rest)
          .patch('d1', autoMistEnabled: true);
      expect(rest.lastPatch?.$2, {'auto_mist_enabled': true});
      expect(saved.autoMistEnabled, isTrue);
      expect(saved.autoVentEnabled, isFalse);
    });
  });

  group('Device.tempOffsetC', () {
    test('temp_offset_c 파싱', () {
      expect(
          Device.fromJson({...base, 'temp_offset_c': -1.5}).tempOffsetC, -1.5);
      expect(
          Device.fromJson({...base, 'temp_offset_c': 12}).tempOffsetC, isNull);
    });
    test('±10 경계는 포함, 문자열 숫자도 읽는다', () {
      expect(Device.fromJson({...base, 'temp_offset_c': 10}).tempOffsetC, 10);
      expect(Device.fromJson({...base, 'temp_offset_c': -10}).tempOffsetC, -10);
      expect(Device.fromJson({...base, 'temp_offset_c': '-1.5'}).tempOffsetC,
          -1.5);
    });
    test('없음·숫자 아님은 null (구 펌웨어)', () {
      expect(Device.fromJson(base).tempOffsetC, isNull);
      expect(Device.fromJson({...base, 'temp_offset_c': 'abc'}).tempOffsetC,
          isNull);
      expect(Device.fromJson({...base, 'temp_offset_c': true}).tempOffsetC,
          isNull);
      expect(Device.fromJson({...base, 'temp_offset_c': 'NaN'}).tempOffsetC,
          isNull);
    });
  });

  // 새 계약(서버 `APP_TEMP_OFFSET_SERVER_BASE_2026-11-05.md` §2) — 계획 Task 1.
  group('사용자 보정값 — 계약별 해석', () {
    test('행 해석 — 계약별 컬럼, 키 없음은 모름', () {
      final row = <String, dynamic>{
        'temp_offset_c': -3.5,
        'temp_offset_user_c': -2.0,
      };
      expect(userOffsetFromRow(row, userContract: true).offset,
          const TempOffset(-2.0));
      expect(userOffsetFromRow(row, userContract: false).offset,
          const TempOffset(-2.0));
      expect(
          userOffsetFromRow({'temp_offset_c': -3.5}, userContract: true).known,
          isFalse);
      expect(
          userOffsetFromRow({'temp_offset_user_c': -2.0}, userContract: false)
              .known,
          isFalse);
      expect(
          userOffsetFromRow({'temp_offset_user_c': null}, userContract: true),
          (known: true, offset: null));
      expect(userOffsetFromRow({'temp_offset_c': null}, userContract: false),
          (known: true, offset: null));
      expect(tempOffsetColumn(userContract: true), 'temp_offset_user_c');
      expect(tempOffsetColumn(userContract: false), 'temp_offset_c');
    });
    test('새 계약은 −8.5~+11.5 밖을 null로, 옛 계약은 ±10 밖을 null로', () {
      expect(
          userOffsetFromRow({'temp_offset_user_c': 11.6}, userContract: true),
          (known: true, offset: null));
      expect(userOffsetFromRow({'temp_offset_c': 12}, userContract: false),
          (known: true, offset: null));
    });
    test('Device.temp_offset_user_c·userOffsetOf', () {
      final d = Device.fromJson(
          {...base, 'temp_offset_c': -3.5, 'temp_offset_user_c': -2.0});
      expect(d.tempOffsetUserC, const TempOffset(-2.0));
      expect(userOffsetOf(d, userContract: true), const TempOffset(-2.0));
      expect(userOffsetOf(d, userContract: false), const TempOffset(-2.0));
      expect(userOffsetOf(Device.fromJson(base), userContract: true), isNull);
      expect(userOffsetOf(Device.fromJson(base), userContract: false), isNull);
      expect(
          Device.fromJson({...base, 'temp_offset_user_c': '1.0'})
              .tempOffsetUserC,
          const TempOffset(1.0));
    });
  });
}
