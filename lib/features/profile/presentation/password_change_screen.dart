import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/figma_icon.dart';
import '../../../shared/widgets/viva_modal.dart';
import '../../../shared/widgets/viva_text_field.dart';
import '../../auth/data/auth_repository.dart';
import 'widgets/my_page_widgets.dart';

/// 비밀번호 변경(Figma MyAcc_pwchange 1134:7865 / 7996 / 8076 / 8146).
/// 현재 → (40) → 새로운 → (24) → 확인. 세 칸이 차야 "변경"이 켜진다.
/// 새 비밀번호 규칙(영문+숫자+특수문자 6~12자) 미충족은 두 칸 빨간 테두리 +
/// 규칙 문구, 확인 불일치·현재 불일치는 모달.
class PasswordChangeScreen extends ConsumerStatefulWidget {
  const PasswordChangeScreen({super.key});

  static const currentKey = Key('pw_change_current');
  static const newKey = Key('pw_change_new');
  static const confirmKey = Key('pw_change_confirm');
  static const submitKey = Key('pw_change_submit');

  /// 영문·숫자·특수문자를 모두 포함한 6~12자.
  static bool meetsRule(String v) =>
      v.length >= 6 &&
      v.length <= 12 &&
      RegExp(r'[A-Za-z]').hasMatch(v) &&
      RegExp(r'[0-9]').hasMatch(v) &&
      RegExp(r'[^A-Za-z0-9]').hasMatch(v);

  @override
  ConsumerState<PasswordChangeScreen> createState() =>
      _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends ConsumerState<PasswordChangeScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final _show = <Key, bool>{};
  String? _ruleError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_current, _next, _confirm]) {
      c.addListener(() => setState(() => _ruleError = null));
    }
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _filled =>
      _current.text.isNotEmpty &&
      _next.text.isNotEmpty &&
      _confirm.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_filled || _busy) return;
    if (!PasswordChangeScreen.meetsRule(_next.text)) {
      setState(() => _ruleError = 'pw_change_rule'.tr());
      return;
    }
    if (_next.text != _confirm.text) {
      await showVivaModal(context, message: 'pw_change_confirm_mismatch'.tr());
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(current: _current.text, next: _next.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('pw_change_done'.tr())));
      Navigator.of(context).maybePop();
    } on AuthException catch (e) {
      if (!mounted) return;
      final wrongCurrent = e.statusCode == '400' ||
          e.message.toLowerCase().contains('invalid login credentials');
      await showVivaModal(context,
          message: (wrongCurrent ? 'pw_change_current_mismatch' : 'pw_change_failed')
              .tr());
    } catch (_) {
      if (!mounted) return;
      await showVivaModal(context, message: 'pw_change_failed'.tr());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _eye(Key key) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _show[key] = !(_show[key] ?? false)),
      child: FigmaIcon.tinted(
          (_show[key] ?? false)
              ? 'redesign_v2/visibility_off'
              : 'redesign_v2/visibility',
          size: 24,
          color: context.glass.deviceOff));

  @override
  Widget build(BuildContext context) => MyPageScaffold(
        title: 'pw_change_title'.tr(),
        floating: MyPageCta(
            key: PasswordChangeScreen.submitKey,
            label: 'pw_change_submit'.tr(),
            onPressed: _filled && !_busy ? _submit : null),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          VivaTextField(
              fieldKey: PasswordChangeScreen.currentKey,
              label: 'pw_change_current'.tr(),
              controller: _current,
              obscureText: !(_show[PasswordChangeScreen.currentKey] ?? false),
              suffix: _eye(PasswordChangeScreen.currentKey),
              textInputAction: TextInputAction.next,
              gapBelow: 40),
          VivaTextField(
              fieldKey: PasswordChangeScreen.newKey,
              label: 'pw_change_new'.tr(),
              controller: _next,
              hintText: 'pw_change_rule'.tr(),
              errorText: _ruleError,
              obscureText: !(_show[PasswordChangeScreen.newKey] ?? false),
              suffix: _eye(PasswordChangeScreen.newKey),
              textInputAction: TextInputAction.next),
          VivaTextField(
              fieldKey: PasswordChangeScreen.confirmKey,
              label: 'pw_change_confirm'.tr(),
              controller: _confirm,
              hintText: 'pw_change_rule'.tr(),
              errorText: _ruleError,
              obscureText: !(_show[PasswordChangeScreen.confirmKey] ?? false),
              suffix: _eye(PasswordChangeScreen.confirmKey),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              gapBelow: 0),
        ]),
      );
}
