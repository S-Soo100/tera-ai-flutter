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
///
/// 등록 설정(`registrar`)은 넘기지 않는다 — 카메라 펌웨어가 `NAME:`/`JWT:`를
/// 아직 받지 않아(요청서 2026-09-17 §2-3) 앱 등록 경로가 없고, `UNPAIR`를 보내면
/// 플래시 때 개발 계정으로 된 등록만 지워질 수 있다. §2-3 배포 후 사육장처럼 연결.
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
