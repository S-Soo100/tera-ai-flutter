import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// PRD §3.4 자동 루틴 & 타이머 설정 (풀스크린 모달).
///
/// 내용은 PRD가 "논의 필요"(Q2)로 남긴 구간이라 스펙 확정 후 별도 계획에서
/// 채운다. 지금은 버튼의 목적지가 존재한다는 것까지만 보장한다.
class RoutineSettingsScreen extends StatelessWidget {
  const RoutineSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('home_routine_settings'.tr())),
      body: Center(child: Text('home_routine_empty'.tr())),
    );
  }
}
