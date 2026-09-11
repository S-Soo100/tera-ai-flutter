import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/core/analytics/analytics_events.dart';
import 'package:vivnanaut/core/analytics/analytics_providers.dart';
import 'package:vivnanaut/features/my_cage/domain/nightly_report.dart';
import 'package:vivnanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivnanaut/features/my_pets/data/pet_repository.dart';
import 'package:vivnanaut/features/my_pets/domain/pet.dart';
import 'package:vivnanaut/features/my_pets/presentation/my_pets_screen.dart';
import 'package:vivnanaut/features/profile/domain/user_profile.dart';
import 'package:vivnanaut/features/profile/presentation/profile_providers.dart';

import '../home/analytics_recorder_spy.dart';

class _Repository implements PetRepository {
  @override
  Future<void> clearPets() async {}
  @override
  List<Pet> getAllPets() => [];
  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Profile extends ProfileNotifier {
  @override
  Future<UserProfile?> build() async => null;
}

void main() {
  testWidgets(
      'automatic pets list is not usage; explicit report and list selections are',
      (tester) async {
    final analytics = AnalyticsRecorderSpy();
    await tester.pumpWidget(ProviderScope(overrides: [
      analyticsRecorderProvider.overrideWithValue(analytics),
      petRepositoryProvider.overrideWithValue(_Repository()),
      supabasePetRepositoryProvider.overrideWithValue(null),
      profileNotifierProvider.overrideWith(_Profile.new),
      nightlyReportProvider.overrideWith((ref) async =>
          const NightlyReport(activitySeconds: 0, highlights: [])),
    ], child: const MaterialApp(home: MyPetsScreen())));
    await tester.pumpAndSettle();
    expect(analytics.features, isEmpty);
    await tester.tap(find.text('my_pets_tab_report'));
    await tester.pumpAndSettle();
    expect(analytics.features, [AnalyticsFeature.reports]);
    await tester.tap(find.text('my_pets_tab_list'));
    await tester.pumpAndSettle();
    expect(
        analytics.features, [AnalyticsFeature.reports, AnalyticsFeature.pets]);
    expect(analytics.events, isEmpty,
        reason: 'selection does not claim report read or pet saved');
  });
}
