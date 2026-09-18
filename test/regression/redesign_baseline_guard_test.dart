import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Figma 재설계 기준선 감시(2026-09-18).
///
/// 재설계 138커밋이 별도 브랜치에만 있어 main 빌드가 구화면으로 보인 사고가
/// 있었다. 옛 브랜치를 병합하거나 파일을 되돌려 재설계 화면이 사라지면 이 테스트가
/// 실패해 커밋(테스트 통과 필수)이 막힌다. 화면을 의도적으로 바꿀 때는 이 목록을
/// 함께 고친다 — 목록을 지우는 것으로 우회하지 말 것.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('재설계 핵심 화면·위젯 파일이 있다', () {
    const files = [
      'lib/features/auth/presentation/login_screen.dart', // Figma 로그인
      'lib/features/home/presentation/home_screen.dart',
      'lib/features/home/presentation/widgets/device_control_sheet.dart',
      'lib/features/my_cage/presentation/crecam_screen.dart',
      'lib/features/my_cage/presentation/device_add_flow_screen.dart',
      'lib/features/profile/presentation/profile_screen.dart',
      'lib/features/profile/presentation/notification_settings_screen.dart',
      'lib/features/notification/presentation/push_pre_popup.dart',
      'lib/shared/widgets/viva_modal.dart',
      'lib/shared/widgets/viva_text_field.dart',
      'assets/images/logo_vivanaut_wordmark.png',
      'assets/images/splash_vivanaut.png',
    ];
    final missing = [
      for (final f in files)
        if (!File(f).existsSync()) f
    ];
    expect(missing, isEmpty, reason: '재설계 파일이 사라졌습니다 — 옛 브랜치 병합/되돌리기를 의심하세요');
  });

  test('재설계 화면 표지가 코드에 남아 있다', () {
    expect(read('lib/features/auth/presentation/login_screen.dart'),
        contains('logo_vivanaut_wordmark'),
        reason: 'Figma 로그인 로고');
    expect(read('lib/features/home/presentation/home_screen.dart'),
        isNot(contains('QuickControlGrid')),
        reason: '2026-09-04 삭제된 옛 제어 그리드');
    expect(read('lib/app.dart'), isNot(contains('PushPermissionPrompt')),
        reason: '로그인 직후 일괄 권한 시트는 폐지(Figma 권한 요청)');
    expect(read('pubspec.yaml'),
        contains('image: assets/images/splash_vivanaut.png'),
        reason: '스플래시는 vivanaut 워드마크');
    expect(read('pubspec.yaml'), isNot(contains('logo_stacked.png')),
        reason: '옛 terra ai 스플래시');
  });

  test('앱 버전이 재설계 병합(0.111.4+280) 아래로 내려가지 않는다', () {
    final match = RegExp(r'^version:\s*[\d.]+\+(\d+)', multiLine: true)
        .firstMatch(read('pubspec.yaml'));
    expect(match, isNotNull);
    expect(int.parse(match!.group(1)!), greaterThanOrEqualTo(280));
  });
}
