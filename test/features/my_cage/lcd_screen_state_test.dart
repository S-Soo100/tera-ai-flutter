import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/lcd_screen_state.dart';
import 'package:vivanaut/shared/domain/actuator_marker.dart';
import 'package:vivanaut/shared/domain/control_log.dart';

/// 모듈 화면 설정 데이터·도메인(기획 2026-11-03 §4·§11·§12, 단계 ①).
void main() {
  group('LcdSaverSettings', () {
    test('null(미설정)은 Figma 기본값 — 꺼짐/rotate/60초/10초/아이콘 켬', () {
      final s = LcdSaverSettings.fromJson(null);
      expect(s, LcdSaverSettings.defaults);
      expect(s.enabled, isFalse);
      expect(s.mode, LcdSaverMode.rotate);
      expect(s.imageSec, 60, reason: '가이드 서버 기본 20초가 아니라 Figma 1분');
      expect(s.infoSec, 10);
      expect(s.showOfflineIcon, isTrue);
      expect(LcdSaverSettings.tryParse(null), isNull);
    });

    test('서버 값은 칸에 안 맞아도 그대로 읽는다(20초·7초)', () {
      final s = LcdSaverSettings.fromJson({
        'enabled': true,
        'mode': 'rotate',
        'image_sec': 20,
        'info_sec': 7,
        'show_offline_icon': false,
      });
      expect(s.enabled, isTrue);
      expect(s.imageSec, 20);
      expect(s.infoSec, 7);
      expect(s.showOfflineIcon, isFalse);
    });

    test('모르는 mode는 rotate, image는 image', () {
      expect(LcdSaverSettings.fromJson({'mode': 'slideshow'}).mode,
          LcdSaverMode.rotate);
      expect(LcdSaverSettings.fromJson({'mode': 'image'}).mode,
          LcdSaverMode.image);
    });

    test('필드별 타입 이상·누락은 그 필드만 기본값', () {
      final s = LcdSaverSettings.fromJson({
        'enabled': 'yes',
        'image_sec': -5,
        'info_sec': 15.0,
      });
      expect(s.enabled, isFalse);
      expect(s.imageSec, 60);
      expect(s.infoSec, 15, reason: 'JSON double 정수값은 읽는다');
      expect(s.showOfflineIcon, isTrue);
    });

    test('문자열 JSON(Realtime 대비)도 읽고, 깨진 문자열은 미설정', () {
      expect(
          LcdSaverSettings.tryParse('{"enabled":true,"image_sec":120}')
              ?.imageSec,
          120);
      expect(LcdSaverSettings.tryParse('{not json'), isNull);
      expect(LcdSaverSettings.tryParse(42), isNull);
    });

    test('toJson은 PUT 본문 5필드를 항상 전부 낸다', () {
      final body = LcdSaverSettings.defaults
          .copyWith(enabled: true, mode: LcdSaverMode.image)
          .toJson();
      expect(body, {
        'enabled': true,
        'mode': 'image',
        'image_sec': 60,
        'info_sec': 10,
        'show_offline_icon': true,
      });
      expect(body.keys, hasLength(5));
    });

    test('== / hashCode — 같은 값이면 같다', () {
      final a = LcdSaverSettings.fromJson({'enabled': true, 'image_sec': 120});
      final b = LcdSaverSettings.fromJson({'enabled': true, 'image_sec': 120});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == a.copyWith(infoSec: 15), isFalse);
    });
  });

  group('LcdStepper', () {
    test('사진 노출 60~300초 60초 단위', () {
      const s = kLcdImageSecStepper;
      expect(s.fits(60), isTrue);
      expect(s.fits(300), isTrue);
      expect(s.fits(20), isFalse);
      expect(s.fits(90), isFalse);
      expect(s.fits(360), isFalse);
      expect(s.next(60, 1), 120);
      expect(s.next(120, -1), 60);
    });

    test('범위 끝에선 더 안 가고, 누를 수 없다', () {
      const s = kLcdImageSecStepper;
      expect(s.next(60, -1), 60);
      expect(s.canStep(60, -1), isFalse);
      expect(s.canStep(60, 1), isTrue);
      expect(s.next(300, 1), 300);
      expect(s.canStep(300, 1), isFalse);
      const i = kLcdInfoSecStepper;
      expect(i.next(10, -1), 10);
      expect(i.next(30, 1), 30);
      expect(i.next(25, 1), 30);
      expect(i.next(15, -1), 10);
    });

    test('칸 밖 값은 처음 누를 때 가장 가까운 칸으로 맞추기만 한다', () {
      const s = kLcdImageSecStepper;
      expect(s.next(20, 1), 60, reason: '20초는 최소 칸 1분으로');
      expect(s.next(20, -1), 60);
      expect(s.canStep(20, -1), isTrue, reason: '칸 밖이면 맞추기 위해 누를 수 있다');
      expect(s.next(100, 1), 120);
      expect(s.next(100, -1), 120, reason: '100은 120이 더 가깝다');
      expect(s.next(90, 1), 120, reason: '같은 거리면 누른 방향');
      expect(s.next(90, -1), 60);
      expect(s.next(400, -1), 300, reason: '범위 위는 최대 칸으로');
      const i = kLcdInfoSecStepper;
      expect(i.next(7, 1), 10);
      expect(i.next(12, 1), 10);
      expect(i.next(13, -1), 15);
    });
  });

  group('LcdQuietWindow', () {
    test('서버 TIME·HH:MM 파싱', () {
      expect(LcdQuietWindow.parse('23:00:00', '07:00:00'),
          const LcdQuietWindow(startMinute: 23 * 60, endMinute: 7 * 60));
      expect(LcdQuietWindow.parse('20:00', '8:00'),
          const LcdQuietWindow(startMinute: 1200, endMinute: 480));
      expect(LcdQuietWindow.parseMinute('07:07:30'), 427);
      expect(LcdQuietWindow.parseMinute('24:00'), isNull);
      expect(LcdQuietWindow.parseMinute('12:60'), isNull);
      expect(LcdQuietWindow.parseMinute('noon'), isNull);
      expect(LcdQuietWindow.parseMinute(null), isNull);
      expect(LcdQuietWindow.parse('23:00', null), isNull);
    });

    test('start==end는 유효하지 않다', () {
      final w = LcdQuietWindow.parse('08:00', '08:00:00')!;
      expect(w.isValid, isFalse);
      expect(w.containsMinute(480), isFalse);
      expect(LcdQuietWindow.defaults.isValid, isTrue);
    });

    test('toApi는 KST HH:MM 24시간', () {
      expect(
          LcdQuietWindow.defaults.toApi(), {'start': '20:00', 'end': '08:00'});
      expect(
          const LcdQuietWindow(startMinute: 5, endMinute: 23 * 60 + 50).toApi(),
          {'start': '00:05', 'end': '23:50'});
    });

    test('표시는 H:mm~H:mm, 시 앞 0 없음(20:00~8:00)', () {
      expect(LcdQuietWindow.defaults.displayLabel, '20:00~8:00');
      expect(
          const LcdQuietWindow(startMinute: 0, endMinute: 7 * 60 + 30)
              .displayLabel,
          '0:00~7:30');
    });

    test('자정 넘김: 시작 포함·종료 제외', () {
      const w = LcdQuietWindow.defaults; // 20:00~08:00
      expect(w.containsMinute(20 * 60), isTrue);
      expect(w.containsMinute(23 * 60 + 59), isTrue);
      expect(w.containsMinute(0), isTrue);
      expect(w.containsMinute(7 * 60 + 59), isTrue);
      expect(w.containsMinute(8 * 60), isFalse);
      expect(w.containsMinute(12 * 60), isFalse);
      expect(w.containsMinute(19 * 60 + 59), isFalse);
    });

    test('같은 날 구간', () {
      const w = LcdQuietWindow(startMinute: 9 * 60, endMinute: 17 * 60);
      expect(w.containsMinute(9 * 60), isTrue);
      expect(w.containsMinute(16 * 60 + 59), isTrue);
      expect(w.containsMinute(17 * 60), isFalse);
      expect(w.containsMinute(3 * 60), isFalse);
    });

    test('contains는 폰 시간대와 무관하게 KST(UTC+9)로 판정', () {
      const w = LcdQuietWindow.defaults;
      // 11:30 UTC = 20:30 KST
      expect(w.contains(DateTime.utc(2026, 11, 3, 11, 30)), isTrue);
      // 23:00 UTC = 다음 날 08:00 KST → 종료(제외)
      expect(w.contains(DateTime.utc(2026, 11, 3, 23)), isFalse);
      // 22:59 UTC = 07:59 KST
      expect(w.contains(DateTime.utc(2026, 11, 3, 22, 59)), isTrue);
      // 03:00 UTC = 12:00 KST
      expect(w.contains(DateTime.utc(2026, 11, 3, 3)), isFalse);
      expect(kstMinuteOfDay(DateTime.utc(2026, 11, 3, 15)), 0);
      // 로컬 DateTime도 같은 순간으로 본다.
      final instant = DateTime.utc(2026, 11, 3, 11, 30);
      expect(w.contains(instant.toLocal()), isTrue);
    });
  });

  group('LcdAmPmTime', () {
    test('오전 12시=0시, 오후 12시=12시', () {
      const am12 = LcdAmPmTime(pm: false, hour12: 12, minute: 0);
      const pm12 = LcdAmPmTime(pm: true, hour12: 12, minute: 30);
      expect(am12.hour24, 0);
      expect(am12.minuteOfDay, 0);
      expect(pm12.hour24, 12);
      expect(pm12.minuteOfDay, 12 * 60 + 30);
      expect(LcdAmPmTime.fromMinuteOfDay(0), am12);
      expect(LcdAmPmTime.fromMinuteOfDay(12 * 60 + 30), pm12);
      expect(LcdAmPmTime.fromMinuteOfDay(20 * 60),
          const LcdAmPmTime(pm: true, hour12: 8, minute: 0));
      expect(LcdAmPmTime.fromMinuteOfDay(8 * 60).clockLabel, '8:00');
    });

    test('시 화살표 1~12 순환, 오전/오후는 그대로', () {
      const t = LcdAmPmTime(pm: false, hour12: 12, minute: 0);
      final up = t.stepHour(1);
      expect(up.hour12, 1);
      expect(up.pm, isFalse);
      final down =
          const LcdAmPmTime(pm: true, hour12: 1, minute: 0).stepHour(-1);
      expect(down.hour12, 12);
      expect(down.pm, isTrue);
      expect(const LcdAmPmTime(pm: true, hour12: 11, minute: 0).stepHour(1).pm,
          isTrue);
    });

    test('분 화살표 10분 단위 00~50 순환, 시는 안 바뀜', () {
      const t = LcdAmPmTime(pm: true, hour12: 8, minute: 50);
      final up = t.stepMinute(1);
      expect(up.minute, 0);
      expect(up.hour12, 8);
      expect(
          const LcdAmPmTime(pm: true, hour12: 8, minute: 0)
              .stepMinute(-1)
              .minute,
          50);
      expect(stepQuietMinute(20, 1), 30);
      expect(stepQuietMinute(20, -1), 10);
    });

    test('칸 밖 분은 처음 누를 때 가까운 10분으로', () {
      expect(stepQuietMinute(7, 1), 10);
      expect(stepQuietMinute(7, -1), 10);
      expect(stepQuietMinute(3, 1), 0);
      expect(stepQuietMinute(5, 1), 10, reason: '같은 거리면 누른 방향');
      expect(stepQuietMinute(5, -1), 0);
      expect(stepQuietMinute(57, 1), 50, reason: '00으로 넘기지 않는다');
      expect(stepQuietMinute(54, -1), 50);
    });

    test('오전/오후 두 칸 → 구간', () {
      final w = LcdQuietWindow.fromAmPm(
          const LcdAmPmTime(pm: true, hour12: 8, minute: 0),
          const LcdAmPmTime(pm: false, hour12: 8, minute: 0));
      expect(w, LcdQuietWindow.defaults);
      expect(w.startAmPm.pm, isTrue);
      expect(w.endAmPm.pm, isFalse);
    });

    test('withPm은 오전/오후만 바꾼다', () {
      const t = LcdAmPmTime(pm: false, hour12: 12, minute: 10);
      expect(t.withPm(true).minuteOfDay, 12 * 60 + 10);
    });
  });

  group('DeviceLcdScreen', () {
    test('lcd_power null이면 켜짐, 예약은 둘 다 있어야', () {
      final s = DeviceLcdScreen.fromJson({
        'lcd_power': null,
        'lcd_quiet_start': '23:00:00',
        'lcd_quiet_end': null,
      });
      expect(s.power, isTrue);
      expect(s.quiet, isNull);
      expect(s.saver, isNull);
      expect(s.saverOrDefault, LcdSaverSettings.defaults);
      expect(s.hasImage, isFalse);
      expect(s, DeviceLcdScreen.unknown);
    });

    test('가이드 예시 행 전체', () {
      final s = DeviceLcdScreen.fromJson({
        'lcd_power': false,
        'lcd_quiet_start': '23:00:00',
        'lcd_quiet_end': '07:00:00',
        'lcd_saver': {
          'enabled': true,
          'mode': 'rotate',
          'image_sec': 20,
          'info_sec': 10,
          'show_offline_icon': true
        },
        'lcd_image_key': 'lcd/abc/3f9a1c2e',
        'lcd_image_set_at': '2026-11-03T02:10:00+00:00',
        'lcd_updated_at': '2026-11-03T02:10:00+00:00',
        'lcd_screen_on': true,
        'lcd_override_until': '2026-11-03T23:00:00Z',
      });
      expect(s.power, isFalse);
      expect(s.quiet, const LcdQuietWindow(startMinute: 1380, endMinute: 420));
      expect(s.saver?.imageSec, 20);
      expect(s.imageKey, 'lcd/abc/3f9a1c2e');
      expect(s.hasImage, isTrue);
      expect(s.imageSetAt, DateTime.utc(2026, 11, 3, 2, 10));
      expect(s.screenOn, isTrue);
      expect(s.overrideUntil, DateTime.utc(2026, 11, 3, 23));
    });

    test('start==end 예약·빈 사진 키는 없는 것으로', () {
      final s = DeviceLcdScreen.fromJson({
        'lcd_quiet_start': '08:00:00',
        'lcd_quiet_end': '08:00:00',
        'lcd_image_key': '',
      });
      expect(s.quiet, isNull);
      expect(s.imageKey, isNull);
    });

    test('신 컬럼은 관대하게 — 문자열 bool·못 읽는 시각은 null', () {
      expect(DeviceLcdScreen.fromJson({'lcd_screen_on': 'false'}).screenOn,
          isFalse);
      expect(DeviceLcdScreen.fromJson({'lcd_screen_on': 1}).screenOn, isTrue);
      expect(DeviceLcdScreen.fromJson({'lcd_screen_on': 'maybe'}).screenOn,
          isNull);
      expect(
          DeviceLcdScreen.fromJson({'lcd_override_until': 'soon'})
              .overrideUntil,
          isNull);
      expect(
          DeviceLcdScreen.fromJson({'lcd_override_until': 1730000000})
              .overrideUntil,
          isNull);
    });

    test('전원 스위치 — override 펌웨어 + 화면 보고가 있을 때만 lcd_screen_on', () {
      final reported =
          DeviceLcdScreen.fromJson({'lcd_power': true, 'lcd_screen_on': false});
      expect(reported.switchOn(lcdOverride: true), isFalse);
      expect(reported.switchOn(lcdOverride: false), isTrue);
      final notYet = DeviceLcdScreen.fromJson({'lcd_power': false});
      expect(notYet.switchOn(lcdOverride: true), isFalse,
          reason: '첫 보고 전엔 구 규칙(lcd_power)');
    });

    test('inQuietAt — KST로 예약 시간 안', () {
      final s = DeviceLcdScreen.fromJson(
          {'lcd_quiet_start': '20:00:00', 'lcd_quiet_end': '08:00:00'});
      expect(s.inQuietAt(DateTime.utc(2026, 11, 3, 13)), isTrue); // 22시 KST
      expect(s.inQuietAt(DateTime.utc(2026, 11, 3, 3)), isFalse); // 12시 KST
      expect(DeviceLcdScreen.unknown.inQuietAt(DateTime.utc(2026, 11, 3, 13)),
          isFalse);
    });
  });

  group('LcdSupport (§12-4)', () {
    test('4갈래', () {
      expect(LcdSupport.fromCapabilities({'hub': true, 'lcd': false}),
          LcdSupport.noLcd);
      expect(LcdSupport.fromCapabilities({'hub': true, 'lcd_saver': true}),
          LcdSupport.hub,
          reason: '허브는 lcd_saver가 있어도 허브');
      expect(LcdSupport.fromCapabilities({'hub': true}), LcdSupport.hub);
      expect(LcdSupport.fromCapabilities({'lcd_saver': true}),
          LcdSupport.supported);
      expect(LcdSupport.fromCapabilities({'board': 'relay'}),
          LcdSupport.needsUpdate);
      expect(LcdSupport.fromCapabilities(null), LcdSupport.needsUpdate);
      expect(LcdSupport.fromCapabilities({'lcd_saver': 'true'}),
          LcdSupport.needsUpdate,
          reason: 'true(bool)만 지원');
    });

    test('lcd_override는 true일 때만', () {
      expect(lcdOverrideFromCapabilities({'lcd_override': true}), isTrue);
      expect(lcdOverrideFromCapabilities({'lcd_override': 1}), isFalse);
      expect(lcdOverrideFromCapabilities(null), isFalse);
    });

    test('Device는 capabilities에서 판정한다', () {
      final d = Device.fromJson({
        'id': 'd1',
        'capabilities': {'lcd_saver': true, 'lcd_override': true},
        'lcd_power': false,
      });
      expect(d.lcdSupport, LcdSupport.supported);
      expect(d.lcdOverride, isTrue);
      expect(d.lcdScreen.power, isFalse);
    });
  });

  group('classifyLcdCommand', () {
    test('결과 전 — pending/sent/null, acked인데 result 없음', () {
      expect(classifyLcdCommand(null, null), LcdCommandOutcome.pending);
      expect(classifyLcdCommand('pending', null), LcdCommandOutcome.pending);
      expect(classifyLcdCommand('sent', null), LcdCommandOutcome.pending);
      expect(classifyLcdCommand('acked', null), LcdCommandOutcome.pending);
      expect(LcdCommandOutcome.pending.isFinal, isFalse);
    });

    test('ok는 acked일 때만', () {
      expect(classifyLcdCommand('acked', 'ok'), LcdCommandOutcome.ok);
      expect(classifyLcdCommand('rejected', 'ok'), LcdCommandOutcome.failed);
    });

    test('미전달·무응답', () {
      expect(
          classifyLcdCommand('expired', null), LcdCommandOutcome.notDelivered);
      expect(classifyLcdCommand('acked', 'expired'),
          LcdCommandOutcome.notDelivered);
      expect(classifyLcdCommand('rejected', 'device_offline'),
          LcdCommandOutcome.notDelivered);
      expect(classifyLcdCommand('skipped', 'device_offline'),
          LcdCommandOutcome.notDelivered);
      expect(classifyLcdCommand('no_ack', null), LcdCommandOutcome.noAck);
      expect(classifyLcdCommand('lost', null), LcdCommandOutcome.noAck);
    });

    test('구 펌웨어·재페어링·잘못된 요청', () {
      expect(classifyLcdCommand('acked', 'unknown_action'),
          LcdCommandOutcome.needsUpdate);
      expect(classifyLcdCommand('rejected', 'rejected_unknown_action'),
          LcdCommandOutcome.needsUpdate,
          reason: 'rejected_ 접두사는 뗀다');
      expect(classifyLcdCommand('acked', 'no_token'),
          LcdCommandOutcome.needsRepair);
      expect(classifyLcdCommand('acked', 'bad_request'),
          LcdCommandOutcome.badRequest);
    });

    test('사진 실패 — 사진 없음 vs 옛 사진 유지', () {
      for (final r in [
        'dl_connect',
        'dl_read',
        'http_401',
        'http_404',
        'http_500',
        'sha_mismatch',
        'flash_write',
      ]) {
        expect(classifyLcdCommand('acked', r), LcdCommandOutcome.photoLost,
            reason: r);
      }
      expect(classifyLcdCommand('acked', 'busy'), LcdCommandOutcome.photoBusy);
    });

    test('그 외는 failed', () {
      expect(classifyLcdCommand('acked', 'error'), LcdCommandOutcome.failed);
      expect(classifyLcdCommand('rejected', null), LcdCommandOutcome.failed);
      expect(classifyLcdCommand('skipped', null), LcdCommandOutcome.failed);
    });
  });

  group('DeviceLinkStatus', () {
    Map<String, dynamic> row() => {
          'id': 'd1',
          'is_online': true,
          'last_seen_at': '2026-11-03T02:10:00+00:00',
          'lcd_text': '밥 6시',
          'lcd_text_updated_at': '2026-11-03T01:00:00+00:00',
          'lcd_power': true,
          'lcd_quiet_start': '20:00:00',
          'lcd_quiet_end': '08:00:00',
          'lcd_saver': {
            'enabled': true,
            'mode': 'rotate',
            'image_sec': 60,
            'info_sec': 10,
            'show_offline_icon': true
          },
          'lcd_image_key': 'lcd/d1/abc',
          'capabilities': {'lcd_saver': true, 'board': 'relay'},
        };

    test('3초마다 같은 행이 오면 같은 값(중복 방출 거름)', () {
      final a = DeviceLinkStatus.fromJson(row());
      final b = DeviceLinkStatus.fromJson(row());
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.lcdSupport, LcdSupport.supported);
      expect(a.lcdScreen.saver?.enabled, isTrue);
    });

    test('LCD 판정과 무관한 capabilities 변화는 같은 값', () {
      final a = DeviceLinkStatus.fromJson(row());
      final b = DeviceLinkStatus.fromJson(
          row()..['capabilities'] = {'lcd_saver': true, 'board': 'mosfet'});
      expect(a, b);
    });

    test('OTA로 지원이 켜지면 다른 값', () {
      final before = DeviceLinkStatus.fromJson(row()..['capabilities'] = null);
      final after = DeviceLinkStatus.fromJson(row());
      expect(before.lcdSupport, LcdSupport.needsUpdate);
      expect(before == after, isFalse);
    });

    test('LCD 설정이 바뀌면 다른 값', () {
      final a = DeviceLinkStatus.fromJson(row());
      expect(a == DeviceLinkStatus.fromJson(row()..['lcd_power'] = false),
          isFalse);
      expect(a == DeviceLinkStatus.fromJson(row()..['lcd_image_key'] = null),
          isFalse);
      expect(
          a ==
              DeviceLinkStatus.fromJson(row()
                ..['lcd_saver'] = {
                  'enabled': true,
                  'mode': 'rotate',
                  'image_sec': 120,
                  'info_sec': 10,
                  'show_offline_icon': true
                }),
          isFalse);
    });

    test('목록 스냅샷(Device)과 실시간 행이 같은 값', () {
      expect(DeviceLinkStatus.of(Device.fromJson(row())),
          DeviceLinkStatus.fromJson(row()));
    });
  });

  // 기획 §4: 새 action 6종은 차트 마커·제어 기록에 넣지 않는다(lcd_bitmap과 같은 규칙).
  test('새 LCD action 6종은 차트 마커·제어 기록에서 무시된다', () {
    const actions = [
      'lcd_power',
      'lcd_quiet',
      'lcd_quiet_clear',
      'lcd_saver',
      'lcd_image',
      'lcd_image_clear',
    ];
    final rows = [
      for (final (i, a) in actions.indexed)
        <String, dynamic>{
          'id': 'c$i',
          'action': a,
          'status': 'acked',
          'result': 'ok',
          'issued_at': '2026-11-03T02:1$i:00Z',
        },
    ];
    expect(ActuatorMarker.fromCommands(rows), isEmpty);
    expect(buildControlLog(commandRows: rows, buckets: const []), isEmpty);
    for (final a in actions) {
      expect(controlLogActions(), isNot(contains(a)));
      expect(isControlLogStart(a), isFalse);
    }
  });
}
