import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/my_cage/domain/species_comfort.dart';

void main() {
  group('speciesIdFromText', () {
    test('한글 통칭·부분 입력을 speciesId로 매핑', () {
      expect(speciesIdFromText('크레스티드'), 'crested-gecko');
      expect(speciesIdFromText('크레스티드 게코'), 'crested-gecko');
      expect(speciesIdFromText('레오파드 게코'), 'leopard-gecko');
      expect(speciesIdFromText('펫테일'), 'fat-tailed-gecko');
    });

    test('영문·대소문자 흡수', () {
      expect(speciesIdFromText('Crested Gecko'), 'crested-gecko');
      expect(speciesIdFromText('LEOPARD'), 'leopard-gecko');
    });

    test('미지원 종·빈값·null은 null', () {
      expect(speciesIdFromText('이구아나'), isNull);
      expect(speciesIdFromText(''), isNull);
      expect(speciesIdFromText('   '), isNull);
      expect(speciesIdFromText(null), isNull);
    });
  });

  group('classifyComfort (안심존 21~29, margin 1.5)', () {
    ComfortLevel c(double v) => classifyComfort(v, 21, 29, 1.5);

    test('범위 안 = good (경계 포함)', () {
      expect(c(21), ComfortLevel.good);
      expect(c(28), ComfortLevel.good); // 실측 28°C → 딱 좋아요
      expect(c(29), ComfortLevel.good);
    });

    test('margin 이내로 초과 = cautionHigh, 초과 = dangerHigh', () {
      expect(c(30), ComfortLevel.cautionHigh); // 29+1.0
      expect(c(30.5), ComfortLevel.cautionHigh); // 29+1.5 경계
      expect(c(31), ComfortLevel.dangerHigh); // 29+2.0
    });

    test('margin 이내로 미달 = cautionLow, 미달 = dangerLow', () {
      expect(c(20), ComfortLevel.cautionLow); // 21-1.0
      expect(c(19.5), ComfortLevel.cautionLow); // 21-1.5 경계
      expect(c(18), ComfortLevel.dangerLow); // 21-3.0
    });
  });

  group('ComfortLevel severity (더 나쁜 쪽 선택용)', () {
    test('good < caution < danger', () {
      expect(ComfortLevel.good.severity, 0);
      expect(ComfortLevel.cautionHigh.severity, 1);
      expect(ComfortLevel.cautionLow.severity, 1);
      expect(ComfortLevel.dangerHigh.severity, 2);
      expect(ComfortLevel.dangerLow.severity, 2);
    });
  });

  group('comfortVerdict 매핑', () {
    test('good은 지표 무관 딱 좋아요', () {
      expect(comfortVerdict(ComfortLevel.good, isTemp: true).key, 'comfort_good');
      expect(
          comfortVerdict(ComfortLevel.good, isTemp: false).key, 'comfort_good');
    });

    test('온도/습도가 서로 다른 키·이모지', () {
      final tempHot = comfortVerdict(ComfortLevel.cautionHigh, isTemp: true);
      final humidHigh = comfortVerdict(ComfortLevel.cautionHigh, isTemp: false);
      expect(tempHot.key, 'comfort_temp_hot');
      expect(humidHigh.key, 'comfort_humid_high');
      expect(tempHot.emoji, isNot(humidHigh.emoji));
    });
  });
}
