// UX-01·03·07 (2026-10-01): 비밀번호 규칙 통일, 인증번호 입력, 비밀번호 재설정.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/auth/data/auth_repository.dart';
import 'package:vivanaut/features/auth/domain/password_rule.dart';
import 'package:vivanaut/features/auth/presentation/auth_error_text.dart';
import 'package:vivanaut/features/auth/presentation/email_verification_screen.dart';
import 'package:vivanaut/features/auth/presentation/password_reset_screen.dart';
import 'package:vivanaut/features/auth/presentation/widgets/otp_code_field.dart';

class _Strings extends AssetLoader {
  const _Strings();
  @override
  Future<Map<String, dynamic>> load(String p, Locale l) async =>
      jsonDecode(File('assets/l10n/ko.json').readAsStringSync())
          as Map<String, dynamic>;
}

class _FakeAuth implements AuthRepository {
  int verifyCalls = 0;
  int resetSends = 0;
  int resetVerifies = 0;
  String? updatedPassword;
  Object? verifyError;
  Completer<void>? verifyGate;

  @override
  Future<AuthResponse> verifyOTP(
      {required String email, required String token}) async {
    verifyCalls++;
    await verifyGate?.future;
    if (verifyError != null) throw verifyError!;
    return AuthResponse();
  }

  @override
  Future<void> sendPasswordResetCode({required String email}) async =>
      resetSends++;

  @override
  Future<void> verifyPasswordResetCode(
      {required String email, required String token}) async {
    resetVerifies++;
    if (verifyError != null) throw verifyError!;
  }

  @override
  Future<void> updatePassword(String next) async => updatedPassword = next;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget home, {AuthRepository? auth}) => ProviderScope(
    overrides: [
      if (auth != null) authRepositoryProvider.overrideWithValue(auth),
    ],
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
                home: home))));

Future<void> _pump(WidgetTester tester, Widget home,
    {AuthRepository? auth, double width = 393}) async {
  tester.view.physicalSize = Size(width, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(home, auth: auth));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('UX-07 비밀번호 규칙', () {
    test('영문+숫자+특수문자 6~12자만 통과', () {
      expect(meetsPasswordRule('abc12!'), isTrue);
      expect(meetsPasswordRule('sdf45412ds@'), isTrue);
      expect(meetsPasswordRule('abc123'), isFalse); // 특수문자 없음
      expect(meetsPasswordRule('abcdef!'), isFalse); // 숫자 없음
      expect(meetsPasswordRule('12345!'), isFalse); // 영문 없음
      expect(meetsPasswordRule('a1!'), isFalse); // 짧음
      expect(meetsPasswordRule('abcdefg1234!!'), isFalse); // 13자
    });
  });

  group('인증 오류 문구', () {
    testWidgets('서버 영문 메시지를 한글 안내로 바꾼다', (tester) async {
      await _pump(tester, const SizedBox());
      expect(
          authErrorText(const AuthException('Token has expired or is invalid',
              code: 'otp_expired')),
          contains('인증번호'));
      expect(authErrorText(const AuthException('x', code: 'same_password')),
          contains('다른 비밀번호'));
      expect(authErrorText(AuthRetryableFetchException(message: 'x')),
          contains('인터넷'));
      expect(
          authErrorText(
              const AuthException('rate', statusCode: '429', code: 'x')),
          contains('잠시 후'));
      expect(authErrorText(StateError('x')), contains('잠시 후'));
    });
  });

  group('UX-03 인증번호 입력', () {
    for (final width in [320.0, 375.0, 393.0]) {
      testWidgets('폭 $width에서 넘치지 않는다', (tester) async {
        await _pump(
            tester,
            EmailVerificationScreen(email: 'a@b.co'),
            auth: _FakeAuth(),
            width: width);
        expect(tester.takeException(), isNull);
        final field = tester.getRect(find.byType(OtpCodeField));
        expect(field.left, greaterThanOrEqualTo(24));
        expect(field.right, lessThanOrEqualTo(width - 24));
      });
    }

    testWidgets('붙여넣기(공백·기호 섞임)도 6자리로 들어가고 인증은 한 번만',
        (tester) async {
      final auth = _FakeAuth()..verifyGate = Completer<void>();
      await _pump(tester, EmailVerificationScreen(email: 'a@b.co'), auth: auth);
      await tester.enterText(find.byKey(OtpCodeField.fieldKey), '123 456');
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(auth.verifyCalls, 1);
      // 확인 중 버튼은 꺼져 있다.
      final button =
          tester.widget<FilledButton>(find.byKey(const Key('otp-verify')));
      expect(button.onPressed, isNull);
      auth.verifyGate!.complete();
      await tester.pump();
    });

    testWidgets('틀린 코드면 비우고 한글 오류를 칸 아래에 남긴다', (tester) async {
      final auth = _FakeAuth()
        ..verifyError =
            const AuthException('Token has expired or is invalid');
      await _pump(tester, EmailVerificationScreen(email: 'a@b.co'), auth: auth);
      await tester.enterText(find.byKey(OtpCodeField.fieldKey), '123456');
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('otp-error')), findsOneWidget);
      expect(
          tester
              .widget<TextField>(find.byKey(OtpCodeField.fieldKey))
              .controller!
              .text,
          isEmpty);
      // 다시 입력하면 오류가 사라진다.
      await tester.enterText(find.byKey(OtpCodeField.fieldKey), '1');
      await tester.pump();
      expect(find.byKey(const Key('otp-error')), findsNothing);
    });
  });

  group('UX-01 비밀번호 재설정', () {
    testWidgets('이메일 → 인증번호 → 새 비밀번호 단계', (tester) async {
      final auth = _FakeAuth();
      await _pump(tester, const PasswordResetScreen(initialEmail: 'a@b.co'),
          auth: auth);
      await tester.tap(find.byKey(PasswordResetScreen.submitKey));
      await tester.pump();
      await tester.pump();
      expect(auth.resetSends, 1);
      expect(find.byType(OtpCodeField), findsOneWidget);

      await tester.enterText(find.byKey(OtpCodeField.fieldKey), '654321');
      await tester.pump();
      await tester.pump();
      expect(auth.resetVerifies, 1);
      expect(find.byKey(PasswordResetScreen.newKey), findsOneWidget);

      // 규칙 미충족은 저장하지 않고 규칙 안내.
      await tester.enterText(find.byKey(PasswordResetScreen.newKey), 'abc123');
      await tester.enterText(
          find.byKey(PasswordResetScreen.confirmKey), 'abc123');
      await tester.pump();
      await tester.tap(find.byKey(PasswordResetScreen.submitKey));
      await tester.pump();
      expect(auth.updatedPassword, isNull);
      expect(find.byKey(const Key('pw-reset-error')), findsOneWidget);

      // 확인 불일치도 저장하지 않는다.
      await tester.enterText(find.byKey(PasswordResetScreen.newKey), 'abc12!');
      await tester.enterText(
          find.byKey(PasswordResetScreen.confirmKey), 'abc12?');
      await tester.pump();
      await tester.tap(find.byKey(PasswordResetScreen.submitKey));
      await tester.pump();
      expect(auth.updatedPassword, isNull);
      expect(find.text('비밀번호가 일치하지 않습니다'), findsOneWidget);
    });

    testWidgets('잘못된 이메일 형식이면 보내지 않는다', (tester) async {
      final auth = _FakeAuth();
      await _pump(tester, const PasswordResetScreen(initialEmail: 'nope'),
          auth: auth);
      await tester.tap(find.byKey(PasswordResetScreen.submitKey));
      await tester.pump();
      expect(auth.resetSends, 0);
      expect(find.byKey(const Key('pw-reset-error')), findsOneWidget);
    });

    testWidgets('틀린 인증번호는 코드 단계에 머물며 오류 안내', (tester) async {
      final auth = _FakeAuth();
      await _pump(tester, const PasswordResetScreen(initialEmail: 'a@b.co'),
          auth: auth);
      await tester.tap(find.byKey(PasswordResetScreen.submitKey));
      await tester.pump();
      await tester.pump();
      auth.verifyError = const AuthException('Token has expired or is invalid');
      await tester.enterText(find.byKey(OtpCodeField.fieldKey), '000000');
      await tester.pump();
      await tester.pump();
      expect(find.byType(OtpCodeField), findsOneWidget);
      expect(find.byKey(const Key('pw-reset-error')), findsOneWidget);
    });
  });
}
