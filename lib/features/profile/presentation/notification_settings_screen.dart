import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../../home/presentation/home_control_providers.dart';
import '../../home/presentation/routine_settings_screen.dart'
    show ScheduleSwitch;
import '../../home/presentation/widgets/env_setting_widgets.dart';
import '../../my_cage/presentation/management_colors.dart';
import '../../my_cage/presentation/widgets/management_widgets.dart';
import '../../notification/data/push_messaging_service.dart';
import '../../notification/presentation/push_providers.dart';
import '../data/notification_preferences_repository.dart';
import 'widgets/my_page_widgets.dart';

/// 알림 설정(Figma PushAlarm 1142:9613 → v4 1657:5547). 기능 설정 3종 + 온습도
/// 이탈 알림 이동 행 + 수신 동의 2종.
/// 행 369×72 흰색 r12(선 없음, 간격 8): 제목 16/600 + 부제 14/500 왼쪽 16,
/// 스위치 80×32 `#C00306` 오른쪽 16. 마케팅 행은 87h(동의 일자 12/500 두 줄).
///
/// 온습도 이탈 알림(S39)은 토글이 아니라 "설정하기 >" 이동 행이다 — 홈 세트의
/// 기기(`currentDeviceIdProvider`)의 온습도 설정 화면을 연다. 기기가 없으면
/// 부제 자리에 이유를 쓰고 행을 막는다.
///
/// 값은 아직 기기 로컬에만 저장된다([NotificationPreferencesRepository] 주석).
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  static const highlightKey = Key('notif_toggle_highlight');
  static const commentKey = Key('notif_toggle_comment');
  static const likeKey = Key('notif_toggle_like');
  static const newsKey = Key('notif_toggle_news');
  static const marketingKey = Key('notif_toggle_marketing');
  static const systemOffKey = Key('notif_system_off');
  static const featureSectionKey = Key('notif_feature_section');
  static const envAlertKey = Key('notif_env_alert_entry');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPrefsProvider);
    // 앱 복귀 시 PushLifecycleObserver가 권한을 다시 읽어 이 값을 갱신한다.
    final permission = ref.watch(pushPermissionProvider);
    final systemOff = permission == PushPermission.denied ||
        permission == PushPermission.notDetermined;
    final n = ref.read(notificationPrefsProvider.notifier);
    return MyPageScaffold(
      title: 'notif_settings_title'.tr(),
      // 원본 첫 라벨 y118.5 = 헤더 106 + 12.5.
      padding: const EdgeInsets.fromLTRB(12, 12.5, 12, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (systemOff) ...[
          _SystemOffNotice(
              onAllow: () => requestPushPermission(ref, retry: true)),
          const SizedBox(height: 24),
        ],
        MyPageSectionTitle('notif_settings_section_features'.tr()),
        // 기기 알림이 꺼져 있으면 기능 알림 토글은 동작하지 않으므로 흐리게·조작
        // 불가로 보인다. 저장된 선택은 그대로라 허용하고 돌아오면 바로 살아난다.
        // 온습도 이탈 알림 이동 행은 같이 흐리지만 이동은 막지 않는다 — 적정
        // 범위 설정은 알림 권한과 무관하게 쓰인다(실시간 카드·판정 기준).
        // 수신 동의(아래)는 동의 기록이라 기기 알림과 무관하게 조작할 수 있다.
        Opacity(
          key: featureSectionKey,
          opacity: systemOff ? 0.4 : 1,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            IgnorePointer(
              ignoring: systemOff,
              child: _ToggleRow(
                  key: highlightKey,
                  title: 'notif_settings_highlight'.tr(),
                  subtitle: 'notif_settings_highlight_desc'.tr(),
                  value: prefs.highlight,
                  onChanged: (v) => n.update(prefs.copyWith(highlight: v))),
            ),
            const SizedBox(height: 8),
            const _EnvAlertEntryRow(key: envAlertKey),
            const SizedBox(height: 8),
            IgnorePointer(
              ignoring: systemOff,
              child: _ToggleRow(
                  key: commentKey,
                  title: 'notif_settings_comment'.tr(),
                  subtitle: 'notif_settings_comment_desc'.tr(),
                  value: prefs.comment,
                  onChanged: (v) => n.update(prefs.copyWith(comment: v))),
            ),
            const SizedBox(height: 8),
            IgnorePointer(
              ignoring: systemOff,
              child: _ToggleRow(
                  key: likeKey,
                  title: 'notif_settings_like'.tr(),
                  subtitle: 'notif_settings_like_desc'.tr(),
                  value: prefs.like,
                  onChanged: (v) => n.update(prefs.copyWith(like: v))),
            ),
          ]),
        ),
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

/// 온습도 이탈 알림 이동 행(Figma S39 1657:5547 — "설정하기 >", 토글 아님).
///
/// 대상 = 홈 세트의 기기. 화면을 연 뒤 홈 세트가 바뀌어도 누르는 순간의 기기
/// id로 경로를 만든다(온습도 설정은 라우트 인자로 기기를 고정한다).
class _EnvAlertEntryRow extends ConsumerWidget {
  const _EnvAlertEntryRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(currentDeviceIdProvider);
    final deviceId = device.isLoading ? null : device.valueOrNull;
    final String subtitle;
    final Widget value;
    if (deviceId != null) {
      subtitle = 'notif_settings_env_alert_desc'.tr();
      value = Text('notif_settings_env_alert_action'.tr());
    } else if (device.isLoading) {
      subtitle = 'notif_settings_env_alert_desc'.tr();
      value = const SkeletonLoading(width: 55, height: 19);
    } else {
      // 기기 없음·조회 실패 — 갈 곳이 없으니 막고 이유를 부제 자리에 쓴다.
      subtitle = (device.hasError
              ? 'notif_settings_env_alert_load_failed'
              : 'notif_settings_env_alert_no_device')
          .tr();
      value = Text('notif_settings_env_alert_action'.tr());
    }
    return _SettingRow(
      title: 'notif_settings_env_alert'.tr(),
      subtitle: subtitle,
      onTap: deviceId == null
          ? null
          : () => context.push(tempHumidSettingPath(deviceId)),
      // Figma Right(77×19) — 설정하기 16/500 `#949090` + 화살표 18 `#3C3C3C`.
      trailing: Opacity(
        opacity: deviceId == null && !device.isLoading ? 0.4 : 1,
        child: EnvSettingLinkTrailing(value: value),
      ),
    );
  }
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
  Widget build(BuildContext context) => _SettingRow(
      title: title,
      subtitle: subtitle,
      small: small,
      trailing: ScheduleSwitch(
          value: value,
          color: context.glass.navSelected,
          onChanged: onChanged));
}

/// 알림 설정 한 행 — 제목·부제 + 오른쪽 [trailing]. [onTap]이 있으면 행 전체가
/// 눌린다(이동 행).
class _SettingRow extends StatelessWidget {
  const _SettingRow(
      {required this.title,
      required this.subtitle,
      required this.trailing,
      this.onTap,
      this.small = false});
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  /// 부제 12/500 행간 16 두 줄(마케팅 동의 일자).
  final bool small;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final radius = BorderRadius.circular(12);
    final content = Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                // 좁은 폰에서 어절 중간 줄바꿈("받는 알\n림") 대신 줄마다 한 줄을
                // 유지하고 공간이 모자랄 때만 축소한다(2026-09-18 사용자 결정).
                // 마케팅 동의 일자처럼 의도된 줄(\n)은 그대로 나눈다.
                // 줄 상자 높이는 고정 — 축소돼도 행 높이(원본 72)가 변하지 않게.
                for (final line in subtitle.split('\n'))
                  SizedBox(
                      height: small ? 16 : 16.7,
                      child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(line,
                              maxLines: 1,
                              softWrap: false,
                              style: managementStyle(context,
                                      size: small ? 12 : 14,
                                      color: glass.textTertiary)
                                  .copyWith(
                                      height: small ? 16 / 12 : 16.7 / 14)))),
              ])),
          // 원본 글줄 폭 251.5는 369 안에서 간격 4여야 한 줄로 들어간다.
          const SizedBox(width: 4),
          trailing,
        ]));
    return Material(
      color: glass.surfaceHeader,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, borderRadius: radius, child: content),
    );
  }
}

/// 기기(시스템) 알림이 꺼져 있다는 안내(2026-09-18 사용자 결정 — Figma 밖).
/// 앱 안 토글이 켜져 있어도 알림이 오지 않는 이유와 해결 버튼을 한곳에 둔다.
/// 버튼은 상태와 무관하게 "알림 허용" 하나(2026-09-18 사용자 결정): 시스템 팝업을
/// 띄울 수 있으면 띄우고, Android에서 두 번 거절로 막혔으면 앱 설정을 연다 —
/// "설정 열기"라고 쓰면 한 번만 거절한 경우 팝업이 떠 문구와 동작이 어긋난다.
class _SystemOffNotice extends StatelessWidget {
  const _SystemOffNotice({required this.onAllow});
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Container(
      key: NotificationSettingsScreen.systemOffKey,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
          color: glass.surfaceHeader, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('notif_settings_system_off_title'.tr(),
                    style: managementStyle(context,
                            weight: FontWeight.w600, color: glass.textPrimary)
                        .copyWith(height: 19.09 / 16)),
                const SizedBox(height: 4),
                Text('notif_settings_system_off_body'.tr(),
                    style: managementStyle(context,
                            size: 14, color: glass.textTertiary)
                        .copyWith(height: 16.7 / 14)),
              ]),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 36,
          child: FilledButton(
            key: const Key('notif_system_off_action'),
            onPressed: onAllow,
            style: FilledButton.styleFrom(
              backgroundColor: glass.navSelected,
              foregroundColor: ManagementColors.buttonForeground(context),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              textStyle:
                  managementStyle(context, size: 14, weight: FontWeight.w600),
            ),
            child: Text('notif_settings_system_off_allow'.tr(),
                maxLines: 1, softWrap: false),
          ),
        ),
      ]),
    );
  }
}
