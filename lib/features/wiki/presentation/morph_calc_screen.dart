import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/morph_genetics.dart';
import '../domain/punnett_engine.dart';
import 'wiki_providers.dart';

class MorphCalcScreen extends ConsumerStatefulWidget {
  final String speciesId;

  const MorphCalcScreen({super.key, required this.speciesId});

  @override
  ConsumerState<MorphCalcScreen> createState() => _MorphCalcScreenState();
}

class _MorphCalcScreenState extends ConsumerState<MorphCalcScreen> {
  String? _fatherMorph;
  String? _motherMorph;
  bool _showResult = false;
  List<String> _fatherHets = [];
  List<String> _motherHets = [];
  PunnettResult? _result;

  @override
  Widget build(BuildContext context) {
    final morphAsync = ref.watch(morphDataProvider(widget.speciesId));

    return Scaffold(
      appBar: AppBar(title: const Text('모프 계산기')),
      body: morphAsync.when(
        loading: () => const SkeletonPageLoading(cardCount: 3),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('모프 데이터를 불러올 수 없습니다: $e'),
          ),
        ),
        data: (data) => _buildBody(context, data),
      ),
    );
  }

  Widget _buildBody(BuildContext context, MorphGeneticsData data) {
    final morphNames = data.selectableMorphNames;
    final warnings = _checkWarnings(data);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Species info
          Text(
            data.speciesNameKo,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (data.calculatorNote != null) ...[
            const SizedBox(height: 4),
            Text(
              data.calculatorNote!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 24),

          // Father dropdown
          Text('아빠 모프', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _fatherMorph,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '모프 선택',
            ),
            items: morphNames
                .map((name) =>
                    DropdownMenuItem(value: name, child: Text(name)))
                .toList(),
            onChanged: (value) {
              setState(() {
                _fatherMorph = value;
                _fatherHets = [];
                _showResult = false;
                _result = null;
              });
            },
          ),
          _buildHetSelector(
            context,
            data,
            _fatherMorph,
            _fatherHets,
            (newHets) => setState(() {
              _fatherHets = newHets;
              _showResult = false;
              _result = null;
            }),
          ),
          const SizedBox(height: 16),

          // Mother dropdown
          Text('엄마 모프', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _motherMorph,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '모프 선택',
            ),
            items: morphNames
                .map((name) =>
                    DropdownMenuItem(value: name, child: Text(name)))
                .toList(),
            onChanged: (value) {
              setState(() {
                _motherMorph = value;
                _motherHets = [];
                _showResult = false;
                _result = null;
              });
            },
          ),
          _buildHetSelector(
            context,
            data,
            _motherMorph,
            _motherHets,
            (newHets) => setState(() {
              _motherHets = newHets;
              _showResult = false;
              _result = null;
            }),
          ),
          const SizedBox(height: 24),

          // Warnings
          ...warnings,

          // Calculate button
          FilledButton.icon(
            onPressed: _fatherMorph != null && _motherMorph != null
                ? () {
                    final fatherEntry = data.morphs
                        .where((m) => m.name == _fatherMorph)
                        .first;
                    final motherEntry = data.morphs
                        .where((m) => m.name == _motherMorph)
                        .first;

                    final fatherGenotype = PunnettEngine.genotypeFromMorph(
                      morph: fatherEntry,
                      hetGeneIds: _fatherHets,
                      morphData: data,
                    );
                    final motherGenotype = PunnettEngine.genotypeFromMorph(
                      morph: motherEntry,
                      hetGeneIds: _motherHets,
                      morphData: data,
                    );

                    final result = PunnettEngine.calculate(
                      father: fatherGenotype,
                      mother: motherGenotype,
                      morphData: data,
                    );

                    setState(() {
                      _showResult = true;
                      _result = result;
                    });
                  }
                : null,
            icon: const Icon(Icons.calculate),
            label: const Text('결과 보기'),
          ),

          // Result
          if (_showResult && _result != null) ...[
            const SizedBox(height: 24),

            // 전체 교배 경고
            for (final warning in _result!.warnings) ...[
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.warning,
                          color:
                              Theme.of(context).colorScheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          warning,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 결과 제목
            Text(
              '$_fatherMorph × $_motherMorph',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // 각 결과 카드
            for (final outcome in _result!.outcomes) ...[
              _OutcomeCard(outcome: outcome),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildHetSelector(
    BuildContext context,
    MorphGeneticsData data,
    String? selectedMorph,
    List<String> hets,
    void Function(List<String>) onChanged,
  ) {
    if (selectedMorph == null) return const SizedBox.shrink();

    // 선택된 모프의 유전자 ID 집합
    final morphGenes = data.morphs
            .where((m) => m.name == selectedMorph)
            .firstOrNull
            ?.genes
            .toSet() ??
        {};

    // het 후보: 열성 유전자 중 모프에 없는 것
    final candidates = data.genes
        .where((g) =>
            g.inheritance == 'recessive' && !morphGenes.contains(g.id))
        .toList();

    if (candidates.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('보유 가능 het',
            style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: candidates.map((gene) {
            final selected = hets.contains(gene.id);
            return FilterChip(
              label: Text(gene.name,
                  style: const TextStyle(fontSize: 12)),
              selected: selected,
              onSelected: (v) {
                final newHets = List<String>.from(hets);
                if (v) {
                  newHets.add(gene.id);
                } else {
                  newHets.remove(gene.id);
                }
                onChanged(newHets);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  List<Widget> _checkWarnings(MorphGeneticsData data) {
    final widgets = <Widget>[];

    if (_fatherMorph == null || _motherMorph == null) return widgets;

    // Find genes for selected morphs
    final fatherEntry =
        data.morphs.where((m) => m.name == _fatherMorph).firstOrNull;
    final motherEntry =
        data.morphs.where((m) => m.name == _motherMorph).firstOrNull;

    if (fatherEntry == null || motherEntry == null) return widgets;

    final fatherGeneIds = fatherEntry.genes.toSet();
    final motherGeneIds = motherEntry.genes.toSet();
    final commonGeneIds = fatherGeneIds.intersection(motherGeneIds);

    // Check lethal combinations
    for (final geneId in commonGeneIds) {
      final gene = data.genes.where((g) => g.id == geneId).firstOrNull;
      if (gene != null && gene.homozygousLethal) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.warning,
                        color:
                            Theme.of(context).colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '치사 조합 경고: ${gene.name}(${gene.nameEn}) 유전자가 양쪽 모두에 있습니다. '
                        '호모접합(homozygous) 개체는 치사할 수 있습니다.',
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    // Check health warnings for all genes in both parents
    final allGeneIds = {...fatherGeneIds, ...motherGeneIds};
    for (final geneId in allGeneIds) {
      final gene = data.genes.where((g) => g.id == geneId).firstOrNull;
      if (gene != null && gene.healthWarning != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              color: Colors.orange.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.health_and_safety,
                        color: Colors.orange.shade300),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${gene.name}: ${gene.healthWarning}',
                        style: TextStyle(color: Colors.orange.shade200),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }
}

class _OutcomeCard extends StatelessWidget {
  final OffspringOutcome outcome;

  const _OutcomeCard({required this.outcome});

  @override
  Widget build(BuildContext context) {
    final percent = (outcome.probability * 100).toStringAsFixed(1);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: outcome.isLethal ? colorScheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 표현형 이름 + 확률
            Row(
              children: [
                if (outcome.isLethal)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.dangerous,
                      size: 18,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                Expanded(
                  child: Text(
                    outcome.phenotypeName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: outcome.isLethal
                              ? colorScheme.onErrorContainer
                              : null,
                        ),
                  ),
                ),
                Text(
                  '$percent%',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: outcome.isLethal
                            ? colorScheme.onErrorContainer
                            : colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 확률 바
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: outcome.probability,
                minHeight: 6,
                backgroundColor: outcome.isLethal
                    ? colorScheme.error.withValues(alpha: 0.2)
                    : colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  outcome.isLethal ? colorScheme.error : colorScheme.primary,
                ),
              ),
            ),
            // 유전형 상세
            if (outcome.genotypeDetails.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                outcome.genotypeDetails.join(' · '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: outcome.isLethal
                          ? colorScheme.onErrorContainer
                          : colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            // 건강 경고 (치사 아닌 경우)
            if (outcome.healthWarning != null && !outcome.isLethal) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.health_and_safety,
                        size: 14, color: Colors.orange.shade300),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        outcome.healthWarning!,
                        style: TextStyle(
                            fontSize: 11, color: Colors.orange.shade200),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
