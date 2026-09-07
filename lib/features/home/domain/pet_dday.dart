import '../../my_cage/domain/species_comfort.dart';

/// 개체 D-Day 문구. PRD §3.2 목업 문구 형식 `젤리와 함께한 지 D+152일`.
///
/// 기존 `Pet.adoptionDuration`(`입양 5개월째`)과 형식이 달라 재사용하지 않는다.
/// 입양일이 없으면 null — 줄 자체를 숨기기 위함이지 0일이 아니다.
String? dDayLabel({
  required String petName,
  required DateTime? adoptionDate,
  required DateTime now,
}) {
  if (adoptionDate == null) return null;
  final from =
      DateTime(adoptionDate.year, adoptionDate.month, adoptionDate.day);
  final to = DateTime(now.year, now.month, now.day);
  final days = to.difference(from).inDays;
  return '$petName와 함께한 지 D+$days일';
}

/// 사육장 환경 상태 배지. PRD §3.2 `온습도 정상 🟢`.
enum EnvStatus {
  /// 종별 안심존 안.
  normal,

  /// 안심존을 벗어남.
  warning,

  /// 판정 불가(종 미설정 / 측정값 없음 / 센서 오프라인). 배지를 숨긴다.
  unknown,
}

/// 온습도가 종별 안심존 안인지 판정한다.
///
/// [comfort]가 null(종 미설정)이면 판정하지 않는다 — 임의 기준치를 지어내면
/// 사용자가 잘못된 안전 신호를 믿게 된다.
/// 0값은 실측이 아니라 센서 오프라인 센티넬이다(DHT22는 0을 못 낸다).
EnvStatus envStatus({
  required double? temp,
  required double? humid,
  required SpeciesComfort? comfort,
}) {
  if (comfort == null) return EnvStatus.unknown;
  if (temp == null || humid == null) return EnvStatus.unknown;
  if (temp <= 0 || humid <= 0) return EnvStatus.unknown;

  final tempOk = temp >= comfort.tempMin && temp <= comfort.tempMax;
  final humidOk = humid >= comfort.humidMin && humid <= comfort.humidMax;
  return tempOk && humidOk ? EnvStatus.normal : EnvStatus.warning;
}
