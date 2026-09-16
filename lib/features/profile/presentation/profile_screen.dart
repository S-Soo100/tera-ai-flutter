import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../shared/widgets/figma_icon.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../../community/presentation/community_providers.dart';
import '../../my_cage/presentation/management_colors.dart';
import '../../my_cage/presentation/widgets/management_widgets.dart';
import '../../notification/presentation/notification_providers.dart';
import '../domain/user_profile.dart';
import 'profile_providers.dart';
import 'widgets/my_page_widgets.dart';

/// 마이 페이지(Figma MyPage 1142:8860 / 1142:8956). 라우트 `/profile`.
///
/// 커뮤니티 설정: 프로필 카드(→ `/profile/community`) + 차단한 사용자(→
/// `/profile/blocked`, 오른쪽 N명). 앱 설정: 알림(→ `/profile/notifications`) ·
/// 내 계정(→ `/profile/account`) · 버전 정보 — 여기까지 원본 좌표(348/420/492).
/// 그 아래는 원본에 없는 행: 받은 알림(→ `/notifications`, 알림 내역 화면이 갈
/// 곳이 없어 남긴다, 미읽음 점 유지) · 화면 모드(사용자 결정 전까지 유지) ·
/// 디자인 랩(개발 빌드만). 로그아웃은 내 계정 화면으로 옮겼다.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const profileCardKey = Key('mypage_profile_card');
  static const blockedRowKey = Key('mypage_blocked_row');
  static const inboxRowKey = Key('profile_notifications_tile');
  static const notificationsRowKey = Key('mypage_notifications_row');
  static const accountRowKey = Key('mypage_account_row');
  static const versionRowKey = Key('mypage_version_row');
  static const themeRowKey = Key('mypage_theme_row');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final profile = ref.watch(profileNotifierProvider);
    final blockedCount =
        ref.watch(blockedProfilesProvider).valueOrNull?.length ?? 0;
    final version = ref.watch(appVersionProvider).valueOrNull;
    final unread = ref.watch(unreadNotificationCountProvider);
    final iconColor = ManagementColors.buttonForeground(context);

    return MyPageScaffold(
      title: 'mypage_title'.tr(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MyPageSectionTitle('mypage_section_community'.tr()),
        profile.when(
          loading: () => const SkeletonLoading(
              width: double.infinity, height: 76, borderRadius: 12),
          error: (e, _) => _ProfileCard(profile: null, onTap: null),
          data: (p) => _ProfileCard(
              profile: p, onTap: () => context.push('/profile/community')),
        ),
        const SizedBox(height: 8),
        MyPageRow(
            key: blockedRowKey,
            title: 'mypage_blocked_title'.tr(),
            subtitle: 'mypage_blocked_subtitle'.tr(),
            icon: MyPageRasterIcon('person_cancel', color: iconColor),
            trailingText: 'mypage_blocked_count_fmt'.tr(args: ['$blockedCount']),
            onTap: () => context.push('/profile/blocked')),
        const SizedBox(height: 24),
        MyPageSectionTitle('mypage_section_app'.tr()),
        MyPageRow(
            key: notificationsRowKey,
            title: 'mypage_notifications_title'.tr(),
            subtitle: 'mypage_notifications_subtitle'.tr(),
            icon: MyPageRasterIcon('notifications', color: iconColor),
            onTap: () => context.push('/profile/notifications')),
        const SizedBox(height: 8),
        MyPageRow(
            key: accountRowKey,
            title: 'mypage_account_title'.tr(),
            subtitle: 'mypage_account_subtitle'.tr(),
            icon: FigmaIcon.tinted(FigmaIcons.person,
                size: 24, color: iconColor),
            onTap: () => context.push('/profile/account')),
        const SizedBox(height: 8),
        // 최신 판정(스토어 API·원격 설정)은 후속 — 지금은 버전만 보여주고, 탭하면
        // 원본 모달 문구 대신 판정 불가를 말하지 않도록 화살표 없이 둔다(RESULTS C7).
        MyPageRow(
            key: versionRowKey,
            title: 'mypage_version_title'.tr(),
            icon: MyPageRasterIcon('info_i', color: iconColor),
            trailingText: version == null ? '…' : _formatVersion(version),
            showArrow: false),
        const SizedBox(height: 8),
        MyPageRow(
            key: inboxRowKey,
            title: 'mypage_inbox_title'.tr(),
            subtitle: 'mypage_inbox_subtitle'.tr(),
            icon: MyPageRasterIcon('notifications', color: iconColor),
            badge: unread > 0
                ? Container(
                    key: const Key('profile_notifications_dot'),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: glass.navSelected, shape: BoxShape.circle))
                : null,
            onTap: () => context.push('/notifications')),
        const SizedBox(height: 8),
        MyPageRow(
            key: themeRowKey,
            title: 'mypage_theme_title'.tr(),
            subtitle: 'mypage_theme_subtitle'.tr(),
            icon: Icon(Icons.brightness_6_outlined, size: 24, color: iconColor),
            trailingText: _themeLabel(ref.watch(themeModeProvider)),
            onTap: () => _pickTheme(context, ref)),
        if (kDebugMode) ...[
          const SizedBox(height: 8),
          MyPageRow(
              title: 'mypage_dev_title'.tr(),
              subtitle: 'mypage_dev_subtitle'.tr(),
              icon: Icon(Icons.palette_outlined, size: 24, color: iconColor),
              onTap: () => context.push('/design-test')),
        ],
      ]),
    );
  }

  /// `0.110.0+275` → `0.110.0 (275)`(Figma "0.90.3 (173)").
  static String _formatVersion(String v) {
    final i = v.indexOf('+');
    if (i < 0) return v;
    return 'mypage_version_fmt'
        .tr(args: [v.substring(0, i), v.substring(i + 1)]);
  }

  static String _themeLabel(ThemeMode m) => switch (m) {
        ThemeMode.system => 'profile_theme_system'.tr(),
        ThemeMode.light => 'profile_theme_light'.tr(),
        ThemeMode.dark => 'profile_theme_dark'.tr(),
      };

  Future<void> _pickTheme(BuildContext context, WidgetRef ref) async {
    final picked = await showModalBottomSheet<ThemeMode>(
        context: context,
        backgroundColor: context.glass.overlay,
        builder: (ctx) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final m in ThemeMode.values)
                ListTile(
                    title: Text(_themeLabel(m),
                        style: managementStyle(ctx, weight: FontWeight.w600)),
                    trailing: ref.read(themeModeProvider) == m
                        ? FigmaIcon.tinted('redesign_v2/check',
                            size: 24, color: ctx.glass.navSelected)
                        : null,
                    onTap: () => Navigator.pop(ctx, m)),
            ])));
    if (picked != null) await ref.read(themeModeProvider.notifier).set(picked);
  }
}

/// 프로필 카드 369×76 흰색 r12(선 없음): 아바타 52 왼쪽 12 → 16 → 닉네임
/// 16/700 + 사육 경험 태그(40×24 흰색 r12, 14/700 `#D61619`) / 부제 14/500,
/// 오른쪽 arrow 18(오른쪽 12).
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.onTap});
  final UserProfile? profile;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final name = (profile?.displayName?.trim().isNotEmpty ?? false)
        ? profile!.displayName!
        : 'mypage_profile_default_name'.tr();
    final exp = profile?.experience;
    final badge = profile?.experienceHidden == true
        ? 'commu_profile_exp_hidden'.tr()
        : experienceLabelKey(exp)?.tr();
    final subtitle = experienceDescKey(exp)?.tr() ??
        'mypage_profile_add_experience'.tr();
    return Material(
        key: ProfileScreen.profileCardKey,
        color: glass.surfaceHeader,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
                height: 76,
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(children: [
                      MyPageAvatar(size: 52, imageUrl: profile?.avatarUrl),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Row(children: [
                              Flexible(
                                  child: Text(name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: managementStyle(context,
                                          weight: FontWeight.w700))),
                              if (badge != null) ...[
                                const SizedBox(width: 4),
                                Container(
                                    height: 24,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                        color: glass.surfaceTint,
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: Text(badge,
                                        style: managementStyle(context,
                                            size: 14,
                                            weight: FontWeight.w700,
                                            color: glass.liveRed))),
                              ],
                            ]),
                            const SizedBox(height: 8),
                            Text(subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: managementStyle(context,
                                    size: 14, color: glass.textTertiary)),
                          ])),
                      const SizedBox(width: 8),
                      FigmaIcon.tinted(FigmaIcons.arrowNext,
                          size: 18, color: glass.textSecondary),
                    ])))));
  }
}
