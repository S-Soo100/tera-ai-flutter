import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_styles.dart';
import '../home_set_providers.dart';

/// 미읽음 알림 개수. 알림 저장소가 생기기 전까지 0 고정 —
/// Red Dot 표시 로직 자체는 지금 검증 가능해야 하므로 provider로 뺀다.
final unreadNotificationCountProvider = Provider<int>((ref) => 0);

/// PRD §3.1 Header Bar.
///
/// 좌측 개체 선택 드롭다운(세트 1개면 화살표 비노출), 우측 알림 센터(미읽음
/// Red Dot)와 사육장 설정.
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

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.spacing16,
        vertical: AppStyles.spacing8,
      ),
      child: Row(
        children: [
          Flexible(
            child: InkWell(
              onTap: multi ? () => _openSetPicker(context, ref) : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      current?.displayLabel ?? 'home_no_set'.tr(),
                      style: AppStyles.subsectionTitle(context),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (multi)
                    const Icon(
                      Icons.expand_more,
                      key: dropdownArrowKey,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                tooltip: 'home_notifications'.tr(),
                onPressed: () => context.push('/notifications'),
              ),
              if (unread > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    key: redDotKey,
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'home_enclosure_settings'.tr(),
            onPressed: () => context.push('/enclosure-settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSetPicker(BuildContext context, WidgetRef ref) async {
    final sets = ref.read(enclosureSetsProvider).valueOrNull ?? const [];
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var i = 0; i < sets.length; i++)
              ListTile(
                title: Text(sets[i].displayLabel),
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
