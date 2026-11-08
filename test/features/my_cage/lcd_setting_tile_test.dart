import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/presentation/supabase_module_providers.dart';
import 'package:vivanaut/features/home/domain/enclosure_set.dart';
import 'package:vivanaut/features/home/presentation/home_screen.dart';
import 'package:vivanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/enclosure.dart';
import 'package:vivanaut/features/my_cage/data/lcd_repository.dart';
import 'package:vivanaut/features/my_cage/data/lcd_text_store.dart';
import 'package:vivanaut/features/my_cage/domain/lcd_text.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/lcd_setting_tile.dart';

/// LCD 문구 화면([showLcdSheet]) + 홈 줄(`HomeLcdRow`)의 문구 표시.
///
/// 2026-11-03부터 홈 줄은 모듈 화면 설정 화면으로 가고, 문구 화면은 그 화면의
/// '화면 표시 문구' 줄에서 연다 — 여기선 같은 호출을 하는 [_Opener]로 연다.
///
/// 네트워크를 타지 않는 대역. 호출 기록으로 "정말 REST로 갔는가"를 본다.
class _FakeLcdRepo implements LcdRepository {
  _FakeLcdRepo({this.fail = false, this.pending});

  final bool fail;
  final Completer<void>? pending;
  final List<String> calls = [];

  @override
  Future<void> setText(String deviceId, String text) async {
    calls.add('set:$deviceId:$text');
    await pending?.future;
    if (fail) throw Exception('boom');
  }

  @override
  Future<void> clear(String deviceId) async {
    calls.add('clear:$deviceId');
    await pending?.future;
    if (fail) throw Exception('boom');
  }

  // 모듈 화면 설정 호출(2026-11-03)은 문구 시트가 쓰지 않는다.
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// 앱 재시작을 흉내 내려고 ProviderScope 밖에서 살아남는 메모리 저장소.
class _MemoryLcdTextStore implements LcdTextStore {
  final Map<String, String> values = {};
  final _changes = StreamController<String>.broadcast();

  String _key(String account, String deviceId) => '$account/$deviceId';

  @override
  String? load(String account, String deviceId) =>
      values[_key(account, deviceId)];

  @override
  Future<void> save(String account, String deviceId, String text) async {
    values[_key(account, deviceId)] = text;
    _changes.add(_key(account, deviceId));
  }

  @override
  Stream<String?> watch(String account, String deviceId) async* {
    yield load(account, deviceId);
    yield* _changes.stream
        .where((k) => k == _key(account, deviceId))
        .map((_) => load(account, deviceId));
  }

  @override
  Future<void> clearAll() async => values.clear();
}

const _openKey = Key('open_lcd_sheet');

/// 모듈 화면 설정의 '화면 표시 문구' 줄과 같은 호출로 문구 화면을 연다.
class _Opener extends ConsumerWidget {
  const _Opener();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(currentSetProvider).valueOrNull?.device;
    if (device == null) return const SizedBox.shrink();
    return TextButton(
        key: _openKey,
        onPressed: () => showLcdSheet(context, ref, device.id,
            defaultText: device.hardwareId),
        child: const Text('open'));
  }
}

const _host = Scaffold(body: Column(children: [HomeLcdRow(), _Opener()]));

Future<void> _pump(WidgetTester tester, _FakeLcdRepo repo,
    {String? deviceId = 'd1',
    String? hardwareId,
    LcdTextStore? store,
    String account = 'u1',
    Stream<DeviceLinkStatus?>? link}) async {
  await tester.pumpWidget(
    ProviderScope(
      // 재시작 흉내 — 같은 위치에 새 scope를 끼우면 provider 상태가 남는다.
      key: UniqueKey(),
      overrides: [
        lcdRepositoryProvider.overrideWithValue(repo),
        lcdTextStoreProvider.overrideWithValue(store ?? _MemoryLcdTextStore()),
        lcdTextAccountProvider.overrideWithValue(account),
        deviceLinkStatusProvider.overrideWith((ref, id) =>
            link ??
            Stream.value(
                const DeviceLinkStatus(isOnline: true, lastSeenAt: null))),
        moduleOnlineProvider.overrideWith((ref, id) => true),
        currentSetProvider.overrideWith((ref) async => deviceId == null
            ? null
            : EnclosureSet(
                enclosure: Enclosure(
                    id: 'e1', name: '1번', createdAt: DateTime(2026, 8, 1)),
                device: Device(
                    id: deviceId,
                    ownerId: null,
                    enclosureId: null,
                    name: null,
                    hardwareId: hardwareId,
                    isOnline: true,
                    lastSeenAt: null),
                camera: null,
                pet: null,
              )),
      ],
      child: const MaterialApp(home: _host),
    ),
  );
  await tester.pumpAndSettle();
}

/// 전체 화면 좌표 검사용 — 온라인 기기 d1 하나가 있는 세트.
List<Override> _fullScreenOverrides(_FakeLcdRepo repo) => [
      lcdRepositoryProvider.overrideWithValue(repo),
      lcdTextStoreProvider.overrideWithValue(_MemoryLcdTextStore()),
      lcdTextAccountProvider.overrideWithValue('u1'),
      deviceLinkStatusProvider.overrideWith((ref, id) => Stream.value(
          const DeviceLinkStatus(isOnline: true, lastSeenAt: null))),
      moduleOnlineProvider.overrideWith((ref, id) => true),
      currentSetProvider.overrideWith((ref) async => EnclosureSet(
          enclosure: Enclosure(
              id: 'e1', name: '1번', createdAt: DateTime(2026, 8, 1)),
          device: Device(
              id: 'd1',
              ownerId: null,
              enclosureId: null,
              name: null,
              isOnline: true,
              lastSeenAt: null),
          camera: null,
          pet: null)),
    ];

void main() {
  testWidgets('적용을 누르면 현재 기기로 setText가 나간다', (tester) async {
    final repo = _FakeLcdRepo();
    await _pump(tester, repo);

    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('lcd_text_field')), '밥 6시');
    await tester.pump();
    await tester.tap(find.byKey(const Key('lcd_apply')));
    await tester.pumpAndSettle();

    expect(repo.calls, ['set:d1:밥 6시']);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('20자 상한 — 붙여넣기 후 전송도 20자 이내다', (tester) async {
    final repo = _FakeLcdRepo();
    await _pump(tester, repo);

    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('lcd_text_field')), 'a' * 80);
    await tester.pump();
    final field =
        tester.widget<TextField>(find.byKey(const Key('lcd_text_field')));
    expect(field.controller!.text.length, 20);
    await tester.tap(find.byKey(const Key('lcd_apply')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['set:d1:${'a' * 20}']);
  });

  testWidgets('실패하면 시트를 닫지 않고 사유를 보여준다', (tester) async {
    final repo = _FakeLcdRepo(fail: true);
    await _pump(tester, repo);

    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('lcd_text_field')), '재시도 문구');
    await tester.pump();
    await tester.tap(find.byKey(const Key('lcd_apply')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lcd_text_field')), findsOneWidget,
        reason: '시트가 열린 채여야 재시도할 수 있다');
    expect(find.byType(SnackBar), findsOneWidget);
    final field =
        tester.widget<TextField>(find.byKey(const Key('lcd_text_field')));
    expect(field.controller!.text, '재시도 문구');
    expect(field.readOnly, isFalse);
    await tester.tap(find.byKey(const Key('lcd_apply')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['set:d1:재시도 문구', 'set:d1:재시도 문구']);
  });

  testWidgets('프로그램 입력도 공백 포함 20자까지만 전송한다', (tester) async {
    final repo = _FakeLcdRepo();
    await _pump(tester, repo);
    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();

    final field =
        tester.widget<TextField>(find.byKey(const Key('lcd_text_field')));
    field.controller!.text = '123456789 123456789 12345';
    await tester.pump();
    await tester.tap(find.byKey(const Key('lcd_apply')));
    await tester.pumpAndSettle();

    expect(repo.calls, ['set:d1:123456789 123456789 ']);
  });

  testWidgets('전송 중 연속 적용은 한 번만 보내고 입력을 잠근다', (tester) async {
    final pending = Completer<void>();
    final repo = _FakeLcdRepo(pending: pending);
    await _pump(tester, repo);
    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('lcd_text_field')), '전송 문구');
    await tester.pump();

    final apply =
        tester.widget<FilledButton>(find.byKey(const Key('lcd_apply')));
    apply.onPressed!();
    apply.onPressed!();
    await tester.pump();

    expect(repo.calls, ['set:d1:전송 문구']);
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('lcd_text_field')))
            .readOnly,
        isTrue);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('lcd_apply')))
            .onPressed,
        isNull);

    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lcd_text_field')), findsNothing);
  });

  testWidgets('기기가 없는 세트에서는 로우를 그리지 않는다', (tester) async {
    final repo = _FakeLcdRepo();
    await _pump(tester, repo, deviceId: null);

    expect(find.byKey(HomeLcdRow.rowKey), findsNothing);
  });

  testWidgets('P08 전체 화면 좌표 — 그림 자리 118, 안내 305, 입력 359, 완료 696 단독',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeLcdRepo();
    await tester.pumpWidget(ProviderScope(
        overrides: _fullScreenOverrides(repo),
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.only(top: 62, bottom: 34)),
                child: child!),
            home: _host)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.getRect(find.byKey(const Key('lcd_illustration_slot'))),
        const Rect.fromLTWH(24, 118, 345, 171));
    expect(tester.getRect(find.text('lcd_screen_description')).top, 305);
    // 번역 없는 테스트라 안내가 1줄(원본 2줄 → 359). 상대 간격 16으로 확인.
    final field = tester.getRect(find.byKey(const Key('lcd_field')));
    expect(field.top,
        tester.getRect(find.text('lcd_screen_description')).bottom + 16);
    expect(field.height, 65);
    // Figma 1659:5764 — 입력칸 아래 8에 안내 한 줄(x24, 12/500 #949090).
    final hint = tester.getRect(find.byKey(const Key('lcd_unique_hint')));
    expect(hint.top, field.bottom + 8);
    expect(hint.left, 24);
    final hintText =
        tester.widget<Text>(find.byKey(const Key('lcd_unique_hint')));
    expect(hintText.data, 'lcd_text_unique_hint');
    expect(hintText.style?.fontSize, 12);
    expect(hintText.style?.color, const Color(0xFF949090));
    expect(tester.getRect(find.byKey(const Key('lcd_counter'))).right,
        closeTo(364, 0.5));
    expect(find.text('0/20'), findsOneWidget);
    expect(tester.getRect(find.byKey(const Key('lcd_apply'))),
        const Rect.fromLTWH(12, 696, 369, 56));
    // 수정 없음(빈 문구)이면 완료 비활성, 입력하면 활성.
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('lcd_apply')))
            .onPressed,
        isNull);
    await tester.enterText(find.byKey(const Key('lcd_text_field')), '도도도네 집');
    await tester.pump();
    expect(find.text('6/20'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('lcd_apply')))
            .onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('작은 폰 키보드 — 입력칸과 아래 안내가 완료 버튼에 안 가린다', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
        overrides: _fullScreenOverrides(_FakeLcdRepo()),
        child: MaterialApp(
            // 실기기처럼 키보드가 열리면 하단 안전영역(34)은 0으로 보고된다.
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    padding: EdgeInsets.only(
                        top: 62,
                        bottom: MediaQuery.of(context).viewInsets.bottom > 0
                            ? 0
                            : 34)),
                child: child!),
            home: _host)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byKey(const Key('lcd_text_field')));
    await tester.pumpAndSettle();
    final cta = tester.getRect(find.byKey(const Key('lcd_apply')));
    expect(cta.bottom, closeTo(667 - 300 - 36, 0.5));
    expect(tester.getRect(find.byKey(const Key('lcd_field'))).bottom,
        lessThanOrEqualTo(cta.top));
    expect(tester.getRect(find.byKey(const Key('lcd_unique_hint'))).bottom,
        lessThanOrEqualTo(cta.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('처음 열면 감지된 기기 이름(terra-…)이 채워져 있다', (tester) async {
    // Figma 1081:3160 — 입력칸에 `viva-iot-ㅁㅁㅁㅁ`가 #1E1E1E(= 실제 값)로
    // 들어 있고 카운터가 14/20이다. 회색 예시("예: 밥 6시")는 원본에 없다.
    final repo = _FakeLcdRepo();
    await _pump(tester, repo, hardwareId: 'terra-cb7d7864');

    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<TextField>(find.byKey(const Key('lcd_text_field')))
            .controller!
            .text,
        'terra-cb7d7864');
    expect(find.text('14/20'), findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('lcd_text_field')))
            .decoration!
            .hintText,
        isNull,
        reason: '예시 문구는 쓰지 않는다');
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('lcd_apply')))
            .onPressed,
        isNotNull,
        reason: '채워진 값 그대로 보낼 수 있어야 한다');
    expect(tester.takeException(), isNull);
  });

  testWidgets('전송 이력이 있으면 기기 이름 대신 마지막 문구를 채운다', (tester) async {
    final repo = _FakeLcdRepo();
    await _pump(tester, repo, hardwareId: 'terra-cb7d7864');

    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('lcd_text_field')), '도도네 집');
    await tester.pump();
    await tester.tap(find.byKey(const Key('lcd_apply')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('lcd_text_field')))
            .controller!
            .text,
        '도도네 집');
    expect(tester.takeException(), isNull);
  });

  testWidgets('기기 이름을 모르면 빈 칸으로 연다', (tester) async {
    final repo = _FakeLcdRepo();
    await _pump(tester, repo);

    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();
    expect(find.text('0/20'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // 고객 문의(2026-10-06): LCD엔 바꾼 이름, 앱을 다시 켜면 기기 ID가 보였다.
  testWidgets('앱을 다시 켜도 보낸 문구가 홈 줄과 입력칸에 남는다', (tester) async {
    final store = _MemoryLcdTextStore();
    final repo = _FakeLcdRepo();
    await _pump(tester, repo, hardwareId: 'terra-cb7d7864', store: store);
    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('lcd_text_field')), '도도네 집');
    await tester.pump();
    await tester.tap(find.byKey(const Key('lcd_apply')));
    await tester.pumpAndSettle();
    expect(find.text('도도네 집'), findsOneWidget, reason: '보낸 즉시 홈 줄 반영');

    // 재시작 — provider 상태는 모두 새로 만들고 저장소만 남는다.
    await _pump(tester, repo, hardwareId: 'terra-cb7d7864', store: store);
    expect(find.text('도도네 집'), findsOneWidget);
    expect(find.text('terra-cb7d7864'), findsNothing);

    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('lcd_text_field')))
            .controller!
            .text,
        '도도네 집');
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('lcd_apply')))
            .onPressed,
        isNull,
        reason: '수정 없음이면 완료 비활성');
    expect(tester.takeException(), isNull);
  });

  testWidgets('다른 계정에는 이전 계정이 보낸 문구가 보이지 않는다', (tester) async {
    final store = _MemoryLcdTextStore();
    await store.save('u1', 'd1', '도도네 집');
    await _pump(tester, _FakeLcdRepo(),
        hardwareId: 'terra-cb7d7864', store: store, account: 'u2');
    expect(find.text('도도네 집'), findsNothing);
    expect(find.text('terra-cb7d7864'), findsOneWidget);
  });

  testWidgets('전송 실패면 문구를 저장하지 않는다', (tester) async {
    final store = _MemoryLcdTextStore();
    await _pump(tester, _FakeLcdRepo(fail: true), store: store);
    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('lcd_text_field')), '실패 문구');
    await tester.pump();
    await tester.tap(find.byKey(const Key('lcd_apply')));
    await tester.pumpAndSettle();
    expect(store.values, isEmpty);
  });

  group('서버 확정값(devices.lcd_text, 2026-10-07)', () {
    DeviceLinkStatus status(String? text, DateTime? at) => DeviceLinkStatus(
        isOnline: true,
        lastSeenAt: null,
        lcd: DeviceLcdText(text: text, updatedAt: at));
    final t0 = DateTime.utc(2026, 10, 7, 3);

    testWidgets('다른 폰에서 바꾼 문구도 서버 값으로 보인다', (tester) async {
      final store = _MemoryLcdTextStore();
      await store.save('u1', 'd1', '이 폰 옛 문구');
      await _pump(tester, _FakeLcdRepo(),
          hardwareId: 'terra-cb7d7864',
          store: store,
          link: Stream.value(status('다른 폰 문구', t0)));
      expect(find.text('다른 폰 문구'), findsOneWidget);
      expect(find.text('이 폰 옛 문구'), findsNothing);
    });

    testWidgets('보내면 즉시 새 문구, ACK가 오면 서버 값으로 이어진다', (tester) async {
      final link = StreamController<DeviceLinkStatus?>();
      addTearDown(link.close);
      await _pump(tester, _FakeLcdRepo(),
          store: _MemoryLcdTextStore(), link: link.stream);
      link.add(status('옛 문구', t0));
      await tester.pumpAndSettle();
      expect(find.text('옛 문구'), findsOneWidget);

      await tester.tap(find.byKey(_openKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('lcd_text_field')), '새 문구');
      await tester.pump();
      await tester.tap(find.byKey(const Key('lcd_apply')));
      await tester.pumpAndSettle();
      expect(find.text('새 문구'), findsOneWidget, reason: 'ACK 전에도 새 문구');

      link.add(status('새 문구', t0.add(const Duration(seconds: 2))));
      await tester.pumpAndSettle();
      expect(find.text('새 문구'), findsOneWidget);
      expect(find.text('옛 문구'), findsNothing);
    });

    testWidgets('30초 안에 ACK가 없으면 기기에 뜬 옛 문구로 돌아간다', (tester) async {
      final link = StreamController<DeviceLinkStatus?>();
      addTearDown(link.close);
      await _pump(tester, _FakeLcdRepo(),
          store: _MemoryLcdTextStore(), link: link.stream);
      link.add(status('옛 문구', t0));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_openKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('lcd_text_field')), '새 문구');
      await tester.pump();
      await tester.tap(find.byKey(const Key('lcd_apply')));
      await tester.pumpAndSettle();
      expect(find.text('새 문구'), findsOneWidget);

      await tester.pump(kLcdPendingWindow);
      await tester.pumpAndSettle();
      expect(find.text('옛 문구'), findsOneWidget);
    });
  });

  // 2026-10-07 시뮬: 네트워크 복귀로 홈이 다시 만들어진 뒤 LCD 화면이 다시
  // 그려지면서 사라진 홈 줄의 ref를 읽어 앱 전체가 오류 화면이 됐다.
  testWidgets('홈 줄이 사라진 뒤 LCD 화면이 다시 그려져도 죽지 않는다', (tester) async {
    final showRow = ValueNotifier(true);
    addTearDown(showRow.dispose);
    final repo = _FakeLcdRepo();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        lcdRepositoryProvider.overrideWithValue(repo),
        lcdTextStoreProvider.overrideWithValue(_MemoryLcdTextStore()),
        lcdTextAccountProvider.overrideWithValue('u1'),
        deviceLinkStatusProvider.overrideWith((ref, id) => Stream.value(
            const DeviceLinkStatus(isOnline: true, lastSeenAt: null))),
        moduleOnlineProvider.overrideWith((ref, id) => true),
        currentSetProvider.overrideWith((ref) async => EnclosureSet(
            enclosure: Enclosure(
                id: 'e1', name: '1번', createdAt: DateTime(2026, 8, 1)),
            device: Device(
                id: 'd1',
                ownerId: null,
                enclosureId: null,
                name: null,
                isOnline: true,
                lastSeenAt: null),
            camera: null,
            pet: null)),
      ],
      child: ValueListenableBuilder<bool>(
          valueListenable: showRow,
          builder: (context, show, _) => MaterialApp(
              home: show ? _host : const Scaffold(body: SizedBox()))),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();

    showRow.value = false; // 홈 줄 폐기 + 앱 다시 그리기
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('lcd_text_field')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('lcd_text_field')), '밥 6시');
    await tester.pump();
    await tester.tap(find.byKey(const Key('lcd_apply')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['set:d1:밥 6시']);
  });
}
