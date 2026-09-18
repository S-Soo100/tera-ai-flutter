// 로그인 화면 Figma 좌표 검증 (1133:5712 기본 · 1134:6617 오류 · 1134:6472 키보드).
import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/auth/data/login_prefs_repository.dart';
import 'package:vivanaut/features/auth/presentation/login_screen.dart';
import 'package:vivanaut/shared/widgets/figma_icon.dart';

class _Strings extends AssetLoader {
  const _Strings();
  @override
  Future<Map<String, dynamic>> load(String p, Locale l) async =>
      jsonDecode(File('assets/l10n/ko.json').readAsStringSync())
          as Map<String, dynamic>;
}

class _Prefs implements LoginPrefsRepository {
  _Prefs({this.lastEmail, this.autoLogin = true});
  @override
  String? lastEmail;
  @override
  bool autoLogin;
  Map<String, Object>? saved;
  @override
  Future<void> save({required String email, required bool autoLogin}) async =>
      saved = {'email': email, 'autoLogin': autoLogin};
}

Widget _app(LoginPrefsRepository prefs) => ProviderScope(
    overrides: [loginPrefsProvider.overrideWithValue(prefs)],
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
                // 실기기처럼 키보드가 열리면 하단 안전영역(34)은 0으로 보고된다.
                builder: (c, child) => MediaQuery(
                    data: MediaQuery.of(c).copyWith(
                        padding: EdgeInsets.only(
                            top: 62,
                            bottom: MediaQuery.of(c).viewInsets.bottom > 0
                                ? 0
                                : 34)),
                    child: child!),
                home: const LoginScreen()))));

Future<void> _pump(WidgetTester tester, {LoginPrefsRepository? prefs}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(prefs ?? _Prefs()));
  await tester.pumpAndSettle();
}

Rect _rect(WidgetTester tester, Finder f) => tester.getRect(f);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('기본 상태 — 로고·필드·체크·CTA 좌표', (tester) async {
    await _pump(tester);
    final logo = _rect(tester, find.byKey(const ValueKey('login-logo')));
    expect(logo.left, closeTo(96.5, 0.6));
    expect(logo.top, closeTo(98, 0.5));
    expect(logo.width, closeTo(200, 0.5));

    final idLabel = _rect(tester, find.text('아이디'));
    expect(idLabel.left, 24);
    expect(idLabel.top, closeTo(178.6, 0.6));

    final email = _rect(tester, find.byKey(const ValueKey('login-email')));
    expect(email.left, 12);
    expect(email.width, 369);
    expect(email.height, 65);
    expect(email.top, closeTo(209.6, 0.6));
    final hint = _rect(tester, find.text('vivanaut@gmail.com'));
    expect(hint.left, closeTo(29, 0.5));

    final pw = _rect(tester, find.byKey(const ValueKey('login-password')));
    expect(pw.top, closeTo(329.6, 0.6));
    final eye = _rect(
        tester, find.byKey(const ValueKey('login-password-visibility')));
    expect(eye.left, closeTo(340, 0.5));
    expect(eye.width, 24);
    expect(eye.center.dy, closeTo(pw.center.dy, 0.5));
    expect(
        tester
            .widget<FigmaIcon>(find.descendant(
                of: find.byKey(const ValueKey('login-password-visibility')),
                matching: find.byType(FigmaIcon)))
            .name,
        'redesign_v2/visibility');

    final check = _rect(tester, find.byKey(const ValueKey('login-auto-login')));
    expect(check.left, 20);
    expect(check.top, closeTo(406.6, 0.6));
    expect(check.height, 24);
    final checkLabel = _rect(tester, find.text('자동 로그인'));
    expect(checkLabel.left, 48);

    final cta = _rect(tester, find.byKey(const ValueKey('login-submit')));
    expect(cta, const Rect.fromLTWH(12, 696, 369, 56));
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('login-submit'))).onPressed,
        isNull);
    final signup = _rect(tester, find.byKey(const ValueKey('login-signup')));
    expect(signup.top, 752);
    expect(find.byKey(const ValueKey('login-password-error')), findsNothing);
  });

  testWidgets('둘 다 입력하면 CTA 활성, 눈 아이콘 토글', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byKey(const ValueKey('login-email')), 'a@b.co');
    await tester.enterText(find.byKey(const ValueKey('login-password')), '123456');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('login-submit'))).onPressed,
        isNotNull);
    await tester.tap(find.byKey(const ValueKey('login-password-visibility')));
    await tester.pump();
    expect(
        tester
            .widget<FigmaIcon>(find.descendant(
                of: find.byKey(const ValueKey('login-password-visibility')),
                matching: find.byType(FigmaIcon)))
            .name,
        'redesign_v2/visibility_off');
    expect(tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
        isFalse);
  });

  testWidgets('오류 상태 — 이메일 형식·비밀번호 규칙 문구 위치', (tester) async {
    await _pump(tester);
    await tester.enterText(
        find.byKey(const ValueKey('login-email')), 'vivanaut@gmail.');
    await tester.enterText(find.byKey(const ValueKey('login-password')), '12345');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();

    final emailError = _rect(tester, find.text('올바른 이메일 형식을 입력해 주세요'));
    expect(emailError.right, 369); // 오른쪽 정렬, 안쪽 12
    expect(emailError.top, closeTo(282.6, 0.6));
    expect(
        tester
            .widget<Text>(find.text('올바른 이메일 형식을 입력해 주세요'))
            .textAlign,
        TextAlign.right);
    // 뒤 항목은 밀리지 않는다.
    expect(_rect(tester, find.text('비밀번호')).top, closeTo(298.6, 0.6));
    final pwError =
        _rect(tester, find.byKey(const ValueKey('login-password-error')));
    expect(pwError.right, 373);
    expect(pwError.center.dy, closeTo(418.6, 0.8));
    // 다른 칸을 고쳐도 이 칸 오류는 남는다.
    await tester.enterText(find.byKey(const ValueKey('login-password')), '123456');
    await tester.pump();
    expect(find.text('올바른 이메일 형식을 입력해 주세요'), findsOneWidget);
    expect(find.byKey(const ValueKey('login-password-error')), findsNothing);
    // 고치기 시작하면 오류가 사라진다.
    await tester.enterText(
        find.byKey(const ValueKey('login-email')), 'vivanaut@gmail.com');
    await tester.pump();
    expect(find.text('올바른 이메일 형식을 입력해 주세요'), findsNothing);
  });

  testWidgets('키보드가 열리면 CTA는 키보드 위 12, 가입 링크 숨김', (tester) async {
    await _pump(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 287);
    await tester.pumpAndSettle();
    final cta = _rect(tester, find.byKey(const ValueKey('login-submit')));
    expect(cta.bottom, closeTo(852 - 287 - 12, 0.5));
    expect(find.byKey(const ValueKey('login-signup')), findsNothing);
  });

  testWidgets('마지막 아이디·자동 로그인 값을 불러온다', (tester) async {
    await _pump(tester, prefs: _Prefs(lastEmail: 'x@y.z', autoLogin: false));
    expect(find.text('x@y.z'), findsOneWidget);
    final icon = tester.widget<FigmaIcon>(find.descendant(
        of: find.byKey(const ValueKey('login-auto-login')),
        matching: find.byType(FigmaIcon)));
    expect(icon.name, 'redesign_v2/check_box_outline_blank_400');
    await tester.tap(find.byKey(const ValueKey('login-auto-login')));
    await tester.pump();
    expect(
        tester
            .widget<FigmaIcon>(find.descendant(
                of: find.byKey(const ValueKey('login-auto-login')),
                matching: find.byType(FigmaIcon)))
            .name,
        'redesign_v2/check_box_400');
  });
}
