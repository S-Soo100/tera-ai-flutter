import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/my_cage/domain/update_day_label.dart';
void main() {
  test('두 분 전이라도 자정을 넘으면 어제다', () {
    expect(calendarDaysAgo(DateTime(2026,9,12,23,59),DateTime(2026,9,13,0,1)),1);
  });
  test('오늘과 월/연 경계 일수를 계산한다', () {
    expect(calendarDaysAgo(DateTime(2026,9,13,1),DateTime(2026,9,13,23)),0);
    expect(calendarDaysAgo(DateTime(2025,12,30),DateTime(2026,1,2)),3);
  });
}
