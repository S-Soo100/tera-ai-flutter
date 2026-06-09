import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../domain/device.dart';
import 'supabase_module_providers.dart';
import 'widgets/actuator_controls.dart';
import 'widgets/module_status_card.dart';

class SmartCageScreen extends ConsumerWidget {
  const SmartCageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceListAsync = ref.watch(deviceListProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'smart_cage_title'.tr(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _CircleAddButton(
              onTap: () => context.push('/smart-cage/devices/pair'),
            ),
          ),
        ],
      ),
      body: deviceListAsync.when(
        loading: () => const _SkeletonBody(),
        error: (e, _) => _ErrorBody(message: e.toString()),
        data: (devices) {
          if (devices.isEmpty) {
            return const _NoPairingBody();
          }
          return _DeviceBody(devices: devices);
        },
      ),
    );
  }
}

// ── device 0개 ────────────────────────────────────────────────────────────────

class _NoPairingBody extends StatelessWidget {
  const _NoPairingBody();

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
            Icon(
              Icons.sensors_off_rounded,
              size: 64,
              color: cs.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 20),
            Text(
              'smart_cage_no_device'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'smart_cage_no_device_subtitle'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => context.push('/smart-cage/devices/pair'),
              icon: const Icon(Icons.bluetooth_searching_rounded, size: 20),
              label: Text('smart_cage_pair_button'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

// ── device 1개 이상: 본문 ─────────────────────────────────────────────────────

class _DeviceBody extends ConsumerWidget {
  const _DeviceBody({required this.devices});

  final List<Device> devices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        if (devices.length >= 2) ...[
          _DeviceSelector(devices: devices),
          const SizedBox(height: 12),
        ],
        ModuleStatusCard(),
        const SizedBox(height: 12),
        ActuatorControls(),
      ],
    );
  }
}

// ── device 선택 칩 (2개 이상일 때) ────────────────────────────────────────────

class _DeviceSelector extends ConsumerWidget {
  const _DeviceSelector({required this.devices});

  final List<Device> devices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedDeviceIdProvider);
    // selectedId가 null이거나 목록에 없으면 첫 번째가 실질 선택
    final effectiveId = (selectedId != null &&
            devices.any((d) => d.id == selectedId))
        ? selectedId
        : devices.first.id;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'smart_cage_select_device'.tr(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: devices.map((device) {
              final isSelected = device.id == effectiveId;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isSelected,
                  label: Text(
                    device.name?.isNotEmpty == true
                        ? device.name!
                        : device.id.substring(0, 8),
                  ),
                  avatar: Icon(
                    device.isOnline
                        ? Icons.circle
                        : Icons.circle_outlined,
                    size: 10,
                    color: device.isOnline
                        ? Colors.green
                        : cs.onSurface.withValues(alpha: 0.4),
                  ),
                  onSelected: (_) {
                    ref.read(selectedDeviceIdProvider.notifier).state =
                        device.id;
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── 로딩 스켈레톤 ─────────────────────────────────────────────────────────────

class _SkeletonBody extends StatelessWidget {
  const _SkeletonBody();

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlightColor = Theme.of(context).colorScheme.surface;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _SkeletonCard(height: 140),
          const SizedBox(height: 12),
          _SkeletonCard(height: 220),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

// ── 에러 ──────────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'error_generic'.tr(),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 상단 + 버튼 ───────────────────────────────────────────────────────────────

class _CircleAddButton extends StatelessWidget {
  const _CircleAddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.add, size: 20),
        ),
      ),
    );
  }
}
