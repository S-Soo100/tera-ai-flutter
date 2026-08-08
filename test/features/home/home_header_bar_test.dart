import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tera_ai/features/home/domain/enclosure_set.dart';
import 'package:tera_ai/features/home/presentation/home_set_providers.dart';
import 'package:tera_ai/features/home/presentation/widgets/home_header_bar.dart';
import 'package:tera_ai/features/my_cage/domain/enclosure.dart';
import 'package:tera_ai/features/my_pets/domain/pet.dart';
import 'package:tera_ai/features/profile/domain/user_profile.dart';
import 'package:tera_ai/features/profile/presentation/profile_providers.dart';
import 'package:tera_ai/shared/widgets/account_avatar.dart';

EnclosureSet _set(String id, String encName, {String? petName}) => EnclosureSet(
      enclosure:
          Enclosure(id: id, name: encName, createdAt: DateTime(2026, 1, 1)),
      device: null,
      camera: null,
      pet: petName == null
          ? null
          : Pet(
              id: 'p-$id',
              name: petName,
              speciesId: 'crested_gecko',
              speciesName: '크레스티드 게코',
            ),
    );

ProviderContainer _makeContainer(
  List<EnclosureSet> sets,
  int unread,
  UserProfile? profile,
) =>
    ProviderContainer(overrides: [
      enclosureSetsProvider.overrideWith((ref) async => sets),
      unreadNotificationCountProvider.overrideWith((ref) => unread),
      profileNotifierProvider.overrideWith(() => _StubProfile(profile)),
    ]);

class _StubProfile extends ProfileNotifier {
  _StubProfile(this._profile);
  final UserProfile? _profile;
  @override
  Future<UserProfile?> build() async => _profile;
}

UserProfile _profile({String? name, String? avatar}) => UserProfile(
      id: 'u1',
      displayName: name,
      avatarUrl: avatar,
      timezone: 'Asia/Seoul',
      preferredSpecies: const [],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Future<ProviderContainer> _pump(
  WidgetTester tester,
  List<EnclosureSet> sets, {
  int unread = 0,
  UserProfile? profile,
}) async {
  final c = _makeContainer(sets, unread, profile);
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(routerConfig: _router()),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

/// 아바타 탭이 라우팅이라 GoRouter가 필요하다. 실제 앱과 같은 경로를 쓴다 —
/// 경로가 어긋나면 여기서 잡힌다.
GoRouter _router() => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: HomeHeaderBar()),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('profile-screen'))),
        ),
      ],
    );

void main() {
  testWidgets('현재 세트 라벨을 보여준다', (tester) async {
    await _pump(tester, [_set('e1', '1번 사육장', petName: '젤리')]);
    // 개체명과 사육장명을 **한 덩어리로 합치지 않는다** — 뭐가 주인공인지
    // 읽는 사람이 매번 판단하게 만들지 않기 위함.
    expect(find.text('젤리'), findsOneWidget);
    expect(find.text('1번 사육장'), findsOneWidget);
    expect(find.text('젤리 (1번 사육장)'), findsNothing);
  });

  testWidgets('세트가 1개면 드롭다운 화살표 비노출 (PRD §3.1 예외)', (tester) async {
    await _pump(tester, [_set('e1', '1번 사육장')]);
    expect(find.byKey(HomeHeaderBar.dropdownArrowKey), findsNothing);
  });

  testWidgets('세트가 2개 이상이면 화살표 노출', (tester) async {
    await _pump(tester, [_set('e1', 'A'), _set('e2', 'B')]);
    expect(find.byKey(HomeHeaderBar.dropdownArrowKey), findsOneWidget);
  });

  testWidgets('드롭다운에서 다른 세트를 고르면 선택 인덱스가 바뀐다', (tester) async {
    final c = await _pump(tester, [_set('e1', 'A'), _set('e2', 'B')]);

    await tester.tap(find.byKey(HomeHeaderBar.dropdownArrowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B').last);
    await tester.pumpAndSettle();

    expect(c.read(selectedSetIndexProvider), 1);
  });

  testWidgets('미읽음 0이면 Red Dot 없음', (tester) async {
    await _pump(tester, [_set('e1', 'A')], unread: 0);
    expect(find.byKey(HomeHeaderBar.redDotKey), findsNothing);
  });

  testWidgets('미읽음이 있으면 Red Dot 노출', (tester) async {
    await _pump(tester, [_set('e1', 'A')], unread: 3);
    expect(find.byKey(HomeHeaderBar.redDotKey), findsOneWidget);
  });

  testWidgets('세트가 없으면 빈 라벨로 죽지 않는다', (tester) async {
    await _pump(tester, const []);
    expect(find.byType(HomeHeaderBar), findsOneWidget);
  });

  group('내 계정 아바타', () {
    testWidgets('탭하면 프로필 화면으로 간다 — 여기가 계정으로 가는 유일한 문이다',
        (tester) async {
      await _pump(tester, [_set('e1', 'A')], profile: _profile(name: '수'));
      await tester.tap(find.byKey(HomeHeaderBar.accountAvatarKey));
      await tester.pumpAndSettle();
      expect(find.text('profile-screen'), findsOneWidget);
    });

    testWidgets('프로필이 아직 없어도 아바타는 그린다 — 감추면 로그아웃이 잠긴다',
        (tester) async {
      await _pump(tester, [_set('e1', 'A')], profile: null);
      expect(find.byKey(HomeHeaderBar.accountAvatarKey), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('사진이 없으면 표시명 첫 글자로 떨어진다', (tester) async {
      await _pump(tester, [_set('e1', 'A')], profile: _profile(name: '수정'));
      expect(find.text('수'), findsOneWidget);
    });

    testWidgets('알림 점을 달지 않는다 — 옆의 🔔과 경쟁시키지 않는다', (tester) async {
      await _pump(tester, [_set('e1', 'A')],
          unread: 3, profile: _profile(name: '수'));
      // Red Dot은 🔔에만 하나.
      expect(find.byKey(HomeHeaderBar.redDotKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(HomeHeaderBar.accountAvatarKey),
          matching: find.byKey(HomeHeaderBar.redDotKey),
        ),
        findsNothing,
      );
    });
  });

  group('AccountAvatar.initialOf', () {
    test('한글은 그대로', () => expect(AccountAvatar.initialOf('수정'), '수'));
    test('영문은 대문자', () => expect(AccountAvatar.initialOf('seung'), 'S'));
    test('앞뒤 공백을 무시한다',
        () => expect(AccountAvatar.initialOf('  베  '), '베'));
    test('비어 있으면 null — 아이콘으로 떨어진다', () {
      expect(AccountAvatar.initialOf(null), isNull);
      expect(AccountAvatar.initialOf('   '), isNull);
    });
  });
}
