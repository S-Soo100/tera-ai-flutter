// UX-02 (2026-10-01): 개체 조회 실패·로딩을 "개체 없음"으로 보이지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/my_pets/data/pet_repository.dart';
import 'package:vivanaut/features/my_pets/data/supabase_pet_repository.dart';
import 'package:vivanaut/features/my_pets/domain/pet.dart';
import 'package:vivanaut/features/my_pets/presentation/my_cre_activity_screen.dart';
import 'package:vivanaut/features/my_pets/presentation/my_pets_providers.dart';
import 'package:vivanaut/features/my_pets/presentation/widgets/pet_list_status_view.dart';

class _Local extends PetRepository {}

class _Remote implements SupabasePetRepository {
  bool fail = true;
  List<Pet> cache = const [];
  int syncs = 0;
  @override
  Future<void> syncFromRemote() async {
    syncs++;
    if (fail) throw Exception('network');
    cache = [Pet(id: 'p', name: '모찌', speciesId: 's', speciesName: 'Gecko')];
  }

  @override
  List<Pet> getAllPets() => cache;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container(_Remote remote) => ProviderContainer(overrides: [
      currentUserProvider.overrideWithValue(null),
      petRepositoryProvider.overrideWithValue(_Local()),
      supabasePetRepositoryProvider.overrideWithValue(remote),
    ]);

Widget _screen(PetListLoad load) => ProviderScope(
    child: MaterialApp(
        theme: AppTheme.light,
        home: MyCreActivityScreen(
          header: const Text('header'),
          userId: null,
          pet: null,
          petLoad: load,
          hasCameraConnection: false,
          assignments: const [],
          onAddPet: () {},
        )));

void main() {
  test('첫 조회 실패는 failed, 다시 시도 성공은 ready + 목록 복원', () async {
    final remote = _Remote();
    final c = _container(remote);
    addTearDown(c.dispose);
    expect(c.read(petListProvider), isEmpty);
    expect(c.read(petListLoadProvider), PetListLoad.loading);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(petListLoadProvider), PetListLoad.failed);
    expect(c.read(petListProvider), isEmpty);

    remote.fail = false;
    await c.read(petListProvider.notifier).syncFromRemote();
    expect(c.read(petListLoadProvider), PetListLoad.ready);
    expect(c.read(petListProvider).single.name, '모찌');
  });

  test('갱신 실패는 이미 보이던 목록을 지우지 않는다', () async {
    final remote = _Remote()..fail = false;
    final c = _container(remote);
    addTearDown(c.dispose);
    c.read(petListProvider);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(petListProvider), hasLength(1));
    remote.fail = true;
    await expectLater(
        c.read(petListProvider.notifier).syncFromRemote(), throwsException);
    expect(c.read(petListProvider), hasLength(1));
    expect(c.read(petListLoadProvider), PetListLoad.failed);
  });

  test('로컬 모드(비로그인)는 바로 ready', () {
    final c = ProviderContainer(overrides: [
      currentUserProvider.overrideWithValue(null),
      petRepositoryProvider.overrideWithValue(_Local()),
      supabasePetRepositoryProvider.overrideWithValue(null),
    ]);
    addTearDown(c.dispose);
    expect(c.read(petListLoadProvider), PetListLoad.ready);
  });

  testWidgets('로딩 중엔 개체 추가 안내 대신 스켈레톤', (tester) async {
    await tester.pumpWidget(_screen(PetListLoad.loading));
    expect(find.byKey(const Key('pet_list_loading')), findsOneWidget);
    expect(find.byKey(const Key('activity_add_pet')), findsNothing);
  });

  testWidgets('실패면 다시 시도, 개체 추가 안내 없음', (tester) async {
    await tester.pumpWidget(_screen(PetListLoad.failed));
    expect(find.byKey(PetListStatusView.retryKey), findsOneWidget);
    expect(find.byKey(const Key('activity_add_pet')), findsNothing);
  });

  testWidgets('조회 성공 0마리일 때만 개체 추가 안내', (tester) async {
    await tester.pumpWidget(_screen(PetListLoad.ready));
    expect(find.byKey(const Key('activity_add_pet')), findsOneWidget);
    expect(find.byKey(PetListStatusView.retryKey), findsNothing);
  });
}
