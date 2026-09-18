import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/redesign_group_repository.dart';
import '../domain/pair_target_kind.dart';
import '../domain/redesign_management.dart';
import 'device_add_flow_controller.dart';
import 'device_add_flow_screen.dart';
import 'device_management_controller.dart';

/// Scope keeps one idempotency key throughout a physical pairing session.
class DeviceAddFlowRoute extends ConsumerWidget {
  const DeviceAddFlowRoute({super.key, this.initialKind, this.onProvisioned});
  final PairTargetKind? initialKind;
  final VoidCallback? onProvisioned;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentUserProvider.select((u) => u?.id));
    return ProviderScope(
        key: ValueKey(account),
        overrides: [
          deviceAddCompletedProvider.overrideWith(
              (ref) => ref.read(managementMutationCompletedProvider)),
          deviceAddAutoGroupProvider.overrideWith((ref) {
            final requestId = const Uuid().v4();
            final repository = ref.watch(redesignGroupRepositoryProvider);
            var alive = true;
            ref.onDispose(() => alive = false);
            return (owner, registeredIds) async {
              if (!alive ||
                  account == null ||
                  owner != account ||
                  repository == null) {
                throw const ManagementFailure('management_auth_changed');
              }
              final inventory = await repository.load();
              final keys = {
                for (final entry in registeredIds.entries)
                  ManagementKey(
                      kind: entry.key == PairTargetKind.device
                          ? ManagementKind.device
                          : ManagementKind.camera,
                      id: entry.value)
              };
              if (keys.length != 2 ||
                  keys.any((key) => inventory.item(key) == null)) {
                throw const ManagementFailure('management_item_missing');
              }
              final groups = {
                for (final key in keys) inventory.item(key)!.groupId
              };
              if (groups.length == 1 && groups.single != null) {
                return groups.single!;
              }
              if (groups.any((g) => g != null)) {
                throw const ManagementFailure('management_save_failed');
              }
              final groupId = await repository.saveGroup(
                  GroupEditDraft(
                      name: nextManagementName('management_default_group'.tr(),
                          inventory.groups.map((g) => g.name)),
                      members: keys,
                      expectedGroups: {for (final key in keys) key: null},
                      useDefaultName: true),
                  requestId: requestId);
              if (alive) ref.read(managementMutationCompletedProvider)();
              return groupId;
            };
          }),
        ],
        child: DeviceAddFlowScreen(
            initialKind: initialKind, onProvisioned: onProvisioned));
  }
}
