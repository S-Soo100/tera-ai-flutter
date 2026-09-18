import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/redesign_tab_header.dart';
import '../home_set_providers.dart';

class HomeHeaderBar extends ConsumerWidget {
  const HomeHeaderBar({super.key});
  static const height = 44.0;
  static const dropdownArrowKey = Key('home_header_dropdown_arrow');
  static const setPillKey = Key('home_header_set_pill');
  static const addButtonKey = Key('home_header_add_button');
  static const settingsButtonKey = Key('home_header_settings_button');
  static const personButtonKey = Key('home_header_person_button');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sets = ref.watch(homeDeviceSetsProvider).valueOrNull ?? const [];
    final current = ref.watch(currentSetProvider).valueOrNull;
    return RedesignTabHeader(
      choices: [
        for (final set in sets) (id: set.device!.id, label: set.homeLabel)
      ],
      selectedId: current?.device?.id,
      emptyLabel: 'device_module_label'.tr(),
      pillKey: setPillKey,
      arrowKey: dropdownArrowKey,
      managementKey: addButtonKey,
      accountKey: personButtonKey,
      onSelected: (id) =>
          ref.read(selectedHomeDeviceIdProvider.notifier).state = id,
    );
  }
}
