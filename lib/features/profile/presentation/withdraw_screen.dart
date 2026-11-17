import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/terra_rest_client.dart';
import '../../../core/theme/glass_palette.dart';
import '../../../shared/providers/external_url_launcher.dart';
import '../../auth/data/auth_repository.dart';
import '../../notification/presentation/push_providers.dart';
import '../../my_cage/presentation/widgets/management_widgets.dart';
import 'widgets/my_page_widgets.dart';

/// 회원 탈퇴(Figma MyAcc_withdraw 1142:8361): 질문 18/600 + 설명 16/500
/// `#626262` + 빨간 CTA. 실제 처리는 terra-server `POST /account/delete`
/// ([AuthRepository.deleteAccount]) — 응답별 안내는 `_withdraw`.
class WithdrawScreen extends ConsumerStatefulWidget {
  const WithdrawScreen({super.key});

  static const submitKey = Key('withdraw_submit');
  static const webDeletionLinkKey = Key('withdraw_web_deletion_link');

  @override
  ConsumerState<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends ConsumerState<WithdrawScreen> {
  bool _busy = false;

  Future<void> _withdraw() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final auth = ref.read(authRepositoryProvider);
    final push = ref.read(pushLifecycleControllerProvider);
    try {
      await auth.deleteAccount();
      // 로그아웃과 같은 경로로 푸시 기기 정리 후 세션 종료.
      await push.logout(auth.signOut);
      if (mounted) context.go('/login');
    } on TerraRestException catch (e) {
      // 회신 docs/BACKEND_REPLY_DELETE_ACCOUNT_2026-11-17.md §3.
      // 401은 TerraRestClient가 세션 복구를 한 번 해 본 뒤다. refresh token까지
      // 거부됐으면 세션이 스스로 지워졌으니(SupabaseAuthSession) 로그인 화면으로,
      // 갱신이 망 오류였을 뿐 세션이 남아 있으면 로그아웃하지 않고 다시 시도.
      if (e.statusCode == 401 && auth.currentUser == null) {
        messenger.showSnackBar(
            SnackBar(content: Text('withdraw_session_expired'.tr())));
        if (mounted) context.go('/login');
        return;
      }
      // 409 admin_account = 관리자 계정(앱 탈퇴 불가). 그 밖(500 네 가지 등)은
      // 다시 시도 — 서버가 끝난 단계를 건너뛰어 다시 불러도 안전하다.
      final key =
          e.statusCode == 409 ? 'withdraw_not_allowed' : 'withdraw_failed';
      messenger.showSnackBar(SnackBar(content: Text(key.tr())));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('withdraw_failed'.tr())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return MyPageScaffold(
      title: 'withdraw_title'.tr(),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      floating: MyPageCta(
          key: WithdrawScreen.submitKey,
          label: 'withdraw_submit'.tr(),
          color: glass.navSelected,
          onPressed: _busy ? null : _withdraw),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('withdraw_question'.tr(),
            textAlign: TextAlign.center,
            style: managementStyle(context, size: 18, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('withdraw_description'.tr(),
            textAlign: TextAlign.center,
            style: managementStyle(context, color: glass.bodySecondary)),
        const SizedBox(height: 16),
        // Figma 밖(2026-11-17): Play 정책상 앱 밖 삭제 요청 경로도 알린다
        // (앱을 지운 사용자·관리자 계정은 이 경로로 운영자가 대행한다).
        Center(
          child: TextButton(
            key: WithdrawScreen.webDeletionLinkKey,
            onPressed: () =>
                openExternalLink(context, ref, LegalLinks.accountDeletion),
            child: Text('withdraw_web_link'.tr(),
                style: managementStyle(context,
                        size: 14, color: glass.bodySecondary)
                    .copyWith(decoration: TextDecoration.underline)),
          ),
        ),
      ]),
    );
  }
}
