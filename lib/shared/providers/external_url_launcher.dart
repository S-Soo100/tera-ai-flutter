import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// 회사 사이트의 법적 고지 페이지. Google Play는 Console 칸과 함께 앱 안에도
/// 개인정보처리방침 링크를 요구하고, 계정 삭제는 앱 밖 웹 경로도 둬야 한다
/// (`docs/ops/google-play-account.md` "출시 전 막힌 것").
abstract final class LegalLinks {
  static final privacyPolicy = Uri.parse('https://www.vivanaut.co.kr/privacy');
  static final accountDeletion =
      Uri.parse('https://www.vivanaut.co.kr/account-deletion');
}

/// 외부 브라우저로 주소를 연다. 열지 못하면 false — 호출부가 주소를 안내한다.
typedef ExternalUrlLauncher = Future<bool> Function(Uri uri);

/// 테스트는 이 provider를 덮어 실제 브라우저를 띄우지 않는다.
final externalUrlLauncherProvider = Provider<ExternalUrlLauncher>(
  (ref) => (uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  },
);

/// 외부 브라우저로 [uri]를 열고, 못 열면 주소를 스낵바로 알려 준다
/// (브라우저가 없거나 막힌 기기에서도 사용자가 주소를 옮겨 적을 수 있게).
Future<void> openExternalLink(
    BuildContext context, WidgetRef ref, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await ref.read(externalUrlLauncherProvider)(uri);
  if (!ok) {
    messenger.showSnackBar(SnackBar(
        content: Text('external_link_failed_fmt'.tr(args: ['$uri']))));
  }
}
