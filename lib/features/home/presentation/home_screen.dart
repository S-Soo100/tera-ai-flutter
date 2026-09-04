import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/glass_dock.dart';
import '../../../shared/widgets/glass_tab_shell.dart';
import 'widgets/cage_control_grid.dart';
import 'widgets/device_offline_notice.dart';
import 'widgets/env_summary_card.dart';
import 'widgets/home_header_bar.dart';
import 'widgets/running_timer_chip.dart';
import 'widgets/top_fixed_area.dart';

/// 홈 탭 — Figma `vivanaut app` Home (668:833) **단일 스크롤**.
///
/// PRD 재설계 1단계(2026-09-02, §4.1): 서브탭·타임라인·개체 프로필 분기 폐기.
/// 위→아래(마진 12, 섹션 간격 12):
/// 헤더(44) → 라이브(369×271) → 온습도 요약 카드(탭→`/env-detail`) →
/// 제어 그리드 5타일 → 일정 설정.
///
/// 스크롤은 [SingleChildScrollView] + Column이다 — ListView는 스크롤 아웃된
/// 자식을 dispose하는데, 최상단 라이브([TopFixedArea]/WebRtcLiveView)가
/// dispose되면 재연결(수초)이 걸린다. 홈 콘텐츠는 한 화면 남짓이라 전체
/// keep-alive 비용이 없다.
///
/// [RunningTimerChip]·[DeviceOfflineNotice]는 **그리드 위**에 남긴다 — 타이머
/// 진행·오프라인 사유 고지는 안전 기능이다(회색 버튼만 두면 고장으로 읽힌다).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const scheduleRowKey = Key('home_schedule_row');

  /// Figma A.4 좌우 마진·섹션 간격.
  static const double _margin = 12;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    return GlassTabShell(
      child: Column(
        children: [
          const Padding(
            // top 0 — Figma 668:833은 헤더가 status bar 바로 아래 선다
            // (Frame 56 y=62 = status bar 끝, 추가 여백 없음).
            padding: EdgeInsets.fromLTRB(_margin, 0, _margin, _gap),
            child: HomeHeaderBar(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                // 플로팅 독 높이만큼 비워야 마지막 섹션이 안 가려진다.
                bottom: glassDockListPadding(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: _margin),
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      child: TopFixedArea(),
                    ),
                  ),
                  const SizedBox(height: _gap),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: _margin),
                    child: EnvSummaryCard(),
                  ),
                  const SizedBox(height: _gap),
                  // 칩·오프라인 고지는 자체 패딩(16)을 가진 기존 위젯 그대로다.
                  const RunningTimerChip(),
                  const DeviceOfflineNotice(),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: _margin),
                    child: CageControlGrid(),
                  ),
                  // Figma 실측 22 — 그리드끝(634)→일정 로우(683) 49에서
                  // 라벨 19·라벨-로우 갭 8을 뺀 값.
                  const SizedBox(height: 22),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: _margin),
                    child: _ScheduleSection(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 일정 설정 — Figma A.4 ⑤ (라벨 14 Medium + 로우 h51 surfaceTint radius 12).
class _ScheduleSection extends StatelessWidget {
  const _ScheduleSection();

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'home_schedule_settings'.tr(),
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 14 * -0.02,
            color: glass.textTertiary,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: glass.surfaceTint,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: HomeScreen.scheduleRowKey,
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push('/home/routines'),
            child: SizedBox(
              height: 51,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'home_routine_settings'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 16 * -0.02,
                          color: glass.textSecondary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: glass.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
