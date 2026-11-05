import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 환기팬·냉각팬 타이머 시작 안내는 같은 말투여야 한다(2026-11-05 QA 관찰).
/// 둘 다 기기가 켜진 것을 확인한 뒤(`ControlOutcome.ok`)에만 뜨므로 "켜짐"이
/// 맞다 — 냉각팬만 "명령을 보냈어요"라 같은 동작을 다르게 말했다.
void main() {
  final ko = (jsonDecode(File('assets/l10n/ko.json').readAsStringSync()) as Map)
      .cast<String, dynamic>();

  test('냉각팬 타이머 시작 안내는 환기팬과 같은 꼴', () {
    for (final suffix in ['started_timer', 'started_steady']) {
      final fan = ko['home_fan_$suffix'] as String;
      final cooling = ko['home_cooling_$suffix'] as String;
      expect(cooling, fan.replaceFirst('환기팬', '냉각팬'), reason: suffix);
    }
  });
}
