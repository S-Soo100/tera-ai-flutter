import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/pet_camera_assignment_repository.dart';
import '../domain/activity_summary.dart';

final petCameraAssignmentRepositoryProvider =
    Provider<PetCameraAssignmentRepository>((ref) =>
        SupabasePetCameraAssignmentRepository(Supabase.instance.client));
final petCameraAssignmentsProvider = FutureProvider.autoDispose
    .family<List<ActivityAssignment>, String>((ref, petId) {
  final userId = ref.watch(currentUserProvider.select((u) => u?.id));
  if (userId == null) return const [];
  return ref.watch(petCameraAssignmentRepositoryProvider).list(userId, petId);
});
final selectedMyCrePetIdProvider = StateProvider<String?>((ref) {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return null;
});
