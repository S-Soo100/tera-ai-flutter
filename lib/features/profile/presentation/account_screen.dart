import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/viva_modal.dart';
import '../../auth/data/auth_repository.dart';
import '../../notification/presentation/push_providers.dart';
import 'widgets/my_page_widgets.dart';

/// 내 계정(Figma MyAccount 1134:7760): 비밀번호 변경 · 회원 탈퇴 행(64h) +
/// 빨간 로그아웃 CTA(y696) → "로그아웃 하시겠습니까?" 모달.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  static const passwordRowKey = Key('account_password_row');
  static const withdrawRowKey = Key('account_withdraw_row');
  static const logoutKey = Key('account_logout');

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _loggingOut = false;

  Future<void> _logout() async {
    if (_loggingOut) return;
    final ok = await showVivaModal(context,
        message: 'account_logout_question'.tr(),
        cancelLabel: 'common_cancel'.tr(),
        confirmLabel: 'account_logout'.tr());
    if (!ok || !mounted) return;
    _loggingOut = true;
    final auth = ref.read(authRepositoryProvider);
    try {
      // 푸시 기기 비활성화 → 토큰 삭제 → 서버 로그아웃 순서(푸시 컨트롤러 담당).
      await ref.read(pushLifecycleControllerProvider).logout(auth.signOut);
      if (mounted) context.go('/login');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('auth_logout_error'.tr())));
      }
    } finally {
      _loggingOut = false;
    }
  }

  @override
  Widget build(BuildContext context) => MyPageScaffold(
        title: 'account_title'.tr(),
        floating: MyPageCta(
            key: AccountScreen.logoutKey,
            label: 'account_logout'.tr(),
            color: context.glass.navSelected,
            onPressed: _logout),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          MyPageRow(
              key: AccountScreen.passwordRowKey,
              title: 'account_change_password'.tr(),
              onTap: () => context.push('/profile/account/password')),
          const SizedBox(height: 8),
          MyPageRow(
              key: AccountScreen.withdrawRowKey,
              title: 'account_withdraw'.tr(),
              onTap: () => context.push('/profile/account/withdraw')),
        ]),
      );
}
