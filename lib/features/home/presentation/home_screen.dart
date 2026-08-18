import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_dock.dart';
import '../../../shared/widgets/glass_tab_shell.dart';
import '../domain/device_mode.dart';
import 'home_set_providers.dart';
import 'widgets/hourly_env_strip.dart';
import 'widgets/home_header_bar.dart';
import 'widgets/home_sub_tabs_bar.dart';
import 'widgets/live_env_card.dart';
import 'widgets/device_offline_notice.dart';
import 'widgets/quick_control_grid.dart';
import 'widgets/running_timer_chip.dart';
import 'widgets/timeline_clip_feed.dart';
import 'widgets/timeline_date_scroller.dart';
import 'widgets/timeline_summary_chips.dart';
import 'widgets/tonight_card.dart';
import 'widgets/top_fixed_area.dart';
import 'widgets/weekly_env_rows_card.dart';

/// PRD §2 홈 탭 와이어프레임 조립 + A안(Liquid Glass) 표면.
///
/// Header / TopFixedArea / SubTabsBar 는 고정이고 그 아래 컨테이너만 바뀐다.
/// **TopFixedArea가 서브탭 컨테이너 밖에 있는 것이 핵심**이다 — 안에 두면
/// 탭 전환 때 WebRtcLiveView가 dispose되어 재연결(수초)이 걸린다.
///
/// A안 표면 규칙(월페이퍼·전역 다크·SafeArea)은 [GlassTabShell]이 맡는다.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// 한 번이라도 연 서브탭. 여기 들어온 뒤에야 IndexedStack에 실물이 올라간다.
  ///
  /// IndexedStack은 자식을 **전부** 빌드하므로, 그냥 두면 사육장 제어만 쓰는
  /// 사용자도 홈에 들어올 때마다 타임라인이 motion_clips를 조회하고 클립마다
  /// presigned 썸네일 URL을 요청한다. 첫 방문 전까지 빈 자리표시자를 넣어
  /// 그 비용을 미룬다. 한 번 방문한 뒤에는 계속 살려둬 스크롤·필터 상태를
  /// 보존한다(원래 IndexedStack을 쓴 이유).
  late final Set<HomeSubTab> _visited = {ref.read(homeSubTabProvider)};

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(homeSubTabProvider);
    _visited.add(tab);

    return GlassTabShell(
      child: Column(
        children: [
          const HomeHeaderBar(),
          // 라이브/프로필 면은 **풀블리드**다(A안 2차, 2026-08-14) — 좌우 여백 0,
          // 헤더 바로 아래에서 시작해 화면 폭을 다 쓴다. 카메라가 홈의
          // 주인공이라 카드 한 장으로 가두지 않는다. 내부(LiveSurface·
          // 오버레이 슬롯)는 무변경, 아래 모서리만 둥글려 뒤 콘텐츠와 잇는다.
          const ClipRRect(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(AppTheme.glassTileRadius),
            ),
            child: TopFixedArea(),
          ),
          const SizedBox(height: AppStyles.spacing12),
          const HomeSubTabsBar(),
          Expanded(
            child: IndexedStack(
              index: tab == HomeSubTab.control ? 0 : 1,
              children: [
                if (_visited.contains(HomeSubTab.control))
                  const _ControlContainer()
                else
                  const SizedBox.shrink(),
                if (_visited.contains(HomeSubTab.timeline))
                  const _TimelineContainer()
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// PRD §3.4 사육장 제어 서브탭 — B안(Flighty) 카드 순서(2026-08-18).
///
/// 오늘 밤(주인공) → 온습도 행(지난 24시간·이번 주) → CONTROLS 캡슐 행 → 루틴.
/// 현재값 리드아웃은 라이브 위 전광판 오버레이([LiveStatOverlay])로 올라갔다
/// — 캠 없는 세트만 아래 카드([_EnvReadoutFallback])로 남는다.
class _ControlContainer extends StatelessWidget {
  const _ControlContainer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        RunningTimerChip(),
        // 제어 캡슐이 왜 안 눌리는지 밝힌다. 맨 위에 둬야 회색 버튼을
        // 먼저 만나지 않는다.
        DeviceOfflineNotice(),
        _EnvReadoutFallback(),
        TonightCard(),
        // 애플 날씨 문법(2026-08-17): 시간대 스트립 + 이번 주 7행. 통계 탭의
        // 연속 곡선과 일부러 다르다 — 홈은 훑는 자리다.
        HourlyEnvStrip(),
        WeeklyEnvRowsCard(),
        QuickControlGrid(),
        SizedBox(height: AppStyles.spacing8),
        _RoutineSettingsButton(),
        SizedBox(height: AppStyles.spacing24),
      ],
    );
  }
}

/// 상단이 **개체 프로필 면**(캠 없는 세트)일 때만 현재값 카드를 남긴다.
///
/// 라이브가 있으면 같은 숫자가 영상 위 오버레이에 이미 있다 — 두 번 보여주지
/// 않는다. 분기 조건은 [TopFixedArea]와 같은 `camera == null`이다.
class _EnvReadoutFallback extends ConsumerWidget {
  const _EnvReadoutFallback();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCamera =
        ref.watch(currentSetProvider).valueOrNull?.camera != null;
    if (hasCamera) return const SizedBox.shrink();
    return const LiveEnvCard();
  }
}

/// PRD §3.4 `[자동 루틴 & 타이머 설정 >]` 풀스크린 모달 호출 버튼.
/// 모달 내용은 PRD Q2("논의 필요")라 이 계획 범위 밖 — 버튼과 이동만 만든다.
class _RoutineSettingsButton extends StatelessWidget {
  const _RoutineSettingsButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
      child: OutlinedButton.icon(
        icon: const Icon(Icons.settings_outlined, size: 18),
        label: Text('home_routine_settings'.tr()),
        onPressed: () => context.push('/home/routines'),
      ),
    );
  }
}

/// PRD §3.5 타임라인 서브탭.
class _TimelineContainer extends StatelessWidget {
  const _TimelineContainer();

  @override
  Widget build(BuildContext context) {
    // CustomScrollView인 이유: 클립 피드가 sliver라 화면에 보이는 행만 빌드된다.
    // ListView + shrinkWrap이면 클립 전량이 즉시 만들어져 썸네일 요청이 폭주한다.
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: TimelineSummaryChips()),
        const SliverToBoxAdapter(child: TimelineDateScroller()),
        const TimelineClipFeed(),
        // CustomScrollView는 ListView와 달리 MediaQuery 패딩을 자동 소비하지
        // 않는다 — 플로팅 독 높이만큼 직접 비워야 마지막 클립이 안 가려진다.
        SliverToBoxAdapter(
          child: SizedBox(height: glassDockListPadding(context).bottom),
        ),
      ],
    );
  }
}
