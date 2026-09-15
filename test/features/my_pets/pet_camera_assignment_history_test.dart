import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_pets/data/pet_camera_assignment_repository.dart';
import 'package:vivanaut/features/my_pets/domain/activity_summary.dart';

void main() {
  test('recorded boundaries and legacy unknown start remain distinct', () {
    final rows = [
      {
        'user_id': 'u',
        'pet_identity': 'p',
        'camera_id': 'c',
        'start_at': '2026-09-15T00:00:00Z',
        'end_at': '2026-09-16T00:00:00Z',
        'origin': 'recorded'
      },
      {
        'user_id': 'u',
        'pet_identity': 'p',
        'camera_id': 'old',
        'start_at': null,
        'end_at': '2026-09-15T00:00:00Z',
        'origin': 'legacy_inherited'
      },
    ];
    final scope = parsePetAssignmentRows(rows, accountId: 'u', petId: 'p');
    expect(scope[0].startUtc, DateTime.utc(2026, 9, 15));
    expect(scope[1].startUtc, isNull);
    expect(scope[1].origin, ActivityOrigin.legacy);
  });
  test('cross-account or cross-pet records cannot enter selection', () {
    for (final row in [
      {
        'user_id': 'other',
        'pet_identity': 'p',
        'camera_id': 'c',
        'origin': 'legacy_inherited'
      },
      {
        'user_id': 'u',
        'pet_identity': 'other',
        'camera_id': 'c',
        'origin': 'legacy_inherited'
      },
    ]) {
      expect(() => parsePetAssignmentRows([row], accountId: 'u', petId: 'p'),
          throwsFormatException);
    }
  });
  test('new assignments never invent a start or accept local timestamps', () {
    for (final start in [null, '2026-09-15T00:00:00']) {
      expect(
          () => parsePetAssignmentRows([
                {
                  'user_id': 'u',
                  'pet_identity': 'p',
                  'camera_id': 'c',
                  'origin': 'recorded',
                  'start_at': start
                }
              ], accountId: 'u', petId: 'p'),
          throwsFormatException);
    }
  });
}
