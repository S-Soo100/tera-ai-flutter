import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/domain/keep_all_words.dart';
import '../../../shared/widgets/viva_modal.dart';
import '../../home/domain/env_alert.dart';
import '../../home/presentation/widgets/env_alert_card.dart';
import '../../my_cage/data/lcd_quiet_store.dart';
import '../../my_cage/data/lcd_repository.dart';
import '../../my_cage/data/lcd_text_store.dart';
import '../../my_cage/domain/device.dart';
import '../../my_cage/domain/lcd_screen_state.dart';
import '../../my_cage/domain/lcd_text.dart';
import '../../my_cage/presentation/lcd_quiet_time_screen.dart';
import '../../my_cage/presentation/lcd_saver_screen.dart';
import '../../my_cage/presentation/lcd_screen_providers.dart';
import '../../my_cage/presentation/lcd_settings_screen.dart';
import '../../my_cage/presentation/supabase_module_providers.dart';
import '../../my_cage/presentation/sys_health_controllers.dart'
    show commandRowProvider;
import '../../my_cage/presentation/widgets/lcd_setting_tile.dart';
import '../../my_cage/presentation/widgets/webrtc_live_view.dart';
import '../../notification/data/push_messaging_service.dart';
import '../../notification/domain/push_consent_flow.dart';
import '../../notification/presentation/push_pre_popup.dart';

/// 글자 간격 Figma 대조용 임시 페이지(디버그 빌드 전용, 2026-11-09).
///
/// 데이터가 없어 실기기로 열리지 않는 상태를 **실제 위젯·실제 문구** 그대로
/// 띄운다. 값만 데모다 — 서버·기기에 아무것도 보내지 않는다.
/// 결과: `docs/design-audits/2026-11-09-text-spacing-13mini/`.
class TextSpacingCheckScreen extends StatelessWidget {
  const TextSpacingCheckScreen({super.key});

  static const _pages = <String, String>{
    'env_alert': '온습도 알림 카드 (A12)',
    'cam_offline': '카메라 오프라인 (1525:10689)',
    'lcd_settings_off': 'LCD 설정 · 예약 꺼짐',
    'lcd_settings_on': 'LCD 설정 · 예약 켜짐',
    'lcd_settings_sticky': 'LCD 설정 · 전원 꺼짐 각주',
    'lcd_settings_offline': 'LCD 설정 · 오프라인',
    'lcd_quiet': 'LCD 꺼짐 시간',
    'lcd_quiet_offline': 'LCD 꺼짐 시간 · 오프라인',
    'lcd_saver_empty': 'LCD 보호 사진 · 없음',
    'lcd_saver_photo': 'LCD 보호 사진 · 있음',
    'lcd_saver_offline': 'LCD 보호 사진 · 오프라인',
  };

  PushConsentFlow _flow() => PushConsentFlow(
        currentPermission: () async => PushPermission.notDetermined,
        requestPermission: ({bool retry = false}) async {},
        setTopic: (_, __) async {},
        isAsked: (_) => false,
        markAsked: (_) async {},
      );

  void _modal(BuildContext context, String message, {String? detail}) =>
      unawaited(showVivaModal(context,
          message: message,
          detail: detail,
          cancelLabel: 'common_cancel'.tr(),
          confirmLabel: 'reboot_ok'.tr()));

  @override
  Widget build(BuildContext context) {
    Widget row(String label, VoidCallback onTap) => ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -3),
        title: Text(label),
        onTap: onTap);
    return Scaffold(
      appBar: AppBar(title: const Text('글자 간격 대조')),
      body: ListView(children: [
        for (final e in _pages.entries)
          row(e.value, () => context.push('/design-test/text-check/${e.key}')),
        row('모달 · 카메라 재시작',
            () => _modal(context, keepAllWords('camera_reboot_confirm'.tr()))),
        row(
            '모달 · 기기 재시작',
            () => _modal(
                context,
                keepAllWords([
                  'device_reboot_confirm'.tr(),
                  'device_reboot_schedule_note'.tr(),
                ].join('\n')))),
        row(
            '모달 · 라이브 오프라인',
            () => unawaited(showVivaModal(context,
                message: 'live_reboot_offline_title'.tr(),
                detail: keepAllWords('live_reboot_offline_body'.tr())))),
        for (final topic in PushTopic.values)
          row('알림 팝업 · ${topic.name}',
              () => unawaited(askPushConsentWith(context, _flow(), topic))),
      ]),
    );
  }
}

/// [TextSpacingCheckScreen]의 전체 화면 항목.
class TextSpacingCheckPage extends StatefulWidget {
  const TextSpacingCheckPage({super.key, required this.name});
  final String name;

  @override
  State<TextSpacingCheckPage> createState() => _TextSpacingCheckPageState();
}

class _TextSpacingCheckPageState extends State<TextSpacingCheckPage> {
  static const _id = 'demo-device';
  ProviderContainer? _container;

  @override
  void initState() {
    super.initState();
    if (widget.name.startsWith('lcd_')) {
      _container = ProviderContainer(overrides: _lcdOverrides(widget.name));
    }
  }

  @override
  void dispose() {
    _container?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final container = _container;
    if (container != null) {
      return UncontrolledProviderScope(
        container: container,
        child: switch (widget.name) {
          final n when n.startsWith('lcd_quiet') =>
            const LcdQuietTimeScreen(deviceId: _id),
          final n when n.startsWith('lcd_saver') =>
            const LcdSaverScreen(deviceId: _id),
          _ => const LcdSettingsScreen(deviceId: _id),
        },
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: switch (widget.name) {
          'cam_offline' => AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child:
                    debugLiveOfflineView(onRetry: () {}, onWifiChange: () {}),
              ),
            ),
          _ => Align(
              alignment: Alignment.topCenter,
              child: EnvAlertCard(
                  alerts: EnvAlert.openLatestPerSlot([
                _alert('t', 'env_temp_low', 'danger',
                    '[저온 경고] 온도가 너무 낮아 개체가 위험할 수 있어요'),
                _alert(
                    'h', 'env_humid_low', 'caution', '[건조 주의] 적정 습도보다 -5.2%'),
              ])),
            ),
        },
      ),
    );
  }

  static EnvAlert _alert(
          String id, String kind, String level, String message) =>
      EnvAlert.fromRow({
        'id': id,
        'device_id': _id,
        'kind': kind,
        'message': message,
        'context': {'rule': 'v4', 'level': level},
        'triggered_at': '2026-11-02T05:00:00Z',
        'resolved_at': null,
      })!;

  static DeviceLinkStatus _link(String name) {
    final quiet = name == 'lcd_settings_on'
        ? LcdQuietWindow.parse('20:00', '06:00')
        : name.startsWith('lcd_quiet')
            ? LcdQuietWindow.parse('18:00', '08:00')
            : null;
    final hasPhoto = name == 'lcd_settings_on' || name == 'lcd_saver_photo';
    return DeviceLinkStatus(
      isOnline: !name.endsWith('_offline'),
      lastSeenAt: null,
      lcdScreen: DeviceLcdScreen(
        power: name != 'lcd_settings_sticky',
        quiet: quiet,
        saver: name == 'lcd_saver_photo'
            ? LcdSaverSettings.defaults
                .copyWith(enabled: true, imageSec: 30, infoSec: 15)
            : name == 'lcd_settings_on'
                ? LcdSaverSettings.defaults.copyWith(enabled: true)
                : null,
        imageKey: hasPhoto ? 'demo' : null,
      ),
      lcdSupport: LcdSupport.supported,
      lcdOverride: false,
    );
  }

  static List<Override> _lcdOverrides(String name) {
    final link = _link(name);
    return [
      lcdRepositoryProvider.overrideWithValue(_DemoLcdRepo()),
      commandRowProvider.overrideWith((ref, id) => const Stream.empty()),
      deviceLinkStatusProvider.overrideWith((ref, id) => Stream.value(link)),
      lcdLinkRefreshProvider.overrideWith((ref, id) async => link),
      lcdQuietStoreProvider.overrideWithValue(_DemoQuietStore()),
      lcdTextAccountProvider.overrideWithValue('demo'),
      lcdTextStoreProvider.overrideWithValue(_DemoTextStore()),
      moduleOnlineProvider.overrideWith((ref, id) => link.isOnline),
      deviceListProvider.overrideWith((ref) async => const [
            Device(
                id: _id,
                ownerId: 'demo',
                enclosureId: null,
                name: '사육장 1',
                hardwareId: 'viva-iot-0001',
                isOnline: true,
                lastSeenAt: null),
          ]),
      lcdNowProvider.overrideWithValue(() => DateTime.utc(2026, 11, 3, 3)),
    ];
  }
}

class _DemoLcdRepo implements LcdRepository {
  @override
  Future<LcdStateSnapshot> getState(String deviceId) async =>
      const LcdStateSnapshot(
          screen: DeviceLcdScreen.unknown,
          text: DeviceLcdText.unknown,
          previewUrl: null);

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('디자인 테스트에서는 보내지 않는다');
}

class _DemoQuietStore implements LcdQuietStore {
  @override
  LcdQuietWindow? load(String account, String deviceId) => null;
  @override
  Future<void> save(
      String account, String deviceId, LcdQuietWindow window) async {}
  @override
  Future<void> clearAll() async {}
}

class _DemoTextStore implements LcdTextStore {
  @override
  String? load(String account, String deviceId) => null;
  @override
  Future<void> save(String account, String deviceId, String text) async {}
  @override
  Stream<String?> watch(String account, String deviceId) => Stream.value(null);
  @override
  Future<void> clearAll() async {}
}
