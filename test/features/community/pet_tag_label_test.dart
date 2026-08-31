import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/community/domain/community_post.dart';

void main() {
  final now = DateTime(2026, 8, 29);

  test('만 나이 + 모프 + 성별', () {
    expect(
      petTagLabel(
          morph: '릴리화이트',
          sex: 'female',
          birthDate: DateTime(2024, 5, 1),
          now: now),
      '2살 릴리화이트 여아',
    );
  });
  test('1살 미만은 개월 표기', () {
    expect(
      petTagLabel(
          morph: '달마시안',
          sex: 'male',
          birthDate: DateTime(2026, 3, 10),
          now: now),
      '5개월 달마시안 남아',
    );
  });
  test('성별 미구분은 아가', () {
    expect(
        petTagLabel(
            morph: '달마시안',
            sex: 'unknown',
            birthDate: DateTime(2025, 8, 1),
            now: now),
        '1살 달마시안 아가');
  });
  test('birthDate 없으면 나이 생략', () {
    expect(petTagLabel(morph: '릴리화이트', sex: 'female', now: now),
        '릴리화이트 여아');
  });
  test('모프 없으면 건너뛴다', () {
    expect(petTagLabel(sex: 'female', birthDate: DateTime(2024, 5, 1), now: now),
        '2살 여아');
  });
  test('전부 없으면 null', () {
    expect(petTagLabel(now: now), isNull);
    expect(petTagLabel(sex: null, now: now), isNull);
  });
  test('생후 0개월(당월)은 나이 생략', () {
    expect(petTagLabel(sex: 'unknown', birthDate: DateTime(2026, 8, 20), now: now),
        '아가');
  });
}
