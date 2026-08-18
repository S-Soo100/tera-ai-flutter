import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/home/domain/enclosure_set.dart';
import 'package:vivnanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivnanaut/features/my_cage/data/device_settings_repository.dart';
import 'package:vivnanaut/features/my_cage/domain/device.dart';
import 'package:vivnanaut/features/my_cage/domain/enclosure.dart';
import 'package:vivnanaut/features/my_cage/domain/device_settings.dart';
import 'package:vivnanaut/features/my_cage/presentation/widgets/setpoint_setting_tile.dart';

/// 2026-08-18 회신 §5 — 목표 온습도(setpoint) REST.
class _FakeRepo implements DeviceSettingsRepository {
  _FakeRepo({this.current, this.fail = false});

  DeviceSettings? current;
  final bool fail;
  final List<String> calls = [];

  @override
  Future<DeviceSettings> get(String deviceId) async {
    calls.add('get:$deviceId');
    return current ?? DeviceSettings(deviceId: deviceId);
  }

  @override
  Future<DeviceSettings> patch(String deviceId,
      {double? targetTempC, double? targetHumidityPct}) async {
    calls.add('patch:$deviceId:t=$targetTempC:h=$targetHumidityPct');
    if (fail) throw Exception('boom');
    current = DeviceSettings(
      deviceId: deviceId,
      targetTempC: targetTempC ?? current?.targetTempC,
      targetHumidityPct: targetHumidityPct ?? current?.targetHumidityPct,
    );
    return current!;
  }
}

Enclosure _enclosure() =>
    Enclosure(id: 'e1', name: '1번 사육장', createdAt: DateTime(2026, 8, 1));

Future<void> _pump(WidgetTester tester, _FakeRepo repo,
    {String? deviceId = 'd1'}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deviceSettingsRepositoryProvider.overrideWithValue(repo),
        currentSetProvider.overrideWith((ref) async => deviceId == null
            ? null
            : EnclosureSet(
                enclosure: _enclosure(),
                device: Device(
                    id: deviceId,
                    ownerId: null,
                    enclosureId: null,
                    name: '거실 사육장',
                    isOnline: true,
                    lastSeenAt: null),
                camera: null,
                pet: null,
              )),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SetpointSettingTile()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('DeviceSettings', () {
    test('fromJson: 미설정 200(전부 null)도 읽힌다', () {
      final s = DeviceSettings.fromJson({'device_id': 'd1'});
      expect(s.hasTarget, isFalse);
      expect(s.targetTempC, isNull);
    });

    test('fromJson: 값 + 범위 읽기', () {
      final s = DeviceSettings.fromJson({
        'device_id': 'd1',
        'target_temp_c': 28,
        'target_humidity_pct': '60.5',
        'target_temp_min': 24.0,
        'target_temp_max': 32.0,
      });
      expect(s.targetTempC, 28);
      expect(s.targetHumidityPct, 60.5);
      expect(s.targetTempMin, 24);
      expect(s.targetTempMax, 32);
      expect(s.hasTarget, isTrue);
    });

    test('patchBody: 안 바꾸는 값은 키째로 뺀다', () {
      expect(DeviceSettings.patchBody(targetTempC: 30), {'target_temp_c': 30});
      expect(DeviceSettings.patchBody(targetHumidityPct: 55),
          {'target_humidity_pct': 55});
      expect(DeviceSettings.patchBody(), isEmpty);
    });

    test('범위 검증은 서버와 같다 — 온도 −20~60, 습도 0~100', () {
      expect(DeviceSettings.validateTemp(-20), isTrue);
      expect(DeviceSettings.validateTemp(60), isTrue);
      expect(DeviceSettings.validateTemp(61), isFalse);
      expect(DeviceSettings.validateHumidity(0), isTrue);
      expect(DeviceSettings.validateHumidity(100), isTrue);
      expect(DeviceSettings.validateHumidity(101), isFalse);
    });
  });

  testWidgets('저장하면 현재 기기로 PATCH — 비운 칸은 안 보낸다', (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);

    await tester.tap(find.byKey(SetpointSettingTile.tileKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('setpoint_temp_field')), '28');
    await tester.pump();
    await tester.tap(find.byKey(const Key('setpoint_apply')));
    await tester.pumpAndSettle();

    expect(repo.calls.where((c) => c.startsWith('patch:')),
        ['patch:d1:t=28.0:h=null']);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('범위 밖이면 저장 버튼이 잠기고 이유를 말한다', (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);
    await tester.tap(find.byKey(SetpointSettingTile.tileKey));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('setpoint_humidity_field')), '120');
    await tester.pump();
    final btn = tester.widget<FilledButton>(find.byKey(const Key('setpoint_apply')));
    expect(btn.onPressed, isNull);
    expect(find.byKey(const Key('setpoint_invalid')), findsOneWidget);
    expect(repo.calls.where((c) => c.startsWith('patch:')), isEmpty);
  });

  testWidgets('현재 목표가 있으면 subtitle에 바로 보인다 + 대상 기기 이름을 밝힌다',
      (tester) async {
    final repo = _FakeRepo(
        current: const DeviceSettings(
            deviceId: 'd1', targetTempC: 28, targetHumidityPct: 60));
    await _pump(tester, repo);
    expect(find.text('setpoint_tile_value'), findsOneWidget);
    // 편집기가 어느 기기를 고치는지 title에 있다 — 사육장 탭 카드의 기기와
    // 다를 수 있어서.
    expect(find.text('setpoint_tile_title_for'), findsOneWidget);
  });

  testWidgets('기기가 없으면 탭이 막히고 이유가 subtitle에 있다', (tester) async {
    await _pump(tester, _FakeRepo(), deviceId: null);
    final tile = tester.widget<ListTile>(find.byKey(SetpointSettingTile.tileKey));
    expect(tile.enabled, isFalse);
    expect(find.text('lcd_no_device'), findsOneWidget);
  });

  testWidgets('실패하면 시트가 닫히지 않고 에러 스낵바', (tester) async {
    final repo = _FakeRepo(fail: true);
    await _pump(tester, repo);
    await tester.tap(find.byKey(SetpointSettingTile.tileKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('setpoint_temp_field')), '28');
    await tester.pump();
    await tester.tap(find.byKey(const Key('setpoint_apply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('setpoint_temp_field')), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
