import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/pair_target_kind.dart';
import 'my_cage_providers.dart';
import 'widgets/wifi_provisioning_view.dart';

/// 게코캠 카메라 WiFi 프로비저닝 화면.
///
/// [DevicePairingScreen]과 동일한 [WifiProvisioningView]를 재사용하되,
/// 카메라(`PairTargetKind.camera`) 필터와 완료 후 카메라 목록 갱신만 지정한다.
class CameraPairingScreen extends ConsumerWidget {
  const CameraPairingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('camera_pairing_title'.tr()),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SafeArea(
        child: WifiProvisioningView(
          kind: PairTargetKind.camera,
          doneSubtitleKey: 'camera_done_subtitle',
          onProvisioned: () => ref.invalidate(camerasProvider),
        ),
      ),
    );
  }
}
