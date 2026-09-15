import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/my_pets/domain/pet.dart';
import 'package:vivanaut/features/my_pets/presentation/my_cre_activity_screen.dart';
import 'package:vivanaut/shared/widgets/figma_icon.dart';

void main() {
  testWidgets('empty profile offers registration and preserves old reports',
      (tester) async {
    var added = 0;
    var legacy = 0;
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            theme: AppTheme.light,
            home: MyCreActivityScreen(
                header: const Text('Group header'),
                userId: null,
                pet: null,
                hasCameraConnection: false,
                assignments: const [],
                onAddPet: () => added++,
                onOpenLegacyReports: () => legacy++))));
    expect(find.byType(Image), findsOneWidget);
    expect(
        tester.widget<Image>(find.byType(Image)).image, FigmaImages.emptyPet);
    await tester.tap(find.byKey(const Key('activity_add_pet')));
    expect(added, 1);
    await tester.ensureVisible(find.byKey(const Key('activity_legacy')));
    await tester.tap(find.byKey(const Key('activity_legacy')));
    expect(legacy, 1);
  });
  testWidgets(
      'profile uses pet name, fixed header stays after scroll and legacy remains reachable',
      (tester) async {
    var legacy = 0;
    final pet = Pet(
        id: 'p',
        name: 'Individual',
        speciesId: 's',
        speciesName: 'Crested gecko');
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            theme: AppTheme.light,
            home: MyCreActivityScreen(
                header: const Text('Group header'),
                userId: null,
                pet: pet,
                hasCameraConnection: false,
                assignments: const [],
                onAddPet: () {},
                onOpenLegacyReports: () => legacy++))));
    await tester.pump();
    expect(find.text('Individual'), findsOneWidget);
    expect(find.byKey(const Key('activity_no_connection')), findsOneWidget);
    expect(find.byKey(const Key('activity_day_chart')), findsOneWidget);
    final headerY = tester.getTopLeft(find.text('Group header')).dy;
    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -600));
    await tester.pump();
    expect(tester.getTopLeft(find.text('Group header')).dy, headerY);
    await tester.ensureVisible(find.byKey(const Key('activity_legacy')));
    await tester.tap(find.byKey(const Key('activity_legacy')));
    expect(legacy, 1);
    expect(tester.takeException(), isNull);
  });
}
