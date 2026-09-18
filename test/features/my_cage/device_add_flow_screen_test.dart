import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/my_cage/domain/device_add_flow.dart';
import 'package:vivanaut/features/my_cage/domain/pair_target_kind.dart';
import 'package:vivanaut/features/my_cage/domain/wifi_access_point.dart';
import 'package:vivanaut/features/my_cage/presentation/device_add_flow_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/device_add_flow_screen.dart';
import 'device_add_flow_test.dart' show Gateway, device, camera;

class Translations extends AssetLoader {
  const Translations();
  @override
  Future<Map<String, Object?>> load(String path, Locale locale) async {
    final Object? raw =
        jsonDecode(File('assets/l10n/ko.json').readAsStringSync());
    return raw is Map<String, Object?> ? raw : {};
  }
}

class Controller extends DeviceAddFlowController {
  Controller(DeviceAddState initial)
      : super(
            gateway: Gateway(),
            accountId: 'a',
            isCurrent: () => true,
            token: () => '',
            namePrefix: (_) => '기기',
            names: () async => [],
            confirm: (_, __) async => null,
            saveCredentials: (_, __) async {},
            readCredentials: () async => {},
            autoGroup: (_, __) async => 'group') {
    state = initial;
  }
  @override
  Future<void> scan() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final font = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      font.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await font.load();
  });
  for (final (step, single) in [
    for (final step in DeviceAddStep.values) (step, false),
    (DeviceAddStep.results, true),
  ]) {
    testWidgets(
        '${step.name}${single ? ' single' : ''} narrow screen and large text fit without overflow',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.reset);
      final initial = DeviceAddState(
          step: step,
          candidates: [device, camera],
          ssid: 'A long WiFi network with spaces',
          networks: [
            const WifiAccessPoint(
                no: 1,
                ssid: 'A long network name with many words',
                rssi: -30,
                channel: 1)
          ],
          results: step == DeviceAddStep.results
              ? {
                  PairTargetKind.device: const DeviceAddResult(
                      candidate: device,
                      outcome: DeviceAddOutcome.registered,
                      registeredId: 'd'),
                  if (!single)
                    PairTargetKind.camera: const DeviceAddResult(
                        candidate: camera,
                        outcome: DeviceAddOutcome.registrationPending,
                        wifiConnected: true),
                }
              : {});
      await tester.pumpWidget(EasyLocalization(
          supportedLocales: const [Locale('ko')],
          path: 'assets/l10n',
          assetLoader: const Translations(),
          child: Builder(
              builder: (context) => ProviderScope(
                  key: ValueKey(step),
                  overrides: [
                    deviceAddAccountProvider.overrideWithValue('a'),
                    deviceAddFlowProvider('test')
                        .overrideWith((ref) => Controller(initial)),
                  ],
                  child: MaterialApp(
                      theme: AppTheme.light,
                      locale: context.locale,
                      supportedLocales: context.supportedLocales,
                      localizationsDelegates: context.localizationDelegates,
                      builder: (context, child) => MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                              textScaler: const TextScaler.linear(1.7)),
                          child: child!),
                      home: const DeviceAddFlowScreen(flowKey: 'test'))))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
  testWidgets('opt-in capture measured selection/password/result screens',
      (tester) async {
    if (!const bool.fromEnvironment('CAPTURE_PAIRING')) return;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    for (final step in [
      DeviceAddStep.scan,
      DeviceAddStep.credentials,
      DeviceAddStep.results
    ]) {
      final initial = DeviceAddState(
          step: step,
          candidates: [device, camera],
          selected: {
            PairTargetKind.device: device,
            PairTargetKind.camera: camera
          },
          ssid: 'KT_GIGA_2G',
          results: step == DeviceAddStep.results
              ? {
                  PairTargetKind.device: const DeviceAddResult(
                      candidate: device,
                      outcome: DeviceAddOutcome.registered,
                      registeredId: 'd'),
                  PairTargetKind.camera: const DeviceAddResult(
                      candidate: camera,
                      outcome: DeviceAddOutcome.registered,
                      registeredId: 'c'),
                }
              : {},
          groupId: 'g');
      await tester.pumpWidget(EasyLocalization(
          supportedLocales: const [Locale('ko')],
          path: 'assets/l10n',
          assetLoader: const Translations(),
          child: Builder(
              builder: (context) => ProviderScope(
                  key: ValueKey(step),
                  overrides: [
                    deviceAddAccountProvider.overrideWithValue('a'),
                    deviceAddFlowProvider('test')
                        .overrideWith((ref) => Controller(initial))
                  ],
                  child: MaterialApp(
                      theme: AppTheme.light,
                      locale: context.locale,
                      supportedLocales: context.supportedLocales,
                      localizationsDelegates: context.localizationDelegates,
                      builder: (context, child) =>
                          RepaintBoundary(key: boundary, child: child!),
                      home: MediaQuery(
                          data: const MediaQueryData(
                              size: Size(393, 852),
                              padding: EdgeInsets.only(top: 62, bottom: 34)),
                          child:
                              const DeviceAddFlowScreen(flowKey: 'test')))))));
      await tester.pumpAndSettle();
      Future<void> capture(String name) => tester.runAsync(() async {
            final image = await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await File('/private/tmp/pairing-$name.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
      await capture(step.name);
      if (step == DeviceAddStep.credentials) {
        await tester.tap(find.text('비밀번호 기억하기'));
        await tester.pumpAndSettle();
        await capture('credentials-checked');
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
