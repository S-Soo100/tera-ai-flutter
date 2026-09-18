import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/pet_form_state.dart';
import 'my_pets_providers.dart';
import 'widgets/pet_form_screen.dart';

class PetEditScreen extends ConsumerWidget {
  const PetEditScreen(
      {super.key, required this.petId, this.groups = const [], this.onSave});
  final String petId;
  final List<PetFormGroupOption> groups;
  final PetFormSave? onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentUserProvider.select((user) => user?.id));
    final pets = ref.watch(petListProvider);
    final matches = pets.where((pet) => pet.id == petId);
    if (matches.isEmpty) {
      return Scaffold(
        appBar: petFormAppBar(
            context, 'pet_form_title'.tr(), () => Navigator.of(context).pop()),
        body: Center(child: Text('pet_form_missing'.tr())),
      );
    }
    return PetFormScreen(
        key: ValueKey('$account:$petId'),
        original: matches.first,
        groups: groups,
        onSave: onSave);
  }
}
