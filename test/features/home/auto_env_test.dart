import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/home/domain/auto_env.dart';
import 'package:vivanaut/features/home/presentation/auto_env_providers.dart';
import 'package:vivanaut/features/my_cage/data/device_settings_repository.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/device_settings.dart';
import 'package:vivanaut/features/my_cage/presentation/device_settings_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/supabase_module_providers.dart';

/// 서버 대신 설정을 돌려주는 가짜 저장소. [patchResponse]가 있으면 PATCH가
/// 그 본문을 그대로 돌려준다(필드를 무시하는 마이그레이션 전 서버 흉내).
/// 없으면 서버처럼 보낸 값을 반영해 돌려준다.
class _FakeSettingsRepo implements DeviceSettingsRepository {
  _FakeSettingsRepo({this.patchResponse, this.patchGate});

  final Map<String, dynamic>? patchResponse;
  final Completer<void>? patchGate;
  final patches = <Map<String, dynamic>>[];
  var gets = 0;

  @override
  Future<DeviceSettings> get(String deviceId) async {
    gets++;
    return DeviceSettings(deviceId: deviceId);
  }

  @override
  Future<DeviceSettings> patch(
    String deviceId, {
    double? targetTempC,
    double? targetHumidityPct,
    double? targetTempMin,
    double? targetTempMax,
    double? targetHumidMin,
    double? targetHumidMax,
    bool? autoVentEnabled,
    bool? autoMistEnabled,
  }) async {
    final body = DeviceSettings.patchBody(
        autoVentEnabled: autoVentEnabled, autoMistEnabled: autoMistEnabled);
    patches.add(body);
    if (patchGate != null) await patchGate!.future;
    return DeviceSettings.fromJson(
        patchResponse ?? {'device_id': deviceId, ...body});
  }
}

ProviderContainer _containerWith(_FakeSettingsRepo repo) {
  final c = ProviderContainer(overrides: [
    deviceSettingsRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(c.dispose);
  return c;
}

/// 자동 환기·분무 설정·상태 도메인(계획 2026-11-05 Task 1).
void main() {
  const linkBase = <String, dynamic>{'is_online': true, 'last_seen_at': null};

  group('AutoEnvState', () {
    test('auto_env_state 파싱', () {
      expect(
          AutoEnvState.fromJson({
            'vent': {'active': true}
          }).ventActive,
          isTrue);
      expect(AutoEnvState.fromJson(null), AutoEnvState.none);
      expect(AutoEnvState.fromJson({'vent': 'x'}), AutoEnvState.none);
    });

    test('active가 정확히 true일 때만 켜짐 — 문자열·숫자·누락은 꺼짐', () {
      for (final raw in <Object?>[
        {
          'vent': {'active': 'true'}
        },
        {
          'vent': {'active': 1}
        },
        {'vent': <String, dynamic>{}},
        {
          'mist': {'today_count': 1}
        },
        'not json',
        42,
        <Object?>[],
      ]) {
        expect(AutoEnvState.fromJson(raw), AutoEnvState.none, reason: '$raw');
      }
    });

    test('계약 C3 예시 행 그대로', () {
      final s = AutoEnvState.fromJson({
        'vent': {
          'active': true,
          'causes': ['humid_high'],
          'since': '2026-11-05T05:10:00+00:00',
          'paused_until': null,
          'schedule_hold': false,
          'runtime_today_sec': 5400,
        },
        'mist': {'last_at': '2026-11-05T02:00:00+00:00', 'today_count': 1},
        'day': '2026-11-05',
      });
      expect(s, const AutoEnvState(ventActive: true));
    });

    test('문자열 JSON도 읽는다(LCD 설정과 같은 Realtime 대비)', () {
      expect(
          AutoEnvState.fromJson('{"vent":{"active":true}}').ventActive, isTrue);
    });

    test('값으로 비교한다', () {
      expect(
          const AutoEnvState(ventActive: true),
          AutoEnvState.fromJson({
            'vent': {'active': true}
          }));
      expect(const AutoEnvState(ventActive: true).hashCode,
          const AutoEnvState(ventActive: true).hashCode);
      expect(const AutoEnvState(ventActive: true), isNot(AutoEnvState.none));
    });
  });

  group('AutoEnvReason', () {
    test('reason wire', () {
      expect(AutoEnvReason.fromWire('auto_vent:humid_high+temp_high'),
          AutoEnvReason.ventBoth);
      expect(AutoEnvReason.fromWire('auto_mist'), AutoEnvReason.mist);
      expect(AutoEnvReason.fromWire('nope'), isNull);
      expect(
          AutoEnvReason.ventHumidHigh.labelKey, 'auto_reason_vent_humid_high');
    });

    test('계약 C2 여덟 값 전부', () {
      expect(
          {
            'auto_vent:humid_high': AutoEnvReason.ventHumidHigh,
            'auto_vent:temp_high': AutoEnvReason.ventTempHigh,
            'auto_vent:humid_high+temp_high': AutoEnvReason.ventBoth,
            'auto_vent_end': AutoEnvReason.ventEnd,
            'auto_vent_cold': AutoEnvReason.ventCold,
            'auto_vent_cap': AutoEnvReason.ventCap,
            'auto_vent_disabled': AutoEnvReason.ventDisabled,
            'auto_mist': AutoEnvReason.mist,
          }
              .map((k, v) => MapEntry(AutoEnvReason.fromWire(k), v))
              .entries
              .every((e) => e.key == e.value),
          isTrue);
      expect(AutoEnvReason.fromWire(null), isNull);
      expect(AutoEnvReason.fromWire(3), isNull);
      // 요청서의 옛 이름은 서버가 쓰지 않는다(계약 C2).
      expect(AutoEnvReason.fromWire('humid_high'), isNull);
    });

    test('labelKey는 auto_reason_ + snake_case', () {
      expect(AutoEnvReason.values.map((r) => r.labelKey), [
        'auto_reason_vent_humid_high',
        'auto_reason_vent_temp_high',
        'auto_reason_vent_both',
        'auto_reason_vent_end',
        'auto_reason_vent_cold',
        'auto_reason_vent_cap',
        'auto_reason_vent_disabled',
        'auto_reason_mist',
      ]);
    });

    test('원인 문구 키가 ko.json에 모두 있다', () {
      final ko = jsonDecode(File('assets/l10n/ko.json').readAsStringSync())
          as Map<String, dynamic>;
      for (final r in AutoEnvReason.values) {
        expect(ko[r.labelKey], isA<String>(), reason: r.labelKey);
      }
    });
  });

  group('Device·DeviceLinkStatus.autoEnv', () {
    test('DeviceLinkStatus는 auto_env_state를 싣고 값으로 비교한다', () {
      final a = DeviceLinkStatus.fromJson({
        ...linkBase,
        'auto_env_state': {
          'vent': {'active': true}
        }
      });
      final b = DeviceLinkStatus.fromJson({
        ...linkBase,
        'auto_env_state': {
          'vent': {'active': true}
        }
      });
      expect(a.autoEnv.ventActive, isTrue);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('autoEnv가 다르면 다른 상태', () {
      final on = DeviceLinkStatus.fromJson({
        ...linkBase,
        'auto_env_state': {
          'vent': {'active': true}
        }
      });
      final off = DeviceLinkStatus.fromJson(linkBase);
      expect(off.autoEnv, AutoEnvState.none);
      expect(on, isNot(off));
    });

    test('목록 스냅샷(Device → of)에도 실린다', () {
      final d = Device.fromJson({
        'id': 'd1',
        ...linkBase,
        'auto_env_state': {
          'vent': {'active': true}
        }
      });
      expect(d.autoEnv.ventActive, isTrue);
      expect(DeviceLinkStatus.of(d).autoEnv.ventActive, isTrue);
      expect(Device.fromJson({'id': 'd1'}).autoEnv, AutoEnvState.none);
    });
  });

  group('providers', () {
    // 2026-11-06 사용자 결정으로 출시(서버 "전체 켬" 전).
    test('출시 스위치 켜짐', () {
      expect(kAutoEnvReleased, isTrue);
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(autoEnvReleasedProvider), isTrue);
    });

    test('autoEnvStateProvider — 연결 상태의 autoEnv, 없으면 none', () async {
      final status = StreamController<DeviceLinkStatus?>();
      addTearDown(status.close);
      final c = ProviderContainer(overrides: [
        deviceLinkStatusProvider('d').overrideWith((ref) => status.stream),
      ]);
      addTearDown(c.dispose);
      final seen = <AutoEnvState>[];
      c.listen(autoEnvStateProvider('d'), (_, next) => seen.add(next),
          fireImmediately: true);
      expect(seen, [AutoEnvState.none], reason: '아직 값이 없으면 none');

      status.add(DeviceLinkStatus.fromJson({
        ...linkBase,
        'auto_env_state': {
          'vent': {'active': true}
        }
      }));
      await Future<void>.delayed(Duration.zero);
      // 생존 신호만 바뀐 행 — autoEnv가 같으니 하위에 알리지 않는다.
      status.add(DeviceLinkStatus.fromJson({
        ...linkBase,
        'last_seen_at': '2026-11-05T05:10:03+00:00',
        'auto_env_state': {
          'vent': {'active': true}
        }
      }));
      await Future<void>.delayed(Duration.zero);
      status.add(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(autoEnvStateProvider('d')), AutoEnvState.none);
      expect(seen, [
        AutoEnvState.none,
        const AutoEnvState(ventActive: true),
        AutoEnvState.none,
      ]);
    });
  });

  group('DeviceSettingsNotifier.saveAuto', () {
    test('서버가 값을 무시하면 저장 실패', () async {
      final c = _containerWith(
          _FakeSettingsRepo(patchResponse: {'device_id': 'd'})); // 필드 없는 200
      // autoDispose — 화면처럼 구독해 둔다.
      c.listen(deviceSettingsProvider('d'), (_, __) {});
      await c.read(deviceSettingsProvider('d').future);
      await expectLater(
          c.read(deviceSettingsProvider('d').notifier).saveAuto(vent: true),
          throwsA(isA<AutoEnvSaveMismatch>()));
      expect(
          c.read(deviceSettingsProvider('d')).value!.autoVentEnabled, isFalse);
    });

    test('성공하면 응답 값을 상태에 넣고 보낸 필드만 PATCH', () async {
      final repo = _FakeSettingsRepo();
      final c = _containerWith(repo);
      c.listen(deviceSettingsProvider('d'), (_, __) {});
      await c.read(deviceSettingsProvider('d').future);
      await c.read(deviceSettingsProvider('d').notifier).saveAuto(mist: true);
      expect(repo.patches, [
        {'auto_mist_enabled': true}
      ]);
      final s = c.read(deviceSettingsProvider('d')).value!;
      expect(s.autoMistEnabled, isTrue);
      expect(s.autoVentEnabled, isFalse);
    });

    test('저장 중에는 구독이 없어도 버려지지 않는다(keepAlive)', () async {
      final gate = Completer<void>();
      final repo = _FakeSettingsRepo(patchGate: gate);
      final c = _containerWith(repo);
      final sub = c.listen(deviceSettingsProvider('d'), (_, __) {});
      await c.read(deviceSettingsProvider('d').future);
      final notifier = c.read(deviceSettingsProvider('d').notifier);
      final saving = notifier.saveAuto(vent: true);
      sub.close(); // 저장 중 시트를 닫았다.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      // 다시 열어도 같은 인스턴스 — 버려졌다면 새로 만들며 GET을 또 한다.
      c.listen(deviceSettingsProvider('d'), (_, __) {});
      expect(repo.gets, 1, reason: '저장 중 provider가 버려지지 않아야 한다');
      gate.complete();
      await expectLater(saving, completes);
      expect(repo.patches, [
        {'auto_vent_enabled': true}
      ]);
      expect(
          c.read(deviceSettingsProvider('d')).value!.autoVentEnabled, isTrue);
    });
  });
}
