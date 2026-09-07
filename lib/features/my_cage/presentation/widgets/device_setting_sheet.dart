import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../home/presentation/home_set_providers.dart';
import '../../domain/device.dart';

/// 사육장 설정 화면의 "현재 세트의 제어 기기에 묶인 설정" 진입 타일 공용 껍데기
/// (LCD 문구·목표 온습도가 쓴다 — 2026-08-18 리뷰 반영, 복제 통합).
///
/// 대상은 **홈이 보고 있는 세트의 기기**(`currentSetProvider.device`). 기기가
/// 없으면 탭을 막는 대신 이유를 subtitle로 밝힌다 — 회색 타일만 두면 고장으로
/// 읽힌다.
class DeviceSettingTile extends ConsumerWidget {
  const DeviceSettingTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;

  /// 제목. 기기가 없을 때도 불리므로 nullable — 기기명을 넣고 싶으면 여기서
  /// 조립한다.
  final String Function(Device? device) title;

  /// 기기가 있을 때의 부제. provider를 읽어야 하면 [ref]로 읽는다.
  final String Function(WidgetRef ref, Device device) subtitle;

  final void Function(BuildContext context, WidgetRef ref, Device device) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(currentSetProvider).valueOrNull?.device;
    return ListTile(
      leading: Icon(icon),
      title: Text(title(device)),
      subtitle: Text(
          device == null ? 'lcd_no_device'.tr() : subtitle(ref, device)),
      enabled: device != null,
      onTap: device == null ? null : () => onTap(context, ref, device),
    );
  }
}

/// 설정 시트 껍데기 — 세이프에어리어·키보드 여백·제목. 본문은 [children].
class DeviceSettingSheet extends StatelessWidget {
  const DeviceSettingSheet({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppStyles.spacing16,
          right: AppStyles.spacing16,
          top: AppStyles.spacing16,
          bottom:
              MediaQuery.of(context).viewInsets.bottom + AppStyles.spacing16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppStyles.subsectionTitle(context)),
            const SizedBox(height: AppStyles.spacing12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// 시트의 "보내고 닫기" 공통 꼬리. 성공이면 시트를 닫고 토스트, 실패면 시트를
/// **열어 둔 채** 실패 토스트(값을 다시 고칠 수 있게). 반환값은 성공 여부 —
/// 호출부는 실패 시 `_sending`을 풀어야 한다.
///
/// 메신저는 pop **전에** 잡는다 — 닫힌 시트의 context로는 못 찾는다.
Future<bool> submitAndClose(
  BuildContext context,
  Future<void> Function() run, {
  required String successKey,
  required String failureKey,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await run();
    if (!context.mounted) return true;
    Navigator.of(context).pop();
    messenger?.showSnackBar(SnackBar(content: Text(successKey.tr())));
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    messenger?.showSnackBar(
        SnackBar(content: Text(failureKey.tr(args: ['$e']))));
    return false;
  }
}
