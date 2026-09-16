// 마이 페이지 계열 Figma 좌표 검증 (1142:8860 / 1134:7760 / 1142:8361 / 1142:9613).
import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/community/presentation/community_providers.dart';
import 'package:vivanaut/features/notification/presentation/notification_providers.dart';
import 'package:vivanaut/features/profile/data/notification_preferences_repository.dart';
import 'package:vivanaut/features/profile/domain/user_profile.dart';
import 'package:vivanaut/features/profile/presentation/account_screen.dart';
import 'package:vivanaut/features/profile/presentation/notification_settings_screen.dart';
import 'package:vivanaut/features/profile/presentation/password_change_screen.dart';
import 'package:vivanaut/features/profile/presentation/profile_providers.dart';
import 'package:vivanaut/features/profile/presentation/profile_screen.dart';
import 'package:vivanaut/features/profile/presentation/withdraw_screen.dart';
import 'package:vivanaut/features/home/presentation/routine_settings_screen.dart'
    show ScheduleSwitch;

class _Strings extends AssetLoader {
  const _Strings();
  @override
  Future<Map<String, dynamic>> load(String p, Locale l) async =>
      jsonDecode(File('assets/l10n/ko.json').readAsStringSync())
          as Map<String, dynamic>;
}

class _Profile extends ProfileNotifier {
  _Profile(this.profile);
  final UserProfile? profile;
  @override
  Future<UserProfile?> build() async => profile;
}

class _MemPrefs implements NotificationPreferencesRepository {
  NotificationPrefs prefs = const NotificationPrefs();
  @override
  NotificationPrefs load() => prefs;
  @override
  Future<void> save(NotificationPrefs p) async => prefs = p;
}

List<Override> overrides({UserProfile? profile, int blocked = 0}) => [
      currentUserProvider.overrideWith((ref) => null),
      profileNotifierProvider.overrideWith(() => _Profile(profile)),
      appVersionProvider.overrideWith((ref) async => '0.90.3+173'),
      blockedProfilesProvider.overrideWith((ref) async => [
            for (var i = 0; i < blocked; i++)
              (id: 'u$i', name: '닉네임', avatarUrl: null)
          ]),
      unreadNotificationCountProvider.overrideWithValue(0),
      notificationPreferencesRepositoryProvider
          .overrideWithValue(_MemPrefs()),
    ];

Widget app(Widget home, List<Override> ov) => ProviderScope(
    overrides: ov,
    child: EasyLocalization(
        supportedLocales: const [Locale('ko')],
        startLocale: const Locale('ko'),
        path: 'assets/l10n',
        assetLoader: const _Strings(),
        child: Builder(
            builder: (c) => MaterialApp(
                theme: AppTheme.light,
                locale: c.locale,
                supportedLocales: c.supportedLocales,
                localizationsDelegates: c.localizationDelegates,
                builder: (c, child) => MediaQuery(
                    data: MediaQuery.of(c).copyWith(
                        padding: const EdgeInsets.only(top: 62, bottom: 34)),
                    child: child!),
                home: home))));

Future<void> pump(WidgetTester tester, Widget home, List<Override> ov) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app(home, ov));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('마이 페이지 — 제목·카드·행 좌표', (tester) async {
    await pump(tester, const ProfileScreen(), overrides(blocked: 2));
    final title = tester.getRect(find.text('마이 페이지'));
    expect(title.center.dx, closeTo(196.5, 1));
    expect(title.top, closeTo(74.5, 1));
    expect(tester.getRect(find.text('커뮤니티 설정')).topLeft,
        const Offset(24, 122));
    final card = tester.getRect(find.byKey(ProfileScreen.profileCardKey));
    expect(card, const Rect.fromLTWH(12, 149, 369, 76));
    expect(find.text('자동생성닉네임'), findsOneWidget);
    expect(find.text('사육 경험 정보를 추가해 주세요'), findsOneWidget);
    final blocked = tester.getRect(find.byKey(ProfileScreen.blockedRowKey));
    expect(blocked, const Rect.fromLTWH(12, 233, 369, 64));
    expect(find.text('2명'), findsOneWidget);
    expect(tester.getRect(find.text('앱 설정')).topLeft, const Offset(24, 321));
    expect(tester.getRect(find.byKey(ProfileScreen.notificationsRowKey)),
        const Rect.fromLTWH(12, 348, 369, 64));
    expect(tester.getRect(find.byKey(ProfileScreen.accountRowKey)),
        const Rect.fromLTWH(12, 420, 369, 64));
    expect(tester.getRect(find.byKey(ProfileScreen.versionRowKey)),
        const Rect.fromLTWH(12, 492, 369, 64));
    expect(find.text('0.90.3 (173)'), findsOneWidget);
    // 원본에 없는 행은 그 아래.
    expect(tester.getRect(find.byKey(ProfileScreen.inboxRowKey)).top,
        greaterThan(556));
  });

  testWidgets('프로필 카드 — 사육 경험이 있으면 태그와 설명', (tester) async {
    await pump(
        tester,
        const ProfileScreen(),
        overrides(
            profile: UserProfile(
                id: 'u',
                displayName: '레이 토마토',
                experience: 'beginner',
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026))));
    expect(find.text('레이 토마토'), findsOneWidget);
    expect(find.text('입문자'), findsOneWidget);
    expect(find.text('1년 미만'), findsOneWidget);
  });

  testWidgets('내 계정 — 행 122/194, 로그아웃 CTA 696', (tester) async {
    await pump(tester, const AccountScreen(), overrides());
    expect(tester.getRect(find.byKey(AccountScreen.passwordRowKey)),
        const Rect.fromLTWH(12, 122, 369, 64));
    expect(tester.getRect(find.byKey(AccountScreen.withdrawRowKey)),
        const Rect.fromLTWH(12, 194, 369, 64));
    expect(tester.getRect(find.byKey(AccountScreen.logoutKey)),
        const Rect.fromLTWH(12, 696, 369, 56));
  });

  testWidgets('회원 탈퇴 — 문구 y122, CTA 696', (tester) async {
    await pump(tester, const WithdrawScreen(), overrides());
    expect(tester.getRect(find.text('회원 탈퇴를 진행하시겠습니까?')).top,
        closeTo(122, 1));
    expect(tester.getRect(find.byKey(WithdrawScreen.submitKey)),
        const Rect.fromLTWH(12, 696, 369, 56));
  });

  testWidgets('비밀번호 변경 — 필드 153/289/409, 세 칸 채워야 CTA, 규칙 미충족 안내',
      (tester) async {
    await pump(tester, const PasswordChangeScreen(), overrides());
    expect(tester.getRect(find.byKey(PasswordChangeScreen.currentKey)).top,
        closeTo(153, 1));
    expect(tester.getRect(find.byKey(PasswordChangeScreen.newKey)).top,
        closeTo(289, 1));
    expect(tester.getRect(find.byKey(PasswordChangeScreen.confirmKey)).top,
        closeTo(409, 1));
    FilledButton cta() => tester.widget<FilledButton>(find.descendant(
        of: find.byKey(PasswordChangeScreen.submitKey),
        matching: find.byType(FilledButton)));
    expect(cta().onPressed, isNull);
    await tester.enterText(find.byKey(PasswordChangeScreen.currentKey), 'old');
    await tester.enterText(find.byKey(PasswordChangeScreen.newKey), '1235113213');
    await tester.enterText(
        find.byKey(PasswordChangeScreen.confirmKey), '1235113213');
    await tester.pump();
    expect(cta().onPressed, isNotNull);
    await tester.tap(find.byKey(PasswordChangeScreen.submitKey));
    await tester.pumpAndSettle();
    // 힌트 2 + 오류 안내 2.
    expect(find.text('영문+숫자+특수문자 6자~12자'), findsNWidgets(4));
    expect(PasswordChangeScreen.meetsRule('sdf45412ds@'), isTrue);
    expect(PasswordChangeScreen.meetsRule('1235113213'), isFalse);
    expect(PasswordChangeScreen.meetsRule('a1!'), isFalse);
  });

  testWidgets('알림 설정 — 토글 저장, 마케팅 동의 일자', (tester) async {
    await pump(tester, const NotificationSettingsScreen(), overrides());
    expect(tester.getRect(find.text('기능 설정')).top, closeTo(118.5, 1));
    expect(tester.getRect(find.byKey(NotificationSettingsScreen.highlightKey)),
        const Rect.fromLTWH(12, 145.5, 369, 72));
    await tester.tap(find.descendant(
        of: find.byKey(NotificationSettingsScreen.marketingKey),
        matching: find.byType(ScheduleSwitch)));
    await tester.pumpAndSettle();
    expect(find.textContaining('수신 동의 20'), findsOneWidget);
  });
}
