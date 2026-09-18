import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/my_pets/data/pet_event_repository.dart';
import 'package:vivanaut/features/my_pets/data/pet_repository.dart';
import 'package:vivanaut/features/my_pets/domain/media_item.dart';
import 'package:vivanaut/features/my_pets/domain/pet.dart';
import 'package:vivanaut/features/my_pets/domain/pet_event.dart';
import 'package:vivanaut/features/my_pets/presentation/my_pets_providers.dart';
import 'package:vivanaut/features/my_pets/presentation/pet_detail_screen.dart';
import 'package:vivanaut/features/my_pets/presentation/pet_form_route.dart';

/// P18 — 구형 경로 `/my-pets/:petId`(기기관리 → 개체 탭에서 아직 진입)의 삭제
/// 확인창을 승인된 23번 공통 확인창·문구로 맞췄는지 본다.
class _Pets extends PetRepository {
  _Pets(this.pet);
  final Pet pet;
  @override
  List<Pet> getAllPets() => [pet];
  @override
  Future<void> clearPets() async {}
}

class _Events extends PetEventRepository {
  @override
  List<PetEvent> getEvents(String petId) => const [];
}

class _Media extends PetMediaNotifier {
  @override
  Future<List<MediaItem>> build(String arg) async => const [];
}

class _Strings extends AssetLoader {
  const _Strings();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/l10n/ko.json').readAsStringSync())
          as Map<String, dynamic>;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('구형 개체 상세의 삭제도 공통 확인창(을/를 문구·빨간 삭제)을 거친다', (tester) async {
    final pet = Pet(
        id: 'p', name: '크랑이', speciesId: 'crested', speciesName: '크레스티드 게코');
    final deleted = <String>[];
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
              body: TextButton(
                  onPressed: () => context.push('/my-pets/p'),
                  child: const Text('open')))),
      GoRoute(
          path: '/my-pets/:petId',
          builder: (_, state) =>
              PetDetailScreen(petId: state.pathParameters['petId']!)),
    ]);
    await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('ko')],
        startLocale: const Locale('ko'),
        path: 'assets/l10n',
        assetLoader: const _Strings(),
        child: Builder(
            builder: (context) => ProviderScope(
                    overrides: [
                      petListProvider.overrideWith(
                          (ref) => PetListNotifier(_Pets(pet), null)),
                      petEventRepositoryProvider.overrideWithValue(_Events()),
                      petMediaProvider.overrideWith(_Media.new),
                      currentUserProvider.overrideWith((ref) => null),
                      deleteRedesignPetProvider
                          .overrideWithValue((p) async => deleted.add(p.id)),
                    ],
                    child: MaterialApp.router(
                        theme: AppTheme.light,
                        locale: context.locale,
                        supportedLocales: context.supportedLocales,
                        localizationsDelegates: context.localizationDelegates,
                        routerConfig: router)))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(PetDetailScreen), findsOneWidget);

    await tester.tap(find.byTooltip('삭제'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('크랑이를 삭제하시겠습니까?\n크레 활동 데이터, 그래프도 삭제됩니다.'), findsOneWidget);
    // 취소는 아무것도 안 한다.
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(deleted, isEmpty);
    expect(find.byType(PetDetailScreen), findsOneWidget);

    await tester.tap(find.byTooltip('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();
    expect(deleted, ['p']);
    expect(find.byType(PetDetailScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
