import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/core/analytics/analytics_consent.dart';
import 'package:vivnanaut/core/analytics/analytics_consent_tile.dart';
import 'analytics_consent_test.dart' show MemoryConsentRepository;

void main() {
  testWidgets(
      'optional choice saves independently from deployment and can be withdrawn',
      (tester) async {
    final repo = MemoryConsentRepository();
    final container = ProviderContainer(overrides: [
      analyticsConsentRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    container.read(analyticsConsentProvider.notifier).selectAccount('a');
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child:
            const MaterialApp(home: Scaffold(body: AnalyticsConsentTile()))));
    expect(find.text('analytics_consent_preparing'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(repo.values['a'], isTrue);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(repo.values['a'], isFalse);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse);
  });
}
