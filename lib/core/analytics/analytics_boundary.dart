import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_providers.dart';
import 'analytics_consent.dart';
import 'analytics_providers.dart';
import 'analytics_recorder.dart';
import 'clarity_sdk.dart';
import 'clarity_setup.dart';

final analyticsRuntimeConfigProvider =
    Provider<ClarityRuntimeConfig>((ref) => ClarityRuntimeConfig.environment);

/// Never use the actual URI as a screen name. Unknown paths fail closed.
String? analyticsScreenForPath(String location) {
  final path = Uri.tryParse(location)?.path;
  const fixed = {
    '/home': 'home',
    '/crecam': 'camera',
    '/my-pets': 'pets',
    '/community': 'community',
    '/community-share': 'community_share',
    '/community-share/caption': 'community_caption',
    '/crecam/cameras/pair': 'camera_pairing',
    '/crecam/highlights': 'highlights',
    '/crecam/bookmarks': 'bookmarks',
    '/smart-cage': 'smart_cage',
    '/smart-cage/devices/pair': 'device_pairing',
    '/smart-cage/enclosures': 'enclosures',
    '/my-pets/add': 'pet_add',
    '/pet-add': 'pet_add',
    '/home/routines': 'routines',
    '/env-detail': 'environment',
    '/enclosure-settings': 'enclosure_settings',
    '/env-settings': 'environment_settings',
  };
  if (fixed.containsKey(path)) return fixed[path];
  if (path == null) return null;
  const patterns = {
    r'^/crecam/cameras/[^/]+/live$': 'live',
    r'^/crecam/cameras/[^/]+$': 'camera_detail',
    r'^/crecam/(clips|motion-clips|player)/[^/]+$': 'clip_player',
    r'^/my-pets/[^/]+/edit$': 'pet_edit',
    r'^/my-pets/[^/]+$': 'pet_detail',
    r'^/smart-cage/enclosures/[^/]+$': 'enclosure_detail',
    r'^/community-player/[^/]+$': 'community_player',
    r'^/community-user/[^/]+$': 'community_user',
  };
  for (final entry in patterns.entries) {
    if (RegExp(entry.key).hasMatch(path)) return entry.value;
  }
  return null;
}

/// This widget never swaps/remounts its child. Every frame, including frames
/// already queued by the SDK at withdrawal, retains the root mask.
class AnalyticsBoundary extends ConsumerStatefulWidget {
  const AnalyticsBoundary(
      {super.key, required this.router, required this.child});
  final GoRouter router;
  final Widget child;
  @override
  ConsumerState<AnalyticsBoundary> createState() => _AnalyticsBoundaryState();
}

class _AnalyticsBoundaryState extends ConsumerState<AnalyticsBoundary>
    with WidgetsBindingObserver {
  late final AnalyticsRecorder _recorder;
  late final ClarityRuntimeConfig _config;
  ClarityAnalyticsSdk? _sdk;
  bool _foreground = true;
  bool _frameScheduled = false;
  String? _accountId;

  @override
  void initState() {
    super.initState();
    _recorder = ref.read(analyticsRecorderProvider);
    _config = ref.read(analyticsRuntimeConfigProvider);
    final sdk = ref.read(analyticsSdkProvider);
    if (sdk is ClarityAnalyticsSdk) {
      _sdk = sdk;
      sdk.bind(context);
    }
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.router.routerDelegate.addListener(_onRouteChanged);
    widget.router.routeInformationProvider.addListener(_onRouteIntent);
    ref.listenManual(currentUserProvider, (_, user) {
      if (_accountId != user?.id) {
        _accountId = user?.id;
        _recorder.suspend();
      }
      // fireImmediately can run during initState. Gate closes synchronously;
      // provider state is changed only after the frame has completed.
      _afterFrame();
    }, fireImmediately: true);
    ref.listenManual(analyticsConsentProvider, (_, __) => _onRouteChanged());
    _afterFrame();
  }

  String? get _screen {
    final matches = widget.router.routerDelegate.currentConfiguration;
    if (matches.isEmpty || matches.isError) return null;
    // Delegate state resolves the top imperative push and nested shell leaf.
    return analyticsScreenForPath(
        widget.router.routerDelegate.state.uri.toString());
  }

  void _onRouteIntent() {
    final uri = widget.router.routeInformationProvider.value.uri;
    if (analyticsScreenForPath(uri.toString()) == null) _recorder.suspend();
    _afterFrame();
  }

  void _onRouteChanged() {
    final consent = ref.read(analyticsConsentProvider);
    if (_screen == null || !consent.granted || !_foreground) {
      _sync();
    }
    _afterFrame();
  }

  void _sync() {
    final consent = ref.read(analyticsConsentProvider);
    _recorder.synchronize(
        enabled: _config.canCollect,
        consent: consent.accountId == _accountId && consent.granted,
        accountId: _accountId,
        screenName: _screen,
        foreground: _foreground);
  }

  void _afterFrame() {
    if (!mounted || _frameScheduled) return;
    _frameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      if (mounted) {
        ref.read(analyticsConsentProvider.notifier).selectAccount(_accountId);
        _sync();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _sync();
    } else {
      _afterFrame();
    }
  }

  @override
  void didUpdateWidget(covariant AnalyticsBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router.routerDelegate.removeListener(_onRouteChanged);
      oldWidget.router.routeInformationProvider.removeListener(_onRouteIntent);
      _recorder.suspend();
      widget.router.routerDelegate.addListener(_onRouteChanged);
      widget.router.routeInformationProvider.addListener(_onRouteIntent);
      _onRouteChanged();
    }
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRouteChanged);
    widget.router.routeInformationProvider.removeListener(_onRouteIntent);
    WidgetsBinding.instance.removeObserver(this);
    _recorder.suspend();
    _sdk?.unbind();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClarityMask(child: widget.child);
}
