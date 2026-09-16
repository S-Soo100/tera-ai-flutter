// 마이 페이지 계열 캡처. 옵트인:
//   flutter test --no-pub --dart-define=CAPTURE_MYPAGE=true \
//     test/design/redesign_mypage_capture_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:vivanaut/features/community/presentation/blocked_users_screen.dart';
import 'package:vivanaut/features/profile/domain/user_profile.dart';
import 'package:vivanaut/features/profile/presentation/account_screen.dart';
import 'package:vivanaut/features/profile/presentation/community_profile_screen.dart';
import 'package:vivanaut/features/profile/presentation/notification_settings_screen.dart';
import 'package:vivanaut/features/profile/presentation/password_change_screen.dart';
import 'package:vivanaut/features/profile/presentation/profile_screen.dart';
import 'package:vivanaut/features/profile/presentation/withdraw_screen.dart';
import 'remaining_ui_capture_test.dart' show shell, capture;
import '../features/profile/mypage_layout_test.dart' show overrides;

void main() {
  if (!const bool.fromEnvironment('CAPTURE_MYPAGE')) {
    test('opt-in mypage captures', () {}, skip: 'CAPTURE_MYPAGE=true');
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

  testWidgets('mypage captures', (tester) async {
    final boundary = GlobalKey();
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.binding.setSurfaceSize(const Size(393, 852));
    final profile = UserProfile(
        id: 'u',
        displayName: '레이토마토',
        experience: 'expert',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026));
    for (final (name, home, ov) in [
      ('mypage', const ProfileScreen(), overrides()),
      ('commu-profile', const CommunityProfileScreen(),
          overrides(profile: profile)),
      ('commu-block', const BlockedUsersScreen(), overrides(blocked: 5)),
      ('push-alarm', const NotificationSettingsScreen(), overrides()),
      ('my-account', const AccountScreen(), overrides()),
      ('pw-change', const PasswordChangeScreen(), overrides()),
      ('withdraw', const WithdrawScreen(), overrides()),
    ]) {
      await tester.pumpWidget(shell(boundary, home, overrides: ov));
      await tester.pumpAndSettle();
      await capture(tester, boundary, name);
    }
  });
}
