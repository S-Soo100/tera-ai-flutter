import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/domain/player_speed.dart';
import 'package:vivanaut/shared/widgets/figma_icon.dart';

/// 2026-09-21 사용자 결정 — Figma 아이콘 시트대로 1X/1.2X/1.5X/2X 네 단계.
void main() {
  test('네 단계를 순서대로 돌고 처음으로 돌아온다', () {
    expect(kPlayerSpeeds, [1.0, 1.2, 1.5, 2.0]);
    expect(nextPlayerSpeed(1.0), 1.2);
    expect(nextPlayerSpeed(1.2), 1.5);
    expect(nextPlayerSpeed(1.5), 2.0);
    expect(nextPlayerSpeed(2.0), 1.0);
  });

  test('목록에 없는 옛 값은 처음으로 돌린다', () {
    expect(nextPlayerSpeed(1.75), 1.0);
    expect(nextPlayerSpeed(0), 1.0);
  });

  test('단계마다 아이콘이 있고 서로 다르다', () {
    final assets = [for (final s in kPlayerSpeeds) FigmaIcons.speed(s)];
    expect(assets.toSet().length, kPlayerSpeeds.length, reason: '중복 금지');
    for (final name in assets) {
      expect(File('assets/icons/$name.svg').existsSync(), isTrue,
          reason: '$name.svg 없음');
    }
  });

  test('아이콘 파일명이 아니라 글리프를 기준으로 고른다', () {
    // ⚠️ export 파일명이 글리프와 어긋나 있다 — speed_1_2x.svg는 "1X"를,
    // speed_1_2x-1.svg가 "1.2X"를 그린다(2026-09-21 렌더 실측).
    expect(FigmaIcons.speed(1.0), 'redesign_v2/speed_1_2x');
    expect(FigmaIcons.speed(1.2), 'redesign_v2/speed_1_2x-1');
    expect(FigmaIcons.speed(1.5), 'redesign_v2/speed_1_5x');
    expect(FigmaIcons.speed(2.0), FigmaIcons.speed2x);
  });

  test('배속 아이콘은 전부 36 프레임 export다', () {
    for (final s in kPlayerSpeeds) {
      final svg = File('assets/icons/${FigmaIcons.speed(s)}.svg')
          .readAsStringSync();
      final vb = RegExp(r'viewBox="([^"]+)"').firstMatch(svg)!.group(1)!;
      expect(vb.trim().split(RegExp(r'\s+'))[2], '36', reason: '$s');
    }
  });
}
