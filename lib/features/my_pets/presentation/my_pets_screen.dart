import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/redesign_tab_header.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../home/domain/group_display_label.dart';
import '../../my_cage/presentation/my_cage_providers.dart';
import '../../my_cage/domain/redesign_management.dart';
import 'my_cre_activity_screen.dart';
import 'my_pets_providers.dart';
import 'pet_assignment_providers.dart';
import '../domain/activity_summary.dart';

/// Selection is an animal ID; only the dropdown label changes with its group.
class MyPetsScreen extends ConsumerWidget {
  const MyPetsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserProvider.select((u) => u?.id));
    final pets = ref.watch(petListProvider);
    final selectedId = ref.watch(selectedMyCrePetIdProvider);
    final selected =
        pets.where((p) => p.id == selectedId).firstOrNull ?? pets.firstOrNull;
    final groups = ref.watch(enclosuresProvider).valueOrNull ?? const [];
    final camerasAsync = ref.watch(camerasProvider);
    final camera = selected?.enclosureId == null ||
            camerasAsync.isLoading ||
            camerasAsync.hasError
        ? null
        : camerasAsync.valueOrNull
            ?.where((camera) => camera.enclosureId == selected!.enclosureId)
            .firstOrNull;
    ref.listen(myPetsTabProvider, (_, value) {
      if (value == 1) {
        ref.read(myPetsTabProvider.notifier).state = 0;
        context.push('/my-pets/reports');
      }
    });
    return MyCreActivityScreen(
      header: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: RedesignTabHeader(
              choices: [
                for (final pet in pets)
                  (
                    id: pet.id,
                    label: groupDisplayLabel(
                        groupId: pet.enclosureId,
                        individualName: pet.name,
                        groups: groups)
                  )
              ],
              selectedId: selected?.id,
              emptyLabel: 'tab_my_pets'.tr(),
              onSelected: (id) =>
                  ref.read(selectedMyCrePetIdProvider.notifier).state = id)),
      pet: selected,
      userId: userId,
      hasCameraConnection: selected?.enclosureId == null
          ? false
          : camerasAsync.isLoading || camerasAsync.hasError
              ? null
              : camera != null,
      onConnectCamera: selected == null
          ? null
          : () => context.push('/device-groups/connect-camera', extra: (
                groupId: selected.enclosureId,
                member: ManagementKey(kind: ManagementKind.pet, id: selected.id)
              )),
      // Display the current camera across the requested dates. Do not claim
      // historical pet membership or truncate at registration/link dates.
      assignments: camera == null
          ? const []
          : [ActivityAssignment.currentCamera(camera.id)],
      assignmentNotice: selected?.enclosureId != null && camerasAsync.hasError
          ? TextButton(
              onPressed: () => ref.invalidate(camerasProvider),
              child: Text('activity_retry'.tr()))
          : null,
      onAddPet: () => context.push('/pet-add'),
      onEditPet: selected == null
          ? null
          : () => context.push('/my-pets/${selected.id}/edit'),
    );
  }
}
