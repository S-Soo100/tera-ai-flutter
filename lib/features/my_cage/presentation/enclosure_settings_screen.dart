import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_styles.dart';
import '../../../shared/widgets/section_header.dart';
import '../../home/domain/enclosure_set.dart';
import '../../home/presentation/home_set_providers.dart';
import '../../my_pets/domain/pet.dart';
import '../../my_pets/presentation/my_pets_providers.dart';

/// 개체 배정 UI 노출 스위치.
///
/// 서버 마이그레이션(`pets.enclosure_id` + `assign_pet_to_enclosure` RPC)이
/// 적용된 뒤에만 켠다. 컬럼/RPC가 없는 서버에서는 호출이 예외만 낸다.
/// 2026-08-06 petcam-lab 적용 완료 → on.
const bool kPetEnclosureAssignmentEnabled = true;

/// PRD §3.1 사육장 설정.
class EnclosureSettingsScreen extends StatelessWidget {
  const EnclosureSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('home_enclosure_settings'.tr())),
      body: ListView(
        children: [
          if (kPetEnclosureAssignmentEnabled) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(AppStyles.spacing16,
                  AppStyles.spacing16, AppStyles.spacing16, 0),
              child: _AssignmentHeader(),
            ),
            const PetAssignmentSection(),
            const Divider(height: AppStyles.spacing32),
          ],
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: Text('enclosure_settings_add_device'.tr()),
            onTap: () => context.push('/smart-cage/devices/pair'),
          ),
          ListTile(
            leading: const Icon(Icons.videocam_outlined),
            title: Text('enclosure_settings_add_camera'.tr()),
            onTap: () => context.push('/crecam/cameras/pair'),
          ),
          ListTile(
            leading: const Icon(Icons.view_in_ar_outlined),
            title: Text('enclosure_settings_manage'.tr()),
            onTap: () => context.push('/smart-cage/enclosures'),
          ),
        ],
      ),
    );
  }
}

class _AssignmentHeader extends StatelessWidget {
  const _AssignmentHeader();

  @override
  Widget build(BuildContext context) =>
      SectionHeader(title: 'enclosure_settings_assignment'.tr());
}

/// 사육장별 배정 개체 목록 + 배정/해제 진입점.
class PetAssignmentSection extends ConsumerWidget {
  const PetAssignmentSection({super.key});

  static const rowKeyPrefix = 'pet_assignment_row_';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sets = ref.watch(enclosureSetsProvider).valueOrNull ?? const [];
    if (sets.isEmpty) {
      return Padding(
        padding: AppStyles.pagePadding,
        child: Text('home_no_set'.tr()),
      );
    }

    return Column(
      children: [
        for (final set in sets)
          ListTile(
            key: Key('$rowKeyPrefix${set.id}'),
            leading: const Icon(Icons.pets_outlined),
            title: Text(set.enclosure.name),
            subtitle: Text(
              set.pet?.name ?? 'enclosure_settings_no_pet'.tr(),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openPicker(context, ref, set),
          ),
      ],
    );
  }

  Future<void> _openPicker(
    BuildContext context,
    WidgetRef ref,
    EnclosureSet set,
  ) async {
    final pets = ref.read(petListProvider);
    if (pets.isEmpty) {
      _toast(context, 'enclosure_settings_no_pets'.tr());
      return;
    }

    final picked = await showModalBottomSheet<_PickResult>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            if (set.pet != null)
              ListTile(
                leading: const Icon(Icons.link_off),
                title: Text('enclosure_settings_unassign'.tr()),
                onTap: () => Navigator.of(ctx).pop(const _PickResult(null)),
              ),
            for (final p in pets)
              ListTile(
                leading: const Icon(Icons.pets),
                title: Text(p.name),
                // 이미 어딘가 배정된 개체는 그 사실을 알려준다 — 고르면
                // 기존 배정이 해제되기 때문(교체 확인 다이얼로그로 이어짐).
                subtitle: p.enclosureId == null || p.enclosureId == set.id
                    ? null
                    : Text('enclosure_settings_already_assigned'.tr()),
                selected: p.id == set.pet?.id,
                onTap: () => Navigator.of(ctx).pop(_PickResult(p)),
              ),
          ],
        ),
      ),
    );

    if (picked == null || !context.mounted) return;

    final target = picked.pet;

    // 이미 이 사육장에 있는 개체를 다시 고른 경우 — 아무 일도 하지 않는다.
    if (target != null && target.id == set.pet?.id) return;

    // RPC가 조용히 교체하므로, 교체가 일어날 상황이면 먼저 확인을 받는다.
    if (target != null) {
      final movingFromAnother =
          target.enclosureId != null && target.enclosureId != set.id;
      final replacingOccupant = set.pet != null;
      if (movingFromAnother || replacingOccupant) {
        final ok = await _confirmSwap(
          context,
          movingPet: movingFromAnother ? target : null,
          occupant: replacingOccupant ? set.pet! : null,
        );
        if (ok != true || !context.mounted) return;
      }
    }

    await _assign(context, ref, petId: target?.id ?? set.pet!.id,
        enclosureId: target == null ? null : set.id);
  }

  Future<bool?> _confirmSwap(
    BuildContext context, {
    required Pet? movingPet,
    required Pet? occupant,
  }) {
    final body = movingPet != null
        ? 'enclosure_settings_swap_body'.tr(args: [movingPet.name])
        : 'enclosure_settings_replace_body'.tr(args: [occupant!.name]);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('enclosure_settings_swap_title'.tr()),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common_cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('common_confirm'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _assign(
    BuildContext context,
    WidgetRef ref, {
    required String petId,
    required String? enclosureId,
  }) async {
    try {
      await ref
          .read(petListProvider.notifier)
          .assignToEnclosure(petId: petId, enclosureId: enclosureId);
      // 세트 조합이 바뀌었으니 홈 헤더·상단 영역이 다시 계산돼야 한다.
      ref.invalidate(enclosureSetsProvider);
    } catch (e, st) {
      // 사용자에겐 다듬은 문구를 보이되, 원문은 진단을 위해 남긴다.
      // (사용자 문구만 남기면 서버 거절 사유를 영영 못 본다)
      debugPrint('[pet-assign] failed: $e\n$st');
      if (!context.mounted) return;
      _toast(context, assignmentErrorMessage(e));
    }
  }

  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

/// 서버 예외를 사용자 언어로 매핑한다.
///
/// Postgres 에러 문자열(`ownership mismatch: pets.user_id=...`)은 사용자에게
/// 아무 의미가 없다. 다만 원인별로 다른 안내가 나가야 하므로 분기한다.
String assignmentErrorMessage(Object error) {
  final raw = error.toString().toLowerCase();
  if (raw.contains('로그인')) {
    return 'enclosure_settings_login_required'.tr();
  }
  if (raw.contains('ownership mismatch') ||
      raw.contains('not owned by caller') ||
      raw.contains('not authenticated')) {
    return 'enclosure_settings_assign_denied'.tr();
  }
  return 'enclosure_settings_assign_failed'.tr();
}

class _PickResult {
  const _PickResult(this.pet);

  /// null = 배정 해제 선택.
  final Pet? pet;
}
