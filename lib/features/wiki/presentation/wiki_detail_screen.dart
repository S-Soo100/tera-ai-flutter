import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/citation_card.dart';
import '../../../shared/widgets/relation_card.dart';
import '../data/care_info_repository.dart';
import '../domain/care_info_detail.dart';
import '../domain/graph_entity.dart';
import 'wiki_providers.dart';

class WikiDetailScreen extends ConsumerWidget {
  final String speciesId;
  final String category;

  const WikiDetailScreen({
    super.key,
    required this.speciesId,
    required this.category,
  });

  static const _categoryNames = {
    'temperature': '온도·습도',
    'enclosure': '사육장',
    'diet': '먹이',
    'mistakes': '초보 실수',
  };

  String get _speciesName =>
      CareInfoRepository.speciesNames[speciesId] ?? speciesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final careInfoAsync = ref.watch(careInfoProvider(speciesId));
    final categoryName = _categoryNames[category] ?? category;

    return Scaffold(
      appBar: AppBar(
        title: Text('$_speciesName — $categoryName'),
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'wiki_detail_chat_fab',
        onPressed: () =>
            context.push('/chat/new?speciesId=$speciesId'),
        tooltip: 'AI에게 물어보기',
        child: const Icon(Icons.chat),
      ),
      body: careInfoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('정보를 불러올 수 없습니다: $e'),
          ),
        ),
        data: (info) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildContent(context, info),
              const SizedBox(height: 24),
              _RelatedInfoSection(speciesId: speciesId),
              const SizedBox(height: 24),
              _CitationsSection(speciesId: speciesId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, CareInfoDetail info) {
    switch (category) {
      case 'temperature':
        return _buildTemperature(context, info);
      case 'enclosure':
        return _buildEnclosure(context, info);
      case 'diet':
        return _buildDiet(context, info);
      case 'mistakes':
        return _buildMistakes(context, info);
      default:
        return Center(child: Text('알 수 없는 카테고리: $category'));
    }
  }

  Widget _buildTemperature(BuildContext context, CareInfoDetail info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: '온도 (${info.tempUnit})'),
        if (info.baskingSurface != null)
          _InfoRow(
              label: '바스킹 표면',
              value: '${info.baskingSurface!.display}${info.tempUnit}'),
        _InfoRow(
            label: '핫존', value: '${info.hotZone.display}${info.tempUnit}'),
        _InfoRow(
            label: '쿨존', value: '${info.coolZone.display}${info.tempUnit}'),
        _InfoRow(
            label: '야간', value: '${info.night.display}${info.tempUnit}'),
        if (info.tempNotes != null) ...[
          const SizedBox(height: 8),
          _NoteCard(text: info.tempNotes!),
        ],
        const SizedBox(height: 24),
        const _SectionHeader(title: '습도'),
        _InfoRow(label: '기본 습도', value: '${info.humidityMin}~${info.humidityMax}%'),
        if (info.humidHide != null)
          _InfoRow(
              label: '습도 하이드', value: '${info.humidHide!.display}%'),
        if (info.humidityMisting != null)
          _InfoRow(label: '미스팅', value: info.humidityMisting!),
        if (info.humidityNotes != null) ...[
          const SizedBox(height: 8),
          _NoteCard(text: info.humidityNotes!),
        ],
      ],
    );
  }

  Widget _buildEnclosure(BuildContext context, CareInfoDetail info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: '사육장'),
        _InfoRow(label: '최소 크기', value: info.minSize),
        if (info.enclosureType != null)
          _InfoRow(label: '타입', value: info.enclosureType!),
        if (info.lighting != null)
          _InfoRow(label: '조명', value: info.lighting!),
        const SizedBox(height: 16),
        const _SectionHeader(title: '권장 기질'),
        _ChipList(items: info.substrate),
        if (info.substrateAvoid.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SectionHeader(title: '피해야 할 기질'),
          _ChipList(items: info.substrateAvoid, isWarning: true),
        ],
        const SizedBox(height: 16),
        const _SectionHeader(title: '필수 용품'),
        ...info.essentials
            .map((item) => _BulletItem(text: item)),
      ],
    );
  }

  Widget _buildDiet(BuildContext context, CareInfoDetail info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: '주식'),
        _ChipList(items: info.mainDiet),
        if (info.treats.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SectionHeader(title: '간식'),
          _ChipList(items: info.treats),
        ],
        const SizedBox(height: 16),
        const _SectionHeader(title: '보충제'),
        _ChipList(items: info.supplements),
        const SizedBox(height: 16),
        const _SectionHeader(title: '급여 정보'),
        _InfoRow(label: '주기', value: info.feedingFrequency),
        if (info.feedingSize != null)
          _InfoRow(label: '크기 기준', value: info.feedingSize!),
        if (info.water != null) _InfoRow(label: '급수', value: info.water!),
        if (info.dietNotes != null) ...[
          const SizedBox(height: 8),
          _NoteCard(text: info.dietNotes!),
        ],
      ],
    );
  }

  Widget _buildMistakes(BuildContext context, CareInfoDetail info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: '초보가 자주 하는 실수'),
        const SizedBox(height: 8),
        ...info.commonMistakes.asMap().entries.map((entry) {
          return ExpansionTile(
            leading: CircleAvatar(
              radius: 14,
              backgroundColor:
                  Theme.of(context).colorScheme.errorContainer,
              child: Text(
                '${entry.key + 1}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            title: Text(
              entry.value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }),
      ],
    );
  }
}

// --- Shared widgets ---

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final String text;
  const _NoteCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline,
                size: 18,
                color: Theme.of(context).colorScheme.onTertiaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipList extends StatelessWidget {
  final List<String> items;
  final bool isWarning;
  const _ChipList({required this.items, this.isWarning = false});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: items
          .map((item) => Chip(
                label: Text(item, style: const TextStyle(fontSize: 13)),
                backgroundColor: isWarning
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
              ))
          .toList(),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('  •  '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _RelatedInfoSection extends ConsumerWidget {
  final String speciesId;
  const _RelatedInfoSection({required this.speciesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(speciesRelationsProvider(speciesId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (groups) {
        if (groups.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: '관련 정보'),
            ...groups.expand((group) => [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      group.type.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  ...group.items.map(
                    (item) => RelationCard(
                      relation: item.relation,
                      target: item.target,
                      onTap: () => _openGraph(context, item.target),
                    ),
                  ),
                ]),
          ],
        );
      },
    );
  }

  void _openGraph(BuildContext context, GraphEntity target) {
    context.push('/wiki/graph/${target.kind.wire}/${target.id}');
  }
}

class _CitationsSection extends ConsumerWidget {
  final String speciesId;
  const _CitationsSection({required this.speciesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(speciesCitationsProvider(speciesId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (citations) {
        if (citations.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: '출처'),
            ...citations.map((c) => CitationCard(citation: c)),
          ],
        );
      },
    );
  }
}
