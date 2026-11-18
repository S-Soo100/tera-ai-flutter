import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/tab_branches.dart';
import '../../../core/theme/glass_palette.dart';
import '../../my_cage/presentation/widgets/management_widgets.dart';
import 'app_update_providers.dart';

/// 강제 업데이트 화면(`/update-required`, Figma 밖 — 기존 관리 화면 토큰·버튼).
///
/// redirect로만 들어오고 스택의 유일한 페이지라 뒤로 가기는 앱을 닫을 뿐이다.
/// 강제 중에 `push`(푸시 알림 탭 이동 등)가 오면 redirect가 이 경로를 한 장 더
/// 쌓으므로, 쌓인 채 열리면 `go`로 한 장만 남긴다([_SinglePage]).
/// [업데이트]는 스토어를 열고, [다시 확인]은 기준을 다시 읽어 풀렸으면 redirect가
/// 원래 흐름(스플래시 → 홈·로그인)으로 보낸다.
class UpdateRequiredScreen extends ConsumerWidget {
  const UpdateRequiredScreen({super.key});

  static const screenKey = Key('update_required_screen');
  static const storeKey = Key('update_required_store');
  static const recheckKey = Key('update_required_recheck');
  static const noticeKey = Key('update_required_notice');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final version =
        ref.watch(appUpdateProvider.select((s) => s.policy?.latestVersion));
    final rechecking = ref.watch(updateRecheckingProvider);
    final notice = ref.watch(updateNoticeProvider);
    return _SinglePage(
        child: Scaffold(
      key: screenKey,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('app_update_required_title'.tr(),
                            textAlign: TextAlign.center,
                            style: managementStyle(context,
                                    size: 20,
                                    weight: FontWeight.w600,
                                    color: glass.textPrimary)
                                .copyWith(height: 28 / 20)),
                        const SizedBox(height: 12),
                        Text('app_update_required_body'.tr(),
                            textAlign: TextAlign.center,
                            style: managementStyle(context,
                                    color: glass.bodySecondary)
                                .copyWith(height: 24 / 16)),
                        if (version != null && version.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('app_update_version'.tr(args: [version]),
                              textAlign: TextAlign.center,
                              style: managementStyle(context,
                                  size: 14, color: glass.textTertiary)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (notice != null) ...[
                Text(notice.tr(),
                    key: noticeKey,
                    textAlign: TextAlign.center,
                    style: managementStyle(context,
                            size: 14, color: glass.bodySecondary)
                        .copyWith(height: 20 / 14)),
                const SizedBox(height: 12),
              ],
              ManagementButton(
                key: storeKey,
                label: 'app_update_action'.tr(),
                onPressed: () => _openStore(context, ref),
              ),
              const SizedBox(height: 8),
              ManagementButton(
                key: recheckKey,
                grey: true,
                label: 'app_update_recheck'.tr(),
                onPressed: rechecking ? null : () => _recheck(context, ref),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  Future<void> _openStore(BuildContext context, WidgetRef ref) async {
    ref.read(updateNoticeProvider.notifier).state = null;
    final ok = await openUpdateStore(ref);
    if (!context.mounted || ok) return;
    ref.read(updateNoticeProvider.notifier).state = 'app_update_store_failed';
  }

  Future<void> _recheck(BuildContext context, WidgetRef ref) async {
    ref.read(updateNoticeProvider.notifier).state = null;
    ref.read(updateRecheckingProvider.notifier).state = true;
    await ref.read(appUpdateProvider.notifier).check();
    // 풀렸으면 redirect가 이미 이 화면을 내렸다.
    if (!context.mounted) return;
    ref.read(updateRecheckingProvider.notifier).state = false;
    if (ref.read(appUpdateProvider).isRequired) {
      ref.read(updateNoticeProvider.notifier).state =
          'app_update_still_required';
    }
  }
}

/// 업데이트 화면이 스택 위에 쌓인 채 열리면(강제 중 `push`) 다음 프레임에
/// [kUpdateRequiredPath]로 `go`해 한 장만 남긴다 — 뒤로 가기가 같은 화면을
/// 한 장씩 걷어 내지 않고 바로 앱을 닫게.
class _SinglePage extends StatefulWidget {
  const _SinglePage({required this.child});
  final Widget child;

  @override
  State<_SinglePage> createState() => _SinglePageState();
}

class _SinglePageState extends State<_SinglePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final router = GoRouter.maybeOf(context);
      if (router != null && router.canPop()) router.go(kUpdateRequiredPath);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
