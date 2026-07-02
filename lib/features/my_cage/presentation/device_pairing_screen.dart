import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/pair_target_kind.dart';
import 'supabase_module_providers.dart';
import 'widgets/wifi_provisioning_view.dart';

/// 사육장 모듈 WiFi 프로비저닝 화면.
///
/// 실제 상태머신/UI는 [WifiProvisioningView]에 공통화되어 있고, 이 화면은
/// 사육장(`PairTargetKind.device`) 필터와 완료 후 처리(디바이스 목록 갱신)만
/// 지정한다.
class DevicePairingScreen extends ConsumerWidget {
  const DevicePairingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ble_pairing_title'.tr()),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SafeArea(
        child: WifiProvisioningView(
          kind: PairTargetKind.device,
          doneSubtitleKey: 'ble_done_subtitle',
          onProvisioned: () => ref.invalidate(deviceListProvider),
        ),
      ),
    );
  }
}
