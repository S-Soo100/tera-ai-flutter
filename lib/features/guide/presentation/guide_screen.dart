import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/guide_data.dart';

final guideDataProvider = FutureProvider<GuideData>((ref) async {
  final jsonString = await rootBundle.loadString('assets/data/guide_steps.json');
  final json = jsonDecode(jsonString) as Map<String, dynamic>;
  return GuideData.fromJson(json);
});

class GuideScreen extends ConsumerStatefulWidget {
  const GuideScreen({super.key});

  @override
  ConsumerState<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends ConsumerState<GuideScreen> {
  final Set<int> _checkedDocuments = {};

  @override
  Widget build(BuildContext context) {
    final guideAsync = ref.watch(guideDataProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('자진신고 가이드'),
      ),
      body: guideAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('데이터를 불러오지 못했어요\n$err', textAlign: TextAlign.center),
        ),
        data: (guide) {
          final daysLeft = guide.daysRemaining;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- D-day 카운트다운 ---
                Center(
                  child: Column(
                    children: [
                      Text(
                        'D-$daysLeft',
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: daysLeft <= 30
                              ? colorScheme.error
                              : colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '마감: ${guide.deadline}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        '계도기간: ~${guide.gracePeriodEnd}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // --- 주의 배너 ---
                Card(
                  color: colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: colorScheme.onErrorContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '정부24가 아닙니다! ${guide.systemName}에서 신고하세요',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // --- WIMS 바로가기 ---
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // url_launcher가 있으면 launchUrl 사용
                      // 여기서는 SnackBar로 URL 표시
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(guide.systemUrl),
                          action: SnackBarAction(
                            label: '확인',
                            onPressed: () {},
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: Text('${guide.systemName} 바로가기'),
                  ),
                ),
                if (guide.systemNote.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    guide.systemNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // --- 10단계 절차 ---
                Text(
                  '신고 절차',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...guide.steps.map((step) {
                  return ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      foregroundColor: colorScheme.onPrimaryContainer,
                      child: Text('${step.order}'),
                    ),
                    title: Text(step.title),
                    subtitle: Text(
                      step.description,
                      style: theme.textTheme.bodySmall,
                    ),
                    children: [
                      if (step.detail != null && step.detail!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
                          child: Text(
                            step.detail!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                    ],
                  );
                }),
                const SizedBox(height: 24),

                // --- 필요 서류 ---
                Text(
                  '필요 서류',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...guide.requiredDocuments.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final doc = entry.value;
                  return CheckboxListTile(
                    value: _checkedDocuments.contains(idx),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _checkedDocuments.add(idx);
                        } else {
                          _checkedDocuments.remove(idx);
                        }
                      });
                    },
                    title: Text(doc.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doc.description),
                        if (doc.note != null && doc.note!.isNotEmpty)
                          Text(
                            doc.note!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                    isThreeLine: doc.note != null && doc.note!.isNotEmpty,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }),
                const SizedBox(height: 24),

                // --- FAQ ---
                Text(
                  '자주 묻는 질문',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...guide.faq.map((item) {
                  return ExpansionTile(
                    leading: const Icon(Icons.help_outline),
                    title: Text(item.question),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
                        child: Text(
                          item.answer,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}
