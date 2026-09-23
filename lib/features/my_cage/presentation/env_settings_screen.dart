import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/glass_page_shell.dart';
import 'widgets/camera_rotate_tile.dart';
import 'widgets/setpoint_setting_tile.dart';

/// 환경설정 — 현재 세트의 기기·카메라에 묶인 **설정**만 모은 화면
/// (2026-09-08 사용자 결정: 사육장 설정에서 연동과 설정을 분리).
///
/// 연동(개체 배정·페어링·사육장 관리)은 `EnclosureSettingsScreen`
/// ("사육장 연동", `[+]` 메뉴)에 남는다. 진입점은 홈 헤더 ⚙️ 하나.
/// 새 기기/카메라 설정이 생기면 여기로 — `DeviceSettingTile` 문법을 따를 것.
class EnvSettingsScreen extends StatelessWidget {
  const EnvSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassPageShell(
      child: Scaffold(
        appBar: AppBar(title: Text('home_env_settings'.tr())),
        body: ListView(
          children: const [
            SetpointSettingTile(),
            // capabilities 미보고(구 펌웨어)·카메라 없음이면 자체적으로 숨는다.
            CameraRotateTile(),
          ],
        ),
      ),
    );
  }
}
