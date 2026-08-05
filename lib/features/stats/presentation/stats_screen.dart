import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// 통계 탭. PRD §3.4 "차트 터치 시 통계 탭으로 이동"의 목적지.
///
/// 내용(온습도 일/주 그래프, 크레 활동 통계·분석)은 PRD 기능요약 수준까지만
/// 정의되어 별도 계획서에서 다룬다. 여기서는 탭이 존재하고 이동이 성립하는
/// 것까지만 보장한다.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('tab_stats'.tr())),
      body: Center(child: Text('stats_empty'.tr())),
    );
  }
}
