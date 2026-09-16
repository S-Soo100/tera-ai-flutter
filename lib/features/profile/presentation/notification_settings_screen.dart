import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/glass_palette.dart';
import '../../home/presentation/routine_settings_screen.dart'
    show ScheduleSwitch;
import '../../my_cage/presentation/widgets/management_widgets.dart';
import '../data/notification_preferences_repository.dart';
import 'widgets/my_page_widgets.dart';

/// 알림 설정(Figma PushAlarm 1142:9613). 기능 설정 3종 + 수신 동의 2종.
/// 행 369×72 흰색 r12(선 없음, 간격 8): 제목 16/600 + 부제 14/500 왼쪽 16,
/// 스위치 80×32 `#C00306` 오른쪽 16. 마케팅 행은 87h(동의 일자 12/500 두 줄).
///
/// 값은 아직 기기 로컬에만 저장된다([NotificationPreferencesRepository] 주석).
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  static const highlightKey = Key('notif_toggle_highlight');
  static const commentKey = Key('notif_toggle_comment');
  static const likeKey = Key('notif_toggle_like');
  static const newsKey = Key('notif_toggle_news');
  static const marketingKey = Key('notif_toggle_marketing');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPrefsProvider);
    final n = ref.read(notificationPrefsProvider.notifier);
    return MyPageScaffold(
      title: 'notif_settings_title'.tr(),
      // 원본 첫 라벨 y118.5 = 헤더 106 + 12.5.
      padding: const EdgeInsets.fromLTRB(12, 12.5, 12, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MyPageSectionTitle('notif_settings_section_features'.tr()),
        _ToggleRow(
            key: highlightKey,
            title: 'notif_settings_highlight'.tr(),
            subtitle: 'notif_settings_highlight_desc'.tr(),
            value: prefs.highlight,
            onChanged: (v) => n.update(prefs.copyWith(highlight: v))),
        const SizedBox(height: 8),
        _ToggleRow(
            key: commentKey,
            title: 'notif_settings_comment'.tr(),
            subtitle: 'notif_settings_comment_desc'.tr(),
            value: prefs.comment,
            onChanged: (v) => n.update(prefs.copyWith(comment: v))),
        const SizedBox(height: 8),
        _ToggleRow(
            key: likeKey,
            title: 'notif_settings_like'.tr(),
            subtitle: 'notif_settings_like_desc'.tr(),
            value: prefs.like,
            onChanged: (v) => n.update(prefs.copyWith(like: v))),
        const SizedBox(height: 24),
        MyPageSectionTitle('notif_settings_section_consent'.tr()),
        _ToggleRow(
            key: newsKey,
            title: 'notif_settings_news'.tr(),
            subtitle: 'notif_settings_news_desc'.tr(),
            value: prefs.news,
            onChanged: (v) => n.update(prefs.copyWith(news: v))),
        const SizedBox(height: 8),
        _ToggleRow(
            key: marketingKey,
            title: 'notif_settings_marketing'.tr(),
            subtitle: prefs.marketing && prefs.marketingAgreedAt != null
                ? '${'notif_settings_marketing_agreed_fmt'.tr(args: [
                        _date(prefs.marketingAgreedAt!)
                      ])}\n${'notif_settings_marketing_desc'.tr()}'
                : 'notif_settings_marketing_desc'.tr(),
            // 원본(1142:9613) 마케팅 행은 동의 전에도 12/16 두 줄 상자.
            small: true,
            value: prefs.marketing,
            onChanged: n.setMarketing),
      ]),
    );
  }

  /// Figma "2026. 9. 16".
  static String _date(DateTime d) => '${d.year}. ${d.month}. ${d.day}';
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.value,
      required this.onChanged,
      this.small = false});
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// 부제 12/500 행간 16 두 줄(마케팅 동의 일자).
  final bool small;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
            color: glass.surfaceHeader,
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                // 행 72 = 16 + 19.09 + 4 + 16.7 + 16 — 행간을 명시해야 맞는다.
                Text(title,
                    style: managementStyle(context, weight: FontWeight.w600)
                        .copyWith(height: 19.09 / 16)),
                const SizedBox(height: 4),
                // 실기기 서체 폭이 원본보다 넓으면 한 줄이 안 들어가므로 줄바꿈을
                // 허용한다(잘라서 "…"로 두지 않는다).
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: managementStyle(context,
                            size: small ? 12 : 14, color: glass.textTertiary)
                        .copyWith(height: small ? 16 / 12 : 16.7 / 14)),
              ])),
          // 원본 글줄 폭 251.5는 369 안에서 간격 4여야 한 줄로 들어간다.
          const SizedBox(width: 4),
          ScheduleSwitch(
              value: value, color: glass.navSelected, onChanged: onChanged),
        ]));
  }
}
