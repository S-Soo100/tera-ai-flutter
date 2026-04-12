import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../features/wiki/domain/citation.dart';

class CitationCard extends StatelessWidget {
  final Citation citation;

  const CitationCard({super.key, required this.citation});

  Future<void> _open(BuildContext context) async {
    final url = citation.resolvedUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('링크를 열 수 없습니다')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final enabled = citation.hasLink;

    final meta = <String>[
      if (citation.authors.isNotEmpty) citation.authors.join(', '),
      if (citation.publisher != null && citation.publisher!.isNotEmpty) citation.publisher!,
      if (citation.year != null) '${citation.year}',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: scheme.surfaceContainerHighest,
      child: InkWell(
        onTap: enabled ? () => _open(context) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ConfidenceBadge(confidence: citation.confidence),
                  const SizedBox(width: 8),
                  _TypeChip(type: citation.type),
                  const Spacer(),
                  Icon(
                    enabled ? Icons.open_in_new : Icons.info_outline,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                citation.title,
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(meta, style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
              if (!enabled) ...[
                const SizedBox(height: 6),
                Text(
                  '링크 없음 — 내부 자료 또는 미검증',
                  style: textTheme.bodySmall?.copyWith(color: scheme.outline),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final CitationConfidence confidence;
  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, bg, fg, icon) = switch (confidence) {
      CitationConfidence.high => ('감수 완료', scheme.primaryContainer, scheme.onPrimaryContainer, Icons.verified),
      CitationConfidence.medium => ('검증', scheme.secondaryContainer, scheme.onSecondaryContainer, Icons.check_circle_outline),
      CitationConfidence.unverified => ('미검증', scheme.errorContainer, scheme.onErrorContainer, Icons.warning_amber),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final CitationType type;
  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = switch (type) {
      CitationType.careSheet => '케어 시트',
      CitationType.book => '단행본',
      CitationType.paper => '논문',
      CitationType.community => '커뮤니티',
      CitationType.unknown => '기타',
    };
    return Text(
      label,
      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
    );
  }
}
