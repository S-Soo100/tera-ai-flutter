import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/morph_genetics.dart';
import 'wiki_providers.dart';

class MorphGuideScreen extends ConsumerWidget {
  final String speciesId;

  const MorphGuideScreen({super.key, required this.speciesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final morphAsync = ref.watch(morphDataProvider(speciesId));

    return morphAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('모프 도감')),
        body: const SkeletonPageLoading(cardCount: 4),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('모프 도감')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('모프 데이터를 불러올 수 없습니다: $e'),
          ),
        ),
      ),
      data: (data) => _MorphGuideLoaded(data: data),
    );
  }
}

class _MorphGuideLoaded extends StatelessWidget {
  final MorphGeneticsData data;

  const _MorphGuideLoaded({required this.data});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${data.speciesNameKo} 모프 도감'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '유전자'),
              Tab(text: '콤보 모프'),
              Tab(text: '라인브리드 형질'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _GenesTab(data: data),
            _CombosTab(data: data),
            _LineBredTab(data: data),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: 유전자
// ---------------------------------------------------------------------------

class _GenesTab extends StatelessWidget {
  final MorphGeneticsData data;

  const _GenesTab({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.genes.isEmpty) {
      return const Center(child: Text('데이터 없음'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (data.alleleGroups.isNotEmpty) ...[
          for (final group in data.alleleGroups) ...[
            _AlleleGroupBanner(group: group),
            const SizedBox(height: 16),
          ],
        ],
        for (final gene in data.genes) ...[
          _GeneCard(gene: gene),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _AlleleGroupBanner extends StatelessWidget {
  final AlleleGroup group;

  const _AlleleGroupBanner({required this.group});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.name, style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              group.description,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: group.members
                  .map(
                    (m) => Chip(
                      label: Text(m),
                      backgroundColor: colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontSize: 12,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                    ),
                  )
                  .toList(),
            ),
            if (group.crossResults.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('교차 교배 결과', style: textTheme.labelMedium),
              const SizedBox(height: 6),
              for (final result in group.crossResults) ...[
                _CrossResultRow(result: result),
              ],
            ],
            if (group.superHealth.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('슈퍼폼 건강 비교', style: textTheme.labelMedium),
              const SizedBox(height: 6),
              for (final entry in group.superHealth.entries)
                _SuperHealthRow(label: entry.key, value: entry.value),
            ],
          ],
        ),
      ),
    );
  }
}

class _CrossResultRow extends StatelessWidget {
  final AlleleGroupCrossResult result;

  const _CrossResultRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${result.key} → ${result.name}',
            style: textTheme.bodySmall,
          ),
          if (result.note != null)
            Text(
              result.note!,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}

class _SuperHealthRow extends StatelessWidget {
  final String label;
  final String value;

  const _SuperHealthRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isWarning = value.contains('⚠️');
    final isOk = value.contains('✅');

    Color? valueColor;
    if (isWarning) valueColor = Colors.orange.shade700;
    if (isOk) valueColor = Colors.green.shade700;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodySmall?.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneCard extends StatelessWidget {
  final MorphGene gene;

  const _GeneCard({required this.gene});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(gene.name, style: textTheme.titleSmall),
                  Text(
                    gene.nameEn,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(gene.inheritanceDisplay),
              labelStyle: TextStyle(
                fontSize: 11,
                color: colorScheme.onSecondaryContainer,
              ),
              backgroundColor: colorScheme.secondaryContainer,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        subtitle: Row(
          children: [
            if (gene.alleleGroup != null) ...[
              _SmallBadge(
                label: '대립유전자 복합체',
                color: Colors.purple.withValues(alpha: 0.2),
                textColor: Colors.purple.shade200,
              ),
              const SizedBox(width: 6),
            ],
            if (gene.homozygousLethal)
              _SmallBadge(
                label: '치사 슈퍼폼',
                color: colorScheme.errorContainer,
                textColor: colorScheme.onErrorContainer,
              ),
          ],
        ),
        children: [
          Text(gene.description, style: textTheme.bodyMedium),
          if (gene.discoveredBy != null || gene.discoveredYear != null) ...[
            const SizedBox(height: 8),
            Text(
              '발견: ${gene.discoveredBy ?? ''}${gene.discoveredYear != null ? ' (${gene.discoveredYear}년)' : ''}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (gene.lines.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '라인: ${gene.lines.join(', ')}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '라인 간 호환: ${gene.linesCompatible ? 'O' : 'X'}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (gene.healthWarning != null) ...[
            const SizedBox(height: 8),
            _WarningCard(message: gene.healthWarning!),
          ],
        ],
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _SmallBadge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: textColor),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  final String message;

  const _WarningCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: 콤보 모프
// ---------------------------------------------------------------------------

class _CombosTab extends StatelessWidget {
  final MorphGeneticsData data;

  const _CombosTab({required this.data});

  static const _sectionLabels = {
    'baseline': '기본',
    'proven_mendelian': '단일 유전자 모프',
    'proven_combo': '콤보 모프',
  };

  static const _sectionOrder = ['baseline', 'proven_mendelian', 'proven_combo'];

  @override
  Widget build(BuildContext context) {
    if (data.morphs.isEmpty) {
      return const Center(child: Text('데이터 없음'));
    }

    final grouped = <String, List<MorphEntry>>{};
    for (final morph in data.morphs) {
      (grouped[morph.geneticsType] ??= []).add(morph);
    }

    final sections = <Widget>[];
    for (final type in _sectionOrder) {
      final entries = grouped[type];
      if (entries == null || entries.isEmpty) continue;
      sections.add(
        _SectionHeader(
          title: _sectionLabels[type] ?? type,
        ),
      );
      sections.add(const SizedBox(height: 8));
      for (final morph in entries) {
        sections.add(_MorphCard(morph: morph));
        sections.add(const SizedBox(height: 12));
      }
    }

    // 정의되지 않은 타입이 있으면 마지막에 추가
    for (final entry in grouped.entries) {
      if (_sectionOrder.contains(entry.key)) continue;
      sections.add(_SectionHeader(title: entry.key));
      sections.add(const SizedBox(height: 8));
      for (final morph in entry.value) {
        sections.add(_MorphCard(morph: morph));
        sections.add(const SizedBox(height: 12));
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: sections,
    );
  }
}

class _MorphCard extends StatelessWidget {
  final MorphEntry morph;

  const _MorphCard({required this.morph});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(morph.name, style: textTheme.titleSmall),
                      if (morph.nameEn != null)
                        Text(
                          morph.nameEn!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (morph.zygosity == 'homozygous')
                  Chip(
                    label: const Text('호모접합'),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onTertiaryContainer,
                    ),
                    backgroundColor: colorScheme.tertiaryContainer,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            if (morph.genes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: morph.genes
                    .map(
                      (g) => Chip(
                        label: Text(g),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                    )
                    .toList(),
              ),
            ],
            if (morph.zygosityNote != null) ...[
              const SizedBox(height: 4),
              Text(
                morph.zygosityNote!,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(morph.description, style: textTheme.bodyMedium),
            if (morph.healthWarning != null) ...[
              const SizedBox(height: 8),
              _WarningCard(message: morph.healthWarning!),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3: 라인브리드 형질
// ---------------------------------------------------------------------------

class _LineBredTab extends StatelessWidget {
  final MorphGeneticsData data;

  const _LineBredTab({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.lineBredTraits.isEmpty) {
      return const Center(child: Text('데이터 없음'));
    }

    final patternGroupIds = data.patternGroups.map((g) => g.id).toSet();
    final ungrouped = data.lineBredTraits
        .where((t) => t.group == null || !patternGroupIds.contains(t.group))
        .toList();

    final sections = <Widget>[];

    for (final group in data.patternGroups) {
      final traits = data.traitsInGroup(group.id);
      if (traits.isEmpty) continue;

      sections.add(_SectionHeader(title: group.name));
      sections.add(const SizedBox(height: 4));
      sections.add(
        Text(
          group.description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
      sections.add(const SizedBox(height: 8));
      for (final trait in traits) {
        sections.add(_LineBredTraitCard(trait: trait));
        sections.add(const SizedBox(height: 12));
      }
    }

    if (ungrouped.isNotEmpty) {
      sections.add(const _SectionHeader(title: '기타 형질'));
      sections.add(const SizedBox(height: 8));
      for (final trait in ungrouped) {
        sections.add(_LineBredTraitCard(trait: trait));
        sections.add(const SizedBox(height: 12));
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: sections,
    );
  }
}

class _LineBredTraitCard extends StatelessWidget {
  final LineBredTrait trait;

  const _LineBredTraitCard({required this.trait});

  Color _chipColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (trait.type) {
      case 'color':
        return Colors.orange.withValues(alpha: 0.15);
      case 'structural':
        return Colors.purple.withValues(alpha: 0.15);
      case 'spot':
        return Colors.green.withValues(alpha: 0.15);
      case 'color_pattern':
        return Colors.brown.withValues(alpha: 0.15);
      case 'pattern':
      default:
        return colorScheme.primaryContainer;
    }
  }

  Color _chipTextColor(BuildContext context) {
    switch (trait.type) {
      case 'color':
        return Colors.orange.shade300;
      case 'structural':
        return Colors.purple.shade300;
      case 'spot':
        return Colors.green.shade300;
      case 'color_pattern':
        return Colors.brown.shade300;
      case 'pattern':
      default:
        return Theme.of(context).colorScheme.onPrimaryContainer;
    }
  }

  String _typeLabel() {
    switch (trait.type) {
      case 'color':
        return '색상';
      case 'structural':
        return '구조';
      case 'spot':
        return '스팟';
      case 'color_pattern':
        return '색+패턴';
      case 'pattern':
        return '패턴';
      default:
        return trait.type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trait.name, style: textTheme.titleSmall),
                      Text(
                        trait.nameEn,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(_typeLabel()),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: _chipTextColor(context),
                  ),
                  backgroundColor: _chipColor(context),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            if (trait.variants.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: trait.variants
                    .map(
                      (v) => Chip(
                        label: Text(v),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        side: BorderSide(
                          color: colorScheme.outlineVariant,
                        ),
                        backgroundColor: Colors.transparent,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 8),
            Text(trait.description, style: textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 공통 위젯
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
