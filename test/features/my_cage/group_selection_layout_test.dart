import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/my_cage/data/redesign_group_repository.dart';
import 'package:vivanaut/features/my_cage/domain/redesign_management.dart';
import 'package:vivanaut/features/my_cage/presentation/device_management_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/group_editor_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/management_widgets.dart';

void main() {
  testWidgets(
      'selection floats over scrolling list and last member is reachable',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final inventory = ManagementInventory(groups: const [
      ManagementGroup(id: 'g', name: 'Group')
    ], items: [
      for (var i = 0; i < 12; i++)
        ManagementItem(
          key: ManagementKey(kind: ManagementKind.camera, id: 'c$i'),
          name: 'Camera $i',
        ),
    ]);
    final repo = RedesignGroupRepository(
      loadRows: (_) async => [],
      rpc: (_, __) async => throw StateError('No writes during selection'),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        managementInventoryProvider.overrideWith((ref) async => inventory),
        redesignGroupRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 62, bottom: 34),
          ),
          child: child!,
        ),
        home: const GroupEditorScreen(groupId: 'g', selectMembers: true),
      ),
    ));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('management_group_next'));
    final buttonRect = tester.getRect(button);
    final list = find.byType(ListView);
    final filledButton =
        find.descendant(of: button, matching: find.byType(FilledButton));
    expect(tester.widget<FilledButton>(filledButton).onPressed, isNull);
    expect(buttonRect.bottom, 752);
    // The scroll viewport must continue behind the CTA, not stop above it.
    expect(tester.getRect(list).bottom, greaterThan(buttonRect.bottom));
    await tester.tap(find.text('Camera 0'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(filledButton).onPressed, isNotNull);
    await tester.tap(find.text('Camera 0'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(filledButton).onPressed, isNull);
    await tester.drag(list, const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(tester.getRect(button), buttonRect);
    final last = find.ancestor(
        of: find.text('Camera 11'), matching: find.byType(ManagementItemRow));
    expect(tester.getRect(last).bottom, lessThanOrEqualTo(buttonRect.top));
    await tester.tap(find.text('Camera 11'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(filledButton).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
