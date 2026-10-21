// 카메라 탭 북마크 카드 부제 — 북마크·직접 녹화 중 최신 시각(2026-10-21).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/presentation/crecam_screen.dart';

void main() {
  final early = DateTime(2026, 10, 1);
  final late = DateTime(2026, 10, 21);

  test('둘 다 있으면 늦은 쪽, 한쪽이 비면 다른 쪽, 둘 다 비면 null', () {
    expect(latestEntryAt(AsyncData(early), AsyncData(late)).value, late);
    expect(latestEntryAt(AsyncData(late), AsyncData(early)).value, late);
    expect(latestEntryAt(const AsyncData(null), AsyncData(late)).value, late);
    expect(latestEntryAt(AsyncData(early), const AsyncData(null)).value, early);
    final none = latestEntryAt(const AsyncData(null), const AsyncData(null));
    expect(none.hasValue, isTrue);
    expect(none.value, isNull);
  });

  test('한쪽이 처음 불러오는 중이면 로딩, 한쪽만 실패하면 남은 값', () {
    expect(latestEntryAt(AsyncData(early), const AsyncLoading()).isLoading,
        isTrue);
    final err = AsyncError<DateTime?>(Exception('x'), StackTrace.empty);
    expect(latestEntryAt(err, AsyncData(late)).value, late);
    expect(latestEntryAt(AsyncData(early), err).value, early);
    expect(latestEntryAt(err, err).hasError, isTrue);
  });
}
