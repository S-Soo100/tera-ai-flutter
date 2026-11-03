import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/network/terra_rest_client.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/lcd_screen_state.dart';
import 'package:vivanaut/features/my_cage/domain/lcd_text.dart';
import 'package:vivanaut/features/my_cage/data/lcd_repository.dart';
import 'package:vivanaut/features/my_cage/presentation/lcd_screen_providers.dart';

import 'lcd_fixtures.dart';

const _power = (kLcdDevice, LcdCommandKind.power);
const _quiet = (kLcdDevice, LcdCommandKind.quiet);
const _night = LcdQuietWindow(startMinute: 22 * 60, endMinute: 6 * 60);

/// fakeAsync 안에서 컨테이너를 만들고 화면처럼 provider를 붙잡는다.
class _Harness {
  _Harness({
    DeviceLinkStatus? initial,
    Future<DeviceLinkStatus?> Function()? refresh,
    MemoryQuietStore? quietStore,
    String? account = 'u1',
  }) : quietStore = quietStore ?? MemoryQuietStore() {
    container = ProviderContainer(
        overrides: lcdOverrides(
            repo: repo,
            rows: rows,
            link: link.stream,
            refresh: refresh,
            quietStore: this.quietStore,
            account: account));
    if (initial != null) link.add(initial);
    container.listen(lcdScreenViewProvider(kLcdDevice), (_, __) {});
    container.listen(lcdQuietTimeProvider(kLcdDevice), (_, __) {});
    container.listen(lcdCommandProvider(_power), (_, __) {});
    container.listen(lcdCommandProvider(_quiet), (_, __) {});
  }

  final repo = FakeLcdRepo();
  final rows = CommandRows();
  final link = StreamController<DeviceLinkStatus?>();
  final MemoryQuietStore quietStore;
  late final ProviderContainer container;

  AsyncValue<LcdScreenView> get view =>
      container.read(lcdScreenViewProvider(kLcdDevice));
  LcdCommandState command(LcdCommandKey key) =>
      container.read(lcdCommandProvider(key));
  LcdCommandController runner(LcdCommandKey key) =>
      container.read(lcdCommandProvider(key).notifier);

  void dispose() => container.dispose();
}

void main() {
  group('상태 읽기', () {
    test('지원 기기 — 스냅샷과 실시간 값으로 그린다(실시간이 진실)', () {
      fakeAsync((async) {
        final h = _Harness(initial: lcdLink(power: false, quiet: _night));
        h.repo.snapshot = const LcdStateSnapshot(
            screen: DeviceLcdScreen(power: true),
            text: DeviceLcdText.unknown,
            previewUrl: 'https://preview');
        async.elapse(Duration.zero);
        final view = h.view.requireValue;
        expect(view.screen.power, isFalse, reason: '스냅샷이 아니라 실시간 값');
        expect(view.screen.quiet, _night);
        expect(view.previewUrl, 'https://preview');
        expect(h.repo.getStateCalls, 1);
        h.dispose();
      });
    });

    test('구 펌웨어·허브는 GET /lcd 없이 기기 행만으로 그린다', () {
      fakeAsync((async) {
        final h = _Harness(initial: lcdLink(support: LcdSupport.needsUpdate));
        async.elapse(Duration.zero);
        expect(h.view.requireValue.support, LcdSupport.needsUpdate);
        expect(h.repo.getStateCalls, 0);
        h.dispose();
      });
    });

    test('진입 시 재조회한 capabilities가 목록 값보다 나중이면 그것을 쓴다', () {
      fakeAsync((async) {
        final refresh = Completer<DeviceLinkStatus?>();
        final h = _Harness(
            initial: lcdLink(support: LcdSupport.needsUpdate),
            refresh: () => refresh.future);
        async.elapse(Duration.zero);
        expect(h.view.requireValue.support, LcdSupport.needsUpdate);
        refresh.complete(lcdLink(support: LcdSupport.supported));
        async.elapse(Duration.zero);
        expect(h.view.requireValue.support, LcdSupport.supported,
            reason: 'OTA 직후 목록 캐시가 오래됐어도 열린 화면이 활성화된다');
        h.dispose();
      });
    });

    test('실시간 값이 없고 재조회도 실패하면 오류', () {
      fakeAsync((async) {
        final h = _Harness(refresh: () async => throw Exception('net'));
        async.elapse(Duration.zero);
        expect(h.view.hasError, isTrue);
        h.dispose();
      });
    });
  });

  group('명령 실행기', () {
    test('ok 뒤 기기 확정값이 목표와 같아질 때까지 목표를 유지한다', () {
      fakeAsync((async) {
        final h = _Harness(initial: lcdLink(power: true));
        async.elapse(Duration.zero);
        unawaited(h.runner(_power).run(const LcdPowerTarget(false)));
        async.elapse(Duration.zero);
        expect(h.repo.calls, ['power:d1:false']);
        expect(h.command(_power).pending, isTrue);
        expect((h.command(_power).target! as LcdPowerTarget).on, isFalse);

        h.rows.emit('c1', 'acked', 'ok');
        async.elapse(Duration.zero);
        expect(h.command(_power).pending, isTrue,
            reason: 'devices가 아직 켜짐 — 스위치가 뒤로 튀지 않게 목표 유지');

        h.link.add(lcdLink(power: false));
        async.elapse(Duration.zero);
        expect(h.command(_power).pending, isFalse);
        expect(h.command(_power).result, LcdCommandResult.ok);
        expect(h.command(_power).round, 1);
        h.dispose();
      });
    });

    test('ok 뒤 확정값이 3초 안에 안 오면 그래도 끝낸다', () {
      fakeAsync((async) {
        final h = _Harness(initial: lcdLink(power: true));
        async.elapse(Duration.zero);
        unawaited(h.runner(_power).run(const LcdPowerTarget(false)));
        async.elapse(Duration.zero);
        h.rows.emit('c1', 'acked', 'ok');
        async.elapse(Duration.zero);
        async.elapse(const Duration(milliseconds: 2900));
        expect(h.command(_power).pending, isTrue);
        async.elapse(const Duration(milliseconds: 200));
        expect(h.command(_power).pending, isFalse);
        expect(h.command(_power).result, LcdCommandResult.ok);
        h.dispose();
      });
    });

    test('신 펌웨어는 lcd_screen_on으로 목표 일치를 본다', () {
      fakeAsync((async) {
        final h = _Harness(
            initial: lcdLink(power: true, screenOn: false, lcdOverride: true));
        async.elapse(Duration.zero);
        expect(h.view.requireValue.switchOn, isFalse);
        unawaited(h.runner(_power).run(const LcdPowerTarget(true)));
        async.elapse(Duration.zero);
        h.rows.emit('c1', 'acked', 'ok');
        async.elapse(Duration.zero);
        expect(h.command(_power).pending, isTrue);
        h.link.add(lcdLink(power: true, screenOn: true, lcdOverride: true));
        async.elapse(Duration.zero);
        expect(h.command(_power).pending, isFalse);
        h.dispose();
      });
    });

    test('8초 무응답이면 늦어요(대기 유지), 서버 no_ack에서 원위치', () {
      fakeAsync((async) {
        final h = _Harness(initial: lcdLink(power: true));
        async.elapse(Duration.zero);
        unawaited(h.runner(_power).run(const LcdPowerTarget(false)));
        async.elapse(Duration.zero);
        async.elapse(const Duration(seconds: 7));
        expect(h.command(_power).slow, isFalse);
        async.elapse(const Duration(seconds: 1));
        expect(h.command(_power).slow, isTrue);
        expect(h.command(_power).pending, isTrue, reason: '대기는 유지');

        h.rows.emit('c1', 'no_ack');
        async.elapse(Duration.zero);
        final s = h.command(_power);
        expect(s.pending, isFalse, reason: '목표를 지워 스위치가 원위치');
        expect(s.slow, isFalse);
        expect(s.result, LcdCommandResult.noAck);
        expect(
            s.result!.messageKeyFor(LcdCommandKind.power), 'lcd_result_no_ack');
        expect(h.view.requireValue.switchOn, isTrue);
        h.dispose();
      });
    });

    test('expired·device_offline은 "기기에 전달되지 않았어요"', () {
      fakeAsync((async) {
        final h = _Harness(initial: lcdLink());
        async.elapse(Duration.zero);
        unawaited(h.runner(_power).run(const LcdPowerTarget(false)));
        async.elapse(Duration.zero);
        h.rows.emit('c1', 'expired');
        async.elapse(Duration.zero);
        expect(h.command(_power).result, LcdCommandResult.notDelivered);
        expect(h.command(_power).result!.messageKeyFor(LcdCommandKind.power),
            'lcd_result_not_delivered');

        unawaited(h.runner(_power).run(const LcdPowerTarget(false)));
        async.elapse(Duration.zero);
        h.rows.emit('c2', 'skipped', 'device_offline');
        async.elapse(Duration.zero);
        expect(h.command(_power).result, LcdCommandResult.notDelivered);
        expect(h.command(_power).round, 2);
        h.dispose();
      });
    });

    test('Realtime이 끝내 안 오면 40초에 응답 없음으로 끝낸다', () {
      fakeAsync((async) {
        final h = _Harness(initial: lcdLink());
        async.elapse(Duration.zero);
        unawaited(h.runner(_power).run(const LcdPowerTarget(false)));
        async.elapse(Duration.zero);
        async.elapse(kLcdCommandGiveUpAfter);
        expect(h.command(_power).pending, isFalse);
        expect(h.command(_power).result, LcdCommandResult.noAck);
        h.dispose();
      });
    });

    test('REST 실패 — 구 펌웨어·미배포·그 밖의 실패를 구분한다', () {
      fakeAsync((async) {
        final h = _Harness(initial: lcdLink());
        async.elapse(Duration.zero);
        for (final (error, result, key) in [
          (
            unsupportedFirmware,
            LcdCommandResult.needsUpdate,
            'lcd_result_needs_update'
          ),
          (
            const TerraRestException(404, 'Not Found'),
            LcdCommandResult.unavailable,
            'lcd_result_unavailable'
          ),
          (
            const TerraRestException(503, 'down'),
            LcdCommandResult.sendFailed,
            'lcd_result_send_failed'
          ),
          (
            const TerraRestException(422, 'bad'),
            LcdCommandResult.sendFailed,
            'lcd_result_send_failed'
          ),
          (
            Exception('socket'),
            LcdCommandResult.sendFailed,
            'lcd_result_send_failed'
          ),
        ]) {
          h.repo.error = error;
          unawaited(h.runner(_power).run(const LcdPowerTarget(false)));
          async.elapse(Duration.zero);
          expect(h.command(_power).pending, isFalse);
          expect(h.command(_power).result, result, reason: '$error');
          expect(h.command(_power).result!.messageKeyFor(LcdCommandKind.power),
              key);
        }
        h.dispose();
      });
    });

    test('같은 종류는 한 번에 하나 — 대기 중 두 번째는 보내지 않는다', () {
      fakeAsync((async) {
        final h = _Harness(initial: lcdLink());
        async.elapse(Duration.zero);
        unawaited(h.runner(_power).run(const LcdPowerTarget(false)));
        unawaited(h.runner(_power).run(const LcdPowerTarget(true)));
        async.elapse(Duration.zero);
        expect(h.repo.calls, ['power:d1:false']);
        // 다른 종류는 따로 간다.
        unawaited(h.runner(_quiet).run(const LcdQuietTarget.set(_night)));
        async.elapse(Duration.zero);
        expect(h.repo.calls, ['power:d1:false', 'quiet:d1:22:00~6:00']);
        h.dispose();
      });
    });

    test('구독 전에 이미 끝난 명령도 회수한다(첫 조회 값)', () {
      fakeAsync((async) {
        final h = _Harness(initial: lcdLink());
        async.elapse(Duration.zero);
        // 첫 조회가 곧바로 실패 결과를 돌려준 경우.
        h.rows.emit('c1', 'acked', 'unknown_action');
        unawaited(h.runner(_power).run(const LcdPowerTarget(false)));
        async.elapse(Duration.zero);
        expect(h.command(_power).result, LcdCommandResult.needsUpdate);
        h.dispose();
      });
    });
  });

  group('꺼짐 예약 시간', () {
    test('서버 값이 있으면 서버 — 폰 기억도 덮어쓴다', () {
      fakeAsync((async) {
        final store = MemoryQuietStore()
          ..values['u1/d1'] =
              const LcdQuietWindow(startMinute: 21 * 60, endMinute: 7 * 60);
        final h = _Harness(initial: lcdLink(quiet: _night), quietStore: store);
        async.elapse(Duration.zero);
        expect(h.container.read(lcdQuietTimeProvider(kLcdDevice)), _night);
        expect(store.values['u1/d1'], _night);
        h.dispose();
      });
    });

    test('서버 값이 없으면 폰 기억 → 없으면 20:00~08:00', () {
      fakeAsync((async) {
        const remembered =
            LcdQuietWindow(startMinute: 21 * 60, endMinute: 7 * 60);
        final store = MemoryQuietStore()..values['u1/d1'] = remembered;
        final h = _Harness(initial: lcdLink(), quietStore: store);
        async.elapse(Duration.zero);
        expect(h.container.read(lcdQuietTimeProvider(kLcdDevice)), remembered);
        h.dispose();

        final empty = _Harness(initial: lcdLink());
        async.elapse(Duration.zero);
        expect(empty.container.read(lcdQuietTimeProvider(kLcdDevice)),
            LcdQuietWindow.defaults);
        empty.dispose();
      });
    });

    test('예약 해제가 성공하면 직전 시간을 폰에 기억한다', () {
      fakeAsync((async) {
        final store = MemoryQuietStore();
        final h = _Harness(initial: lcdLink(quiet: _night), quietStore: store);
        async.elapse(Duration.zero);
        store.values.clear(); // 서버 덮어쓰기와 구분하려고 비운다.
        unawaited(
            h.runner(_quiet).run(const LcdQuietTarget.clear(previous: _night)));
        async.elapse(Duration.zero);
        expect(h.repo.calls, ['quiet_clear:d1']);
        expect(store.values, isEmpty, reason: '성공 전엔 기억하지 않는다');
        h.rows.emit('c1', 'acked', 'ok');
        h.link.add(lcdLink());
        async.elapse(Duration.zero);
        expect(h.command(_quiet).result, LcdCommandResult.ok);
        expect(store.values['u1/d1'], _night);
        expect(h.container.read(lcdQuietTimeProvider(kLcdDevice)), _night,
            reason: '예약을 꺼도 시간 줄은 마지막 시간');
        h.dispose();
      });
    });

    test('예약 해제가 실패하면 기억하지 않는다', () {
      fakeAsync((async) {
        final store = MemoryQuietStore();
        final h = _Harness(initial: lcdLink(quiet: _night), quietStore: store);
        async.elapse(Duration.zero);
        store.values.clear();
        unawaited(
            h.runner(_quiet).run(const LcdQuietTarget.clear(previous: _night)));
        async.elapse(Duration.zero);
        h.rows.emit('c1', 'no_ack');
        async.elapse(Duration.zero);
        expect(store.values, isEmpty);
        h.dispose();
      });
    });

    test('초안 — 시작≠종료 AND 바뀜일 때만 완료', () {
      fakeAsync((async) {
        final h = _Harness(initial: lcdLink());
        async.elapse(Duration.zero);
        final sub =
            h.container.listen(lcdQuietDraftProvider(kLcdDevice), (_, __) {});
        final draft =
            h.container.read(lcdQuietDraftProvider(kLcdDevice).notifier);
        LcdQuietDraftState s() =>
            h.container.read(lcdQuietDraftProvider(kLcdDevice));
        expect(s().window, LcdQuietWindow.defaults);
        expect(s().canSubmit, isFalse, reason: '바뀐 게 없다');
        draft.stepHour(true, 1); // 오후 8 → 9
        expect(s().window.startMinute, 21 * 60);
        expect(s().canSubmit, isTrue);
        draft.stepHour(true, -1);
        expect(s().canSubmit, isFalse, reason: '원래대로 돌아오면 바뀜 아님');
        // 시작=종료(오전 8:00)면 막힌다.
        draft.setPm(true, false);
        expect(s().window.startMinute, 8 * 60);
        expect(s().canSubmit, isFalse);
        sub.close();
        h.dispose();
      });
    });
  });

  test('사진 실패 문구 — 기기에 옛 사진이 남는 실패는 "기존 사진은 그대로예요"', () {
    const image = LcdCommandKind.image;
    expect(LcdCommandResult.photoLost.messageKeyFor(image), 'lcd_photo_lost');
    expect(LcdCommandResult.busy.messageKeyFor(image), 'lcd_photo_busy');
    expect(LcdCommandResult.needsRepair.messageKeyFor(image),
        'lcd_photo_no_token');
    expect(LcdCommandResult.sendFailed.messageKeyFor(image),
        'lcd_photo_send_failed');
    expect(LcdCommandResult.noAck.messageKeyFor(image), 'lcd_photo_no_ack');
    expect(LcdCommandResult.ok.messageKeyFor(image), isNull);
    expect(LcdCommandResult.ofOutcome(LcdCommandOutcome.badRequest),
        LcdCommandResult.sendFailed);
  });
}
