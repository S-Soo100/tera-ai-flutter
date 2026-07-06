import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/enclosure.dart';
import 'my_cage_providers.dart';
import 'supabase_module_providers.dart';

/// 사육장 목록 + 생성. 카드 탭 시 상세(배정) 화면으로.
class EnclosureListScreen extends ConsumerWidget {
  const EnclosureListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enclosuresAsync = ref.watch(enclosuresProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('enclosure_manage_title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'enclosure_create_title'.tr(),
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: enclosuresAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            SkeletonCard(lineCount: 2),
            SizedBox(height: 12),
            SkeletonCard(lineCount: 2),
          ],
        ),
        error: (e, _) => Center(child: Text('error_generic'.tr())),
        data: (list) {
          if (list.isEmpty) return const _EmptyEnclosures();
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _EnclosureCard(enclosure: list[i]),
          );
        },
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('enclosure_create_title'.tr()),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: 'enclosure_name_hint'.tr()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common_cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('enclosure_create_button'.tr()),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await ref.read(enclosureRepositoryProvider).create(name: name);
    ref.invalidate(enclosuresProvider);
  }
}

class _EnclosureCard extends ConsumerWidget {
  const _EnclosureCard({required this.enclosure});
  final Enclosure enclosure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camCount = ref
            .watch(camerasProvider)
            .valueOrNull
            ?.where((c) => c.enclosureId == enclosure.id)
            .length ??
        0;
    final devCount = ref
            .watch(deviceListProvider)
            .valueOrNull
            ?.where((d) => d.enclosureId == enclosure.id)
            .length ??
        0;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(enclosure.name),
        subtitle: Text('enclosure_device_count'.tr(
          namedArgs: {'cams': '$camCount', 'devs': '$devCount'},
        )),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            context.push('/smart-cage/enclosures/${enclosure.id}'),
      ),
    );
  }
}

class _EmptyEnclosures extends StatelessWidget {
  const _EmptyEnclosures();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.holiday_village_outlined,
                size: 64, color: cs.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 20),
            Text('enclosure_list_empty'.tr(),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('enclosure_list_empty_sub'.tr(),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
