import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/tab_branches.dart';
import '../../../shared/services/local_notifications.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../home/presentation/home_set_providers.dart';
import '../data/push_messaging_service.dart';
import '../domain/local_notification_target.dart';
import '../domain/local_tap_router.dart';
import '../domain/push_lifecycle_controller.dart';
import 'push_providers.dart';

/// 푸시·로컬 알림 수명 관리. 로컬 알림 탭 연결은 FCM 지원 여부와 따로 한다
/// (2026-11-16) — FCM이 꺼진 기기(설정 파일 없는 iOS 등)에서도 예약·팬 타이머
/// 알림을 누르면 해당 화면으로 가야 한다. FCM 시작·계정 연결은 지원 기기만.
class PushLifecycleObserver extends ConsumerStatefulWidget {
  const PushLifecycleObserver(
      {super.key, required this.child, required this.router});
  final Widget child;
  final GoRouter router;
  @override
  ConsumerState<PushLifecycleObserver> createState() =>
      _PushLifecycleObserverState();
}

class _PushLifecycleObserverState extends ConsumerState<PushLifecycleObserver> {
  AppLifecycleListener? _lifecycle;
  PushLifecycleController? _controller;
  late final LocalTapRouter _localTaps;
  bool _starting = false;
  bool _localReady = false;
  bool _tapAttached = false;
  bool _ready = false;
  String? _lastUser;

  String get _path => widget.router.routeInformationProvider.value.uri.path;

  /// 지금 맨 위 화면. 주소(`routeInformationProvider`)는 `push`를 반영하지
  /// 않아(go_router `optionURLReflectsImperativeAPIs` 기본 false) 예약 화면을
  /// 열어도 `/home`으로 남는다 — 알림 탭 판단은 실제 화면 스택으로 한다.
  /// 첫 경로를 읽기 전(스택 비어 있음)은 스플래시로 본다.
  String get _topPath =>
      widget.router.routerDelegate.currentConfiguration.lastOrNull
          ?.matchedLocation ??
      '/splash';

  @override
  void initState() {
    super.initState();
    _localTaps = LocalTapRouter(
      currentUserId: () => ref.read(currentUserProvider)?.id,
      currentPath: () => _topPath,
      myDeviceIds: () => ref.read(notificationDeviceIdsProvider)(),
      select: (id) =>
          ref.read(selectedHomeDeviceIdProvider.notifier).state = id,
      open: _openLocal,
    );
    _lifecycle = AppLifecycleListener(
        onResume: () => unawaited(_synchronize(resume: true)));
    widget.router.routeInformationProvider.addListener(_routeChanged);
    // 보관한 알림 탭은 화면 스택이 실제로 바뀐 뒤에 본다 — 주소 알림은 스택
    // 갱신보다 먼저 올 수 있다(로그인 직후 아직 /login인 스택으로 판단).
    widget.router.routerDelegate.addListener(_flushLocalTaps);
    WidgetsBinding.instance.addPostFrameCallback((_) => _routeChanged());
  }

  void _routeChanged() => unawaited(_synchronize());

  void _flushLocalTaps() {
    if (!mounted) return;
    unawaited(_localTaps.flush().catchError((Object _) {
      debugPrint('[push] local tap open failed');
    }));
  }

  Future<void> _synchronize({bool resume = false}) async {
    if (!mounted || _starting || _path == '/splash') return;
    final messaging = ref.read(pushMessagingProvider);
    final supported = messaging.supported;
    if (!_localReady || (supported && !_ready)) {
      _starting = true;
      try {
        if (!_localReady) {
          // JSON(앱 사용 중 다시 띄운 서버 푸시) 탭이 시작 전에 와도 컨트롤러로
          // 가도록 먼저 잡아 둔다 — FCM이 꺼져 있으면 만들지 않는다.
          if (supported) {
            _controller ??= ref.read(pushLifecycleControllerProvider);
          }
          final core = LocalNotifications.instance;
          core.onTap = _localTap;
          _tapAttached = true;
          try {
            await core.ensureInitialized();
            if (!mounted) return;
            await core.deliverInitialTap();
          } catch (_) {
            debugPrint('[push] local initialization failed');
          }
          if (!mounted) return;
          _localReady = true;
        }
        if (!supported) return;
        final PushLifecycleController controller =
            _controller ?? ref.read(pushLifecycleControllerProvider);
        _controller = controller;
        if (!_ready) {
          await controller.start();
          if (!mounted) return;
          _ready = true;
        }
      } finally {
        _starting = false;
      }
    }
    if (!mounted || !supported) return;
    final userId = ref.read(currentUserProvider)?.id;
    if (_lastUser != userId || !_ready || resume || userId == null) {
      _lastUser = userId;
      await _controller?.setUser(userId);
    }
  }

  void _localTap(String payload) {
    if (!mounted) return;
    switch (parseLocalNotificationPayload(payload)) {
      case DeviceNotificationTarget target:
        // 보관 — 로그인·스플래시·강제 업데이트가 끝난 뒤 처리된다.
        _localTaps.hold(target);
        _flushLocalTaps();
      case PushNotificationTarget target:
        unawaited(_controller
            ?.open(PushMessage(
                notificationId: target.notificationId,
                kind: target.kind,
                route: target.route))
            .catchError((Object _) {
          debugPrint('[push] local tap failed');
        }));
      case null:
        debugPrint('[push] ignored invalid local payload');
    }
  }

  /// 같은 경로면 그대로 둔다(선택만 바뀐다). 탭 경로(`/home`)는 `go` — 탭은
  /// `StatefulShellRoute` 브랜치라 다른 화면 위에 `push`하면 셸이 하나 더
  /// 쌓인다. 앱도 탭으로 갈 때는 늘 `go`를 쓴다(스플래시·로그인·기기 추가).
  /// 예약 화면은 셸 밖 최상위 라우트라 서버 푸시 이동과 같이 `push` — 뒤로
  /// 가면 보던 화면으로 돌아간다.
  void _openLocal(String route) {
    if (!mounted || _topPath == route) return;
    if (kHomeTabPaths.contains(route)) {
      widget.router.go(route);
    } else {
      unawaited(widget.router.push<void>(route));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserProvider.select((u) => u?.id), (_, userId) {
      // 로그인 직후 경로가 이미 일반 화면이면 보관한 알림 탭을 처리한다(대개는
      // redirect로 경로가 바뀔 때 처리된다).
      WidgetsBinding.instance.addPostFrameCallback((_) => _flushLocalTaps());
      final controller = _controller;
      if (_ready && controller != null) {
        // Forward observed auth changes without another frame delay. The
        // controller also rotates transport when Riverpod coalesces A→null→B.
        _lastUser = userId;
        unawaited(controller.setUser(userId));
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => _routeChanged());
      }
    });
    return widget.child;
  }

  @override
  void dispose() {
    _localTaps.dispose();
    _lifecycle?.dispose();
    widget.router.routeInformationProvider.removeListener(_routeChanged);
    widget.router.routerDelegate.removeListener(_flushLocalTaps);
    if (_tapAttached) LocalNotifications.instance.onTap = null;
    if (_controller != null) unawaited(_controller!.dispose());
    super.dispose();
  }
}
