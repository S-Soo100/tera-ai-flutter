// 네트워크 관리 화면 캡처(Figma 1913:6462·6570·7778 대조용). Opt-in only:
//   flutter test --no-pub --dart-define=CAPTURE_NETWORK_MANAGE=true \
//     test/design/network_manage_capture_test.dart
// Writes /private/tmp/network-manage-capture/<name>.png (3x, 1179×2556) +
// <name>.json (논리 좌표 rect·실제 적용 TextStyle 수치).
// 값은 테스트 픽스처 — 기기·서버를 쓰지 않는다.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/my_cage/domain/device_add_flow.dart';
import 'package:vivanaut/features/my_cage/domain/network_manage.dart';
import 'package:vivanaut/features/my_cage/domain/pair_target_kind.dart';
import 'package:vivanaut/features/my_cage/presentation/device_add_flow_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/device_add_flow_screen.dart';
import 'package:vivanaut/shared/widgets/figma_icon.dart';
import '../features/my_cage/device_add_flow_screen_test.dart'
    show Controller, Translations;
import '../features/my_cage/network_manage_screen_fixtures.dart';

const _outDir = '/private/tmp/network-manage-capture';
const _logical = Size(393, 852);
const _ratio = 3.0;

// Figma 1913:6462/6570 표본 — 사육장 2·카메라 2(하나는 오프라인).
const _dev1 = DeviceAddCandidate(
    physicalId: 'BB:00:00:00:00:01',
    kind: PairTargetKind.device,
    name: 'terra-iot',
    rssi: -60);
const _dev2 = DeviceAddCandidate(
    physicalId: 'BB:00:00:00:00:02',
    kind: PairTargetKind.device,
    name: 'terra-iot',
    rssi: -45);
const _cam1 = DeviceAddCandidate(
    physicalId: 'BB:00:00:00:00:03',
    kind: PairTargetKind.camera,
    name: 'FB2_P4_CAM_2222',
    rssi: -40);
const _cam2 = DeviceAddCandidate(
    physicalId: 'BB:00:00:00:00:04',
    kind: PairTargetKind.camera,
    name: 'FB2_P4_CAM_2223',
    rssi: -70);

const _owned = <String, NetworkMatch>{
  'BB:00:00:00:00:01': (
    device: OwnedNetworkDevice(
        kind: PairTargetKind.device,
        id: 'd1',
        name: '사육장',
        hardwareId: 'viva-iot-1234',
        isOnline: true,
        wifiRssi: -68,
        wifiSsid: 'iptime1354111'),
    via: NetworkMatchVia.hardware
  ),
  'BB:00:00:00:00:02': (
    device: OwnedNetworkDevice(
        kind: PairTargetKind.device,
        id: 'd2',
        name: '사육장',
        hardwareId: 'viva-iot-1111',
        isOnline: true,
        wifiRssi: -50,
        wifiSsid: 'iptime452'),
    via: NetworkMatchVia.hardware
  ),
  'BB:00:00:00:00:03': (
    device: OwnedNetworkDevice(
        kind: PairTargetKind.camera,
        id: 'c1',
        name: '카메라1',
        hardwareId: 'viva-iot-2222',
        isOnline: true,
        wifiRssi: -20,
        wifiSsid: 'iptime4555555555552'),
    via: NetworkMatchVia.hardware
  ),
  'BB:00:00:00:00:04': (
    device: OwnedNetworkDevice(
        kind: PairTargetKind.camera,
        id: 'c2',
        name: '카메라1',
        hardwareId: 'viva-iot-2222',
        isOnline: false),
    via: NetworkMatchVia.hardware
  ),
};

const _all = [_dev1, _dev2, _cam1, _cam2];
const _picked = <String, DeviceAddCandidate>{
  'BB:00:00:00:00:02': _dev2,
  'BB:00:00:00:00:03': _cam1,
  'BB:00:00:00:00:04': _cam2,
};

DeviceAddState _results(Map<String, DeviceAddResult> results) => DeviceAddState(
    networkManage: true,
    step: DeviceAddStep.results,
    ssid: 'iptime452',
    candidates: _all,
    owned: _owned,
    selected: _picked,
    results: results);

final Map<String, Object?> _ko = () {
  final Object? raw =
      jsonDecode(File('assets/l10n/ko.json').readAsStringSync());
  return raw is Map<String, Object?> ? raw : <String, Object?>{};
}();
String _s(String key) {
  final v = _ko[key];
  return v is String ? v : key;
}

String _hex(Color? c) => c == null
    ? 'null'
    : '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

List<double> _rect(WidgetTester tester, Finder f) {
  final r = tester.getRect(f);
  return [r.left, r.top, r.width, r.height];
}

/// 실제로 그린 스타일(DefaultTextStyle 병합 후) — RenderParagraph에서 읽는다.
Map<String, Object?> _text(WidgetTester tester, Finder f) {
  final el = f.evaluate().first;
  RenderParagraph? para;
  void find(RenderObject o) {
    if (para != null) return;
    if (o is RenderParagraph) {
      para = o;
      return;
    }
    o.visitChildren(find);
  }

  final ro = el.renderObject;
  if (ro != null) find(ro);
  final style = para?.text.style;
  final size = style?.fontSize;
  final w = el.widget;
  return {
    'text': w is Text ? (w.data ?? w.textSpan?.toPlainText()) : null,
    'rect': _rect(tester, f),
    'fontFamily': style?.fontFamily,
    'fontSize': size,
    'fontWeight': style?.fontWeight?.value,
    'heightFactor': style?.height,
    'lineHeightPx':
        size == null || style?.height == null ? null : size * style!.height!,
    'letterSpacing': style?.letterSpacing,
    'color': _hex(style?.color),
    'maxLines': w is Text ? w.maxLines : null,
    'didExceedMaxLines': para?.didExceedMaxLines,
  };
}

Map<String, Object?> _icon(WidgetTester tester, Finder f) {
  final w = tester.widget<FigmaIcon>(f);
  return {
    'icon': w.name,
    'size': w.size,
    'color': _hex(w.color),
    'rect': _rect(tester, f),
  };
}

Finder _iconIn(Finder within, bool Function(String) test) => find.descendant(
    of: within,
    matching: find.byWidgetPredicate((w) => w is FigmaIcon && test(w.name)));

Map<String, Object?>? _maybe(Finder f, Map<String, Object?> Function() read) =>
    f.evaluate().isEmpty ? null : read();

Map<String, Object?> _rowMetrics(
    WidgetTester tester, DeviceAddCandidate c, NetworkMatch match) {
  final row = find.byKey(Key('network_manage_row_${c.physicalId}'));
  final id = c.physicalId;
  final d = match.device;
  Finder textIn(String s) => find.descendant(of: row, matching: find.text(s));
  return {
    'physicalId': id,
    'rect': _rect(tester, row),
    'name': _text(tester, textIn(d.name)),
    'hw': d.hardwareId == null
        ? null
        : _maybe(
            textIn(d.hardwareId!), () => _text(tester, textIn(d.hardwareId!))),
    'ssid': _maybe(find.byKey(Key('network_manage_ssid_$id')),
        () => _text(tester, find.byKey(Key('network_manage_ssid_$id')))),
    'dbm': _maybe(find.byKey(Key('network_manage_dbm_$id')),
        () => _text(tester, find.byKey(Key('network_manage_dbm_$id')))),
    'noConnection': _maybe(textIn(_s('network_manage_no_connection')),
        () => _text(tester, textIn(_s('network_manage_no_connection')))),
    'signal': _maybe(
        _iconIn(row, (n) => n.contains('signal_cellular')),
        () =>
            _icon(tester, _iconIn(row, (n) => n.contains('signal_cellular')))),
    'check': _maybe(_iconIn(row, (n) => n.contains('check_box')),
        () => _icon(tester, _iconIn(row, (n) => n.contains('check_box')))),
  };
}

/// 화면 전체 Text·FigmaIcon 덤프(키 없는 요소 대조용).
List<Map<String, Object?>> _dump(WidgetTester tester, GlobalKey boundary) {
  final out = <Map<String, Object?>>[];
  void visit(Element e) {
    final r = e.renderObject;
    final w = e.widget;
    if (r is RenderBox && r.hasSize && r.attached) {
      final p = r.localToGlobal(Offset.zero);
      final rect = [p.dx, p.dy, r.size.width, r.size.height];
      if (w is Text) {
        out.add({
          'type': 'Text',
          'text': w.data ?? w.textSpan?.toPlainText(),
          'rect': rect,
          if (w.key != null) 'key': w.key.toString(),
        });
      } else if (w is FigmaIcon) {
        out.add({
          'type': 'FigmaIcon',
          'icon': w.name,
          'size': w.size,
          'rect': rect
        });
      }
    }
    e.visitChildren(visit);
  }

  boundary.currentContext!.visitChildElements(visit);
  return out;
}

Future<void> _write(WidgetTester tester, GlobalKey boundary, String name,
    Map<String, Object?> metrics) async {
  void repaint(RenderObject o) {
    o.markNeedsPaint();
    o.visitChildren(repaint);
  }

  repaint(boundary.currentContext!.findRenderObject()!);
  await tester.pump();
  final json = {
    'name': name,
    'logicalSize': [_logical.width, _logical.height],
    'pixelRatio': _ratio,
    'safeArea': {'top': 62, 'bottom': 34},
    ...metrics,
    'all': _dump(tester, boundary),
  };
  await tester.runAsync(() async {
    final image = await (boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary)
        .toImage(pixelRatio: _ratio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_outDir).createSync(recursive: true);
    File('$_outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    File('$_outDir/$name.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
    image.dispose();
  });
}

void main() {
  if (!const bool.fromEnvironment('CAPTURE_NETWORK_MANAGE')) {
    test('opt-in network manage captures', () {},
        skip: 'CAPTURE_NETWORK_MANAGE=true');
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final font = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      font.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await font.load();
  });

  /// 진행 스피너가 무한 회전이라 settle 대신 고정 프레임만 돌린다.
  Future<GlobalKey> pump(WidgetTester tester, DeviceAddState initial) async {
    debugDisableShadows = false;
    tester.view.devicePixelRatio = _ratio;
    tester.view.physicalSize = _logical * _ratio;
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    final controller = Controller(initial);
    const screen = DeviceAddFlowScreen(
        flowKey: 'capture', networkManage: NetworkManageRequest());
    await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('ko')],
        startLocale: const Locale('ko'),
        path: 'assets/l10n',
        assetLoader: const Translations(),
        child: Builder(
            builder: (context) => ProviderScope(
                    overrides: [
                      deviceAddAccountProvider.overrideWithValue('a'),
                      deviceWifiNameStoreProvider
                          .overrideWithValue(NmWifiNames()),
                      deviceAddFlowProvider('capture')
                          .overrideWith((ref) => controller),
                    ],
                    child: MaterialApp(
                        theme: AppTheme.light,
                        locale: context.locale,
                        supportedLocales: context.supportedLocales,
                        localizationsDelegates: context.localizationDelegates,
                        builder: (c, child) => RepaintBoundary(
                            key: boundary,
                            // Figma 393×852 프레임 안전영역 상 62 / 하 34.
                            child: MediaQuery(
                                data: MediaQuery.of(c).copyWith(
                                    padding: const EdgeInsets.only(
                                        top: 62, bottom: 34)),
                                child: child!)),
                        home: screen)))));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    return boundary;
  }

  Map<String, Object?> common(WidgetTester tester) {
    final title = find.text(_s('network_manage_title'));
    final rescan = find.byKey(const Key('device_add_rescan'));
    final cont = find.byKey(const Key('device_add_continue'));
    final cta = rescan.evaluate().isNotEmpty ? rescan : cont;
    return {
      'screenTitle': _maybe(title, () => _text(tester, title)),
      'cta': cta.evaluate().isEmpty
          ? null
          : {
              'key': (cta.evaluate().first.widget.key).toString(),
              'rect': _rect(tester, cta),
              'label': _maybe(
                  find.descendant(of: cta, matching: find.byType(Text)),
                  () => _text(tester,
                      find.descendant(of: cta, matching: find.byType(Text)))),
            },
    };
  }

  Map<String, Object?> scanMetrics(WidgetTester tester) {
    final heading = find.text(_s('network_manage_select_title'));
    final sub = find.text(_s('network_manage_select_subtitle'));
    final rows = [
      for (final c in _all)
        if (find
            .byKey(Key('network_manage_row_${c.physicalId}'))
            .evaluate()
            .isNotEmpty)
          _rowMetrics(tester, c, _owned[c.physicalId]!)
    ]..sort((a, b) => ((a['rect']! as List<double>)[1])
        .compareTo((b['rect']! as List<double>)[1]));
    final spinner = _iconIn(find.byType(DeviceAddFlowScreen),
        (n) => n == 'redesign_v2/progress_activity');
    return {
      ...common(tester),
      'heading': _maybe(heading, () => _text(tester, heading)),
      'subtitle': _maybe(sub, () => _text(tester, sub)),
      'headingSpinner': _maybe(spinner, () => _icon(tester, spinner)),
      'firstRow': rows.isEmpty ? null : rows.first['rect'],
      'rows': rows,
    };
  }

  testWidgets('01-scan', (tester) async {
    final boundary = await pump(
        tester,
        const DeviceAddState(
            networkManage: true, busy: true, candidates: _all, owned: _owned));
    expect(find.byKey(const Key('device_add_rescan')), findsOneWidget);
    await _write(tester, boundary, '01-scan', scanMetrics(tester));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugDisableShadows = true;
  });

  testWidgets('02-selected', (tester) async {
    final boundary = await pump(
        tester,
        const DeviceAddState(
            networkManage: true,
            candidates: _all,
            owned: _owned,
            selected: _picked));
    expect(find.text('기기 3개 네트워크 연결'), findsOneWidget);
    await _write(tester, boundary, '02-selected', scanMetrics(tester));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugDisableShadows = true;
  });

  testWidgets('03-done', (tester) async {
    final boundary = await pump(
        tester,
        _results({
          _dev2.physicalId: nmUpdated(_dev2, 'd2', CameraReconnect.online),
          _cam1.physicalId: nmUpdated(_cam1, 'c1', CameraReconnect.online),
          _cam2.physicalId: nmUpdated(_cam2, 'c2', CameraReconnect.online),
        }));
    final done = find.byKey(const Key('network_manage_done'));
    expect(done, findsOneWidget);
    final check = find.byWidgetPredicate(
        (w) => w is FigmaIcon && w.name == 'redesign_v2/check_circle');
    final confirm = find.byKey(const Key('network_manage_confirm'));
    await _write(tester, boundary, '03-done', {
      ...common(tester),
      'checkCircle': _icon(tester, check),
      'doneText': _text(tester, done),
      'checkToTextGap':
          tester.getTopLeft(done).dy - tester.getBottomLeft(check).dy,
      'cta': {
        'key': confirm.evaluate().first.widget.key.toString(),
        'rect': _rect(tester, confirm),
        'label': _text(
            tester, find.descendant(of: confirm, matching: find.byType(Text))),
      },
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugDisableShadows = true;
  });

  testWidgets('04-results', (tester) async {
    final boundary = await pump(
        tester,
        _results({
          _dev2.physicalId: nmUpdated(_dev2, 'd2', CameraReconnect.online),
          _cam1.physicalId: nmUpdated(_cam1, 'c1', CameraReconnect.missing),
          _cam2.physicalId:
              nmUpdated(_cam2, 'c2', CameraReconnect.online, unverified: true),
        }));
    expect(find.byKey(const Key('network_manage_done')), findsNothing);
    final heading = find.text(_s('device_add_results'));
    final rows = [
      for (final c in [_dev2, _cam1, _cam2])
        () {
          final row = find.byKey(Key('network_manage_result_${c.physicalId}'));
          final texts = find.descendant(of: row, matching: find.byType(Text));
          return {
            'physicalId': c.physicalId,
            'rect': _rect(tester, row),
            'texts': [
              for (var i = 0; i < texts.evaluate().length; i++)
                _text(tester, texts.at(i))
            ],
          };
        }()
    ];
    final retry = find.byKey(const Key('device_wifi_retry'));
    await _write(tester, boundary, '04-results', {
      ...common(tester),
      'heading': _text(tester, heading),
      'firstRow': rows.first['rect'],
      'rows': rows,
      'cta': _maybe(
          retry,
          () => {
                'key': retry.evaluate().first.widget.key.toString(),
                'rect': _rect(tester, retry),
                'label': _text(tester,
                    find.descendant(of: retry, matching: find.byType(Text))),
              }),
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugDisableShadows = true;
  });

  testWidgets('05-connecting', (tester) async {
    final boundary = await pump(
        tester,
        const DeviceAddState(
            networkManage: true,
            step: DeviceAddStep.connecting,
            ssid: 'iptime452',
            candidates: _all,
            owned: _owned,
            selected: _picked,
            activePhysicalId: 'BB:00:00:00:00:03',
            connectingIndex: 2,
            connectingTotal: 3));
    final progress = find.byKey(const Key('network_manage_progress'));
    expect(tester.widget<Text>(progress).data, '2/3 · 카메라1');
    final overlay = find.byKey(const Key('device_add_connecting_overlay'));
    final label = find.descendant(
        of: overlay, matching: find.text(_s('device_add_connecting')));
    final spinner =
        _iconIn(overlay, (n) => n == 'redesign_v2/progress_activity');
    await _write(tester, boundary, '05-connecting', {
      ...common(tester),
      'overlay': _rect(tester, overlay),
      'spinner': _icon(tester, spinner),
      'connectingText': _text(tester, label),
      'progress': _text(tester, progress),
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugDisableShadows = true;
  });
}
