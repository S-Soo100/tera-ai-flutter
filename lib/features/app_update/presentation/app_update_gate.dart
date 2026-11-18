import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/tab_branches.dart';
import '../../../shared/providers/external_url_launcher.dart';
import '../../../shared/widgets/viva_modal.dart';
import '../domain/app_update_state.dart';
import '../domain/update_policy.dart';
import 'app_update_providers.dart';

/// 업데이트 안내 진입점(`app.dart` builder). 화면을 덮지 않는다 — 강제는
/// 라우터 redirect(`/update-required`)가, 권장은 루트 Navigator 확인 창이 맡는다.
///
/// - 첫 비-스플래시 경로에서 한 번 확인한다.
/// - 복귀(resume)는 [AppUpdateNotifier.checkOnResume] 규칙(강제면 매번, 아니면 6시간).
/// - 권장이면 확인 창을 이 실행에서 `latest_build`마다 한 번 띄운다. [나중에]를
///   **직접** 눌렀을 때만 기억하고, 바깥 탭·자동 닫힘은 기억하지 않는다(다음
///   실행에 다시 뜬다). [업데이트]는 스토어만 연다.
/// - 강제로 바뀌면 열려 있던 권장 창을 닫는다.
class AppUpdateGate extends ConsumerStatefulWidget {
  const AppUpdateGate({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate> {
  AppLifecycleListener? _lifecycle;
  bool _started = false;

  /// 이 실행에서 권장 창을 띄운 `latest_build`.
  int? _shownFor;

  /// 떠 있는 권장 창을 닫는 신호. 창이 없으면 null.
  Completer<void>? _closeRecommended;

  String get _path => widget.router.routeInformationProvider.value.uri.path;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    widget.router.routeInformationProvider.addListener(_routeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _routeChanged());
  }

  void _routeChanged() {
    if (!mounted || _path == '/splash') return;
    if (!_started) {
      _started = true;
      unawaited(ref.read(appUpdateProvider.notifier).check());
    }
    _scheduleRecommended();
  }

  void _onResume() {
    if (!mounted || !_started) return;
    unawaited(ref.read(appUpdateProvider.notifier).checkOnResume());
  }

  /// 경로 변경·상태 변경 콜백 안에서 바로 창을 띄우지 않는다 — 새 페이지가
  /// 그려진 다음 프레임에.
  void _scheduleRecommended() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _showRecommended());

  Future<void> _showRecommended() async {
    if (!mounted || _closeRecommended != null) return;
    final update = ref.read(appUpdateProvider);
    final policy = update.policy;
    if (update.status != AppUpdateStatus.recommended || policy == null) return;
    if (_shownFor == policy.latestBuild) return;
    final path = _path;
    if (path == '/splash' || path == kUpdateRequiredPath) return;
    final navigatorContext =
        widget.router.routerDelegate.navigatorKey.currentContext;
    if (navigatorContext == null || !navigatorContext.mounted) return;

    _shownFor = policy.latestBuild;
    final close = Completer<void>();
    _closeRecommended = close;
    final version = policy.latestVersion;
    final result = await showVivaModalChoice(navigatorContext,
        message: 'app_update_recommended_title'.tr(),
        detail:
            version.isEmpty ? null : 'app_update_version'.tr(args: [version]),
        cancelLabel: 'app_update_later'.tr(),
        confirmLabel: 'app_update_action'.tr(),
        dismissOn: close.future);
    if (identical(_closeRecommended, close)) _closeRecommended = null;
    if (!mounted) return;
    switch (result) {
      case VivaModalResult.cancel:
        await ref.read(appUpdateProvider.notifier).dismissRecommended();
      case VivaModalResult.confirm:
        await _openStore(policy);
      case VivaModalResult.dismissed:
        break;
    }
  }

  Future<void> _openStore(UpdatePolicy policy) async {
    final uri = policy.storeUri;
    if (uri == null) return;
    final messenger = ScaffoldMessenger.maybeOf(
        widget.router.routerDelegate.navigatorKey.currentContext ?? context);
    final ok = await ref.read(externalUrlLauncherProvider)(uri);
    if (ok || !mounted) return;
    messenger
        ?.showSnackBar(SnackBar(content: Text('app_update_store_failed'.tr())));
  }

  void _closeOpenRecommended() {
    final close = _closeRecommended;
    _closeRecommended = null;
    if (close != null && !close.isCompleted) close.complete();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppUpdateState>(appUpdateProvider, (previous, next) {
      switch (next.status) {
        case AppUpdateStatus.required:
          _closeOpenRecommended();
        case AppUpdateStatus.recommended:
          _scheduleRecommended();
        case AppUpdateStatus.none:
          break;
      }
    });
    return widget.child;
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    widget.router.routeInformationProvider.removeListener(_routeChanged);
    _closeOpenRecommended();
    super.dispose();
  }
}
