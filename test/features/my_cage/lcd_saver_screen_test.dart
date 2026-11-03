import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:vivanaut/core/router/app_router.dart';
import 'package:vivanaut/features/home/presentation/routine_settings_screen.dart'
    show ScheduleSwitch;
import 'package:vivanaut/features/my_cage/data/lcd_repository.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/lcd_photo_codec.dart';
import 'package:vivanaut/features/my_cage/domain/lcd_screen_state.dart';
import 'package:vivanaut/features/my_cage/domain/lcd_text.dart';
import 'package:vivanaut/features/my_cage/presentation/lcd_saver_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/lcd_screen_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/lcd_settings_screen.dart';
import 'package:vivanaut/shared/widgets/viva_stepper.dart';

import 'lcd_fixtures.dart';

const _k1Url = 'https://preview.test/k1.jpg';

/// 디코드할 수 있는 작은 JPEG(업로드 중 칸에 그리는 자른 사진).
final _jpeg = img.encodeJpg(img.Image(width: 10, height: 8));

class _Env {
  _Env(this.feed);
  final LcdLinkFeed feed;
  final repo = FakeLcdRepo();
  final rows = CommandRows();
  LcdPhotoPick pick = LcdPhotoPicked(_jpeg);
  int pickCalls = 0;
  late GoRouter router;
}

/// 설정 화면을 열고 [enter]면 보호 사진 줄을 눌러 들어온다.
Future<_Env> _open(
  WidgetTester tester, {
  required DeviceLinkStatus link,
  bool online = true,
  bool enter = true,
  String? snapshotKey,
  void Function(_Env env)? setUp,
}) async {
  final env = _Env(LcdLinkFeed(link));
  env.repo.snapshot = LcdStateSnapshot(
      screen: DeviceLcdScreen(imageKey: snapshotKey ?? link.lcdScreen.imageKey),
      text: DeviceLcdText.unknown,
      previewUrl:
          (snapshotKey ?? link.lcdScreen.imageKey) == null ? null : _k1Url);
  setUp?.call(env);
  addTearDown(env.rows.close);
  addTearDown(env.feed.close);
  env.router = await pumpLcdRouter(tester, settle: false, overrides: [
    ...lcdOverrides(
        repo: env.repo,
        rows: env.rows,
        link: env.feed.stream,
        online: online,
        now: DateTime.utc(2026, 11, 3, 3),
        devices: const [lcdTestDevice]),
    lcdPhotoPickerProvider.overrideWithValue((_) async {
      env.pickCalls++;
      return env.pick;
    }),
  ]);
  if (enter) {
    await tester.tap(find.byKey(LcdSettingsScreen.saverRowKey));
    await _frames(tester);
    expect(find.byType(LcdSaverScreen), findsOneWidget);
  }
  return env;
}

/// 반짝임이 끝나지 않으니 몇 프레임만 흘린다.
Future<void> _frames(WidgetTester tester, [int n = 16]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder _inRow(Key row, Key child) =>
    find.descendant(of: find.byKey(row), matching: find.byKey(child));

String _stepValue(WidgetTester tester, Key row) =>
    tester.widget<Text>(_inRow(row, VivaStepper.valueKey)).data!;

bool _done(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(LcdSaverScreen.doneKey)).onPressed !=
    null;

bool _switchOn(WidgetTester tester) => tester
    .widget<ScheduleSwitch>(find.descendant(
        of: find.byKey(LcdSaverScreen.switchKey),
        matching: find.byType(ScheduleSwitch)))
    .value;

bool _switchIgnored(WidgetTester tester) => tester
    .widget<IgnorePointer>(find
        .descendant(
            of: find.byKey(LcdSaverScreen.switchKey),
            matching: find.byType(IgnorePointer))
        .first)
    .ignoring;

bool _stepEnabled(WidgetTester tester, Key row, Key button) =>
    tester
        .widget<FilledButton>(find.descendant(
            of: _inRow(row, button), matching: find.byType(FilledButton)))
        .onPressed !=
    null;

Future<void> _tapStep(WidgetTester tester, Key row, Key button) async {
  await tester.tap(_inRow(row, button));
  await tester.pump();
}

Finder _networkImage(String url) => find.byWidgetPredicate((w) =>
    w is Image &&
    w.image is NetworkImage &&
    (w.image as NetworkImage).url == url);

/// 업로드 대기 → 결과.
Future<void> _pickAndStart(WidgetTester tester) async {
  await tester.tap(find.byKey(LcdSaverScreen.photoAddKey));
  await _frames(tester, 3);
}

/// 실행기 타이머·안내 타이머를 흘려 보낸다.
Future<void> _drain(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 45));

void main() {
  setUpAll(initLcdTestStrings);

  group('수치 (Figma 1659:6396, 393×852)', () {
    testWidgets('사진 없음 — 빈 칸·목록·각주 위치', (tester) async {
      await _open(tester, link: lcdLink());
      expect(find.text('화면 보호 사진 설정'), findsWidgets);
      expect(tester.getRect(find.byKey(LcdSaverScreen.photoBoxKey)),
          const Rect.fromLTWH(84, 130, 225, 180));
      expect(find.text('사진 추가'), findsOneWidget);
      expect(tester.getRect(find.text('사진 추가')).top, 226);
      expect(tester.getRect(find.byKey(LcdSaverScreen.toggleRowKey)),
          const Rect.fromLTWH(24, 334, 345, 55));
      expect(tester.getRect(find.byKey(LcdSaverScreen.imageRowKey)),
          const Rect.fromLTWH(24, 390, 345, 56));
      expect(tester.getRect(find.byKey(LcdSaverScreen.infoRowKey)),
          const Rect.fromLTWH(24, 447, 345, 56));
      expect(tester.getTopLeft(find.byKey(LcdSaverScreen.switchKey)),
          const Offset(281, 345.5));
      expect(
          tester.getTopLeft(find
              .descendant(
                  of: find.byKey(LcdSaverScreen.imageRowKey),
                  matching: find.byType(VivaStepper))
              .first),
          const Offset(237, 402));
      expect(tester.getTopLeft(find.byKey(LcdSaverScreen.noteKey)),
          const Offset(36, 511));
      expect(find.text('모듈 화면에 사진과 기존 온습도 표시가 번갈아 나타납니다'), findsOneWidget);
      expect(tester.getRect(find.byKey(LcdSaverScreen.doneKey)),
          const Rect.fromLTWH(12, 852 - 34 - 66 - 56, 369, 56));
      expect(find.text('1분'), findsOneWidget, reason: '미설정 기본 1분');
      expect(find.text('10초'), findsOneWidget);
    });

    testWidgets('사진 있음 — 미리보기 + 연필 + 교체·삭제 메뉴', (tester) async {
      await _open(tester, link: lcdLink(imageKey: 'k1'));
      expect(find.byKey(LcdSaverScreen.photoPreviewKey), findsOneWidget);
      expect(find.byKey(LcdSaverScreen.photoAddKey), findsNothing);
      expect(tester.getRect(find.byKey(LcdSaverScreen.editButtonKey)),
          const Rect.fromLTWH(261, 262, 36, 36));
      expect(find.byKey(LcdSaverScreen.needPhotoNoteKey), findsNothing);
      await tester.tap(find.byKey(LcdSaverScreen.editButtonKey));
      await tester.pumpAndSettle();
      expect(find.text('사진 교체'), findsOneWidget);
      expect(find.text('사진 삭제'), findsOneWidget);
      // 메뉴 106×96 at (191, 301) — 안쪽 위아래 4·좌우 8, 항목 90×44.
      expect(tester.getRect(find.byKey(LcdSaverScreen.menuReplaceKey)),
          const Rect.fromLTWH(199, 305, 90, 44));
      expect(tester.getRect(find.byKey(LcdSaverScreen.menuRemoveKey)),
          const Rect.fromLTWH(199, 349, 90, 44));
      await tester.tapAt(const Offset(20, 700));
      await tester.pumpAndSettle();
    });
  });

  group('사진 없음 (D9·§11-4·§12-2)', () {
    testWidgets('켜기만 막고 안내를 보인다', (tester) async {
      await _open(tester, link: lcdLink());
      expect(find.byKey(LcdSaverScreen.needPhotoNoteKey), findsOneWidget);
      expect(find.text('사진을 먼저 추가해 주세요'), findsOneWidget);
      expect(_switchOn(tester), isFalse);
      expect(_switchIgnored(tester), isTrue);
      expect(find.text('보호기 · 꺼짐'), findsOneWidget);
    });

    testWidgets('켜져 있으면 끌 수는 있다', (tester) async {
      final env = await _open(tester,
          link: lcdLink(
              saver: LcdSaverSettings.defaults.copyWith(enabled: true)));
      expect(_switchIgnored(tester), isFalse);
      await tester.tap(find.byKey(LcdSaverScreen.switchKey));
      await tester.pump();
      expect(find.text('보호기 · 꺼짐'), findsOneWidget);
      expect(_done(tester), isTrue);
      await tester.tap(find.byKey(LcdSaverScreen.doneKey));
      await _frames(tester);
      expect(env.repo.lastSaver?.enabled, isFalse);
      env.rows.emit('c1', 'acked', 'ok');
      await _frames(tester);
      await _drain(tester);
    });
  });

  group('보호기 값·완료', () {
    testWidgets('칸 밖 서버값은 그대로 보이고 처음 누를 때 칸으로 맞춘다', (tester) async {
      await _open(tester,
          link: lcdLink(
              imageKey: 'k1',
              saver: LcdSaverSettings.defaults
                  .copyWith(imageSec: 90, infoSec: 7)));
      expect(_stepValue(tester, LcdSaverScreen.imageRowKey), '1분 30초');
      expect(_stepValue(tester, LcdSaverScreen.infoRowKey), '7초');
      expect(_done(tester), isFalse);
      await _tapStep(
          tester, LcdSaverScreen.infoRowKey, VivaStepper.decreaseKey);
      expect(_stepValue(tester, LcdSaverScreen.infoRowKey), '10초');
      expect(_done(tester), isTrue, reason: '맞춘 순간부터 바뀜');
      expect(
          _stepEnabled(
              tester, LcdSaverScreen.infoRowKey, VivaStepper.decreaseKey),
          isFalse,
          reason: '끝값');
      // 90초 → +: 같은 거리(60·120) → 누른 방향 쪽 120.
      await _tapStep(
          tester, LcdSaverScreen.imageRowKey, VivaStepper.increaseKey);
      expect(_stepValue(tester, LcdSaverScreen.imageRowKey), '2분');
    });

    testWidgets('20초는 "20초"로, +를 누르면 1분', (tester) async {
      await _open(tester,
          link: lcdLink(
              imageKey: 'k1',
              saver: LcdSaverSettings.defaults.copyWith(imageSec: 20)));
      expect(_stepValue(tester, LcdSaverScreen.imageRowKey), '20초');
      await _tapStep(
          tester, LcdSaverScreen.imageRowKey, VivaStepper.increaseKey);
      expect(_stepValue(tester, LcdSaverScreen.imageRowKey), '1분');
    });

    testWidgets('스위치만 바꾸면 시간·mode·오프라인 아이콘은 서버값 그대로, 보내고 돌아간다', (tester) async {
      const server = LcdSaverSettings(
          enabled: false,
          mode: LcdSaverMode.image,
          imageSec: 20,
          infoSec: 15,
          showOfflineIcon: false);
      final env =
          await _open(tester, link: lcdLink(imageKey: 'k1', saver: server));
      expect(find.text('모듈 화면에 사진만 표시돼요'), findsOneWidget,
          reason: 'mode image 각주');
      await tester.tap(find.byKey(LcdSaverScreen.switchKey));
      await tester.pump();
      await tester.tap(find.byKey(LcdSaverScreen.doneKey));
      await _frames(tester);
      expect(env.repo.lastSaver, server.copyWith(enabled: true));
      expect(env.repo.lastSaver!.toJson(), {
        'enabled': true,
        'mode': 'image',
        'image_sec': 20,
        'info_sec': 15,
        'show_offline_icon': false,
      });
      expect(find.byType(LcdSaverScreen), findsNothing);
      // 대기는 설정 화면 줄 반짝임.
      expect(find.byKey(LcdSettingsScreen.saverPendingKey), findsOneWidget);
      env.rows.emit('c1', 'acked', 'ok');
      env.feed
          .set(lcdLink(imageKey: 'k1', saver: server.copyWith(enabled: true)));
      await _frames(tester);
      expect(find.byKey(LcdSettingsScreen.saverPendingKey), findsNothing);
      expect(
          tester.widget<Text>(find.byKey(LcdSettingsScreen.saverValueKey)).data,
          '켜짐');
      await _drain(tester);
    });

    testWidgets('편집 중 들어온 실시간 값은 초안을 덮지 않는다', (tester) async {
      final env = await _open(tester, link: lcdLink(imageKey: 'k1'));
      await _tapStep(
          tester, LcdSaverScreen.imageRowKey, VivaStepper.increaseKey);
      expect(_stepValue(tester, LcdSaverScreen.imageRowKey), '2분');
      env.feed.set(lcdLink(
          imageKey: 'k1',
          saver: LcdSaverSettings.defaults.copyWith(imageSec: 300)));
      await _frames(tester);
      expect(_stepValue(tester, LcdSaverScreen.imageRowKey), '2분');
    });

    testWidgets('보호기 대기 중 재진입은 편집 잠금', (tester) async {
      final env = await _open(tester, link: lcdLink(imageKey: 'k1'));
      await tester.tap(find.byKey(LcdSaverScreen.switchKey));
      await tester.pump();
      await tester.tap(find.byKey(LcdSaverScreen.doneKey));
      await _frames(tester);
      // 반짝이는 줄을 다시 누를 수 있다.
      await tester.tap(find.byKey(LcdSettingsScreen.saverRowKey));
      await _frames(tester);
      expect(find.byType(LcdSaverScreen), findsOneWidget);
      expect(find.byKey(LcdSaverScreen.groupPendingKey), findsOneWidget);
      expect(_switchOn(tester), isTrue, reason: '대기 중 목표를 그린다');
      expect(_done(tester), isFalse);
      env.rows.emit('c1', 'acked', 'ok');
      env.feed.set(lcdLink(
          imageKey: 'k1',
          saver: LcdSaverSettings.defaults.copyWith(enabled: true)));
      await _frames(tester);
      expect(find.byKey(LcdSaverScreen.groupPendingKey), findsNothing);
      expect(_switchIgnored(tester), isFalse);
      await _drain(tester);
    });
  });

  group('사진 업로드 (D4·§11-5·§12-2)', () {
    testWidgets('고르면 바로 올리고 "기기로 보내는 중" → ok면 배지가 사라진다', (tester) async {
      final env = await _open(tester, link: lcdLink());
      await _pickAndStart(tester);
      expect(env.pickCalls, 1);
      expect(env.repo.calls, ['image:$kLcdDevice:${_jpeg.length}']);
      expect(find.byKey(LcdSaverScreen.sendingBadgeKey), findsOneWidget);
      expect(find.text('기기로 보내는 중'), findsOneWidget);
      expect(_done(tester), isFalse, reason: '사진 대기 중 완료 막힘');
      // 보내는 중엔 다시 고를 수 없다.
      await tester.tap(find.byKey(LcdSaverScreen.photoBoxKey),
          warnIfMissed: false);
      await tester.pump();
      expect(env.pickCalls, 1);
      expect(_networkImage('https://preview.test/new.jpg'), findsOneWidget,
          reason: '201의 서버 미리보기를 바로 그린다');
      env.repo.snapshot = const LcdStateSnapshot(
          screen: DeviceLcdScreen(imageKey: 'k2'),
          text: DeviceLcdText.unknown,
          previewUrl: 'https://preview.test/k2.jpg');
      env.rows.emit('c1', 'acked', 'ok');
      env.feed.set(lcdLink(imageKey: 'k2'));
      await _frames(tester);
      expect(find.byKey(LcdSaverScreen.sendingBadgeKey), findsNothing);
      expect(find.byKey(LcdSaverScreen.editButtonKey), findsOneWidget);
      expect(_networkImage('https://preview.test/k2.jpg'), findsOneWidget,
          reason: 'key가 바뀌면 GET /lcd로 미리보기를 다시 받는다');
      await _drain(tester);
    });

    testWidgets('photoLost(dl_connect) → 안내 + 칸을 바로 빈 칸으로(서버 key가 그대로여도)',
        (tester) async {
      final env = await _open(tester, link: lcdLink(imageKey: 'k1'));
      await tester.tap(find.byKey(LcdSaverScreen.editButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('사진 교체'));
      await _frames(tester, 3);
      expect(find.byKey(LcdSaverScreen.sendingBadgeKey), findsOneWidget);
      env.rows.emit('c1', 'acked', 'dl_connect');
      await _frames(tester);
      expect(find.text('기기에 사진이 없어요. 다시 올려 주세요'), findsOneWidget);
      expect(find.byKey(LcdSaverScreen.photoAddKey), findsOneWidget);
      expect(find.byKey(LcdSaverScreen.needPhotoNoteKey), findsOneWidget);
      expect(_switchIgnored(tester), isTrue, reason: '사진 없음 규칙');
      // 설정 화면 줄은 보호기가 꺼져 있으니 '꺼짐'(사진 없음 표시는 켜 놨을 때만).
      env.router.pop();
      await _frames(tester);
      expect(
          tester.widget<Text>(find.byKey(LcdSettingsScreen.saverValueKey)).data,
          '꺼짐');
      // 다음 key 변경이면 풀린다.
      env.feed.set(lcdLink(imageKey: 'k3'));
      await _frames(tester);
      expect(
          tester.widget<Text>(find.byKey(LcdSettingsScreen.saverValueKey)).data,
          '꺼짐');
      await _drain(tester);
    });

    testWidgets('no_ack → 옛 사진 그대로 + "기존 사진은 그대로예요"', (tester) async {
      final env = await _open(tester, link: lcdLink(imageKey: 'k1'));
      await tester.tap(find.byKey(LcdSaverScreen.editButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('사진 교체'));
      await _frames(tester, 3);
      env.rows.emit('c1', 'no_ack');
      await _frames(tester);
      expect(find.text('기기 응답을 받지 못했어요. 기존 사진은 그대로예요'), findsOneWidget);
      expect(find.byKey(LcdSaverScreen.photoPreviewKey), findsOneWidget);
      expect(find.byKey(LcdSaverScreen.photoAddKey), findsNothing);
      await _drain(tester);
    });

    testWidgets('5MB를 넘으면 올리지 않고 "사진이 너무 커요"', (tester) async {
      final env = await _open(tester, link: lcdLink(), setUp: (env) {
        env.pick = LcdPhotoPicked(Uint8List(kLcdPhotoMaxBytes + 1));
      });
      await _pickAndStart(tester);
      expect(find.text('사진이 너무 커요'), findsOneWidget);
      expect(env.repo.calls, isEmpty);
      await _drain(tester);
    });

    testWidgets('읽지 못하면 "사진을 읽을 수 없어요", 취소는 조용히', (tester) async {
      final env = await _open(tester, link: lcdLink(), setUp: (env) {
        env.pick = const LcdPhotoUnreadable();
      });
      await _pickAndStart(tester);
      expect(find.text('사진을 읽을 수 없어요'), findsOneWidget);
      await _drain(tester);
      env.pick = const LcdPhotoCancelled();
      await _pickAndStart(tester);
      expect(find.text('사진을 읽을 수 없어요'), findsNothing);
      expect(env.repo.calls, isEmpty);
    });

    testWidgets('화면을 나가도 업로드·대기가 끝까지 가고 결과를 화면 밖에서 알린다', (tester) async {
      final env = await _open(tester,
          link: lcdLink(imageKey: 'k1'),
          setUp: (env) => env.repo.uploadGate = Completer<void>());
      await tester.tap(find.byKey(LcdSaverScreen.editButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('사진 교체'));
      await _frames(tester, 3);
      // 201 전에 설정 화면까지 모두 나간다.
      env.router.go('/');
      await _frames(tester);
      expect(find.byType(LcdSettingsScreen), findsNothing);
      env.repo.uploadGate!.complete();
      await _frames(tester);
      expect(env.repo.calls, ['image:$kLcdDevice:${_jpeg.length}'],
          reason: '업로드는 끝까지 보낸다');
      env.rows.emit('c1', 'acked', 'sha_mismatch');
      await _frames(tester);
      expect(find.text('기기에 사진이 없어요. 다시 올려 주세요'), findsOneWidget);
      final container = ProviderScope.containerOf(
          tester.element(find.byType(Scaffold).first));
      expect(container.read(lcdPhotoLostProvider(kLcdDevice)), 'k1');
      await _drain(tester);
    });
  });

  testWidgets('사진 삭제 — 확인 → 지우는 중 → ok면 빈 칸', (tester) async {
    final env = await _open(tester, link: lcdLink(imageKey: 'k1'));
    await tester.tap(find.byKey(LcdSaverScreen.editButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('사진 삭제'));
    await tester.pumpAndSettle();
    expect(find.text('보호 사진을 삭제할까요?'), findsOneWidget);
    await tester.tap(find.byKey(LcdSaverScreen.deleteConfirmKey));
    await _frames(tester);
    expect(env.repo.calls, ['image_clear:$kLcdDevice']);
    expect(find.text('기기에서 지우는 중'), findsOneWidget);
    env.rows.emit('c1', 'acked', 'ok');
    env.feed.set(lcdLink());
    await _frames(tester);
    expect(find.byKey(LcdSaverScreen.photoAddKey), findsOneWidget);
    expect(find.byKey(LcdSaverScreen.sendingBadgeKey), findsNothing);
    await _drain(tester);
  });

  testWidgets('오프라인 — 스위치·stepper·완료·사진 칸·연필 모두 막고 안내 (§11-6)', (tester) async {
    final env =
        await _open(tester, link: lcdLink(imageKey: 'k1'), online: false);
    expect(find.text('기기가 연결돼 있지 않아 지금은 보낼 수 없어요'), findsOneWidget);
    expect(_switchIgnored(tester), isTrue);
    for (final row in [LcdSaverScreen.imageRowKey, LcdSaverScreen.infoRowKey]) {
      expect(_stepEnabled(tester, row, VivaStepper.increaseKey), isFalse);
    }
    expect(_done(tester), isFalse);
    await tester.tap(find.byKey(LcdSaverScreen.editButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('사진 교체'), findsNothing);
    expect(env.repo.calls, isEmpty);
  });

  testWidgets('오프라인 빈 칸은 눌러도 사진첩이 열리지 않는다', (tester) async {
    final env = await _open(tester, link: lcdLink(), online: false);
    await _pickAndStart(tester);
    expect(env.pickCalls, 0);
  });

  testWidgets('구 펌웨어 — 설정 화면 줄이 흐려 들어갈 수 없다', (tester) async {
    await _open(tester,
        link: lcdLink(support: LcdSupport.needsUpdate), enter: false);
    await tester.tap(find.byKey(LcdSettingsScreen.saverRowKey),
        warnIfMissed: false);
    await _frames(tester);
    expect(find.byType(LcdSaverScreen), findsNothing);
  });

  testWidgets('경로로 바로 열어도 구 펌웨어면 모두 막고 업데이트 안내', (tester) async {
    final env = _Env(LcdLinkFeed(lcdLink(support: LcdSupport.needsUpdate)));
    addTearDown(env.rows.close);
    await pumpLcdRouter(tester,
        initial: lcdSaverPath(kLcdDevice),
        settle: false,
        overrides: lcdOverrides(
            repo: env.repo, rows: env.rows, link: env.feed.stream));
    expect(find.byKey(LcdSaverScreen.updateNoteKey), findsOneWidget);
    expect(_done(tester), isFalse);
    expect(env.repo.getStateCalls, 0);
  });
}
