import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/profile/presentation/community_profile_screen.dart';

void main() {
  // Figma 1142:9369 — 바깥 테두리 없음, 선택 안 된 칸끼리 사이에만 1pt 세로선.
  const options = ['beginner', 'intermediate', 'expert'];
  const side = BorderSide(color: Color(0xFFE3E3E3));

  Border? at(int i, String? value) =>
      experienceDivider(index: i, options: options, value: value, side: side);

  test('아무것도 안 고르면 칸 사이 두 줄만(바깥 테두리 없음)', () {
    expect(at(0, null), const Border(right: side));
    expect(at(1, null), const Border(right: side));
    expect(at(2, null), isNull);
  });

  test('숙련자 선택 — 입문자|중급자 사이만, 선택 칸과 닿는 쪽엔 없음', () {
    expect(at(0, 'expert'), const Border(right: side));
    expect(at(1, 'expert'), isNull);
    expect(at(2, 'expert'), isNull);
  });

  test('중급자 선택 — 양옆 모두 선 없음', () {
    expect(at(0, 'intermediate'), isNull);
    expect(at(1, 'intermediate'), isNull);
    expect(at(2, 'intermediate'), isNull);
  });

  test('입문자 선택 — 중급자|숙련자 사이만', () {
    expect(at(0, 'beginner'), isNull);
    expect(at(1, 'beginner'), const Border(right: side));
  });

  test('선이 있으면 오른쪽 한 변만 그린다', () {
    final b = at(0, null)!;
    expect(b.top, BorderSide.none);
    expect(b.bottom, BorderSide.none);
    expect(b.left, BorderSide.none);
    expect(b.right.width, 1);
  });
}
