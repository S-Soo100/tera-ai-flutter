import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/wallpaper_background.dart';
import '../domain/device_mode.dart';
import 'home_set_providers.dart';
import 'widgets/env_mini_chart.dart';
import 'widgets/home_header_bar.dart';
import 'widgets/home_sub_tabs_bar.dart';
import 'widgets/live_env_card.dart';
import 'widgets/device_offline_notice.dart';
import 'widgets/quick_control_grid.dart';
import 'widgets/running_timer_chip.dart';
import 'widgets/timeline_clip_feed.dart';
import 'widgets/timeline_date_scroller.dart';
import 'widgets/timeline_summary_chips.dart';
import 'widgets/top_fixed_area.dart';

/// PRD §2 홈 탭 와이어프레임 조립 + A안(Liquid Glass) 표면.
///
/// Header / TopFixedArea / SubTabsBar 는 고정이고 그 아래 컨테이너만 바뀐다.
/// **TopFixedArea가 서브탭 컨테이너 밖에 있는 것이 핵심**이다 — 안에 두면
/// 탭 전환 때 WebRtcLiveView가 dispose되어 재연결(수초)이 걸린다.
///
/// A안 표면 규칙(2026-08-13):
/// - 바닥은 [WallpaperBackground](월페이퍼), UI는 그 위 유리 레이어.
/// - **트리 전체를 [AppTheme.dark]로 감싼다.** 어두운 월페이퍼 위라 테마색을
///   읽는 기존 위젯(EnvSummaryBar·타임라인·오프라인 배너 등)이 다크 팔레트로
///   그려져야 읽힌다 — 위젯 내부는 건드리지 않고 주변 테마만 바꾼 것이다.
///   이 화면에서 띄우는 시트·다이얼로그도 같은 테마를 이어받는다(의도).
/// - `SafeArea(bottom: false)` — 콘텐츠가 플로팅 독 뒤로 스크롤되고,
///   스크롤 뷰가 `MediaQuery.padding.bottom`(독 높이)을 소비한다.
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

    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        backgroundColor: AppTheme.glassWallpaperTop,
        body: Stack(
          children: [
            const Positioned.fill(child: WallpaperBackground()),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  const HomeHeaderBar(),
                  // 라이브/프로필 면을 유리 카드 모양으로 — 내부(LiveSurface·
                  // 오버레이 슬롯)는 무변경, 감싸는 모서리·여백만 A안.
                  const Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: AppStyles.spacing16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(
                          Radius.circular(AppTheme.glassTileRadius)),
                      child: TopFixedArea(),
                    ),
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
            ),
          ],
        ),
      ),
    );
  }
}

/// PRD §3.4 사육장 제어 서브탭.
class _ControlContainer extends StatelessWidget {
  const _ControlContainer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        RunningTimerChip(),
        // 제어 타일이 왜 안 눌리는지 밝힌다. 맨 위에 둬야 회색 버튼을
        // 먼저 만나지 않는다.
        DeviceOfflineNotice(),
        LiveEnvCard(),
        EnvMiniChart(),
        QuickControlGrid(),
        SizedBox(height: AppStyles.spacing16),
        _RoutineSettingsButton(),
        SizedBox(height: AppStyles.spacing24),
      ],
    );
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
          child: SizedBox(
            height: AppStyles.spacing24 + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }
}
