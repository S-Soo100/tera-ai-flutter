import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/section_header.dart';
import '../domain/device.dart';
import '../domain/terra_camera.dart';
import 'my_cage_providers.dart';
import 'supabase_module_providers.dart';

/// 사육장 상세 — 배정된 카메라/디바이스 표시 + 배정/해제.
class EnclosureDetailScreen extends ConsumerWidget {
  const EnclosureDetailScreen({super.key, required this.enclosureId});
  final String enclosureId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enclosureAsync = ref.watch(enclosureProvider(enclosureId));
    final cameras = ref.watch(camerasProvider).valueOrNull ?? const [];
    final devices = ref.watch(deviceListProvider).valueOrNull ?? const [];
    final myCams =
        cameras.where((c) => c.enclosureId == enclosureId).toList();
    final myDevs =
        devices.where((d) => d.enclosureId == enclosureId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(enclosureAsync.valueOrNull?.name ??
            'enclosure_manage_title'.tr()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionHeader(
            title: 'enclosure_section_cameras'.tr(),
            trailing: TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text('enclosure_assign_camera'.tr()),
              onPressed: () => _pickCamera(context, ref, cameras),
            ),
          ),
          if (myCams.isEmpty)
            _emptyHint(context)
          else
            ...myCams.map((c) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.videocam_outlined),
                  title: Text(c.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.link_off),
                    onPressed: () async {
                      await ref
                          .read(cameraRepositoryProvider)
                          .assignEnclosure(c.id, null);
                    },
                  ),
                )),
          const SizedBox(height: 24),
          SectionHeader(
            title: 'enclosure_section_devices'.tr(),
            trailing: TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text('enclosure_assign_device'.tr()),
              onPressed: () => _pickDevice(context, ref, devices),
            ),
          ),
          if (myDevs.isEmpty)
            _emptyHint(context)
          else
            ...myDevs.map((d) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.sensors),
                  title: Text(d.name ?? d.id),
                  trailing: IconButton(
                    icon: const Icon(Icons.link_off),
                    onPressed: () async {
                      await ref
                          .read(supabaseModuleControlRepositoryProvider)
                          .assignEnclosure(d.id, null);
                      ref.invalidate(deviceListProvider);
                    },
                  ),
                )),
        ],
      ),
    );
  }

  Widget _emptyHint(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'enclosure_section_empty'.tr(),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
      ),
    );
  }

  Future<void> _pickCamera(
      BuildContext context, WidgetRef ref, List<TerraCamera> all) async {
    final unassigned = all.where((c) => c.enclosureId == null).toList();
    final picked = await _showPicker<TerraCamera>(
      context,
      unassigned,
      (c) => c.name,
      Icons.videocam_outlined,
    );
    if (picked == null) return;
    await ref
        .read(cameraRepositoryProvider)
        .assignEnclosure(picked.id, enclosureId);
    // camerasProvider(Stream)는 자동 갱신.
  }

  Future<void> _pickDevice(
      BuildContext context, WidgetRef ref, List<Device> all) async {
    final unassigned = all.where((d) => d.enclosureId == null).toList();
    final picked = await _showPicker<Device>(
      context,
      unassigned,
      (d) => d.name ?? d.id,
      Icons.sensors,
    );
    if (picked == null) return;
    await ref
        .read(supabaseModuleControlRepositoryProvider)
        .assignEnclosure(picked.id, enclosureId);
    ref.invalidate(deviceListProvider);
  }

  Future<T?> _showPicker<T>(
    BuildContext context,
    List<T> items,
    String Function(T) label,
    IconData icon,
  ) {
    return showModalBottomSheet<T>(
      context: context,
      builder: (ctx) {
        if (items.isEmpty) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('enclosure_no_unassigned'.tr(),
                  textAlign: TextAlign.center),
            ),
          );
        }
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('enclosure_pick_title'.tr(),
                    style: Theme.of(ctx).textTheme.titleMedium),
              ),
              ...items.map((it) => ListTile(
                    leading: Icon(icon),
                    title: Text(label(it)),
                    onTap: () => Navigator.pop(ctx, it),
                  )),
            ],
          ),
        );
      },
    );
  }
}
