import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/morph_genetics.dart';
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

  @override
  Widget build(BuildContext context) {
    final morphAsync = ref.watch(morphDataProvider(widget.speciesId));

    return Scaffold(
      appBar: AppBar(title: const Text('모프 계산기')),
      body: morphAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
                _showResult = false;
              });
            },
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
                _showResult = false;
              });
            },
          ),
          const SizedBox(height: 24),

          // Warnings
          ...warnings,

          // Calculate button
          FilledButton.icon(
            onPressed: _fatherMorph != null && _motherMorph != null
                ? () => setState(() => _showResult = true)
                : null,
            icon: const Icon(Icons.calculate),
            label: const Text('결과 보기'),
          ),

          // Result
          if (_showResult) ...[
            const SizedBox(height: 24),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$_fatherMorph × $_motherMorph',
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '이 조합의 데이터를 준비 중입니다.\n퍼넷 스퀘어 엔진이 곧 추가될 예정이에요.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
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
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.health_and_safety, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${gene.name}: ${gene.healthWarning}',
                        style: TextStyle(color: Colors.orange.shade900),
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
