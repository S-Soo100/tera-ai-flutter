import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/domain/webrtc_diag.dart';

WebRtcDiagEvent _e(int i, {Map<String, Object?> data = const {}}) =>
    WebRtcDiagEvent(
      at: DateTime.utc(2026, 9, 23, 1, 0, i),
      cameraId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      gen: i,
      event: 'ev$i',
      data: data,
    );

void main() {
  test('용량을 넘으면 오래된 것부터 버린다', () {
    final b = WebRtcDiagBuffer(capacity: 3);
    for (var i = 0; i < 5; i++) {
      b.add(_e(i));
    }
    expect(b.events.map((e) => e.event), ['ev2', 'ev3', 'ev4']);
  });

  test('한 줄 형식 — UTC 시각·카메라 앞 8자·세대·이벤트·데이터', () {
    final line = _e(7, data: {'delay_s': 3, 'reason': 'timer'}).toLine();
    expect(line,
        '2026-09-23T01:00:07.000Z cam=aaaaaaaa gen=7 ev7 delay_s=3 reason=timer');
  });

  test('내보내기 — 헤더 한 줄 + 이벤트 줄, 비우면 빈 문자열', () {
    final b = WebRtcDiagBuffer()
      ..add(_e(1))
      ..add(_e(2));
    final out = b.export(header: 'vivanaut 0.133.0');
    expect(out.split('\n'), hasLength(3));
    expect(out, startsWith('vivanaut 0.133.0\n'));
    b.clear();
    expect(b.events, isEmpty);
    expect(b.export(), '');
  });
}
