import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/figma_icon.dart';
import '../domain/device_add_flow.dart';
import '../domain/pair_target_kind.dart';
import '../domain/redesign_management.dart';
import 'device_add_flow_controller.dart';
import 'management_colors.dart';
import 'widgets/management_widgets.dart';

/// A route owns a flow identity, so closing it disposes BLE subscriptions and
/// account credentials. Legacy pair routes wrap this same screen.
class DeviceAddFlowScreen extends ConsumerStatefulWidget {
  const DeviceAddFlowScreen(
      {super.key, this.initialKind, this.onProvisioned, this.flowKey});
  final PairTargetKind? initialKind;
  final VoidCallback? onProvisioned;
  final Object? flowKey;
  @override
  ConsumerState<DeviceAddFlowScreen> createState() =>
      _DeviceAddFlowScreenState();
}

class _DeviceAddFlowScreenState extends ConsumerState<DeviceAddFlowScreen> {
  late final Object _key = widget.flowKey ?? Object();
  final _ssid = TextEditingController();
  final _password = TextEditingController();
  int _fillGeneration = 0;
  bool _notified = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(deviceAddFlowProvider(_key).notifier).scan());
      }
    });
  }

  @override
  void dispose() {
    _ssid.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _network(String ssid) async {
    final controller = ref.read(deviceAddFlowProvider(_key).notifier);
    controller.chooseNetwork(ssid);
    _ssid.text = ssid;
    _password.clear();
    final generation = ++_fillGeneration;
    final password = await controller.savedPassword(ssid);
    if (!mounted ||
        generation != _fillGeneration ||
        _password.text.isNotEmpty ||
        _ssid.text != ssid) {
      return;
    }
    if (password != null) _password.text = password;
  }

  Future<void> _close() async {
    final state = ref.read(deviceAddFlowProvider(_key));
    if (state.step == DeviceAddStep.results) {
      _home();
      return;
    }
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 345),
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('device_add_cancel_title'.tr(),
                          textAlign: TextAlign.center,
                          style: managementStyle(context, size: 18)),
                      const SizedBox(height: 20),
                      Row(children: [
                        Expanded(
                            child: TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child:
                                    Text('device_add_keep_connecting'.tr()))),
                        Expanded(
                            child: TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text('device_add_stop'.tr())))
                      ])
                    ])))));
    if (yes == true && mounted) _home();
  }

  void _home() {
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deviceAddFlowProvider(_key));
    ref.listen(deviceAddAccountProvider, (previous, next) {
      if (previous != next) {
        ++_fillGeneration;
        _password.clear();
        _ssid.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _home();
        });
      }
    });
    ref.listen(deviceAddFlowProvider(_key), (previous, next) {
      if (previous?.step == DeviceAddStep.connecting &&
          next.step == DeviceAddStep.results) {
        ++_fillGeneration;
        _password.clear();
      }
      if (!_notified &&
          next.results.values
              .any((r) => r.wifiConnected || r.registeredId != null)) {
        _notified = true;
        widget.onProvisioned?.call();
      }
    });
    final controller = ref.read(deviceAddFlowProvider(_key).notifier);
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) unawaited(_close());
        },
        child: Scaffold(
            body: SafeArea(
                child: Column(children: [
          if (state.step != DeviceAddStep.results ||
              state.results.values
                  .any((r) => r.outcome != DeviceAddOutcome.registered))
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ManagementTopBar(
                    title: 'device_add_title'.tr(),
                    onBack: _close,
                    close: state.step == DeviceAddStep.connecting ||
                        state.step == DeviceAddStep.results)),
          Expanded(
              child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: constraints.maxHeight),
                          child: IntrinsicHeight(
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const SizedBox(height: 16),
                                        if (state.step == DeviceAddStep.scan)
                                          ..._scan(context, state, controller),
                                        if (state.step ==
                                            DeviceAddStep.networks)
                                          ..._networks(
                                              context, state, controller),
                                        if (state.step ==
                                                DeviceAddStep.credentials ||
                                            state.step ==
                                                DeviceAddStep.connecting)
                                          ..._credentials(
                                              context, state, controller),
                                        if (state.step ==
                                            DeviceAddStep.connecting)
                                          ..._connecting(context, state),
                                        if (state.step == DeviceAddStep.results)
                                          ..._results(
                                              context, state, controller),
                                        if (state.errorKey case final error?)
                                          Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Text(error.tr(),
                                                  style: managementStyle(
                                                      context,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .error))),
                                        if (state.step !=
                                                DeviceAddStep.connecting &&
                                            state.step != DeviceAddStep.results)
                                          const Spacer(),
                                        if (state.step ==
                                            DeviceAddStep.scan) ...[
                                          const SizedBox(height: 24),
                                          ManagementButton(
                                              label: 'device_add_selected'.tr(
                                                  args: [
                                                    '${state.selected.length}'
                                                  ]),
                                              onPressed: state.selected.isEmpty
                                                  ? null
                                                  : controller.loadNetworks),
                                          _PairingTextButton(
                                              onPressed: state.busy
                                                  ? null
                                                  : controller.scan,
                                              child: Text(
                                                  'device_add_rescan'.tr())),
                                        ],
                                        if (state.step ==
                                            DeviceAddStep.networks) ...[
                                          const SizedBox(height: 24),
                                          ManagementButton(
                                              label: 'device_add_rescan'.tr(),
                                              onPressed: state.busy
                                                  ? null
                                                  : controller.loadNetworks),
                                          _PairingTextButton(
                                              onPressed: state.busy
                                                  ? null
                                                  : () => _network(''),
                                              child: Text(
                                                  'device_add_manual'.tr())),
                                        ],
                                        if (state.step ==
                                                DeviceAddStep.credentials ||
                                            state.step ==
                                                DeviceAddStep.connecting) ...[
                                          const SizedBox(height: 24),
                                          ManagementButton(
                                              label: 'device_add_connect'.tr(),
                                              onPressed: state.busy
                                                  ? null
                                                  : () => controller.connect(
                                                      _ssid.text,
                                                      _password.text)),
                                          _PairingTextButton(
                                              onPressed: state.busy
                                                  ? null
                                                  : controller.loadNetworks,
                                              child: Text(
                                                  'device_add_choose_network'
                                                      .tr())),
                                        ],
                                        const SizedBox(height: 10),
                                      ]))))))),
        ]))));
  }

  Widget _heading(BuildContext context, String title, String subtitle,
          {List<String> args = const []}) =>
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.tr(),
                style: managementStyle(context,
                    size: 18, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(subtitle.tr(args: args),
                style: managementStyle(context,
                    size: 14, color: context.glass.textTertiary)),
            const SizedBox(height: 16)
          ]));
  Widget _surface(BuildContext context, List<Widget> children) => ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
          color: ManagementColors.nameField(context),
          child: Column(children: children)));
  List<Widget> _scan(BuildContext context, DeviceAddState state,
      DeviceAddFlowController controller) {
    final candidates = [
      for (final candidate in state.candidates)
        if (state.results[candidate.kind]?.canRetry != false) candidate
    ]..sort((a, b) {
        if (widget.initialKind != null && a.kind != b.kind) {
          return a.kind == widget.initialKind ? -1 : 1;
        }
        return b.rssi.compareTo(a.rssi);
      });
    return [
      _heading(
          context, 'device_add_select_title', 'device_add_select_subtitle'),
      if (state.busy) const Center(child: _PairingProgress(size: 28)),
      if (candidates.isEmpty)
        Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
                (state.busy ? 'device_add_searching' : 'device_add_no_devices')
                    .tr(),
                textAlign: TextAlign.center)),
      _surface(context, [
        for (final c in candidates)
          Semantics(
              selected: state.selected[c.kind]?.physicalId == c.physicalId,
              child: InkWell(
                  onTap: state.results[c.kind]?.canRetry == false
                      ? null
                      : () => controller.select(c),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 64),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(children: [
                            ManagementItemIcon(c.kind == PairTargetKind.device
                                ? ManagementKind.device
                                : ManagementKind.camera),
                            const SizedBox(width: 12),
                            Text(_kind(c.kind),
                                style: managementStyle(context,
                                    weight: FontWeight.w600)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                  Text(c.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: managementStyle(context,
                                          weight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(
                                      'device_add_signal'
                                          .tr(args: ['${c.rssi}']),
                                      style: managementStyle(context,
                                          size: 14,
                                          color: context.glass.textTertiary))
                                ])),
                            const SizedBox(width: 12),
                            FigmaIcon.tinted(
                                state.selected[c.kind]?.physicalId ==
                                        c.physicalId
                                    ? 'redesign_v2/check_box_400'
                                    : 'redesign_v2/check_box_outline_blank_400',
                                size: 24,
                                color: context.glass.textPrimary),
                          ])))))
      ]),
    ];
  }

  List<Widget> _networks(BuildContext context, DeviceAddState state,
          DeviceAddFlowController controller) =>
      [
        _heading(
            context, 'device_add_network_title', 'device_add_network_subtitle'),
        if (state.busy) const Center(child: _PairingProgress(size: 28)),
        if (!state.busy && state.networks.isEmpty)
          Padding(
              padding: const EdgeInsets.all(24),
              child: Text('device_add_no_networks'.tr())),
        _surface(context, [
          for (final ap in state.networks)
            InkWell(
                onTap: () => _network(ap.ssid),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 65),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        child: Row(children: [
                          Expanded(
                              child: Text(ap.ssid,
                                  style: managementStyle(context,
                                      weight: FontWeight.w600))),
                          const SizedBox(width: 12),
                          FigmaIcon.tinted('redesign_v2/wifi',
                              size: 24, color: context.glass.textPrimary)
                        ]))))
        ]),
      ];
  List<Widget> _credentials(BuildContext context, DeviceAddState state,
          DeviceAddFlowController controller) =>
      [
        _heading(
            context,
            'device_add_password_title',
            state.ssid.isEmpty
                ? 'device_add_password_subtitle'
                : 'device_add_selected_network',
            args: state.ssid.isEmpty ? [] : [state.ssid]),
        if (state.ssid.isEmpty) ...[
          TextField(
              controller: _ssid,
              autocorrect: false,
              decoration: InputDecoration(labelText: 'device_add_ssid'.tr())),
          const SizedBox(height: 12)
        ],
        Container(
            constraints: const BoxConstraints(minHeight: 65),
            decoration: BoxDecoration(
                color: ManagementColors.nameField(context),
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                  child: TextField(
                      controller: _password,
                      enabled: !state.busy,
                      obscureText: !state.showPassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: managementStyle(context),
                      onChanged: (_) {
                        ++_fillGeneration;
                      },
                      decoration: InputDecoration(
                          hintText: 'device_add_password'.tr(),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false))),
              IconButton(
                  onPressed: state.busy ? null : controller.togglePassword,
                  tooltip: 'device_add_show_password'.tr(),
                  icon: FigmaIcon.tinted(
                      state.showPassword
                          ? 'redesign_v2/visibility'
                          : 'redesign_v2/visibility_off',
                      size: 24,
                      color: context.glass.textPrimary)),
            ])),
        const SizedBox(height: 8),
        Semantics(
            checked: state.remember,
            child: InkWell(
                onTap: state.busy
                    ? null
                    : () => controller.remember(!state.remember),
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      FigmaIcon.tinted(
                          state.remember
                              ? 'redesign_v2/check_box_400'
                              : 'redesign_v2/check_box_outline_blank_400',
                          size: 24,
                          color: context.glass.textPrimary),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text('device_add_remember'.tr(),
                              style: managementStyle(context, size: 14))),
                    ])))),
      ];
  List<Widget> _connecting(BuildContext context, DeviceAddState state) => [
        const Spacer(),
        const Center(child: _PairingProgress(size: 48)),
        const SizedBox(height: 24),
        Text('device_add_connecting'.tr(),
            textAlign: TextAlign.center,
            style: managementStyle(context, size: 18, weight: FontWeight.w600)),
        const SizedBox(height: 16),
        for (final result in state.results.values) _result(context, result),
        const Spacer(),
      ];
  List<Widget> _results(BuildContext context, DeviceAddState state,
      DeviceAddFlowController controller) {
    final confirmed =
        state.results.values.where((r) => r.registeredId != null).length;
    final retry = state.results.values.any((r) => r.canRetry);
    final pending = state.results.values
        .any((r) => r.outcome == DeviceAddOutcome.registrationPending);
    return [
      const Spacer(),
      Center(
          child: FigmaIcon.tinted(
              confirmed > 0
                  ? 'redesign_v2/check_circle'
                  : pending
                      ? 'redesign_v2/progress_activity'
                      : 'redesign_v2/cancel',
              size: 64,
              color: context.glass.textPrimary)),
      const SizedBox(height: 24),
      Text(
          (confirmed == 2
                  ? 'device_add_both_done'
                  : confirmed == 1
                      ? (state.results[PairTargetKind.device]?.registeredId !=
                              null
                          ? 'device_add_device_done'
                          : 'device_add_camera_done')
                      : 'device_add_results')
              .tr(),
          textAlign: TextAlign.center,
          style: managementStyle(context, size: 18, weight: FontWeight.w600)),
      const SizedBox(height: 8),
      if (!retry && !pending && confirmed > 0)
        Text(
            (confirmed == 2
                    ? 'device_add_done_subtitle'
                    : state.results[PairTargetKind.device]?.registeredId != null
                        ? 'device_add_continue_camera_subtitle'
                        : 'device_add_continue_device_subtitle')
                .tr(),
            textAlign: TextAlign.center,
            style: managementStyle(context))
      else
        for (final result in state.results.values) _result(context, result),
      if (confirmed == 1 && !pending)
        _PairingTextButton(
            onPressed: state.busy
                ? null
                : () {
                    final result = state.results.values
                        .firstWhere((r) => r.registeredId != null);
                    context.push('/groups/new',
                        extra: ManagementKey(
                            kind: result.candidate.kind == PairTargetKind.device
                                ? ManagementKind.device
                                : ManagementKind.camera,
                            id: result.registeredId!));
                  },
            child: Text('device_add_link_existing'.tr())),
      if (state.groupError)
        Padding(
            padding: const EdgeInsets.all(12),
            child: Text('device_add_group_error'.tr(),
                textAlign: TextAlign.center)),
      const Spacer(),
      const SizedBox(height: 24),
      if (retry)
        ManagementButton(
            label: 'device_add_retry_failed'.tr(),
            onPressed: state.busy ? null : () => _network(state.ssid)),
      if (pending)
        _PairingTextButton(
            onPressed: state.busy ? null : controller.recheckRegistration,
            child: Text('device_add_recheck'.tr())),
      if (state.groupError)
        ManagementButton(
            label: 'device_add_retry_group'.tr(),
            onPressed: state.busy ? null : controller.groupConfirmed),
      if (confirmed == 1 && !pending) ...[
        const SizedBox(height: 8),
        ManagementButton(
            label: (state.results[PairTargetKind.device]?.registeredId != null
                    ? 'device_add_continue_camera'
                    : 'device_add_continue_device')
                .tr(),
            onPressed: state.busy ? null : controller.continueAdding)
      ],
      if (confirmed == 2 && !state.groupError)
        ManagementButton(
            label: 'device_add_pet'.tr(),
            onPressed: state.busy ? null : () => _petChoice(state.groupId)),
      _PairingTextButton(
          onPressed: state.busy ? null : _home,
          child: Text('device_add_later'.tr())),
    ];
  }

  Future<void> _petChoice(String? groupId) async {
    final choice = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ListTile(
                      title: Text('device_add_existing_pet'.tr()),
                      onTap: () => Navigator.pop(context, 'existing')),
                  ListTile(
                      title: Text('device_add_new_pet'.tr()),
                      onTap: () => Navigator.pop(context, 'new')),
                  ListTile(
                      title: Text('device_add_later'.tr()),
                      onTap: () => Navigator.pop(context)),
                ]))));
    if (!mounted || choice == null) return;
    if (choice == 'new') {
      context.push('/pet-add', extra: groupId);
    } else {
      context.push(groupId == null ? '/my-pets' : '/groups/$groupId');
    }
  }

  Widget _result(BuildContext context, DeviceAddResult result) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Text(
          '${_kind(result.candidate.kind)} · ${switch (result.outcome) {
            DeviceAddOutcome.registered => 'device_add_registered'.tr(),
            DeviceAddOutcome.registrationPending => (result.wifiConnected
                    ? 'device_add_wifi_pending'
                    : 'device_add_uncertain')
                .tr(),
            DeviceAddOutcome.wifiFailed ||
            DeviceAddOutcome.failed =>
              'device_add_failed'.tr(),
          }}',
          textAlign: TextAlign.center,
          style: managementStyle(context)));
  String _kind(PairTargetKind kind) => (kind == PairTargetKind.device
          ? 'device_add_device'
          : 'device_add_camera')
      .tr();
}

class _PairingProgress extends StatefulWidget {
  const _PairingProgress({required this.size});
  final double size;
  @override
  State<_PairingProgress> createState() => _PairingProgressState();
}

class _PairingProgressState extends State<_PairingProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();
  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
      turns: _rotation,
      child: FigmaIcon.tinted('redesign_v2/progress_activity',
          size: widget.size, color: context.glass.textTertiary));
}

/// Figma secondary CTA: 56 high, 18/600, same label role as primary text.
class _PairingTextButton extends StatelessWidget {
  const _PairingTextButton({required this.onPressed, required this.child});
  final VoidCallback? onPressed;
  final Widget child;
  @override
  Widget build(BuildContext context) => TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
          minimumSize: const Size(0, 56),
          foregroundColor: context.glass.textPrimary,
          textStyle:
              managementStyle(context, size: 18, weight: FontWeight.w600)),
      child: child);
}
