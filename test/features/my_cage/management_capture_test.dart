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
import 'package:vivanaut/features/my_cage/data/redesign_group_repository.dart';
import 'package:vivanaut/features/my_cage/domain/redesign_management.dart';
import 'package:vivanaut/features/my_cage/presentation/device_management_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/device_management_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/device_detail_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/group_editor_screen.dart';

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, Object?>> load(String path, Locale locale) async {
    final Object? value =
        jsonDecode(File('assets/l10n/ko.json').readAsStringSync());
    final result = value is Map<String, Object?> ? value : <String, Object?>{};
    const overlay = String.fromEnvironment('MANAGEMENT_TRANSLATIONS');
    if (overlay.isNotEmpty) {
      final Object? extra = jsonDecode(File(overlay).readAsStringSync());
      if (extra is Map<String, Object?>) result.addAll(extra);
    }
    return result;
  }
}

void main() {
  if (!const bool.fromEnvironment('CAPTURE_MANAGEMENT')) {
    test('opt-in management visual capture', () {},
        skip: 'CAPTURE_MANAGEMENT=true');
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
  });
  testWidgets(
      'source-sized localized inventory, detail, group review, selection',
      (tester) async {
    final inventory = ManagementInventory(groups: [
      const ManagementGroup(id: 'g', name: '마뱀이네 집', number: 1)
    ], items: [
      const ManagementItem(
          key: ManagementKey(kind: ManagementKind.device, id: 'd'),
          name: '사육장 1',
          hardwareId: 'terra-iot-real',
          groupId: 'g',
          isOnline: false),
      const ManagementItem(
          key: ManagementKey(kind: ManagementKind.camera, id: 'c'),
          name: '크랑이 캠',
          hardwareId: 'p4cam-real',
          groupId: 'g',
          isOnline: true),
      const ManagementItem(
          key: ManagementKey(kind: ManagementKind.pet, id: 'p'),
          name: '크랑이',
          groupId: 'g',
          subtitle: '아잔틱 릴리 화이트'),
      const ManagementItem(
          key: ManagementKey(kind: ManagementKind.camera, id: 'c2'),
          name: '카메라 2',
          hardwareId: 'p4cam-extra'),
      if (const bool.fromEnvironment('CAPTURE_FLOATING')) ...[
        for (var i = 2; i <= 3; i++)
          ManagementItem(
              key: ManagementKey(kind: ManagementKind.device, id: 'd$i'),
              name: '사육장 $i',
              hardwareId: 'viva-iot-000$i'),
        const ManagementItem(
            key: ManagementKey(kind: ManagementKind.pet, id: 'p2'),
            name: '모모',
            subtitle: '아잔틱 릴리 화이트'),
      ],
    ]);
    final repo = RedesignGroupRepository(
        loadRows: (_) async => [],
        rpc: (_, __) async =>
            throw const ManagementFailure('management_server_unsupported'));
    final boundary = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(393, 852));
    Future<void> pump(Widget screen) async {
      await tester.pumpWidget(EasyLocalization(
          supportedLocales: const [Locale('ko')],
          startLocale: const Locale('ko'),
          path: 'assets/l10n',
          assetLoader: const _Translations(),
          child: Builder(
              builder: (context) => ProviderScope(
                  key: UniqueKey(),
                  overrides: [
                    managementInventoryProvider
                        .overrideWith((ref) async => inventory),
                    redesignGroupRepositoryProvider.overrideWith((ref) => repo),
                  ],
                  child: MaterialApp(
                      theme: AppTheme.light,
                      locale: context.locale,
                      supportedLocales: context.supportedLocales,
                      localizationsDelegates: context.localizationDelegates,
                      builder: (context, child) => RepaintBoundary(
                          key: boundary,
                          child: MediaQuery(
                              data: MediaQuery.of(context).copyWith(
                                  padding: const EdgeInsets.only(
                                      top: 62, bottom: 34)),
                              child: child!)),
                      home: screen)))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final render = boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/private/tmp/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await pump(const DeviceManagementScreen());
    await capture('management-inventory');
    await pump(
        const DeviceDetailScreen(kind: ManagementKind.device, itemId: 'd'));
    await capture('management-device');
    await tester.tap(find.text('그룹 설정'));
    await tester.pumpAndSettle();
    await capture('management-device-group-settings');
    await pump(const GroupEditorScreen(groupId: 'g'));
    await capture('management-group-review');
    await tester.tap(find.text('추가 · 변경'));
    await tester.pumpAndSettle();
    await capture('management-group-selection');
    if (const bool.fromEnvironment('CAPTURE_FLOATING')) {
      final cta = find.byKey(const Key('management_group_next'));
      final before = tester.getRect(cta);
      await tester.drag(find.byType(ListView), const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(tester.getRect(cta), before);
      await capture('management-group-selection-scrolled');
    }
    expect(tester.takeException(), isNull);
  });
}
