import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivanaut/core/router/app_router.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/core/network/terra_rest_client.dart';
import 'package:vivanaut/features/my_cage/data/device_health_repository.dart';
import 'package:vivanaut/features/my_cage/data/lcd_quiet_store.dart';
import 'package:vivanaut/features/my_cage/data/lcd_repository.dart';
import 'package:vivanaut/features/my_cage/data/lcd_text_store.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/lcd_screen_state.dart';
import 'package:vivanaut/features/my_cage/domain/lcd_text.dart';
import 'package:vivanaut/features/my_cage/presentation/lcd_screen_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/supabase_module_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/lcd_setting_tile.dart';

/// 모듈 화면 설정 테스트 공용 대역 — 네트워크·Realtime을 타지 않는다.

const kLcdDevice = 'd1';

/// 쓰기 호출을 기록하고 명령 id(`c1`, `c2`…)를 돌려준다. [error]가 있으면 던진다.
class FakeLcdRepo implements LcdRepository {
  final calls = <String>[];
  Object? error;
  int getStateCalls = 0;
  LcdStateSnapshot snapshot = const LcdStateSnapshot(
      screen: DeviceLcdScreen.unknown,
      text: DeviceLcdText.unknown,
      previewUrl: null);

  String _next(String call) {
    calls.add(call);
    final e = error;
    if (e != null) throw e;
    return 'c${calls.length}';
  }

  /// 있으면 `GET /lcd`가 이것이 끝날 때까지 기다린다(불러오는 중 화면).
  Completer<void>? stateGate;

  /// 있으면 `GET /lcd`가 던진다(불러오기 실패 화면).
  Object? stateError;

  @override
  Future<LcdStateSnapshot> getState(String deviceId) async {
    getStateCalls++;
    await stateGate?.future;
    final e = stateError;
    if (e != null) throw e;
    return snapshot;
  }

  @override
  Future<String> setPower(String deviceId, bool on) async =>
      _next('power:$deviceId:$on');

  @override
  Future<String> setQuiet(String deviceId, LcdQuietWindow window) async =>
      _next('quiet:$deviceId:${window.displayLabel}');

  @override
  Future<String> clearQuiet(String deviceId) async =>
      _next('quiet_clear:$deviceId');

  /// 마지막 `PUT saver` 본문.
  LcdSaverSettings? lastSaver;

  @override
  Future<String> setSaver(String deviceId, LcdSaverSettings settings) async {
    lastSaver = settings;
    return _next('saver:$deviceId');
  }

  @override
  Future<String> deleteImage(String deviceId) async =>
      _next('image_clear:$deviceId');

  /// 마지막 업로드 바이트.
  List<int>? lastUpload;

  /// 업로드 201의 미리보기.
  String? uploadPreviewUrl = 'https://preview.test/new.jpg';

  /// 있으면 업로드가 이것이 끝날 때까지 기다린다(201 전).
  Completer<void>? uploadGate;

  @override
  Future<LcdImageUpload> uploadImage(
    String deviceId,
    List<int> bytes, {
    String filename = 'photo.jpg',
    String contentType = 'image/jpeg',
  }) async {
    lastUpload = bytes;
    await uploadGate?.future;
    final id = _next('image:$deviceId:${bytes.length}');
    return LcdImageUpload(
        commandId: id, previewUrl: uploadPreviewUrl, sha256: null);
  }

  @override
  Future<void> setText(String deviceId, String text) async {
    calls.add('text:$deviceId:$text');
  }

  @override
  Future<void> clear(String deviceId) async {
    calls.add('text_clear:$deviceId');
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class MemoryQuietStore implements LcdQuietStore {
  final values = <String, LcdQuietWindow>{};

  @override
  LcdQuietWindow? load(String account, String deviceId) =>
      values['$account/$deviceId'];

  @override
  Future<void> save(
      String account, String deviceId, LcdQuietWindow window) async {
    values['$account/$deviceId'] = window;
  }

  @override
  Future<void> clearAll() async => values.clear();
}

class MemoryTextStore implements LcdTextStore {
  @override
  String? load(String account, String deviceId) => null;
  @override
  Future<void> save(String account, String deviceId, String text) async {}
  @override
  Stream<String?> watch(String account, String deviceId) => Stream.value(null);
  @override
  Future<void> clearAll() async {}
}

/// 명령 행 스트림 — 테스트가 `rows['c1']!.add(...)`로 결과를 흘린다.
class CommandRows {
  final rows = <String, StreamController<RebootCommandState?>>{};

  StreamController<RebootCommandState?> of(String id) =>
      rows.putIfAbsent(id, StreamController<RebootCommandState?>.new);

  void emit(String id, String status, [String? result]) =>
      of(id).add((status: status, result: result));

  Future<void> close() async {
    for (final c in rows.values) {
      await c.close();
    }
  }
}

/// 실시간 기기 행 — 구독할 때마다 지금 값을 먼저 주고 이후 [set]을 흘린다
/// (provider가 다시 만들어져도 다시 구독할 수 있다).
class LcdLinkFeed {
  LcdLinkFeed(this.value);
  DeviceLinkStatus value;
  final _updates = StreamController<DeviceLinkStatus>.broadcast();

  Stream<DeviceLinkStatus?> get stream => Stream.multi((c) {
        c.add(value);
        final sub = _updates.stream.listen(c.add);
        c.onCancel = sub.cancel;
      });

  void set(DeviceLinkStatus next) {
    value = next;
    _updates.add(next);
  }

  Future<void> close() => _updates.close();
}

DeviceLinkStatus lcdLink({
  bool online = true,
  bool power = true,
  LcdQuietWindow? quiet,
  LcdSaverSettings? saver,
  String? imageKey,
  bool? screenOn,
  DateTime? overrideUntil,
  LcdSupport support = LcdSupport.supported,
  bool lcdOverride = false,
}) =>
    DeviceLinkStatus(
      isOnline: online,
      lastSeenAt: null,
      lcdScreen: DeviceLcdScreen(
          power: power,
          quiet: quiet,
          saver: saver,
          imageKey: imageKey,
          screenOn: screenOn,
          overrideUntil: overrideUntil),
      lcdSupport: support,
      lcdOverride: lcdOverride,
    );

/// 모듈 화면 설정 provider 대역. [link]가 실시간 기기 행, [refresh]는 진입 시
/// 재조회(기본: 같은 값).
List<Override> lcdOverrides({
  required FakeLcdRepo repo,
  required CommandRows rows,
  required Stream<DeviceLinkStatus?> link,
  Future<DeviceLinkStatus?> Function()? refresh,
  MemoryQuietStore? quietStore,
  String? account = 'u1',
  bool online = true,
  DateTime? now,
  List<Device> devices = const [],
}) =>
    [
      lcdRepositoryProvider.overrideWithValue(repo),
      lcdCommandRowProvider.overrideWith((ref, id) => rows.of(id).stream),
      deviceLinkStatusProvider.overrideWith((ref, id) => link),
      lcdLinkRefreshProvider.overrideWith((ref, id) =>
          refresh?.call() ?? Completer<DeviceLinkStatus?>().future),
      lcdQuietStoreProvider.overrideWithValue(quietStore ?? MemoryQuietStore()),
      lcdTextAccountProvider.overrideWithValue(account),
      lcdTextStoreProvider.overrideWithValue(MemoryTextStore()),
      moduleOnlineProvider.overrideWith((ref, id) => online),
      deviceListProvider.overrideWith((ref) async => devices),
      if (now != null) lcdNowProvider.overrideWithValue(now),
    ];

const unsupportedFirmware =
    TerraRestException(400, 'unsupported_firmware: lcd_saver');

/// 문구 줄 기본값(기기 이름)을 가진 사육장 기기.
const lcdTestDevice = Device(
    id: kLcdDevice,
    ownerId: 'u1',
    enclosureId: null,
    name: '사육장 1',
    hardwareId: 'viva-iot-0001',
    isOnline: true,
    lastSeenAt: null);

/// 실제 ko.json 문구로 그린다(화면 글자를 그대로 검사하려고).
class KoStrings extends AssetLoader {
  const KoStrings();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/l10n/ko.json').readAsStringSync())
          as Map<String, dynamic>;
}

/// setUpAll에서 한 번.
Future<void> initLcdTestStrings() async {
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
}

/// 393×852(상태바 62·홈 바 34)에서 [initial] 경로로 연다. 라우트는 앱과 같은
/// [buildLcdSettingsRoute] + 홈 대신 쓸 `/`.
Future<GoRouter> pumpLcdRouter(
  WidgetTester tester, {
  required List<Override> overrides,
  String? initial,
  Widget home = const Scaffold(body: SizedBox()),
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: initial ?? lcdSettingsPath(kLcdDevice),
    routes: [
      GoRoute(path: '/', builder: (_, __) => home),
      buildLcdSettingsRoute(),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: EasyLocalization(
      supportedLocales: const [Locale('ko')],
      startLocale: const Locale('ko'),
      path: 'assets/l10n',
      assetLoader: const KoStrings(),
      child: Builder(
        builder: (c) => MaterialApp.router(
          theme: AppTheme.light,
          locale: c.locale,
          supportedLocales: c.supportedLocales,
          localizationsDelegates: c.localizationDelegates,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  padding: const EdgeInsets.only(top: 62, bottom: 34)),
              child: child!),
        ),
      ),
    ),
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // 반짝임(shimmer)은 끝나지 않는다 — 몇 프레임만 흘린다.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
  return router;
}
