import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../domain/enclosure_set.dart';
import '../home_set_providers.dart';

/// 홈 헤더 — Figma A.4 ① (h44, 좌 세트 드롭다운 필 + 우 원형 버튼 2개).
///
/// 좌: 세트 드롭다운 필(bg surfaceTint, radius 12, 텍스트 16 SemiBold +
/// `keyboard_arrow_down` 24 — 세트 1개면 화살표 숨김, PRD §3.1 예외).
/// 우: 44×44 흰 원형 버튼 ×2 — `[+]`(기기/개체/사육세트 추가 메뉴),
/// `[person]`(→ `/profile`).
///
/// 🔔·⚙️은 PRD 재설계(2026-09-02)로 빠졌다 — 알림 진입은 프로필 화면 안,
/// 사육장 설정 진입은 `[+]` 메뉴의 사육세트 추가(`/enclosure-settings`)가
/// 겸한다. 미읽음 provider는 `notification/presentation/notification_providers`
/// 로 이사했다.
class HomeHeaderBar extends ConsumerWidget {
  const HomeHeaderBar({super.key});

  static const dropdownArrowKey = Key('home_header_dropdown_arrow');
  static const setPillKey = Key('home_header_set_pill');
  static const addButtonKey = Key('home_header_add_button');
  static const personButtonKey = Key('home_header_person_button');

  /// Figma 실측 헤더 높이.
  static const double height = 44;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sets = ref.watch(enclosureSetsProvider).valueOrNull ?? const [];
    final current = ref.watch(currentSetProvider).valueOrNull;
    final multi = sets.length > 1;
    final glass = context.glass;

    // 필 라벨: 개체가 있으면 개체명이 세트의 얼굴, 없으면 사육장명.
    final label = current == null
        ? 'home_no_set'.tr()
        : current.pet?.name ?? current.enclosure.name;

    return SizedBox(
      height: height,
      child: Row(
        children: [
          Flexible(
            child: Material(
              key: setPillKey,
              color: glass.surfaceTint,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                // 세트가 하나뿐이면 고를 게 없다 — 필은 라벨로만 선다.
                onTap: multi ? () => _openSetPicker(context, ref) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 16 * -0.02,
                            color: glass.textSecondary,
                          ),
                        ),
                      ),
                      if (multi) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down,
                          key: dropdownArrowKey,
                          size: 24,
                          color: glass.textSecondary,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          _AddMenuButton(key: addButtonKey),
          const SizedBox(width: 12),
          _CircleButton(
            key: personButtonKey,
            icon: Icons.person_outline,
            tooltip: 'home_account'.tr(),
            onTap: () => context.push('/profile'),
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

/// `[+]` 메뉴 — 기기 추가 / 개체 추가 / 사육세트 추가.
class _AddMenuButton extends StatelessWidget {
  const _AddMenuButton({super.key});

  static const deviceItemKey = Key('home_header_add_device');
  static const petItemKey = Key('home_header_add_pet');
  static const setItemKey = Key('home_header_add_set');

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return PopupMenuButton<String>(
      tooltip: 'home_add_device'.tr(),
      offset: const Offset(0, HomeHeaderBar.height + 4),
      onSelected: (route) => context.push(route),
      itemBuilder: (_) => [
        PopupMenuItem(
          key: deviceItemKey,
          value: '/smart-cage/devices/pair',
          child: Text('home_add_device'.tr()),
        ),
        // 브랜치 하위 `/my-pets/add`가 아니라 셸 밖 전용 라우트 — 홈에서
        // 타 브랜치 하위를 push하면 탭 인덱스가 점프한다(리뷰 2026-09-03).
        PopupMenuItem(
          key: petItemKey,
          value: '/pet-add',
          child: Text('home_add_pet'.tr()),
        ),
        PopupMenuItem(
          key: setItemKey,
          value: '/enclosure-settings',
          child: Text('home_add_set'.tr()),
        ),
      ],
      child: _CircleSurface(
        child: Icon(Icons.add, size: 24, color: glass.textSecondary),
      ),
    );
  }
}

/// 44×44 흰 원형 버튼(Figma A.4 ①).
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final button = Material(
      color: glass.overlay,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 24, color: glass.textSecondary),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// [PopupMenuButton]의 child로 쓰는 원형 면 — 탭 처리는 메뉴 버튼이 한다.
class _CircleSurface extends StatelessWidget {
  const _CircleSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.glass.overlay,
      shape: const CircleBorder(),
      child: SizedBox(width: 44, height: 44, child: Center(child: child)),
    );
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
