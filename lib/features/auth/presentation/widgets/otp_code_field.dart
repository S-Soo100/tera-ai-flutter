import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 6자리 인증번호 입력(UX-03, 2026-10-01).
///
/// 실제 입력은 **보이지 않는 TextField 하나**로 받고, 6칸은 그 값을 그리기만
/// 한다. 그래서 메일에서 복사한 코드 전체 붙여넣기(길게 누르기 메뉴)와 OS
/// 인증번호 자동완성(`AutofillHints.oneTimeCode`)이 그대로 동작하고, 지우기는
/// 평범한 텍스트 삭제다. 칸 크기는 화면 폭에 맞춰 줄어든다(최대 48 — 폭
/// 320에서도 가로로 넘치지 않는다).
///
/// 6자리가 채워지면 [onCompleted]를 부른다 — 중복 호출 방지는 호출자 몫이다.
class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onCompleted,
    this.enabled = true,
    this.autofocus = true,
  });

  static const length = 6;
  static const fieldKey = Key('otp-code-input');

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String>? onCompleted;
  final bool enabled;
  final bool autofocus;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  // 상태는 없다 — 칸 그리기는 ListenableBuilder, 완료 알림만 리스너로 받는다.
  static const _gap = 8.0;
  static const _groupGap = 12.0; // 3-3 그룹 사이 추가 간격
  static const _maxBox = 48.0;

  @override
  void initState() {
    super.initState();
    _last = widget.controller.text;
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(OtpCodeField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  String _last = '';

  void _onChanged() {
    final text = widget.controller.text;
    if (text == _last) return;
    _last = text;
    if (text.length == OtpCodeField.length) widget.onCompleted?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return LayoutBuilder(builder: (context, constraints) {
      const gaps = _gap * (OtpCodeField.length - 1) + _groupGap;
      final box = ((constraints.maxWidth - gaps) / OtpCodeField.length)
          .clamp(24.0, _maxBox);
      final height = box + 8;

      Widget boxRow() {
        final text = widget.controller.text;
        final focused = widget.focusNode.hasFocus;
        final boxes = <Widget>[];
        for (var i = 0; i < OtpCodeField.length; i++) {
          if (i > 0) {
            boxes.add(SizedBox(width: i == 3 ? _gap + _groupGap : _gap));
          }
          final active = focused &&
              widget.enabled &&
              (i == text.length ||
                  (text.length == OtpCodeField.length &&
                      i == OtpCodeField.length - 1));
          boxes.add(Container(
            width: box,
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active ? cs.primary : cs.outline,
                width: active ? 2 : 1,
              ),
            ),
            child: Text(
              i < text.length ? text[i] : '',
              style: theme.textTheme.headlineSmall,
              // 칸 크기는 폭에 맞춰 정해져 글자만 커지면 넘친다 — 1.3배까지만.
              textScaler:
                  MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
            ),
          ));
        }

        return Row(
            mainAxisAlignment: MainAxisAlignment.center, children: boxes);
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.focusNode.requestFocus : null,
        child: Stack(alignment: Alignment.center, children: [
          ListenableBuilder(
            listenable: Listenable.merge([widget.controller, widget.focusNode]),
            builder: (context, _) => boxRow(),
          ),
          // 입력을 받는 진짜 칸 — 투명하게 행 전체를 덮어 길게 누르면
          // 붙여넣기 메뉴가 뜬다.
          Positioned.fill(
            child: Opacity(
              opacity: 0.01,
              child: TextField(
                key: OtpCodeField.fieldKey,
                controller: widget.controller,
                focusNode: widget.focusNode,
                enabled: widget.enabled,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                showCursor: false,
                enableSuggestions: false,
                autocorrect: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(OtpCodeField.length),
                ],
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ]),
      );
    });
  }
}
