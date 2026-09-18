import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/my_cage/data/redesign_group_repository.dart';
import 'package:vivanaut/features/my_cage/domain/redesign_management.dart';
import 'package:vivanaut/features/my_cage/presentation/device_management_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/group_editor_screen.dart';

void main() {
  testWidgets(
      'invalid group name blocks repeated submit and recovers on valid edit',
      (tester) async {
    var writes = 0;
    final inventory = ManagementInventory(groups: const [
      ManagementGroup(id: 'g', name: 'Original'),
      ManagementGroup(id: 'other', name: 'Taken'),
    ], items: const [
      ManagementItem(
          key: ManagementKey(kind: ManagementKind.camera, id: 'c'),
          name: 'Camera',
          groupId: 'g'),
    ]);
    final repo = RedesignGroupRepository(
        loadRows: (_) async => [],
        rpc: (_, __) async {
          writes++;
          return null;
        });
    await tester.pumpWidget(ProviderScope(
        overrides: [
          managementInventoryProvider.overrideWith((ref) async => inventory),
          redesignGroupRepositoryProvider.overrideWith((ref) => repo),
        ],
        child: MaterialApp(
            theme: AppTheme.light,
            home: const GroupEditorScreen(groupId: 'g'))));
    await tester.pumpAndSettle();
    final button = find.descendant(
        of: find.byKey(const Key('management_group_next')),
        matching: find.byType(FilledButton));
    await tester.enterText(find.byType(TextFormField), 'Taken');
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(find.text('management_group_name_duplicate'), findsOneWidget);
    expect(
        tester.widget<TextField>(find.byType(TextField)).decoration?.errorText,
        isNull);
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.enterText(find.byType(TextFormField), 'Fresh');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    expect(find.text('management_group_name_duplicate'), findsNothing);
    expect(writes, 0);
    expect(tester.takeException(), isNull);
  });
}
