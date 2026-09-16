import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

import '../../../core/theme/glass_palette.dart';
import '../../auth/data/auth_repository.dart';
import '../../notification/presentation/push_providers.dart';
import '../../my_cage/presentation/widgets/management_widgets.dart';
import 'widgets/my_page_widgets.dart';

/// 회원 탈퇴(Figma MyAcc_withdraw 1142:8361): 질문 18/600 + 설명 16/500
/// `#626262` + 빨간 CTA. 실제 삭제는 Edge Function `delete-account`(미배포,
/// 계획 C6) — 없으면 "아직 준비되지 않았습니다"로 말한다.
class WithdrawScreen extends ConsumerStatefulWidget {
  const WithdrawScreen({super.key});

  static const submitKey = Key('withdraw_submit');

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
    } on FunctionException {
      messenger
          .showSnackBar(SnackBar(content: Text('withdraw_not_ready'.tr())));
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
      ]),
    );
  }
}
