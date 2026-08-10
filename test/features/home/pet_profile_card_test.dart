import 'package:flutter_test/flutter_test.dart';
import 'package:vivananunt/features/home/domain/pet_dday.dart';
import 'package:vivananunt/features/my_cage/domain/species_comfort.dart';

void main() {
  group('dDayLabel — PRD 목업 문구 형식', () {
    test('입양 152일차 → "젤리와 함께한 지 D+152일"', () {
      final label = dDayLabel(
        petName: '젤리',
        adoptionDate: DateTime(2026, 3, 6),
        now: DateTime(2026, 8, 5),
      );
      expect(label, '젤리와 함께한 지 D+152일');
    });

    test('입양 당일 → D+0일', () {
      final label = dDayLabel(
        petName: '젤리',
        adoptionDate: DateTime(2026, 8, 5),
        now: DateTime(2026, 8, 5, 23),
      );
      expect(label, '젤리와 함께한 지 D+0일');
    });

    test('입양일 없으면 null — 0일로 위장하지 않는다', () {
      expect(
        dDayLabel(
            petName: '젤리', adoptionDate: null, now: DateTime(2026, 8, 5)),
        isNull,
      );
    });

    test('시각 차이는 무시하고 날짜 경계로만 센다', () {
      final label = dDayLabel(
        petName: '젤리',
        adoptionDate: DateTime(2026, 8, 4, 23, 59),
        now: DateTime(2026, 8, 5, 0, 1),
      );
      expect(label, '젤리와 함께한 지 D+1일');
    });
  });

  group('envStatus — 온습도 정상 판정', () {
    const comfort = SpeciesComfort(
      speciesId: 'crested_gecko',
      speciesNameKo: '크레스티드 게코',
      tempMin: 20,
      tempMax: 27,
      humidMin: 50,
      humidMax: 80,
    );

    test('둘 다 안심존 안 → normal', () {
      expect(envStatus(temp: 24.5, humid: 68, comfort: comfort),
          EnvStatus.normal);
    });

    test('온도가 범위를 벗어나면 warning', () {
      expect(
          envStatus(temp: 29, humid: 68, comfort: comfort), EnvStatus.warning);
    });

    test('습도가 범위를 벗어나면 warning', () {
      expect(
          envStatus(temp: 24, humid: 35, comfort: comfort), EnvStatus.warning);
    });

    test('종 미설정(comfort=null) → unknown, 배지 숨김', () {
      expect(envStatus(temp: 24, humid: 68, comfort: null), EnvStatus.unknown);
    });

    test('측정값 없음 → unknown', () {
      expect(envStatus(temp: null, humid: 68, comfort: comfort),
          EnvStatus.unknown);
    });

    test('0값은 센서 오프라인 센티넬 → unknown', () {
      expect(envStatus(temp: 0, humid: 0, comfort: comfort), EnvStatus.unknown);
    });
  });
}
