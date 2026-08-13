import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/account_avatar.dart';
import '../../../../shared/widgets/glass_chip.dart';
import '../../../../shared/widgets/screen_header.dart';
import '../../../profile/presentation/profile_providers.dart';
import '../../domain/enclosure_set.dart';
import '../home_set_providers.dart';

/// 미읽음 알림 개수. 알림 저장소가 생기기 전까지 0 고정 —
/// Red Dot 표시 로직 자체는 지금 검증 가능해야 하므로 provider로 뺀다.
final unreadNotificationCountProvider = Provider<int>((ref) => 0);

/// 홈 헤더. 기획안 §4.1.1 + A안(Liquid Glass) 표면.
///
/// A안 문법: **대형 타이틀**(개체 이름)이 주인공이고, 사육장은 그 아래
/// 유리 캡슐([GlassChip])이 세트 드롭다운을 겸한다. [ScreenHeader] 공용 규격
/// (56pt 고정)은 미전환 탭이 계속 쓰므로 그대로 두고, 홈만 이 표면을 쓴다.
/// 액션([HeaderAction]·[AccountAvatar])과 세트 선택 로직은 이전과 같다.
class HomeHeaderBar extends ConsumerWidget {
  const HomeHeaderBar({super.key});

  static const dropdownArrowKey = Key('home_header_dropdown_arrow');
  static const redDotKey = Key('home_header_red_dot');
  static const accountAvatarKey = Key('home_header_account_avatar');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sets = ref.watch(enclosureSetsProvider).valueOrNull ?? const [];
    final current = ref.watch(currentSetProvider).valueOrNull;
    final unread = ref.watch(unreadNotificationCountProvider);
    final multi = sets.length > 1;
    // 프로필이 아직 안 왔거나 실패해도 아바타는 폴백으로 그린다 —
    // 계정으로 가는 유일한 문이라 조건부로 감추면 안 된다.
    final profile = ref.watch(profileNotifierProvider).valueOrNull;

    // 개체가 주인공, 사육장은 어디인지 알려주는 보조(캡슐).
    final title = current == null
        ? 'home_no_set'.tr()
        : (current.pet?.name ?? current.enclosure.name);
    // 캡슐이 서는 조건: 사육장 이름이 보조로 필요하거나(개체가 주인공일 때),
    // 세트가 여럿이라 선택기가 필요할 때. 개체 없는 단일 세트에서는 큰 제목이
    // 이미 사육장 이름이라 캡슐이 같은 말을 반복하게 된다 — 안 세운다.
    final showCapsule = current != null && (current.pet != null || multi);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppStyles.spacing16,
        AppStyles.spacing8,
        AppStyles.spacing8,
        AppStyles.spacing12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTheme.glassHeaderTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showCapsule) ...[
                  const SizedBox(height: AppStyles.spacing4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GlassChip(
                      onTap:
                          multi ? () => _openSetPicker(context, ref) : null,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              current.enclosure.name,
                              style: AppTheme.glassTileStatus,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (multi) ...[
                            const SizedBox(width: AppStyles.spacing4),
                            const Icon(
                              Icons.expand_more,
                              key: dropdownArrowKey,
                              size: 16,
                              color: AppTheme.glassTextSecondary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 유리 위 아이콘은 항상 밝다 — 표면이 테마와 무관하게 어두운 월페이퍼라
          // 테마 기본색에 맡기지 않는다.
          IconTheme.merge(
            data: const IconThemeData(color: AppTheme.glassTextPrimary),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HeaderAction(
                  icon: Icons.notifications_none,
                  tooltip: 'home_notifications'.tr(),
                  onPressed: () => context.push('/notifications'),
                  showDot: unread > 0,
                  dotKey: redDotKey,
                ),
                HeaderAction(
                  icon: Icons.settings_outlined,
                  tooltip: 'home_enclosure_settings'.tr(),
                  onPressed: () => context.push('/enclosure-settings'),
                ),
                // 내 계정. 이게 붙기 전까지 ProfileScreen은 완성돼 있는데도 앱
                // 어디서도 갈 수 없어, 로그아웃·프로필 편집이 통째로 잠겨 있었다.
                //
                // ⚠️ 이 헤더의 나머지(제목·🔔·⚙️)는 전부 **현재 세트**에 대한
                // 것이고 계정만 축이 다르다. ⚙️는 '사육장 설정'이지 앱 설정이
                // 아니다 — 계정 관련 항목을 ⚙️ 쪽으로 옮기지 말 것.
                AccountAvatar(
                  key: accountAvatarKey,
                  tooltip: 'home_account'.tr(),
                  imageUrl: profile?.avatarUrl,
                  displayName: profile?.displayName,
                  onPressed: () => context.push('/profile'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSetPicker(BuildContext context, WidgetRef ref) async {
    final sets = ref.read(enclosureSetsProvider).valueOrNull ?? const [];
    final currentIndex = ref.read(selectedSetIndexProvider);
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var i = 0; i < sets.length; i++)
              _SetTile(
                set: sets[i],
                isCurrent: i == currentIndex,
                onTap: () => Navigator.of(ctx).pop(i),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      ref.read(selectedSetIndexProvider.notifier).state = picked;
    }
  }
}

/// 세트 한 줄. **어느 것을 보고 있는지 표시한다** — 이름만 나열하면 열어봐야
/// 안다.
class _SetTile extends StatelessWidget {
  const _SetTile({
    required this.set,
    required this.isCurrent,
    required this.onTap,
  });

  final EnclosureSet set;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      selected: isCurrent,
      selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.06),
      title: Text(
        set.pet?.name ?? set.enclosure.name,
        style:
            theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: set.pet == null ? null : Text(set.enclosure.name),
      trailing: isCurrent
          ? Text(
              'home_set_current'.tr(),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.primary),
            )
          : null,
    );
  }
}
