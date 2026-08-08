import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/screen_header.dart';
import '../../domain/enclosure_set.dart';
import '../home_set_providers.dart';

/// 미읽음 알림 개수. 알림 저장소가 생기기 전까지 0 고정 —
/// Red Dot 표시 로직 자체는 지금 검증 가능해야 하므로 provider로 뺀다.
final unreadNotificationCountProvider = Provider<int>((ref) => 0);

/// 홈 헤더. 기획안 §4.1.1.
///
/// [ScreenHeader]를 조립한다 — 통계 탭도 같은 개체 선택기를 요구하므로
/// (기획안 §4.3.1) 헤더 자체는 공용 컴포넌트에 둔다.
class HomeHeaderBar extends ConsumerWidget {
  const HomeHeaderBar({super.key});

  static const dropdownArrowKey = Key('home_header_dropdown_arrow');
  static const redDotKey = Key('home_header_red_dot');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sets = ref.watch(enclosureSetsProvider).valueOrNull ?? const [];
    final current = ref.watch(currentSetProvider).valueOrNull;
    final unread = ref.watch(unreadNotificationCountProvider);
    final multi = sets.length > 1;

    return ScreenHeader(
      // 개체가 주인공, 사육장은 어디인지 알려주는 보조.
      title: current == null
          ? 'home_no_set'.tr()
          : (current.pet?.name ?? current.enclosure.name),
      subtitle: current?.pet == null ? null : current!.enclosure.name,
      onPick: multi ? () => _openSetPicker(context, ref) : null,
      pickerArrowKey: dropdownArrowKey,
      actions: [
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
      ],
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
