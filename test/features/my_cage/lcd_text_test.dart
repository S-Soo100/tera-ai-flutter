import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/lcd_text.dart';

void main() {
  final t0 = DateTime.utc(2026, 10, 7, 3);
  final now = DateTime(2026, 10, 7, 12);

  group('DeviceLcdText.fromJson', () {
    test('서버 값과 확정 시각을 읽는다', () {
      final lcd = DeviceLcdText.fromJson({
        'lcd_text': '도도네 집',
        'lcd_text_updated_at': '2026-10-07T03:00:00+00:00',
      });
      expect(lcd.text, '도도네 집');
      expect(lcd.updatedAt, t0);
      expect(lcd.confirmed, isTrue);
    });

    test('컬럼이 없는 서버면 모름', () {
      expect(DeviceLcdText.fromJson({}), DeviceLcdText.unknown);
      expect(Device.fromJson({'id': 'd1'}).lcd.confirmed, isFalse);
    });

    test('확정된 기본 문구 — 시각만 있고 문구는 null', () {
      final lcd = DeviceLcdText.fromJson(
          {'lcd_text': null, 'lcd_text_updated_at': '2026-10-07T03:00:00Z'});
      expect(lcd.confirmed, isTrue);
      expect(lcd.text, isNull);
    });
  });

  group('resolveLcdText', () {
    test('서버 확정값이 휴대폰 저장값보다 우선', () {
      expect(
          resolveLcdText(
              server: DeviceLcdText(text: '서버 문구', updatedAt: t0),
              pending: null,
              phone: '폰 문구',
              now: now),
          '서버 문구');
    });

    test('서버가 확인한 기본 문구면 휴대폰 저장값을 쓰지 않는다', () {
      expect(
          resolveLcdText(
              server: DeviceLcdText(text: null, updatedAt: t0),
              pending: null,
              phone: '폰 문구',
              now: now),
          isNull);
    });

    test('서버가 모르면(배포 전 이력) 휴대폰 저장값', () {
      expect(
          resolveLcdText(
              server: DeviceLcdText.unknown,
              pending: null,
              phone: '폰 문구',
              now: now),
          '폰 문구');
    });

    test('방금 보낸 문구는 ACK 전까지 먼저 보인다', () {
      final pending = PendingLcdText('새 문구',
          sentAt: now.subtract(const Duration(seconds: 2)), baseline: t0);
      expect(
          resolveLcdText(
              server: DeviceLcdText(text: '옛 문구', updatedAt: t0),
              pending: pending,
              phone: null,
              now: now),
          '새 문구');
    });

    test('서버 값이 바뀌면(ACK) 서버 값 — 시계 비교 없이 기준점으로 판단', () {
      final pending = PendingLcdText('새 문구',
          sentAt: now.subtract(const Duration(seconds: 2)), baseline: t0);
      // 폰 시계가 어긋나 서버 시각이 보낸 시각보다 "앞"이어도 바뀌었으면 서버 값.
      final acked = DeviceLcdText(
          text: '새 문구', updatedAt: t0.add(const Duration(seconds: 1)));
      expect(
          resolveLcdText(
              server: acked, pending: pending, phone: null, now: now),
          '새 문구');
      final other = DeviceLcdText(
          text: '다른 폰 문구', updatedAt: t0.add(const Duration(seconds: 1)));
      expect(
          resolveLcdText(
              server: other, pending: pending, phone: null, now: now),
          '다른 폰 문구');
    });

    test('30초 안에 ACK가 없으면 서버 값으로 돌아간다(기기에 안 갔다)', () {
      final pending = PendingLcdText('새 문구',
          sentAt: now.subtract(kLcdPendingWindow), baseline: t0);
      expect(
          resolveLcdText(
              server: DeviceLcdText(text: '옛 문구', updatedAt: t0),
              pending: pending,
              phone: '새 문구',
              now: now),
          '옛 문구');
    });
  });
}
