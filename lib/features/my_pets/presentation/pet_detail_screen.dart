import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../wiki/data/care_info_repository.dart';
import '../../wiki/presentation/wiki_providers.dart';
import '../domain/pet.dart';
import 'my_pets_providers.dart';
import 'widgets/event_timeline.dart';
import 'widgets/media_gallery.dart';

class PetDetailScreen extends ConsumerWidget {
  final String petId;

  const PetDetailScreen({super.key, required this.petId});

  bool _hasCareInfo(String speciesId) {
    return CareInfoRepository.featuredSpeciesIds.contains(speciesId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pet = ref.watch(petDetailProvider(petId));
    // petList를 watch해서 변경사항 반영
    ref.watch(petListProvider);

    if (pet == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('개체를 찾을 수 없습니다')),
      );
    }

    return Scaffold(
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
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'pet_detail_chat_fab',
        onPressed: () => context.push(
            '/chat/new?petId=${pet.id}&speciesId=${pet.speciesId}'),
        tooltip: 'AI에게 물어보기',
        child: const Icon(Icons.chat),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 프로필 섹션
          _ProfileSection(pet: pet),
          const SizedBox(height: 16),

          // 위키 바로가기
          if (_hasCareInfo(pet.speciesId))
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(selectedWikiSpeciesProvider.notifier).state =
                      pet.speciesId;
                  context.go('/wiki');
                },
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('이 종의 사육 위키 보기'),
              ),
            ),

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
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Pet pet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('개체 삭제'),
        content: Text("'${pet.name}'을(를) 삭제할까요?\n체중 기록도 함께 삭제됩니다."),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => ctx.pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(petListProvider.notifier).delete(pet.id);
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
