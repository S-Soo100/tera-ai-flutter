import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../wiki/domain/citation.dart';
import '../../domain/chat_message.dart';
import '../chat_providers.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onReportBad;

  const ChatBubble({super.key, required this.message, this.onReportBad});

  @override
  Widget build(BuildContext context) {
    if (message.role == 'user') {
      return _UserBubble(message: message);
    }
    if (message.fromCache) {
      return _CacheBubble(message: message, onReportBad: onReportBad);
    }
    return _AssistantBubble(message: message, onReportBad: onReportBad);
  }
}

// ── 레거시 content 파싱 ──

const _sourceSeparator = '\n\n출처:\n';
const _disclaimerSeparator = '\n\n일반 지식 기반 답변입니다. 전문가 확인을 권장합니다.';

/// 기존 메시지(citationIds 없음)에서 본문과 출처/면책 텍스트를 분리
({String body, bool isGeneralKnowledge}) _parseContentBody(String content) {
  final srcIdx = content.indexOf(_sourceSeparator);
  if (srcIdx != -1) {
    return (body: content.substring(0, srcIdx), isGeneralKnowledge: false);
  }
  final discIdx = content.indexOf(_disclaimerSeparator);
  if (discIdx != -1) {
    return (body: content.substring(0, discIdx), isGeneralKnowledge: true);
  }
  return (body: content, isGeneralKnowledge: false);
}

// ── URL 감지 정규식 ──

final _urlRegex = RegExp(
  r'https?://[^\s\)\]\>,]+',
  caseSensitive: false,
);

/// 텍스트에서 URL을 감지하여 클릭 가능한 RichText로 변환
Widget _buildLinkedText(BuildContext context, String text, {Color? textColor}) {
  final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: textColor,
        height: 1.5,
      );
  final linkStyle = style?.copyWith(
    color: Theme.of(context).colorScheme.primary,
    decoration: TextDecoration.underline,
    decorationColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
  );

  final matches = _urlRegex.allMatches(text).toList();

  if (matches.isEmpty) {
    return SelectableText(text, style: style);
  }

  final spans = <TextSpan>[];
  int lastEnd = 0;

  for (final match in matches) {
    if (match.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
    }
    final url = match.group(0)!;
    spans.add(TextSpan(
      text: url,
      style: linkStyle,
      recognizer: TapGestureRecognizer()
        ..onTap = () => _openUrl(url),
    ));
    lastEnd = match.end;
  }

  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd)));
  }

  return RichText(
    text: TextSpan(style: style, children: spans),
  );
}

Future<void> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // 열 수 없는 URL은 무시
  }
}

// ── 공통: 피드백 버튼 ──

Widget _buildFeedbackRow(BuildContext context, VoidCallback? onReportBad) {
  if (onReportBad == null) return const SizedBox.shrink();
  final colorScheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onReportBad,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.thumb_down_outlined,
                  size: 14,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  '부정확',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

// ── 사용자 버블 ──

class _UserBubble extends StatelessWidget {
  final ChatMessage message;
  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            message.content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimary,
                  height: 1.4,
                ),
          ),
        ),
      ),
    );
  }
}

// ── 어시스턴트 버블 ──

class _AssistantBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onReportBad;
  const _AssistantBubble({required this.message, this.onReportBad});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 새 메시지(citationIds/sourceType 있음) vs 레거시 메시지 분기
    final hasStructuredSource =
        message.citationIds.isNotEmpty || message.sourceType != null;

    final String bodyText;
    final bool showGeneralBadge;

    if (hasStructuredSource) {
      bodyText = message.content;
      showGeneralBadge = message.sourceType == 'general_knowledge';
    } else {
      // 레거시: content에서 출처/면책 텍스트 파싱
      final parsed = _parseContentBody(message.content);
      bodyText = parsed.body;
      showGeneralBadge = parsed.isGeneralKnowledge;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLinkedText(context, bodyText),

              // 출처 인라인 칩 (care_data)
              if (message.citationIds.isNotEmpty)
                _CitationChips(citationIds: message.citationIds),

              // 웹 검색 출처 칩
              if (message.webSources.isNotEmpty)
                _WebSourceChips(webSources: message.webSources),

              // 면책 배지 (general_knowledge)
              if (showGeneralBadge && message.citationIds.isEmpty && message.webSources.isEmpty)
                const _GeneralKnowledgeBadge(),

              _buildFeedbackRow(context, onReportBad),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Citation 인라인 칩 ──

class _CitationChips extends ConsumerWidget {
  final List<String> citationIds;

  const _CitationChips({required this.citationIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCitations = ref.watch(chatCitationsProvider(citationIds.join(',')));
    final colorScheme = Theme.of(context).colorScheme;

    return asyncCitations.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (citations) {
        if (citations.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: citations.map((c) => _buildCitationChip(context, c, colorScheme)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildCitationChip(BuildContext context, Citation c, ColorScheme colorScheme) {
    final hasUrl = c.hasLink;
    final label = c.publisher != null && c.publisher!.isNotEmpty
        ? c.publisher!
        : (c.title.length > 20 ? '${c.title.substring(0, 20)}...' : c.title);

    return InkWell(
      onTap: hasUrl ? () => _openUrl(c.resolvedUrl!) : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasUrl ? Icons.open_in_new : Icons.article_outlined,
              size: 12,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 웹 검색 출처 칩 ──

class _WebSourceChips extends StatelessWidget {
  final List<String> webSources;

  const _WebSourceChips({required this.webSources});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: webSources.map((ws) {
          // "title|url" 형식 파싱 (첫 번째 |에서만 분리)
          final idx = ws.indexOf('|');
          final title = idx == -1 ? ws : ws.substring(0, idx);
          final url = idx == -1 ? null : ws.substring(idx + 1);

          return InkWell(
            onTap: url != null ? () => _openUrl(url) : null,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.language,
                    size: 12,
                    color: colorScheme.tertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    title.length > 25 ? '${title.substring(0, 25)}...' : title,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.tertiary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── 면책 배지 (일반 지식 기반) ──

class _GeneralKnowledgeBadge extends StatelessWidget {
  const _GeneralKnowledgeBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'AI 학습 데이터 기반 · 전문가 확인 권장',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 캐시 버블 ──

class _CacheBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onReportBad;
  const _CacheBubble({required this.message, this.onReportBad});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 14,
                      color: colorScheme.tertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '즉시 답변',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.tertiary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: _buildLinkedText(
                  context,
                  message.content,
                  textColor: colorScheme.onTertiaryContainer,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: _buildFeedbackRow(context, onReportBad),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
