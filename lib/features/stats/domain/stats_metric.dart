/// 메인 차트에 겹쳐 그릴 지표. 기획안 §4.3.2 — **다중 선택**.
enum StatsMetric {
  temperature,
  humidity,
  activity;

  String get labelKey => switch (this) {
        StatsMetric.temperature => 'stats_metric_temp',
        StatsMetric.humidity => 'stats_metric_humid',
        StatsMetric.activity => 'stats_metric_activity',
      };

  /// 지금 켤 수 있는가.
  ///
  /// 활동량은 펫캠 AI Vision의 움직임 비율인데(기획안 §4.3.3 Y2), 그 값을
  /// 기간별로 집계하는 경로가 아직 없다. 기획안 §4.3.2가 *"라인업상 불가한
  /// 메트릭은 비활성"*이라 했으니 **비활성으로 보이되 사라지지는 않게** 둔다 —
  /// 숨기면 "이 앱은 활동량을 안 보여주는구나"가 된다.
  bool get isReady => this != StatsMetric.activity;
}

/// 차트에 최소 하나는 남긴다.
///
/// 전부 끄면 빈 플롯이 남아 **고장으로 읽힌다.** 마지막 하나는 꺼지지 않게
/// 막는 편이, 끄게 두고 빈 화면을 설명하는 것보다 낫다.
Set<StatsMetric> toggleMetric(Set<StatsMetric> current, StatsMetric m) {
  if (!m.isReady) return current;
  if (current.contains(m)) {
    if (current.length <= 1) return current;
    return {...current}..remove(m);
  }
  return {...current, m};
}
