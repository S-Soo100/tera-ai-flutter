import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/citation_card.dart';
import '../../../shared/widgets/relation_card.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../data/citation_repository.dart';
import '../data/graph_repository.dart';
import '../domain/citation.dart';
import '../domain/graph_entity.dart';

class _GraphDetailData {
  final GraphEntity entity;
  final Map<RelationType, List<({GraphRelation relation, GraphEntity target})>> outgoing;
  final Map<RelationType, List<({GraphRelation relation, GraphEntity source})>> incoming;
  final List<Citation> citations;

  const _GraphDetailData({
    required this.entity,
    required this.outgoing,
    required this.incoming,
    required this.citations,
  });
}

final _graphDetailProvider =
    FutureProvider.family<_GraphDetailData?, String>((ref, entityId) async {
  final graphRepo = ref.watch(graphRepositoryProvider);
  final citationRepo = ref.watch(citationRepositoryProvider);
  await graphRepo.load();

  final entity = graphRepo.entity(entityId);
  if (entity == null) return null;

  final out = <RelationType, List<({GraphRelation relation, GraphEntity target})>>{};
  final citationIds = <String>{};
  for (final r in graphRepo.outgoing(entityId)) {
    final target = graphRepo.entity(r.to);
    if (target == null) continue;
    (out[r.type] ??= []).add((relation: r, target: target));
    citationIds.addAll(r.citationIds);
  }

  final inc = <RelationType, List<({GraphRelation relation, GraphEntity source})>>{};
  for (final r in graphRepo.incoming(entityId)) {
    final source = graphRepo.entity(r.from);
    if (source == null) continue;
    (inc[r.type] ??= []).add((relation: r, source: source));
    citationIds.addAll(r.citationIds);
  }

  final citations = await citationRepo.hydrate(citationIds.toList());

  return _GraphDetailData(
    entity: entity,
    outgoing: out,
    incoming: inc,
    citations: citations,
  );
});

class GraphDetailScreen extends ConsumerWidget {
  final String kind;
  final String entityId;

  const GraphDetailScreen({
    super.key,
    required this.kind,
    required this.entityId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_graphDetailProvider(entityId));
    return Scaffold(
      appBar: AppBar(title: Text(_kindLabel(kind))),
      body: async.when(
        loading: () => const SkeletonPageLoading(cardCount: 3),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('정보를 불러올 수 없습니다: $e'),
          ),
        ),
        data: (data) {
          if (data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('엔티티를 찾을 수 없습니다: $entityId'),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(entity: data.entity),
                if (data.entity.payload.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _PayloadCard(payload: data.entity.payload),
                ],
                if (data.outgoing.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const _SectionHeader(title: '이 항목이 관련된 대상'),
                  ..._buildOutgoing(context, data.outgoing),
                ],
                if (data.incoming.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const _SectionHeader(title: '이 항목을 참조하는 항목'),
                  ..._buildIncoming(context, data.incoming),
                ],
                if (data.citations.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const _SectionHeader(title: '출처'),
                  ...data.citations.map((c) => CitationCard(citation: c)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildOutgoing(
    BuildContext context,
    Map<RelationType, List<({GraphRelation relation, GraphEntity target})>> groups,
  ) {
    final widgets = <Widget>[];
    groups.forEach((type, items) {
      widgets.add(_GroupLabel(label: type.label));
      for (final item in items) {
        widgets.add(RelationCard(
          relation: item.relation,
          target: item.target,
          onTap: () => _drill(context, item.target),
        ));
      }
    });
    return widgets;
  }

  List<Widget> _buildIncoming(
    BuildContext context,
    Map<RelationType, List<({GraphRelation relation, GraphEntity source})>> groups,
  ) {
    final widgets = <Widget>[];
    groups.forEach((type, items) {
      widgets.add(_GroupLabel(label: type.label));
      for (final item in items) {
        widgets.add(RelationCard(
          relation: item.relation,
          target: item.source,
          onTap: () => _drill(context, item.source),
        ));
      }
    });
    return widgets;
  }

  void _drill(BuildContext context, GraphEntity target) {
    context.push('/wiki/graph/${target.kind.wire}/${target.id}');
  }

  String _kindLabel(String kind) {
    switch (kind) {
      case 'species':
        return '종';
      case 'env_cond':
        return '환경 조건';
      case 'disease':
        return '질병';
      case 'food':
        return '먹이';
      case 'equipment':
        return '기재';
      default:
        return kind;
    }
  }
}

class _Header extends StatelessWidget {
  final GraphEntity entity;
  const _Header({required this.entity});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Text(
      entity.label,
      style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _PayloadCard extends StatelessWidget {
  final Map<String, dynamic> payload;
  const _PayloadCard({required this.payload});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: payload.entries
              .where((e) => e.value != null)
              .map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium,
                        children: [
                          TextSpan(
                            text: '${e.key}: ',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: '${e.value}'),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

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

class _GroupLabel extends StatelessWidget {
  final String label;
  const _GroupLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
