import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../my_pets/domain/pet.dart';
import '../../domain/pet_dday.dart';

/// PRD §3.2 사육장 단품 모드의 상단 대체 카드.
///
/// 대표 사진 + D-Day + 최근 상태 요약(마지막 급여일, 체중) + 온습도 배지.
class PetProfileCard extends StatelessWidget {
  const PetProfileCard({
    super.key,
    required this.pet,
    required this.lastFedAt,
    required this.status,
  });

  final Pet? pet;
  final DateTime? lastFedAt;
  final EnvStatus status;

  @override
  Widget build(BuildContext context) {
    final p = pet;
    if (p == null) {
      return Padding(
        padding: AppStyles.pagePadding,
        child: Text('home_no_pet'.tr()),
      );
    }

    final dday = dDayLabel(
      petName: p.name,
      adoptionDate: p.adoptionDate,
      now: DateTime.now(),
    );

    return Padding(
      padding: AppStyles.pagePadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage:
                p.photoPath == null ? null : FileImage(File(p.photoPath!)),
            child: p.photoPath == null ? const Icon(Icons.pets) : null,
          ),
          const SizedBox(width: AppStyles.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dday ?? p.name,
                  style: AppStyles.subsectionTitle(context),
                ),
                const SizedBox(height: AppStyles.spacing4),
                Text(
                  _summaryLine(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (status != EnvStatus.unknown) ...[
                  const SizedBox(height: AppStyles.spacing8),
                  _StatusBadge(status: status),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _summaryLine() {
    final parts = <String>[];
    if (lastFedAt != null) {
      parts.add(
          'home_last_fed'.tr(args: [DateFormat('MM/dd').format(lastFedAt!)]));
    }
    if (pet?.weight != null) {
      parts.add('home_weight'.tr(args: [pet!.weight!.toStringAsFixed(0)]));
    }
    return parts.join(' · ');
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final EnvStatus status;

  @override
  Widget build(BuildContext context) {
    final normal = status == EnvStatus.normal;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.spacing8,
        vertical: AppStyles.spacing4,
      ),
      decoration: BoxDecoration(
        color: (normal ? Colors.green : Colors.orange).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppStyles.chipRadius),
      ),
      child: Text(
        normal ? 'home_env_normal'.tr() : 'home_env_warning'.tr(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: normal ? Colors.green.shade800 : Colors.orange.shade900,
            ),
      ),
    );
  }
}
