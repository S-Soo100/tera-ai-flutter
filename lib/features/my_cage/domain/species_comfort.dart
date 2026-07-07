/// 사육장에 설정된 종(species)에서 도출한 "적정 안심존".
///
/// 앱 내장 care_info(assets/data/care_info/*.json)의 종별 온습도 범위를 그대로
/// 옮긴 값이다. **임의 수치를 만들지 않는다** — 파충류 사육 정보는 생명과 직결되므로
/// 반드시 care_info 실값에서만 온다. 온도 안심존 = coolZone.min ~ hotZone.max(주간
/// 그라디언트 전체), 습도 = humidityMin ~ humidityMax.
class SpeciesComfort {
  final String speciesId; // "crested-gecko"
  final String speciesNameKo; // "크레스티드 게코"
  final double tempMin;
  final double tempMax;
  final double humidMin;
  final double humidMax;

  const SpeciesComfort({
    required this.speciesId,
    required this.speciesNameKo,
    required this.tempMin,
    required this.tempMax,
    required this.humidMin,
    required this.humidMax,
  });
}

/// enclosure.species(자유 텍스트, 예: "크레스티드")를 care_info speciesId로 정규화.
///
/// care_info는 현재 3종만 지원 → 매칭 안 되면 null(안심존 미표시). 한글 통칭·부분
/// 입력·영문을 모두 흡수하도록 키워드 contains 매칭을 쓴다. 종이 늘면 여기 한 줄 추가.
String? speciesIdFromText(String? raw) {
  if (raw == null) return null;
  final s = raw.toLowerCase().trim();
  if (s.isEmpty) return null;
  bool has(List<String> keywords) => keywords.any(s.contains);
  if (has(['레오파드', '레오파', 'leopard'])) return 'leopard-gecko';
  if (has(['크레스티드', '크레', 'crested'])) return 'crested-gecko';
  if (has(['펫테일', '팻테일', 'fat-tail', 'fat_tail', 'fattail'])) {
    return 'fat-tailed-gecko';
  }
  return null;
}

/// 현재값이 안심존 대비 어느 수준인가.
enum ComfortLevel { good, cautionLow, cautionHigh, dangerLow, dangerHigh }

extension ComfortLevelX on ComfortLevel {
  bool get isGood => this == ComfortLevel.good;
  bool get isCaution =>
      this == ComfortLevel.cautionLow || this == ComfortLevel.cautionHigh;
  bool get isDanger =>
      this == ComfortLevel.dangerLow || this == ComfortLevel.dangerHigh;

  /// good < caution < danger. 전체 판정에서 "더 나쁜 쪽"을 고르는 데 쓴다.
  int get severity => isGood ? 0 : (isCaution ? 1 : 2);
}

/// [v]가 [lo]~[hi] 안이면 good, [margin] 이내로 벗어나면 caution, 그 이상이면 danger.
///
/// margin 권장값: 온도 1.5(°C), 습도 10(%RH). 안심존 자체는 care_info에서 오고,
/// margin은 "조금 벗어남 vs 많이 벗어남"을 가르는 UI 여유값이다.
ComfortLevel classifyComfort(double v, double lo, double hi, double margin) {
  if (v >= lo && v <= hi) return ComfortLevel.good;
  if (v > hi) {
    return (v - hi) <= margin ? ComfortLevel.cautionHigh : ComfortLevel.dangerHigh;
  }
  return (lo - v) <= margin ? ComfortLevel.cautionLow : ComfortLevel.dangerLow;
}

/// 판정 → (이모지, l10n 키). isTemp=false면 습도 문구. 순수함수(프레젠테이션 무관).
({String emoji, String key}) comfortVerdict(
  ComfortLevel level, {
  required bool isTemp,
}) {
  switch (level) {
    case ComfortLevel.good:
      return (emoji: '😊', key: 'comfort_good');
    case ComfortLevel.cautionHigh:
      return isTemp
          ? (emoji: '🌤', key: 'comfort_temp_hot')
          : (emoji: '💧', key: 'comfort_humid_high');
    case ComfortLevel.dangerHigh:
      return isTemp
          ? (emoji: '🥵', key: 'comfort_temp_too_hot')
          : (emoji: '🌊', key: 'comfort_humid_too_high');
    case ComfortLevel.cautionLow:
      return isTemp
          ? (emoji: '🌥', key: 'comfort_temp_cool')
          : (emoji: '🌵', key: 'comfort_humid_dry');
    case ComfortLevel.dangerLow:
      return isTemp
          ? (emoji: '🥶', key: 'comfort_temp_too_cold')
          : (emoji: '🏜', key: 'comfort_humid_too_dry');
  }
}
