// 작은 폰(375×667)에서 키보드(300)가 열렸을 때 하단 버튼·시트 배치.
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/my_cage/data/redesign_group_repository.dart';
import 'package:vivanaut/features/my_cage/domain/redesign_management.dart';
import 'package:vivanaut/features/my_cage/presentation/device_detail_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/device_management_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/group_editor_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/device_setting_sheet.dart';
import 'package:vivanaut/features/my_pets/presentation/widgets/event_timeline.dart';

class _Strings extends AssetLoader {
  const _Strings();
  @override
  Future<Map<String, dynamic>> load(String p, Locale l) async =>
      jsonDecode(File('assets/l10n/ko.json').readAsStringSync())
          as Map<String, dynamic>;
}

const _size = Size(375, 667);
const _keyboard = 300.0;

final _inventory = ManagementInventory(groups: const [
  ManagementGroup(id: 'g', name: 'Original'),
], items: const [
  ManagementItem(
      key: ManagementKey(kind: ManagementKind.device, id: 'd'),
      name: 'device',
      groupId: 'g'),
]);

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('ko')],
      startLocale: const Locale('ko'),
      path: 'assets/l10n',
      assetLoader: const _Strings(),
      child: Builder(
          builder: (c) => ProviderScope(
                  overrides: [
                    managementInventoryProvider
                        .overrideWith((ref) async => _inventory),
                    redesignGroupRepositoryProvider.overrideWith((ref) =>
                        RedesignGroupRepository(
                            loadRows: (_) async => [],
                            rpc: (_, __) async => null)),
                  ],
                  child: MaterialApp(
                      theme: AppTheme.light,
                      locale: c.locale,
                      supportedLocales: c.supportedLocales,
                      localizationsDelegates: c.localizationDelegates,
                      // 실기기처럼 키보드가 열리면 하단 안전영역(34)은 0으로 보고된다.
                      builder: (context, child) => MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                              padding: EdgeInsets.only(
                                  top: 20,
                                  bottom:
                                      MediaQuery.of(context).viewInsets.bottom >
                                              0
                                          ? 0
                                          : 34)),
                          child: child!),
                      home: home)))));
  await tester.pumpAndSettle();
}

Future<void> _openKeyboard(WidgetTester tester) async {
  tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final font = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      font.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await font.load();
  });

  for (final groupId in [null, 'g']) {
    testWidgets('그룹 이름(${groupId ?? '새 그룹'}) — 키보드 위 12에 다음 버튼, 삭제는 숨김',
        (tester) async {
      await _pump(tester, GroupEditorScreen(groupId: groupId));
      await tester.showKeyboard(find.byType(TextFormField));
      await _openKeyboard(tester);
      final next =
          tester.getRect(find.byKey(const Key('management_group_next')));
      expect(next.bottom, closeTo(_size.height - _keyboard - 12, 0.5));
      expect(find.byKey(const Key('management_delete_group')), findsNothing);
      expect(tester.getRect(find.byType(TextFormField)).bottom,
          lessThanOrEqualTo(next.top));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('그룹 이름 — 키보드를 닫으면 삭제 버튼이 돌아온다', (tester) async {
    await _pump(tester, const GroupEditorScreen(groupId: 'g'));
    expect(find.byKey(const Key('management_delete_group')), findsOneWidget);
  });

  testWidgets('기기 이름 — 키보드 위 12에 완료 버튼, 기기 삭제는 숨김', (tester) async {
    await _pump(tester,
        const DeviceDetailScreen(kind: ManagementKind.device, itemId: 'd'));
    expect(find.text('management_delete_device'.tr()), findsOneWidget);
    await tester.showKeyboard(find.byType(TextFormField));
    await _openKeyboard(tester);
    final done = tester.getRect(find.ancestor(
        of: find.text('management_done'.tr()),
        matching: find.byType(FilledButton)));
    expect(done.bottom, closeTo(_size.height - _keyboard - 12, 0.5));
    expect(find.text('management_delete_device'.tr()), findsNothing);
    expect(tester.takeException(), isNull);
  });

  Future<void> openSheet(WidgetTester tester, WidgetBuilder builder) async {
    await _pump(
        tester,
        Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    key: const Key('open'),
                    onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: builder),
                    child: const Text('open')))));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    await _openKeyboard(tester);
  }

  testWidgets('기록 추가 시트 — 키보드가 열려도 넘치지 않고 저장까지 스크롤된다', (tester) async {
    await openSheet(tester, (_) => const AddEventSheet(petId: 'p'));
    expect(tester.takeException(), isNull);
    final save = find.text('pet_save'.tr());
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    expect(tester.getRect(save).bottom,
        lessThanOrEqualTo(_size.height - _keyboard));
  });

  testWidgets('설정 시트 껍데기 — 내용이 키보드 위 공간보다 길면 스크롤한다', (tester) async {
    await openSheet(
        tester,
        (_) => DeviceSettingSheet(title: 'title', children: [
              for (var i = 0; i < 6; i++)
                const Padding(
                    padding: EdgeInsets.only(bottom: 8), child: TextField()),
              FilledButton(onPressed: () {}, child: const Text('apply')),
            ]));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('apply'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('apply')).bottom,
        lessThanOrEqualTo(_size.height - _keyboard));
  });
}
