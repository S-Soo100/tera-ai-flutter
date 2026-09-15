import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/activity_summary.dart';

/// A missing history contract is different from an animal with no assignments.
/// In particular, current enclosure membership cannot prove historical dates.
class AssignmentHistoryUnavailable implements Exception {
  const AssignmentHistoryUnavailable();
}

abstract interface class PetCameraAssignmentRepository {
  Future<List<ActivityAssignment>> list(String accountId, String petId);
}

class SupabasePetCameraAssignmentRepository
    implements PetCameraAssignmentRepository {
  SupabasePetCameraAssignmentRepository(this.client);
  final SupabaseClient client;
  @override
  Future<List<ActivityAssignment>> list(String accountId, String petId) async {
    if (client.auth.currentUser?.id != accountId) {
      throw StateError('Account changed');
    }
    try {
      final rows = await client
          .from('pet_camera_assignments')
          .select('user_id,pet_identity,camera_id,start_at,end_at,origin')
          .eq('user_id', accountId)
          .eq('pet_identity', petId)
          .order('created_at');
      if (client.auth.currentUser?.id != accountId) {
        throw StateError('Account changed');
      }
      return parsePetAssignmentRows(rows, accountId: accountId, petId: petId);
    } on PostgrestException catch (error) {
      if (const {'42P01', 'PGRST205', '42703', 'PGRST204'}
          .contains(error.code)) {
        throw const AssignmentHistoryUnavailable();
      }
      rethrow;
    }
  }
}

List<ActivityAssignment> parsePetAssignmentRows(List<Map<String, dynamic>> rows,
        {required String accountId, required String petId}) =>
    List.unmodifiable(rows.map((row) {
      if (row['user_id'] != accountId || row['pet_identity'] != petId) {
        throw const FormatException('Assignment scope mismatch');
      }
      final origin = switch (row['origin']) {
        'recorded' => ActivityOrigin.exact,
        'legacy_inherited' => ActivityOrigin.legacy,
        _ => throw const FormatException('Unknown assignment origin'),
      };
      DateTime? instant(Object? value) {
        if (value == null) return null;
        if (value is! String ||
            !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value)) {
          throw const FormatException('Assignment instant needs timezone');
        }
        return DateTime.parse(value).toUtc();
      }

      final start = instant(row['start_at']);
      if (origin == ActivityOrigin.exact && start == null) {
        throw const FormatException('Recorded assignment requires start');
      }
      final camera = row['camera_id'];
      if (camera is! String || camera.isEmpty) {
        throw const FormatException('Missing camera');
      }
      return ActivityAssignment(
          cameraId: camera,
          startUtc: start,
          endUtc: instant(row['end_at']),
          origin: origin);
    }));
