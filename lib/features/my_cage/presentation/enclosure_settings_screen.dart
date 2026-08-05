import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// PRD §3.1 사육장 설정. 지금은 기존 페어링 플로우로 가는 진입점만 제공한다
/// (세트 상세 설정 화면은 스펙 미비 — 후속).
class EnclosureSettingsScreen extends StatelessWidget {
  const EnclosureSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('home_enclosure_settings'.tr())),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: Text('enclosure_settings_add_device'.tr()),
            onTap: () => context.push('/smart-cage/devices/pair'),
          ),
          ListTile(
            leading: const Icon(Icons.videocam_outlined),
            title: Text('enclosure_settings_add_camera'.tr()),
            onTap: () => context.push('/crecam/cameras/pair'),
          ),
          ListTile(
            leading: const Icon(Icons.view_in_ar_outlined),
            title: Text('enclosure_settings_manage'.tr()),
            onTap: () => context.push('/smart-cage/enclosures'),
          ),
        ],
      ),
    );
  }
}
