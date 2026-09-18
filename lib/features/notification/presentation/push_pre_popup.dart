import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/glass_palette.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../my_cage/presentation/management_colors.dart';
import '../../my_cage/presentation/widgets/management_widgets.dart';
import '../../profile/data/notification_preferences_repository.dart';
import '../domain/push_consent_flow.dart';
import 'push_providers.dart';

/// 맥락 알림 프리팝업 흐름. 주제 on/off는 마이페이지 > 알림 토글과 같은 값이다.
final pushConsentFlowProvider = Provider<PushConsentFlow>((ref) {
  final preferences = ref.watch(pushPreferencesProvider);
  return PushConsentFlow(
    currentPermission: () => ref.read(pushMessagingProvider).getPermission(),
    requestPermission: ({bool retry = false}) => ref
        .read(pushLifecycleControllerProvider)
        .requestPermission(retry: retry),
    setTopic: (topic, on) {
      final prefs = ref.read(notificationPrefsProvider);
      return ref.read(notificationPrefsProvider.notifier).update(
          switch (topic) {
            PushTopic.highlight => prefs.copyWith(highlight: on),
            PushTopic.community => prefs.copyWith(comment: on, like: on),
          });
    },
    isAsked: (topic) => preferences.promptAsked(topic.name),
    markAsked: (topic) => preferences.markPromptAsked(topic.name),
  );
});

/// [topic]을 아직 안 물었으면 프리팝업을 띄우고 선택을 적용한다(주제별 1회).
/// 로그인 전이면 묻지 않는다. [context]는 살아 있는 Navigator 아래여야 한다.
Future<void> askPushConsent(
    BuildContext context, WidgetRef ref, PushTopic topic) async {
  if (ref.read(currentUserProvider) == null) return;
  await askPushConsentWith(context, ref.read(pushConsentFlowProvider), topic);
}

/// 호출 화면이 곧 닫히는 경우(게시물 작성 → 피드)용 — [flow]를 닫히기 전에
/// 받아 두고 루트 내비게이터 [context]로 띄운다. 로그인 여부는 호출자가 확인.
Future<void> askPushConsentWith(
    BuildContext context, PushConsentFlow flow, PushTopic topic) async {
  if (!flow.claim(topic)) return;
  final accept = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    useSafeArea: false,
    builder: (ctx) => _PushPrePopup(topic: topic),
  );
  // 뒤로 가기로 닫으면 답하지 않은 것 — 설정을 건드리지 않는다.
  if (accept == null) return;
  final optOut = await flow.resolve(topic, accept: accept);
  if (optOut && context.mounted) await showPushOptOutDone(context);
}

/// "수신 거부 완료" 안내(Figma 1179:4537).
Future<void> showPushOptOutDone(BuildContext context) => showDialog<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: false,
      builder: (ctx) => _VivaPopupFrame(
        key: const Key('push_optout_done'),
        title: 'push_optout_done_title'.tr(),
        body: 'push_optout_done_body'.tr(),
        buttons: [
          _PopupButton(
              key: const Key('push_optout_done_confirm'),
              label: 'common_confirm'.tr(),
              color: ctx.glass.textPrimary,
              onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );

/// 프리팝업(Figma 1179:4521 하이라이트 / 1179:4543 커뮤니티).
class _PushPrePopup extends StatelessWidget {
  const _PushPrePopup({required this.topic});
  final PushTopic topic;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return _VivaPopupFrame(
      key: Key('push_prepopup_${topic.name}'),
      title: 'push_prepopup_${topic.name}_title'.tr(),
      body: 'push_prepopup_${topic.name}_body'.tr(),
      buttons: [
        _PopupButton(
            key: const Key('push_prepopup_decline'),
            label: 'push_prepopup_decline'.tr(),
            color: glass.textPrimary,
            onPressed: () => Navigator.pop(context, false)),
        _PopupButton(
            key: const Key('push_prepopup_accept'),
            label: 'push_prepopup_accept'.tr(),
            color: glass.navSelected,
            onPressed: () => Navigator.pop(context, true)),
      ],
    );
  }
}

/// 흰 카드 345·r12·여백 24, 제목 20/700 + 간격 12 + 본문 18/500(행간 28,
/// 가운데), 간격 24 뒤 버튼 44·r12(두 개면 간격 12로 반씩).
class _VivaPopupFrame extends StatelessWidget {
  const _VivaPopupFrame(
      {super.key,
      required this.title,
      required this.body,
      required this.buttons});
  final String title;
  final String body;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    TextStyle text(double size, FontWeight weight) =>
        managementStyle(context,
                size: size, weight: weight, color: glass.textPrimary)
            .copyWith(height: 28 / size);
    return Dialog(
      backgroundColor: glass.surfaceHeader,
      surfaceTintColor: glass.surfaceHeader,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 345),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 제목은 Figma 줄 구성(\n) 그대로 줄마다 한 줄 — 전역 글자 확대(1.15)로
              // 넘치면 어절 중간("켜시겠습/니까?")에서 접는 대신 축소한다.
              for (final line in title.split('\n'))
                FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(line,
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        style: text(20, FontWeight.w700))),
              const SizedBox(height: 12),
              // 본문은 줄바꿈을 허용하되 어절 단위로만 접는다.
              Text(keepAllWords(body),
                  textAlign: TextAlign.center,
                  style: text(18, FontWeight.w500)),
              const SizedBox(height: 24),
              Row(children: [
                for (var i = 0; i < buttons.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: buttons[i]),
                ],
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopupButton extends StatelessWidget {
  const _PopupButton(
      {super.key,
      required this.label,
      required this.color,
      required this.onPressed});
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 44,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: ManagementColors.buttonForeground(context),
            padding: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: managementStyle(context, weight: FontWeight.w600)
                .copyWith(height: 28 / 16),
          ),
          child: Text(label, maxLines: 1, softWrap: false),
        ),
      );
}

/// 화면이 실제로 보일 때 한 번만 [topic]을 묻도록 post-frame으로 예약한다.
void schedulePushConsent(
    BuildContext context, WidgetRef ref, PushTopic topic) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) unawaited(askPushConsent(context, ref, topic));
  });
}

/// 한글 어절 안에서 줄이 바뀌지 않게(CSS `word-break: keep-all`) 글자 사이에
/// WORD JOINER(U+2060)를 넣는다. 공백·명시 줄바꿈에서만 접힌다.
String keepAllWords(String text) => text.splitMapJoin(RegExp(r'\s+'),
    onMatch: (m) => m[0]!, onNonMatch: (word) => word.split('').join('\u2060'));
