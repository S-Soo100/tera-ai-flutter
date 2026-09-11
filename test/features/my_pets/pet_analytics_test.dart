import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivnanaut/core/analytics/analytics_events.dart';
import 'package:vivnanaut/core/analytics/analytics_providers.dart';
import 'package:vivnanaut/features/my_pets/data/pet_repository.dart';
import 'package:vivnanaut/features/my_pets/domain/pet.dart';
import 'package:vivnanaut/features/my_pets/presentation/pet_add_screen.dart';
import 'package:vivnanaut/features/my_pets/presentation/pet_edit_screen.dart';

import '../home/analytics_recorder_spy.dart';

class _Repository implements PetRepository {
  final save = Completer<void>();
  final pet = Pet(
      id: 'private-pet',
      name: 'private-name',
      speciesId: 'crested_gecko',
      speciesName: '크레스티드 게코');
  @override
  Future<void> clearPets() async {}
  @override
  List<Pet> getAllPets() => [pet];
  @override
  Pet? getPet(String id) => pet;
  @override
  Future<void> addPet(Pet pet) => save.future;
  @override
  Future<void> updatePet(Pet pet) => save.future;
  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  for (final edit in [false, true]) {
    for (final outcome in ['success', 'account-change']) {
      testWidgets(
          'pet ${edit ? 'edit' : 'add'} $outcome records confirmed save only',
          (tester) async {
        tester.view.physicalSize = const Size(1000, 2100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _Repository();
        final analytics = AnalyticsRecorderSpy();
        final router = GoRouter(routes: [
          GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(body: Text('done'))),
          GoRoute(
              path: '/form',
              builder: (_, __) => edit
                  ? const PetEditScreen(petId: 'private-pet')
                  : const PetAddScreen()),
        ]);
        addTearDown(router.dispose);
        await tester.pumpWidget(ProviderScope(overrides: [
          analyticsRecorderProvider.overrideWithValue(analytics),
          petRepositoryProvider.overrideWithValue(repository),
          supabasePetRepositoryProvider.overrideWithValue(null),
        ], child: MaterialApp.router(routerConfig: router)));
        router.push('/form');
        await tester.pumpAndSettle();
        expect(analytics.features, isEmpty);
        expect(analytics.events, isEmpty);
        if (!edit) {
          await tester.enterText(
              find.byType(TextFormField).first, 'private-name');
          await tester.tap(find.byType(DropdownButtonFormField<String>).first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('크레스티드 게코').last);
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.byType(FilledButton).last);
        await tester.tap(find.byType(FilledButton).last);
        await tester.pump();
        expect(analytics.features, [AnalyticsFeature.pets]);
        expect(analytics.events, isEmpty);
        if (outcome == 'account-change') analytics.epoch++;
        repository.save.complete();
        await tester.pumpAndSettle();
        expect(analytics.events,
            outcome == 'success' ? [AnalyticsEvent.petSaved] : isEmpty);
      });
    }
  }
}
