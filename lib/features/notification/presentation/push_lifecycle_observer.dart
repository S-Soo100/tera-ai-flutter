import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/local_notifications.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/push_messaging_service.dart';
import '../domain/push_lifecycle_controller.dart';
import 'push_providers.dart';

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
  bool _starting = false;
  bool _ready = false;
  String? _lastUser;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
        onResume: () => unawaited(_synchronize(resume: true)));
    widget.router.routeInformationProvider.addListener(_routeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _routeChanged());
  }

  void _routeChanged() => unawaited(_synchronize());

  Future<void> _synchronize({bool resume = false}) async {
    if (!mounted ||
        _starting ||
        widget.router.routeInformationProvider.value.uri.path == '/splash') {
      return;
    }
    final messaging = ref.read(pushMessagingProvider);
    if (!messaging.supported) return;
    if (!_ready) {
      _starting = true;
      final controller = ref.read(pushLifecycleControllerProvider);
      _controller = controller;
      try {
        final core = LocalNotifications.instance;
        core.onTap = _localTap;
        try {
          await core.ensureInitialized();
          if (!mounted) return;
          await core.deliverInitialTap();
        } catch (_) {
          debugPrint('[push] local initialization failed');
        }
        if (!mounted) return;
        await controller.start();
        if (!mounted) return;
        _ready = true;
      } finally {
        _starting = false;
      }
    }
    if (!mounted) return;
    final userId = ref.read(currentUserProvider)?.id;
    if (_lastUser != userId || !_ready || resume || userId == null) {
      _lastUser = userId;
      await _controller?.setUser(userId);
    }
  }

  void _localTap(String payload) {
    try {
      final json = jsonDecode(payload);
      if (json is! Map<String, Object?>) return;
      final id = json['notification_id'];
      if (id is! String || id.isEmpty) return;
      final kind = json['kind'];
      final route = json['route'];
      unawaited(_controller
          ?.open(PushMessage(
              notificationId: id,
              kind: kind is String ? kind : '',
              route: route is String ? route : ''))
          .catchError((Object _) {
        debugPrint('[push] local tap failed');
      }));
    } catch (_) {
      debugPrint('[push] ignored invalid local payload');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserProvider.select((u) => u?.id), (_, userId) {
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
    _lifecycle?.dispose();
    widget.router.routeInformationProvider.removeListener(_routeChanged);
    if (_controller != null) {
      LocalNotifications.instance.onTap = null;
      unawaited(_controller!.dispose());
    }
    super.dispose();
  }
}
