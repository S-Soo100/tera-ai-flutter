import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/domain/player_speed.dart';
import 'package:vivanaut/shared/widgets/figma_icon.dart';

/// 2026-11-03 Figma 1689:5771 — 1x/2x/3x/4x 네 단계, 기본 2x, 2→3→4→1→2.
void main() {
  test('네 단계를 2→3→4→1→2로 돈다', () {
    expect(kPlayerSpeeds, [1.0, 2.0, 3.0, 4.0]);
    expect(kDefaultPlayerSpeed, 2.0);
    expect(nextPlayerSpeed(2.0), 3.0);
    expect(nextPlayerSpeed(3.0), 4.0);
    expect(nextPlayerSpeed(4.0), 1.0);
    expect(nextPlayerSpeed(1.0), 2.0);
  });

  test('목록 밖 옛 값은 기본 2배로', () {
    expect(nextPlayerSpeed(1.5), 2.0);
    expect(normalizePlayerSpeed(1.2), 2.0);
    expect(normalizePlayerSpeed(1.5), 2.0);
    expect(normalizePlayerSpeed('x'), 2.0);
    expect(normalizePlayerSpeed(null), 2.0);
    expect(normalizePlayerSpeed(1), 1.0);
    expect(normalizePlayerSpeed(4), 4.0);
  });

  test('단계마다 글자 SVG가 있고 서로 다르다', () {
    final names = [for (final s in kPlayerSpeeds) FigmaIcons.speedLabel(s)];
    expect(names.toSet().length, kPlayerSpeeds.length, reason: '중복 금지');
    for (final name in names) {
      expect(File('assets/icons/$name.svg').existsSync(), isTrue,
          reason: '$name.svg 없음');
    }
  });

  test('글자 SVG는 Figma 윤곽 크기 그대로', () {
    // 디자이너 전달(2026-11-03) — Pretendard SemiBold 18 윤곽.
    final sizes = <double, String>{
      1.0: '0 0 17 13',
      2.0: '0 0 19 13',
      3.0: '0 0 20 14',
      4.0: '0 0 20 13',
    };
    sizes.forEach((speed, viewBox) {
      expect(
          File('assets/icons/${FigmaIcons.speedLabel(speed)}.svg')
              .readAsStringSync(),
          contains('viewBox="$viewBox"'),
          reason: '$speed');
      final size = FigmaIcons.speedLabelSize(speed);
      expect('0 0 ${size.width.toInt()} ${size.height.toInt()}', viewBox,
          reason: '그리는 크기 = 파일 크기 ($speed)');
    });
  });

  test('목록 밖 값의 글자는 기본 2x', () {
    expect(FigmaIcons.speedLabel(1.5), FigmaIcons.speedLabel(2.0));
  });

  test('속도계는 28 프레임, 흰 마스크', () {
    final svg =
        File('assets/icons/${FigmaIcons.speedGauge}.svg').readAsStringSync();
    expect(svg, contains('viewBox="0 0 28 28"'));
    expect(svg, isNot(contains('#D9D9D9')));
  });
}
