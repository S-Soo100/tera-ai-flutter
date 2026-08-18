import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/home/domain/night_progress.dart';

void main() {
  group('NightProgress — 22:00~06:00 밤 창', () {
    test('낮(13:00)은 진행 중이 아니고 다음 밤은 오늘 22:00', () {
      final p = NightProgress.at(DateTime(2026, 8, 18, 13));
      expect(p.isRunning, isFalse);
      expect(p.progress, 0);
      expect(p.start, DateTime(2026, 8, 18, 22));
      expect(p.end, DateTime(2026, 8, 19, 6));
      expect(p.untilNext, const Duration(hours: 9));
    });

    test('밤 시작 직후(22:00)는 진행 0', () {
      final p = NightProgress.at(DateTime(2026, 8, 18, 22));
      expect(p.isRunning, isTrue);
      expect(p.progress, 0);
      expect(p.untilNext, Duration.zero);
    });

    test('자정 넘은 02:00은 어제 22:00에 시작한 밤의 절반', () {
      final p = NightProgress.at(DateTime(2026, 8, 19, 2));
      expect(p.isRunning, isTrue);
      expect(p.start, DateTime(2026, 8, 18, 22));
      expect(p.end, DateTime(2026, 8, 19, 6));
      expect(p.progress, closeTo(0.5, 1e-9));
    });

    test('06:00 정각은 밤이 끝난 낮 — 다음 밤까지 16시간', () {
      final p = NightProgress.at(DateTime(2026, 8, 19, 6));
      expect(p.isRunning, isFalse);
      expect(p.untilNext, const Duration(hours: 16));
      expect(p.start, DateTime(2026, 8, 19, 22));
    });

    test('월말 경계(8/31 23:00)에서 끝은 9/1 06:00', () {
      final p = NightProgress.at(DateTime(2026, 8, 31, 23));
      expect(p.isRunning, isTrue);
      expect(p.end, DateTime(2026, 9, 1, 6));
    });
  });
}
