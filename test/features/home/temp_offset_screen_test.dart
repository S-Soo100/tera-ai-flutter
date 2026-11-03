// v4 온도 보정(계획 Task 4, Figma S14·S16·S32~S37, 메모 S45~S47).
// 기기 값 = 공장 보정 −1.5 + 사용자 보정(서버 회신 2026-11-02 §1.2).
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivanaut/core/network/terra_rest_client.dart';
import 'package:vivanaut/core/router/app_router.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/home/data/env_alert_prefs_repository.dart';
import 'package:vivanaut/features/home/domain/env_realtime_values.dart';
import 'package:vivanaut/features/home/presentation/env_live_providers.dart';
import 'package:vivanaut/features/home/presentation/routine_settings_screen.dart'
    show ScheduleSwitch;
import 'package:vivanaut/features/home/presentation/temp_humid_setting_screen.dart';
import 'package:vivanaut/features/home/presentation/temp_offset_providers.dart';
import 'package:vivanaut/features/home/presentation/temp_offset_screen.dart';
import 'package:vivanaut/features/my_cage/data/device_health_repository.dart';
import 'package:vivanaut/features/my_cage/data/device_settings_repository.dart';
import 'package:vivanaut/features/my_cage/data/temp_offset_repository.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/presentation/supabase_module_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/sys_health_controllers.dart';
import 'package:vivanaut/shared/domain/env_thresholds.dart';

import '../notification/notification_test_host.dart';
import 'env_v4_screen_fixtures.dart';

class _OffsetRepo implements TempOffsetRepository {
  _OffsetRepo({this.fail = false});
  final bool fail;
  final List<double> sent = [];

  @override
  Future<String?> send(String deviceId, TempOffset offset) async {
    sent.add(offset.toDeviceValue());
    if (fail) throw const TerraRestException(500, 'boom');
    return 'c${sent.length}';
  }
}

/// 기기 쪽 — 보정값 보고(`devices.temp_offset_c`)와 명령 행 상태.
class _Device {
  _Device(this.offset);
  double? offset;
  final _offsets = StreamController<double?>.broadcast();
  final _commands = StreamController<RebootCommandState?>.broadcast();

  Stream<double?> offsetStream() async* {
    yield offset;
    yield* _offsets.stream;
  }

  void report(double v) {
    offset = v;
    _offsets.add(v);
  }

  void command(String status, [String? result]) =>
      _commands.add((status: status, result: result));

  void close() {
    _offsets.close();
    _commands.close();
  }
}

Device _row(double? offset) => Device(
    id: kEnvV4DeviceId,
    ownerId: 'u1',
    enclosureId: null,
    name: '거실 사육장',
    isOnline: true,
    lastSeenAt: null,
    tempOffsetC: offset);

bool _switchOn(WidgetTester tester) => tester
    .widget<ScheduleSwitch>(find.byKey(TempHumidSettingScreen.offsetToggleKey))
    .value;

String? _text(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data;

void main() {
  setUpAll(initializeNotificationLocalization);

  /// 온습도 설정까지 연다. 기기 보고 온도 [reported].
  Future<(GoRouter, _Device, _OffsetRepo)> pump(
    WidgetTester tester, {
    required double? deviceOffset,
    double reported = 24.7,
    bool online = true,
    _OffsetRepo? repo,
  }) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final device = _Device(deviceOffset);
    addTearDown(device.close);
    final offsets = repo ?? _OffsetRepo();
    final router = GoRouter(initialLocation: '/root', routes: [
      GoRoute(path: '/root', builder: (_, __) => const Scaffold()),
      buildTempHumidSettingRoute(),
    ]);
    addTearDown(router.dispose);
    final now = DateTime.now();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        deviceListProvider.overrideWith((ref) async => [_row(deviceOffset)]),
        deviceOffsetProvider(kEnvV4DeviceId)
            .overrideWith((ref) => device.offsetStream()),
        commandRowProvider
            .overrideWith((ref, id) => device._commands.stream),
        tempOffsetRepositoryProvider.overrideWithValue(offsets),
        moduleLinkProvider(kEnvV4DeviceId)
            .overrideWithValue(online ? ModuleLink.online : ModuleLink.offline),
        envLiveViewProvider(kEnvV4DeviceId).overrideWithValue(envLiveView(
            EnvLiveReading(
                deviceId: kEnvV4DeviceId,
                temperature: reported,
                measuredAt: now),
            now: now,
            online: true)),
        deviceSettingsRepositoryProvider.overrideWithValue(EnvV4SettingsRepo()),
        currentUserProvider.overrideWith((ref) => envV4User()),
        envAlertPrefsRepositoryProvider
            .overrideWith((ref, id) => EnvV4PrefsRepo()),
      ],
      child: localizedNotificationHost((context) => MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
          )),
    ));
    await tester.pumpAndSettle();
    router.push(tempHumidSettingPath(kEnvV4DeviceId));
    await tester.pumpAndSettle();
    return (router, device, offsets);
  }

  Future<void> openOffset(WidgetTester tester) async {
    await tester.tap(find.byKey(TempHumidSettingScreen.offsetRowKey));
    await tester.pumpAndSettle();
    expect(find.byType(TempOffsetScreen), findsOneWidget);
  }

  Future<void> turnOnAndOpen(WidgetTester tester) async {
    await tester.tap(find.byKey(TempHumidSettingScreen.offsetToggleKey));
    await tester.pumpAndSettle();
    expect(_switchOn(tester), isTrue);
    expect(_text(tester, TempHumidSettingScreen.offsetValueKey), '설정하기');
    await openOffset(tester);
  }

  void setMagnitude(WidgetTester tester, int tenths) => tester
      .widget<Slider>(find.byKey(TempOffsetScreen.sliderKey))
      .onChanged!(tenths.toDouble());

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.byKey(TempOffsetScreen.saveKey));
    await tester.pump();
  }

  testWidgets('켜기는 화면 상태만 — 명령 없음, "설정하기"(S32·S45)', (tester) async {
    final (_, _, repo) = await pump(tester, deviceOffset: -1.5);
    expect(_switchOn(tester), isFalse);
    await tester.tap(find.byKey(TempHumidSettingScreen.offsetToggleKey));
    await tester.pumpAndSettle();
    expect(_text(tester, TempHumidSettingScreen.offsetValueKey), '설정하기');
    expect(repo.sent, isEmpty);
  });

  testWidgets('첫 진입 기본 빼기 0.1 — 측정 24.7 → 보정 24.6(S14)', (tester) async {
    await pump(tester, deviceOffset: -1.5);
    await turnOnAndOpen(tester);
    expect(_text(tester, TempOffsetScreen.magnitudeKey), '0.1');
    expect(_text(tester, TempOffsetScreen.measuredKey), '24.7℃');
    expect(_text(tester, TempOffsetScreen.correctedKey), '24.6℃');
  });

  testWidgets('측정값은 사용자 보정만 걷어낸다 — 기기 −0.5·보고 27.2 → 26.2', (tester) async {
    await pump(tester, deviceOffset: -0.5, reported: 27.2);
    await openOffset(tester);
    // 저장값 더하기 1.0으로 시작(S16).
    expect(_text(tester, TempOffsetScreen.magnitudeKey), '1.0');
    expect(_text(tester, TempOffsetScreen.measuredKey), '26.2℃');
    expect(_text(tester, TempOffsetScreen.correctedKey), '27.2℃');
  });

  testWidgets('더하기 1.0 → 보정 온도 25.7, 빼기 4.0 → 20.7(S34·S37)', (tester) async {
    await pump(tester, deviceOffset: -1.5);
    await turnOnAndOpen(tester);
    await tester.tap(find.byKey(TempOffsetScreen.addKey));
    setMagnitude(tester, 10);
    await tester.pumpAndSettle();
    expect(_text(tester, TempOffsetScreen.correctedKey), '25.7℃');
    await tester.tap(find.byKey(TempOffsetScreen.subtractKey));
    setMagnitude(tester, 40);
    await tester.pumpAndSettle();
    expect(_text(tester, TempOffsetScreen.magnitudeKey), '4.0');
    expect(_text(tester, TempOffsetScreen.correctedKey), '20.7℃');
  });

  testWidgets('저장: 공장값에 더해 보내고, 기기가 보고하면 닫힌다 → "측정값 +1℃"', (tester) async {
    final (_, device, repo) = await pump(tester, deviceOffset: -1.5);
    await turnOnAndOpen(tester);
    await tester.tap(find.byKey(TempOffsetScreen.addKey));
    setMagnitude(tester, 10);
    await tester.pumpAndSettle();
    await tapSave(tester);
    expect(repo.sent, [-0.5]);
    expect(find.text('기기에 적용하는 중…'), findsOneWidget);
    // 저장 중 중복 탭은 보내지 않는다.
    await tester.tap(find.byKey(TempOffsetScreen.saveKey));
    await tester.pump();
    expect(repo.sent, [-0.5]);
    device.report(-0.5);
    await tester.pumpAndSettle();
    expect(find.byType(TempOffsetScreen), findsNothing);
    expect(_switchOn(tester), isTrue);
    expect(_text(tester, TempHumidSettingScreen.offsetValueKey), '측정값 +1℃');
  });

  testWidgets('저장: ack ok만 오고 보고가 없으면 15초 뒤 성공으로 닫는다', (tester) async {
    final (_, device, _) = await pump(tester, deviceOffset: -1.5);
    await turnOnAndOpen(tester);
    await tapSave(tester);
    device.command('acked', 'ok');
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(TempOffsetScreen), findsOneWidget);
    await tester.pump(kTempOffsetConfirmTimeout);
    await tester.pumpAndSettle();
    expect(find.byType(TempOffsetScreen), findsNothing);
  });

  testWidgets('저장: 15초 무응답이면 실패 안내·화면 유지', (tester) async {
    await pump(tester, deviceOffset: -1.5);
    await turnOnAndOpen(tester);
    await tapSave(tester);
    await tester.pump(kTempOffsetConfirmTimeout);
    await tester.pump();
    expect(find.byType(TempOffsetScreen), findsOneWidget);
    expect(find.text('기기가 응답하지 않아요. 연결을 확인하고 다시 시도해 주세요'), findsOneWidget);
    expect(find.text('저장'), findsOneWidget);
  });

  testWidgets('저장: no_ack면 15초를 기다리지 않고 안내', (tester) async {
    final (_, device, _) = await pump(tester, deviceOffset: -1.5);
    await turnOnAndOpen(tester);
    await tapSave(tester);
    device.command('no_ack');
    await tester.pump();
    await tester.pump();
    expect(find.text('기기가 응답하지 않아요. 연결을 확인하고 다시 시도해 주세요'), findsOneWidget);
    expect(find.byType(TempOffsetScreen), findsOneWidget);
  });

  testWidgets('저장: 기기가 거절하면 안내', (tester) async {
    final (_, device, _) = await pump(tester, deviceOffset: -1.5);
    await turnOnAndOpen(tester);
    await tapSave(tester);
    device.command('acked', 'error');
    await tester.pump();
    await tester.pump();
    expect(find.text('기기가 보정값을 받지 못했어요. 다시 시도해 주세요'), findsOneWidget);
  });

  testWidgets('저장: 요청 실패면 안내', (tester) async {
    await pump(tester, deviceOffset: -1.5, repo: _OffsetRepo(fail: true));
    await turnOnAndOpen(tester);
    await tapSave(tester);
    await tester.pump();
    expect(find.text('보정값을 저장하지 못했어요. 다시 시도해 주세요'), findsOneWidget);
  });

  testWidgets('오프라인이면 저장 비활성', (tester) async {
    final (_, _, repo) = await pump(tester, deviceOffset: -0.5, online: false);
    await openOffset(tester);
    expect(
        tester
            .widget<FilledButton>(find.descendant(
                of: find.byKey(TempOffsetScreen.saveKey),
                matching: find.byType(FilledButton)))
            .onPressed,
        isNull);
    await tester.tap(find.byKey(TempOffsetScreen.saveKey));
    await tester.pump();
    expect(repo.sent, isEmpty);
  });

  testWidgets('cancel_on_first_entry_turns_toggle_off — 명령 0회(S46)',
      (tester) async {
    final (_, _, repo) = await pump(tester, deviceOffset: -1.5);
    await turnOnAndOpen(tester);
    setMagnitude(tester, 25);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TempOffsetScreen.cancelKey));
    await tester.pumpAndSettle();
    expect(find.byType(TempOffsetScreen), findsNothing);
    expect(_switchOn(tester), isFalse);
    expect(repo.sent, isEmpty);
  });

  testWidgets('첫 진입 뒤로가기도 취소와 같다', (tester) async {
    final (router, _, _) = await pump(tester, deviceOffset: -1.5);
    await turnOnAndOpen(tester);
    router.pop();
    await tester.pumpAndSettle();
    expect(_switchOn(tester), isFalse);
  });

  testWidgets('cancel_after_saved_restores_previous — −2에서 +3 고르고 취소(S47)',
      (tester) async {
    final (_, _, repo) = await pump(tester, deviceOffset: -3.5);
    await openOffset(tester);
    expect(_text(tester, TempOffsetScreen.magnitudeKey), '2.0');
    await tester.tap(find.byKey(TempOffsetScreen.addKey));
    setMagnitude(tester, 30);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TempOffsetScreen.cancelKey));
    await tester.pumpAndSettle();
    expect(_switchOn(tester), isTrue);
    expect(_text(tester, TempHumidSettingScreen.offsetValueKey), '측정값 -2℃');
    expect(repo.sent, isEmpty);
    // 다시 들어가면 저장값으로 시작한다.
    await openOffset(tester);
    expect(_text(tester, TempOffsetScreen.magnitudeKey), '2.0');
  });

  testWidgets('같은 값이면 보내지 않고 닫는다', (tester) async {
    final (_, _, repo) = await pump(tester, deviceOffset: -3.5);
    await openOffset(tester);
    await tapSave(tester);
    await tester.pumpAndSettle();
    expect(find.byType(TempOffsetScreen), findsNothing);
    expect(repo.sent, isEmpty);
  });

  testWidgets('편집기 밖 저장값(사용자 −4.5)은 4.0으로 시작', (tester) async {
    await pump(tester, deviceOffset: -6);
    await openOffset(tester);
    expect(_text(tester, TempOffsetScreen.magnitudeKey), '4.0');
  });

  testWidgets('끄기는 공장 보정 −1.5를 보내고, 확인되면 꺼진다', (tester) async {
    final (_, device, repo) = await pump(tester, deviceOffset: -0.5);
    await tester.tap(find.byKey(TempHumidSettingScreen.offsetToggleKey));
    await tester.pump();
    expect(repo.sent, [-1.5]);
    // 확인 전에도 꺼진 모양으로 잠근다.
    expect(_switchOn(tester), isFalse);
    expect(find.byKey(TempHumidSettingScreen.offsetRowKey), findsNothing);
    device.report(-1.5);
    await tester.pumpAndSettle();
    expect(_switchOn(tester), isFalse);
  });

  testWidgets('끄기 실패(no_ack) → 켜짐으로 돌아오고 안내', (tester) async {
    final (_, device, _) = await pump(tester, deviceOffset: -0.5);
    await tester.tap(find.byKey(TempHumidSettingScreen.offsetToggleKey));
    await tester.pump();
    device.command('no_ack');
    await tester.pumpAndSettle();
    expect(_switchOn(tester), isTrue);
    expect(find.text('기기가 응답하지 않아요. 연결을 확인하고 다시 시도해 주세요'), findsOneWidget);
  });

  testWidgets('오프라인에서 끄기 → 보내지 않고 안내', (tester) async {
    final (_, _, repo) = await pump(tester, deviceOffset: -0.5, online: false);
    await tester.tap(find.byKey(TempHumidSettingScreen.offsetToggleKey));
    await tester.pumpAndSettle();
    expect(repo.sent, isEmpty);
    expect(_switchOn(tester), isTrue);
    expect(find.text('사육장 기기가 연결되어 있을 때 바꿀 수 있어요'), findsOneWidget);
  });

  testWidgets('구 펌웨어 → 토글 잠금', (tester) async {
    final (_, _, repo) = await pump(tester, deviceOffset: null);
    await tester.tap(find.byKey(TempHumidSettingScreen.offsetToggleKey),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_switchOn(tester), isFalse);
    expect(repo.sent, isEmpty);
    expect('temp_humid_offset_unsupported'.tr(), '펌웨어 업데이트 후 사용할 수 있어요');
  });
}
