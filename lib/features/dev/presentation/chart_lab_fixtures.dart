import 'dart:math' as math;

import '../../../shared/domain/actuator_marker.dart';
import '../../../shared/domain/chart_window.dart';
import '../../my_cage/domain/telemetry_bucket.dart';

/// 디자인 검토용 데이터 모양.
///
/// **고르는 기준은 "그림이 달라지는가"가 아니라 "여기서 깨진 적이 있는가"다.**
/// 실제로 축이 뭉치거나 곡선이 납작해졌던 상황을 그대로 재현해 둔다.
enum ChartShape {
  /// 밤에 식고 낮에 오르는 평범한 하루.
  daily('dev_shape_daily'),

  /// 폭이 1℃도 안 되는 구간. 칸 크기를 못 줄이면 곡선이 직선처럼 보인다.
  flat('dev_shape_flat'),

  /// 아주 넓은 구간. 칸 크기를 못 키우면 눈금이 6개를 넘긴다.
  wide('dev_shape_wide'),

  /// 가운데가 통째로 빈 구간(센서 오프라인). 선이 끊겨야 하고, 0으로
  /// 내리꽂히면 안 된다.
  gap('dev_shape_gap'),

  /// 한쪽 지표만 들어온 상태. 반대편 축 라벨이 같이 사라져야 한다.
  tempOnly('dev_shape_temp_only'),

  /// 아무것도 없는 상태.
  empty('dev_shape_empty');

  const ChartShape(this.labelKey);

  final String labelKey;
}

/// [shape]에 맞는 30분 간격 버킷을 [window] 시작부터 **지금까지** 만든다.
///
/// 창 끝(미래)까지 만들지 않는 게 핵심이다 — 미도래 구간에 값이 있으면 회색
/// 밴드 위로 선이 지나가 버려서, 정작 확인하려던 모양이 안 나온다.
List<TelemetryBucket> buildLabBuckets({
  required ChartShape shape,
  required ChartWindow window,
}) {
  if (shape == ChartShape.empty) return const [];

  final steps = window.now.difference(window.start).inMinutes ~/ 30;
  final out = <TelemetryBucket>[];

  for (var i = 0; i <= steps; i++) {
    final at = window.start.add(Duration(minutes: 30 * i));
    final hour = at.hour + at.minute / 60;
    // 새벽 4시 최저, 오후 4시 최고.
    final phase = (hour - 4) / 24 * 2 * math.pi;
    final wave = -math.cos(phase);

    double? t;
    double? h;
    switch (shape) {
      case ChartShape.daily:
        t = 31 + 5 * wave;
        h = 61 - 9 * wave;
      case ChartShape.flat:
        t = 28.3 + 0.25 * wave;
        h = 55.4 + 0.3 * wave;
      case ChartShape.wide:
        t = 25 + 20 * wave;
        h = 55 + 40 * wave;
      case ChartShape.gap:
        // 전체의 가운데 1/3을 센서 오프라인으로 둔다.
        final inGap = i > steps * 0.35 && i < steps * 0.65;
        t = inGap ? null : 31 + 5 * wave;
        h = inGap ? null : 61 - 9 * wave;
      case ChartShape.tempOnly:
        t = 31 + 5 * wave;
        h = null;
      case ChartShape.empty:
        break;
    }

    out.add(TelemetryBucket(
      bucket: at,
      sampleCount: 6,
      tAvg: t,
      tMin: t == null ? null : t - 0.5,
      tMax: t == null ? null : t + 0.5,
      hAvg: h,
      hMin: h == null ? null : h - 2,
      hMax: h == null ? null : h + 2,
    ));
  }
  return out;
}

/// Figma가 그린 것과 같은 구성: 팬 1 + 분무 2 + 히터 1.
///
/// 히터를 하나 끼운 건 **Figma에 그림이 없는 종류**라서다 — Material 아이콘으로
/// 받쳐둔 자리가 나머지 칩과 나란히 놓였을 때 어떻게 보이는지 봐야 한다.
List<ActuatorMarker> buildLabMarkers(ChartWindow w) {
  final span = w.now.difference(w.start);
  ActuatorMarker at(double fraction, MarkerKind kind) => ActuatorMarker(
        kind: kind,
        at: w.start
            .add(Duration(minutes: (span.inMinutes * fraction).round())),
      );
  return [
    at(0.12, MarkerKind.fan),
    at(0.24, MarkerKind.mist),
    at(0.55, MarkerKind.mist),
    at(0.78, MarkerKind.heater),
  ];
}
