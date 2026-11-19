import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/viva_check_row.dart';
import '../../../../shared/widgets/viva_modal.dart';
import '../../../notification/presentation/live_notice_providers.dart';
import '../../../notification/presentation/notification_providers.dart';
import '../../domain/device_add_flow.dart';
import '../../domain/pair_target_kind.dart';
import '../my_cage_providers.dart';

/// 카메라 신호 약함 안내 끄기(`cameras.weak_signal_notice_off_at`) — 테스트 교체용.
final weakSignalNoticeOffWriterProvider =
    Provider<Future<void> Function(String cameraId)>(
        (ref) => ref.watch(cameraRepositoryProvider).turnOffWeakSignalNotice);

/// 카메라 네트워크 신호 약함 모달(Figma 2020:11196 — 2026-11-19 막대에서 바뀜,
/// 서버 `docs/APP_CAMERA_WEAK_SIGNAL_2026-11-13.md`).
///
/// 자리는 차지하지 않는다(크기 0). 이 카메라([cameraId])에 아직 띄우지 않은
/// 미읽음 `camera.weak_signal` 안내가 있고, 이 화면이 보이며(탭이 앞·위에 다른
/// 화면이나 창이 없음) 있으면 모달을 한 번 띄운다 — 영상 상태와는 상관없다
/// (사용자 결정: 신호가 약해 라이브가 실패하는 사용자에게 더 필요하다).
///
/// - [닫기]·바깥 탭: 읽음 처리. 서버가 24시간에 1회만 넣으므로 하루 최대 한 번.
/// - [변경]: 읽음 처리 + 그 카메라 Wi-Fi 바꾸기(`/devices/wifi`). Figma의
///   "네트워크 관리" 흐름이 생기면 그쪽으로 바꾼다(2026-11-19 사용자 결정).
/// - "알림 다시 보지 않기"를 고르고 닫으면(어느 버튼이든) 그 카메라 안내를 끈다.
///   다시 켜는 메뉴는 없다(사용자 결정 — 재등록하면 서버가 초기화).
class WeakSignalNoticePrompt extends ConsumerStatefulWidget {
  const WeakSignalNoticePrompt({
    super.key,
    required this.cameraId,
    required this.deviceId,
    required this.cameraName,
  });

  /// `cameras.id`(uuid).
  final String cameraId;

  /// 기기 ID(`cameras.camera_id`).
  final String deviceId;
  final String cameraName;

  static const checkKey = Key('weak_signal_dont_show');

  /// 화면이 가려져 있을 때 다시 볼 간격.
  static const retryEvery = Duration(seconds: 2);

  @override
  ConsumerState<WeakSignalNoticePrompt> createState() =>
      _WeakSignalNoticePromptState();
}

class _WeakSignalNoticePromptState
    extends ConsumerState<WeakSignalNoticePrompt> {
  Timer? _retry;

  LiveNoticeCamera get _camera =>
      (id: widget.cameraId, deviceId: widget.deviceId);

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

  void _schedule() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybePrompt();
      });

  Future<void> _maybePrompt() async {
    final ids = ref.read(weakSignalNoticeIdsProvider(_camera));
    if (ids.isEmpty) return;
    // 다른 탭(TickerMode 꺼짐)·위에 다른 화면이나 창이 있으면 기다린다 — 다른
    // 창 위에 겹쳐 뜨지 않게.
    final visible = TickerMode.of(context) &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (!visible) {
      _retry ??= Timer(WeakSignalNoticePrompt.retryEvery, () {
        _retry = null;
        if (mounted) _maybePrompt();
      });
      return;
    }
    // 띄우기 전에 표시해 둬야 다른 자리(홈·카메라 탭)가 같은 안내를 또 띄우지 않는다.
    final prompted = ref.read(weakSignalPromptedProvider.notifier);
    prompted.state = {...prompted.state, ...ids};

    // 화면이 닫혀도 저장은 끝까지 한다 — 창을 띄우기 전에 꺼내 둔다.
    final repo = ref.read(notificationRepositoryProvider);
    final writer = ref.read(weakSignalNoticeOffWriterProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final dontShow = ValueNotifier(false);
    final glass = context.glass;
    final result = await showVivaModalChoice(
      context,
      message: 'camera_weak_signal_modal'.tr(),
      cancelLabel: 'weak_wifi_close'.tr(),
      confirmLabel: 'camera_weak_signal_change'.tr(),
      confirmColor: glass.selectionOn,
      footer: Align(
        alignment: Alignment.centerLeft,
        child: ValueListenableBuilder<bool>(
          valueListenable: dontShow,
          builder: (_, value, __) => VivaCheckRow(
              key: WeakSignalNoticePrompt.checkKey,
              label: 'camera_weak_signal_dont_show'.tr(),
              value: value,
              onChanged: (v) => dontShow.value = v),
        ),
      ),
    );
    final turnOff = dontShow.value;
    dontShow.dispose();

    if (result == VivaModalResult.confirm && mounted) {
      unawaited(context.push('/devices/wifi',
          extra: WifiChangeTarget(
              kind: PairTargetKind.camera,
              id: widget.cameraId,
              name: widget.cameraName)));
    }
    await Future.wait([
      for (final id in ids)
        repo.markRead(id).catchError((Object e) {
          // 이번 실행에선 다시 띄우지 않는다(weakSignalPromptedProvider).
          debugPrint('[weak-signal] markRead failed id=$id $e');
        }),
      if (turnOff)
        writer(widget.cameraId).catchError((Object e) {
          debugPrint('[weak-signal] turn off failed camera=${widget.cameraId} $e');
          messenger?.showSnackBar(SnackBar(
              content: Text('camera_weak_signal_off_failed'.tr())));
        }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final ids = ref.watch(weakSignalNoticeIdsProvider(_camera));
    // 탭 전환(TickerMode)에도 다시 본다.
    TickerMode.of(context);
    if (ids.isNotEmpty) _schedule();
    return const SizedBox.shrink();
  }
}
