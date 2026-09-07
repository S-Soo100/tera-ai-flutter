import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/glass_page_shell.dart';

/// PRD §3.1 알림 센터. 카테고리(긴급/안전, 제어/동작 결과, 주간 AI 리포트,
/// 마케팅/혜택)는 정의됐으나 데이터 소스가 없어 목록은 후속 계획에서 채운다.
class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // A안 경량 전환 — 배경·표면 톤만 유리 문법으로.
    return GlassPageShell(
      child: Scaffold(
        appBar: AppBar(title: Text('home_notifications'.tr())),
        body: Center(child: Text('notifications_empty'.tr())),
      ),
    );
  }
}
