import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_styles.dart';
import '../../../shared/widgets/glass_dock.dart';
import '../../../shared/widgets/glass_page_shell.dart';
import '../../my_cage/presentation/widgets/management_widgets.dart';
import '../domain/pet.dart';
import 'my_pets_providers.dart';
import 'pet_form_route.dart';
import 'widgets/event_timeline.dart';
import 'widgets/media_gallery.dart';

class PetDetailScreen extends ConsumerWidget {
  final String petId;

  const PetDetailScreen({super.key, required this.petId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pet = ref.watch(petDetailProvider(petId));
    // petList를 watch해서 변경사항 반영
    ref.watch(petListProvider);

    if (pet == null) {
      return GlassPageShell(
        child: Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('개체를 찾을 수 없습니다')),
        ),
      );
    }

    // A안 경량 전환 — 배경·표면 톤만 유리 문법으로. 상세/삭제 로직 불변.
    return GlassPageShell(
        child: Scaffold(
      appBar: AppBar(
        title: Text(pet.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '수정',
            onPressed: () => context.push('/my-pets/$petId/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '삭제',
            onPressed: () => _confirmDelete(context, ref, pet),
          ),
        ],
      ),
      // 챗 FAB는 제거했다 — /chat 라우트가 없고(챗 기능은 PRD D3 폐기),
      // 누르면 라우터 에러로 떨어지는 죽은 문이었다.
      body: ListView(
        // 하단은 플로팅 독 높이까지 비운다 — 마지막 카드가 독에 가려지지 않게.
        padding: glassDockListPadding(context,
            base: const EdgeInsets.fromLTRB(AppStyles.spacing16,
                AppStyles.spacing16, AppStyles.spacing16, 0)),
        children: [
          // 프로필 섹션
          _ProfileSection(pet: pet),
          const SizedBox(height: 16),

          // 위키 바로가기 버튼은 2026-09-02 PRD 재설계로 제거(위키 라우트 폐지).

          // 이벤트 타임라인
          EventTimeline(petId: petId),
          const SizedBox(height: 16),

          // 미디어 갤러리
          MediaGallery(petId: petId),

          // 메모 섹션
          if (pet.memo != null && pet.memo!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _MemoSection(memo: pet.memo!),
          ],

          const SizedBox(height: 16),
        ],
      ),
    ));
  }

  /// 삭제 확인 — 승인된 23번 공통 확인창([managementConfirm])과 개체 관리
  /// 화면의 문구(받침에 따른 을/를)를 그대로 쓴다(P18 구형 AlertDialog 교체).
  /// 이 화면은 기기관리 → 개체 탭 경로로 아직 살아 있다.
  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Pet pet) async {
    final titleKey = switch (managementNameHasFinalConsonant(pet.name)) {
      true => 'pet_form_delete_title',
      false => 'pet_form_delete_title_open',
      null => 'pet_form_delete_title_unknown',
    };
    final message = '${titleKey.tr(namedArgs: {'name': pet.name})}\n'
        '${'pet_form_delete_body'.tr()}';
    final confirmed =
        await managementConfirm(context, message, action: 'common_delete'.tr());
    if (confirmed && context.mounted) {
      await ref.read(deleteRedesignPetProvider)(pet);
      if (context.mounted) context.pop();
    }
  }
}

class _ProfileSection extends StatelessWidget {
  final Pet pet;

  const _ProfileSection({required this.pet});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 사진 or 아이콘
            _buildPhoto(context),
            const SizedBox(height: 16),

            // 이름
            Text(
              pet.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),

            // 종 / 모프 / 성별
            Text(
              [
                pet.speciesName,
                if (pet.morph != null && pet.morph!.isNotEmpty) pet.morph,
                pet.sexDisplay,
              ].join(' · '),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // 나이 / 입양 기간 / 체중
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (pet.ageDisplay.isNotEmpty)
                  _InfoChip(label: '나이', value: pet.ageDisplay),
                if (pet.adoptionDuration.isNotEmpty)
                  _InfoChip(label: '입양', value: pet.adoptionDuration),
                if (pet.weight != null)
                  _InfoChip(label: '체중', value: '${pet.weight}g'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoto(BuildContext context) {
    if (pet.photoPath != null && pet.photoPath!.isNotEmpty) {
      final isNetwork = pet.photoPath!.startsWith('http');
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: isNetwork
            ? CachedNetworkImage(
                imageUrl: pet.photoPath!,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 120,
                  height: 120,
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                ),
                errorWidget: (_, __, ___) => _buildIconPlaceholder(context),
              )
            : Image.file(
                File(pet.photoPath!),
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildIconPlaceholder(context),
              ),
      );
    }
    return _buildIconPlaceholder(context);
  }

  Widget _buildIconPlaceholder(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset('assets/images/logo.png', width: 64, height: 64),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _MemoSection extends StatelessWidget {
  final String memo;

  const _MemoSection({required this.memo});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '메모',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(memo),
          ],
        ),
      ),
    );
  }
}
