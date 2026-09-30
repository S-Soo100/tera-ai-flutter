import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/skeleton_loading.dart';
import '../my_pets_providers.dart';

/// 개체 목록이 비어 있는데 아직 조회 중이거나 조회에 실패했을 때 "개체 없음"
/// 대신 보여 주는 자리(UX-02, 2026-10-01). 0마리로 확정됐을 때만 호출자가
/// 원래 빈 화면(개체 추가 안내)을 그린다 — [showsInsteadOfEmpty]로 판정.
class PetListStatusView extends ConsumerWidget {
  const PetListStatusView({super.key, required this.load});

  static const retryKey = Key('pet_list_retry');

  final PetListLoad load;

  /// 빈 목록일 때 빈 안내 대신 이 위젯을 그려야 하는가.
  static bool showsInsteadOfEmpty(PetListLoad load) =>
      load != PetListLoad.ready;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (load == PetListLoad.loading) {
      return const Padding(
        key: Key('pet_list_loading'),
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Column(children: [
          SkeletonLoading(width: double.infinity, height: 88, borderRadius: 16),
          SizedBox(height: 8),
          SkeletonLoading(width: double.infinity, height: 88, borderRadius: 16),
        ]),
      );
    }
    final glass = context.glass;
    return Center(
      key: const Key('pet_list_failed'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: glass.textTertiary),
          const SizedBox(height: 16),
          Text('pet_list_failed_title'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600, color: glass.textPrimary)),
          const SizedBox(height: 8),
          Text('pet_list_failed_body'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: glass.bodySecondary)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
              key: retryKey,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: Text('common_retry'.tr()),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(120, 48),
                  foregroundColor: glass.textPrimary),
              // 실패는 syncFromRemote가 상태(failed)로 다시 알린다.
              onPressed: () => ref
                  .read(petListProvider.notifier)
                  .syncFromRemote()
                  .catchError((_) {})),
        ]),
      ),
    );
  }
}
