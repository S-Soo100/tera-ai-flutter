// 로그인 5상태 캡처(Figma 1133:5712 · 1134:6114 · 1134:6259 · 1134:6472 ·
// 1134:6617). 옵트인:
//   flutter test --no-pub --dart-define=CAPTURE_LOGIN=true \
//     test/design/redesign_login_capture_test.dart
// /private/tmp/remaining-after/login-*.png + .json 저장.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:vivanaut/features/auth/data/login_prefs_repository.dart';
import 'package:vivanaut/features/auth/presentation/login_screen.dart';
import 'remaining_ui_capture_test.dart' show shell, capture;

class _Prefs implements LoginPrefsRepository {
  @override
  String? get lastEmail => null;
  @override
  bool get autoLogin => true;
  @override
  Future<void> save({required String email, required bool autoLogin}) async {}
}

void main() {
  if (!const bool.fromEnvironment('CAPTURE_LOGIN')) {
    test('opt-in login captures', () {}, skip: 'CAPTURE_LOGIN=true');
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final f = FontLoader('Pretendard');
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      f.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
    }
    await f.load();
  });

  testWidgets('login captures', (tester) async {
    final boundary = GlobalKey();
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await tester.pumpWidget(shell(boundary, const LoginScreen(),
        overrides: [loginPrefsProvider.overrideWithValue(_Prefs())]));
    await tester.pumpAndSettle();
    await capture(tester, boundary, 'login-default');

    final email = find.byKey(const ValueKey('login-email'));
    final password = find.byKey(const ValueKey('login-password'));
    await tester.enterText(email, 'vivanaut@gmail.com');
    await tester.enterText(password, '**********');
    await tester.pumpAndSettle();
    await capture(tester, boundary, 'login-typing');

    await tester.tap(find.byKey(const ValueKey('login-password-visibility')));
    await tester.pumpAndSettle();
    await capture(tester, boundary, 'login-pw-visible');
    await tester.tap(find.byKey(const ValueKey('login-password-visibility')));

    await tester.tap(find.byKey(const ValueKey('login-auto-login')));
    await tester.pumpAndSettle();
    await capture(tester, boundary, 'login-autologin');

    await tester.enterText(email, 'vivanaut@gmail.');
    await tester.enterText(password, '12345');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();
    await capture(tester, boundary, 'login-error');
  });
}
