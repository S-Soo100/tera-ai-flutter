import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../wiki/data/care_info_repository.dart';
import '../domain/pet.dart';
import '../domain/weight_log.dart';
import 'my_pets_providers.dart';

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
    final weightLogs = ref.watch(weightLogsProvider(petId));

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
                onPressed: () => context.push('/wiki'),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('이 종의 사육 위키 보기'),
              ),
            ),

          // 체중 기록 섹션
          _WeightSection(
            petId: petId,
            logs: weightLogs,
          ),

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
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
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
      child: Icon(
        Icons.pets,
        size: 48,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
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

class _WeightSection extends ConsumerWidget {
  final String petId;
  final List<WeightLog> logs;

  const _WeightSection({required this.petId, required this.logs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '체중 기록',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: '체중 기록 추가',
                  onPressed: () => _showAddDialog(context, ref),
                ),
              ],
            ),
            if (logs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '아직 체중 기록이 없어요',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              )
            else
              ...logs.map((log) => _WeightLogTile(log: log, petId: petId)),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final weightController = TextEditingController();
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('체중 기록'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightController,
              decoration: const InputDecoration(
                labelText: '체중 (g)',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => ctx.pop(true),
            child: const Text('추가'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final w = double.tryParse(weightController.text.trim());
      if (w == null || w <= 0) return;

      final log = WeightLog(
        id: const Uuid().v4(),
        petId: petId,
        weight: w,
        date: DateTime.now(),
        note: noteController.text.trim().isNotEmpty
            ? noteController.text.trim()
            : null,
      );
      await ref.read(weightLogsProvider(petId).notifier).add(log);
    }

    weightController.dispose();
    noteController.dispose();
  }
}

class _WeightLogTile extends ConsumerWidget {
  final WeightLog log;
  final String petId;

  const _WeightLogTile({required this.log, required this.petId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.monitor_weight_outlined),
      title: Text('${log.weight}g'),
      subtitle: Text(
        '${log.date.year}.${log.date.month.toString().padLeft(2, '0')}.${log.date.day.toString().padLeft(2, '0')}'
        '${log.note != null ? '  ${log.note}' : ''}',
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 18),
        onPressed: () async {
          await ref.read(weightLogsProvider(petId).notifier).delete(log.id);
        },
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
