import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/core/analytics/analytics_consent.dart';
import 'package:vivnanaut/features/profile/domain/user_profile.dart';
import 'package:vivnanaut/features/profile/presentation/profile_providers.dart';
import 'package:vivnanaut/features/profile/presentation/profile_screen.dart';
import 'analytics_consent_test.dart' show MemoryConsentRepository;

class _FailedProfile extends ProfileNotifier {
  @override
  Future<UserProfile?> build() async => throw StateError('profile unavailable');
}

class _LoadingProfile extends ProfileNotifier {
  @override
  Future<UserProfile?> build() => Completer<UserProfile?>().future;
}

void main() {
  for (final loading in [true, false]) {
    testWidgets(
        'analytics withdrawal is accessible when profile ${loading ? 'loads' : 'fails'}',
        (tester) async {
      final repo = MemoryConsentRepository()..values['a'] = true;
      final container = ProviderContainer(overrides: [
        profileNotifierProvider
            .overrideWith(loading ? _LoadingProfile.new : _FailedProfile.new),
        analyticsConsentRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);
      container.read(analyticsConsentProvider.notifier).selectAccount('a');
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProfileScreen())));
      await tester.pump();
      final toggle = find.byKey(const Key('analytics_consent_switch'));
      expect(toggle, findsOneWidget);
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(container.read(analyticsConsentProvider).granted, isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
