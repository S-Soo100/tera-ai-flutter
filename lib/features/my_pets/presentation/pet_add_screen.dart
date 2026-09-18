import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/pet_form_state.dart';
import 'widgets/pet_form_screen.dart';

class PetAddScreen extends ConsumerWidget {
  const PetAddScreen(
      {super.key, this.groups = const [], this.onSave, this.initialGroupId});
  final List<PetFormGroupOption> groups;
  final PetFormSave? onSave;
  final String? initialGroupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentUserProvider.select((user) => user?.id));
    return PetFormScreen(
        key: ValueKey(account),
        groups: groups,
        onSave: onSave,
        initialGroupId: initialGroupId);
  }
}
