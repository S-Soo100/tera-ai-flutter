import 'dart:async';

import 'package:flutter/material.dart';

import '../../../my_cage/presentation/widgets/clip_toast.dart';

/// 제어 결과 안내 — 루트 Navigator의 Overlay **맨 위**에 스낵바 모양으로 띄운다.
///
/// 제어 시트는 루트 모달이라 `ScaffoldMessenger` 스낵바가 시트 **뒤**(셸
/// Scaffold)에 그려져, 거절·미전달 안내와 분무 '실행 취소'가 보이지 않았다.
/// 유저는 스위치가 되돌아가는 것만 보고 같은 조작을 반복했다(2026-09-25 점검 —
/// 운영 busy 거절 대부분이 성공 0.7~2.4초 뒤 같은 명령). 시트가 닫혀도 같은
/// Overlay라 그대로 산다.
class ControlFeedback {
  const ControlFeedback(this.overlay);

  /// 시트·화면 어디서든 루트 Overlay를 잡는다.
  factory ControlFeedback.of(BuildContext context) =>
      ControlFeedback(Navigator.maybeOf(context, rootNavigator: true)?.overlay);

  final OverlayState? overlay;

  /// 떠 있는 안내를 닫는 함수 — 제거는 늘 그 안내의 close 한 곳으로만 한다.
  static VoidCallback? _closeCurrent;

  bool get mounted => overlay?.mounted ?? false;

  /// 한 번에 하나 — 새 안내가 이전 것을 대신한다. 반환값을 부르면 일찍 닫힌다.
  VoidCallback show(String text,
      {String? actionLabel,
      VoidCallback? onAction,
      Duration duration = const Duration(seconds: 4)}) {
    final o = overlay;
    if (o == null || !o.mounted) return () {};
    hideCurrent();
    late final OverlayEntry entry;
    var removed = false;
    late final VoidCallback close;
    // 새 안내가 이전 안내를 걷을 때도 이 close를 거친다 — 따로 remove하면
    // 호출부가 나중에 부르는 close가 같은 엔트리를 두 번 remove해 릴리스에서
    // 예외가 나고 호출부(분무 전송 등)가 중단됐다(2026-09-25 리뷰).
    close = () {
      if (removed) return;
      removed = true;
      if (identical(_closeCurrent, close)) _closeCurrent = null;
      entry.remove();
    };

    entry = OverlayEntry(
        builder: (_) => _FeedbackBar(
            text: text,
            duration: duration,
            onExpire: close,
            actionLabel: actionLabel,
            onAction: onAction == null
                ? null
                : () {
                    close();
                    onAction();
                  }));
    _closeCurrent = close;
    o.insert(entry);
    return close;
  }

  /// 완료 토스트(Figma 토스트 문법).
  void toast(String text, {String icon = 'redesign_v2/check'}) {
    final o = overlay;
    if (o == null || !o.mounted) return;
    showClipToastOn(o, text: text, icon: icon);
  }

  /// 떠 있는 안내를 걷는다.
  static void hideCurrent() => _closeCurrent?.call();
}

class _FeedbackBar extends StatefulWidget {
  const _FeedbackBar(
      {required this.text,
      required this.duration,
      required this.onExpire,
      this.actionLabel,
      this.onAction});

  final String text;
  final Duration duration;
  final VoidCallback onExpire;
  final String? actionLabel;
  final VoidCallback? onAction;

  static const barKey = Key('control_feedback_bar');

  @override
  State<_FeedbackBar> createState() => _FeedbackBarState();
}

class _FeedbackBarState extends State<_FeedbackBar> {
  // 위젯이 타이머를 쥔다 — 트리와 함께 정리돼 남는 타이머가 없다.
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, widget.onExpire);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final action = widget.actionLabel;
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom + 16,
      child: Material(
        key: _FeedbackBar.barKey,
        color: scheme.inverseSurface,
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 4, action == null ? 16 : 4, 4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(children: [
              Expanded(
                child: Text(widget.text,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: scheme.onInverseSurface)),
              ),
              if (action != null)
                TextButton(
                  onPressed: widget.onAction,
                  style: TextButton.styleFrom(
                      foregroundColor: scheme.inversePrimary),
                  child: Text(action),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
