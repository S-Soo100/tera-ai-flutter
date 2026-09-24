import 'dart:async';
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/figma_icon.dart';
import '../../../shared/widgets/viva_modal.dart';
import '../../notification/domain/push_consent_flow.dart';
import '../../notification/presentation/push_pre_popup.dart';
import '../domain/device_add_flow.dart';
import '../domain/pair_target_kind.dart';
import '../domain/redesign_management.dart';
import 'device_add_flow_controller.dart';
import 'widgets/link_confirm_screen.dart';
import '../data/redesign_group_repository.dart';
import 'device_management_controller.dart';
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

  /// 단독 성공 뒤 반대 종류 기기만 있는 그룹이 딱 하나면 합류 카드(Figma
  /// 990:7508)를 한 번 띄운다 — 2026-09-16 사용자 결정. 여러 개면 기존
  /// '기존 기기와 연결'(그룹 편집기) 경로.
  bool _joinPrompted = false;
  String? _joinedGroupId;
  bool _joinedGroupHasPet = false;

  Future<void> _maybeOfferJoin(DeviceAddState state) async {
    // 새로 등록한 기기만 — Wi-Fi만 바꾼 카메라는 이미 제 자리가 있다.
    final registered = state.results.values
        .where((r) => r.outcome == DeviceAddOutcome.registered)
        .toList();
    if (_joinPrompted || registered.length != 1) return;
    _joinPrompted = true;
    final result = registered.single;
    final newKind = result.candidate.kind == PairTargetKind.device
        ? ManagementKind.device
        : ManagementKind.camera;
    final otherKind = newKind == ManagementKind.device
        ? ManagementKind.camera
        : ManagementKind.device;
    final ManagementInventory inventory;
    try {
      inventory = await ref.read(managementInventoryProvider.future);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final candidates = [
      for (final g in inventory.groups)
        if (inventory.members(g.id).any((i) => i.key.kind == otherKind) &&
            !inventory.members(g.id).any((i) => i.key.kind == newKind))
          g
    ];
    if (candidates.length != 1) return;
    final group = candidates.single;
    final other =
        inventory.members(group.id).firstWhere((i) => i.key.kind == otherKind);
    final newKey = ManagementKey(kind: newKind, id: result.registeredId!);
    // BLE 광고 이름("terra-iot")이 아니라 등록한 이름("사육장 5")을 보인다.
    final newName = result.registeredName ?? result.candidate.name;
    final deviceName = newKind == ManagementKind.device ? newName : other.name;
    final cameraName = newKind == ManagementKind.camera ? newName : other.name;
    // 그 환경의 기존 멤버(도마뱀 포함)를 그대로 두고 새 기기만 더한다. 도마뱀을
    // 빼고 보내면 서버가 '구성 변경'(40001)으로 거절하고 — PostgREST는 이를
    // 무한 재시도해 응답이 오지 않는다 — 통과해도 도마뱀이 환경에서 빠진다
    // (2026-09-22).
    final draft = GroupEditDraft.existing(group, inventory).select(
        ManagementItem(key: newKey, name: newName, groupId: null));
    // 시간 초과 뒤 다시 눌러도 같은 요청으로 본다(서버 멱등 키).
    final requestId = const Uuid().v4();
    final joined = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => LinkConfirmScreen(
              title: (otherKind == ManagementKind.device
                      ? 'device_add_join_title_device'
                      : 'device_add_join_title_camera')
                  .tr(),
              subtitle: 'device_add_join_subtitle'.tr(),
              rows: [
                LinkConfirmRow(
                    icon: FigmaIcons.homeGlyph,
                    label: 'management_kind_device'.tr(),
                    name: deviceName),
                LinkConfirmRow(
                    icon: FigmaIcons.cameraGlyph,
                    label: 'management_kind_camera'.tr(),
                    name: cameraName),
              ],
              primaryKey: const Key('device_add_join'),
              secondaryKey: const Key('device_add_separate'),
              primaryLabel: 'device_add_join_confirm'.tr(),
              secondaryLabel: 'device_add_join_separate'.tr(),
              failureText: (e) => e is ManagementFailure
                  ? e.key.tr()
                  : 'management_save_failed'.tr(),
              onPrimary: () async {
                final repo = ref.read(redesignGroupRepositoryProvider);
                if (repo == null) {
                  throw const ManagementFailure('management_auth_changed');
                }
                await repo.saveGroup(draft, requestId: requestId);
                // 홈 사육 환경·기기 목록까지 갱신한다(인벤토리만 비우면 홈이
                // 옛 구성을 계속 보인다).
                ref.read(managementMutationCompletedProvider)();
              },
            )));
    if (joined == true && mounted) {
      setState(() {
        _joinedGroupId = group.id;
        // 이미 도마뱀이 있는 환경이면 "도마뱀을 등록해 주세요"를 권하지 않는다
        // (2026-09-25 점검).
        _joinedGroupHasPet = inventory
            .members(group.id)
            .any((i) => i.key.kind == ManagementKind.pet);
      });
    }
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

  /// 모든 결과가 Wi-Fi 실패(비밀번호 오류 계열)인지 — 등록 대기/기타 실패는
  /// 기존 결과 화면 의미를 보존한다(P04: 모든 오류를 비밀번호 오류로 바꾸지 않음).
  static bool _allWifiFailed(DeviceAddState state) =>
      state.results.isNotEmpty &&
      state.results.values
          .every((r) => r.outcome == DeviceAddOutcome.wifiFailed);

  Future<void> _showErrorModal(String messageKey) async {
    if (!mounted) return;
    await showDialog<void>(
        context: context,
        useSafeArea: false, // 원본은 화면 전체 가운데(y354).
        builder: (context) => Dialog(
            backgroundColor: context.glass.surfaceHeader,
            surfaceTintColor: context.glass.surfaceHeader,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            // Figma 982:3500 — 345×144, 안쪽 24, 문구 18/500/28, CTA 297×44 r8.
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 345),
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(messageKey.tr(),
                          key: const Key('device_add_error_modal'),
                          textAlign: TextAlign.center,
                          style: managementStyle(context,
                                  size: 18, color: context.glass.textPrimary)
                              .copyWith(height: 28 / 18)),
                      const SizedBox(height: 24),
                      SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: FilledButton(
                              onPressed: () => Navigator.pop(context),
                              style: FilledButton.styleFrom(
                                  backgroundColor: context.glass.textPrimary,
                                  foregroundColor:
                                      ManagementColors.buttonForeground(
                                          context),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  textStyle: managementStyle(context,
                                          weight: FontWeight.w600)
                                      .copyWith(height: 28 / 16)),
                              child: Text('device_add_confirm'.tr()))),
                    ])))));
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
      if (next.step == DeviceAddStep.results) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await _maybeOfferJoin(next);
          // 사육장 등록 직후 알림 권한(2026-09-18 사용자 추가) — 합류 확인이
          // 끝난 뒤 결과 화면 위에서 묻는다. 권한이 이미 있으면 flow가 건너뛴다.
          final deviceRegistered = next.results.values.any((r) =>
              r.candidate.kind == PairTargetKind.device &&
              r.outcome == DeviceAddOutcome.registered);
          if (deviceRegistered && context.mounted) {
            unawaited(askPushConsent(context, ref, PushTopic.device));
          }
        });
      }
      if (previous?.step == DeviceAddStep.connecting &&
          next.step == DeviceAddStep.results) {
        ++_fillGeneration;
        _password.clear();
        if (_allWifiFailed(next)) {
          // Figma 982:3500 — 비밀번호 화면으로 돌아가 입력을 유지하고 확인 모달.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(_network(next.ssid));
            unawaited(_showErrorModal('device_add_wifi_failed_check'));
          });
        }
      }
      if (next.step == DeviceAddStep.credentials &&
          next.errorKey != null &&
          next.errorKey != previous?.errorKey) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_showErrorModal(next.errorKey!));
        });
      }
      if (!_notified &&
          next.results.values
              .any((r) => r.wifiConnected || r.registeredId != null)) {
        _notified = true;
        widget.onProvisioned?.call();
      }
    });
    final controller = ref.read(deviceAddFlowProvider(_key).notifier);
    final step = state.step;
    final showsTopBar = step != DeviceAddStep.results ||
        state.results.values.any((r) => !_succeeded(r));
    final (body, footer, above) = switch (step) {
      DeviceAddStep.scan => _scan(context, state, controller),
      DeviceAddStep.networks => _networks(context, state, controller),
      DeviceAddStep.credentials ||
      DeviceAddStep.connecting =>
        _credentials(context, state, controller),
      DeviceAddStep.results => _results(context, state, controller),
    };
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) unawaited(_back(state, controller));
        },
        child: Scaffold(
            body: Stack(fit: StackFit.expand, children: [
          SafeArea(
              child: Column(children: [
            if (showsTopBar)
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ManagementTopBar(
                      title: 'device_add_title'.tr(),
                      onBack: () => _back(state, controller),
                      close: step == DeviceAddStep.results,
                      onClose: step == DeviceAddStep.networks ||
                              step == DeviceAddStep.credentials ||
                              step == DeviceAddStep.connecting
                          ? _close
                          : null)),
            Expanded(
                child: Stack(children: [
              SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                      12,
                      16,
                      12,
                      _footerBottom(footer.length, keyboard) +
                          56.0 * footer.length +
                          (above == null ? 0 : 29) +
                          16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...body,
                        if (state.errorKey case final error?)
                          if (step != DeviceAddStep.credentials) ...[
                            Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(error.tr(),
                                    style: managementStyle(context,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))),
                            // 영구 거부면 앱에서 다시 물을 수 없다 — 설정으로
                            // 가는 길을 준다(2026-09-25).
                            if (error == kDeviceAddPermissionError)
                              Align(
                                  alignment: Alignment.centerLeft,
                                  child: _PairingTextButton(
                                      key: const Key(
                                          'device_add_open_settings'),
                                      onPressed: () =>
                                          unawaited(openAppSettings()),
                                      child: Text(
                                          'device_add_open_settings'.tr()))),
                          ],
                      ])),
              // Figma 공통 하단 CTA — 콘텐츠 위 플로팅. 단일 y696, 둘이면
              // 696/752, 키보드가 있으면 키보드 위 43.
              Positioned(
                  left: 12,
                  right: 12,
                  bottom: _footerBottom(footer.length, keyboard),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (above != null)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: above),
                    ...footer,
                  ])),
            ])),
          ])),
          if (step == DeviceAddStep.connecting) const _ConnectingOverlay(),
        ])));
  }

  /// 하단 CTA 아래 여백(SafeArea 안). 원본: 단일 CTA 696~752 → 852-34-752=66,
  /// 보조 포함 752~808 → 10, 키보드 위 43(982:3174).
  double _footerBottom(int buttons, bool keyboard) =>
      keyboard ? 43 : (66.0 - 56.0 * (buttons - 1)).clamp(10.0, 66.0);

  /// 뒤로가기 의미: 비밀번호→네트워크 목록, 네트워크→기기 검색, 그 외 중단 확인.
  Future<void> _back(
      DeviceAddState state, DeviceAddFlowController controller) async {
    switch (state.step) {
      case DeviceAddStep.credentials:
        await controller.loadNetworks();
      case DeviceAddStep.networks:
        await controller.scan();
      case DeviceAddStep.scan:
      case DeviceAddStep.connecting:
      case DeviceAddStep.results:
        await _close();
    }
  }

  /// 제목 18/600 (+ 진행 중이면 오른쪽 8에 20 스피너) / 8 / 부제 14/500.
  Widget _heading(BuildContext context, String title, String subtitle,
          {List<String> args = const [], bool busy = false}) =>
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                  child: Text(title.tr(),
                      style: managementStyle(context,
                              size: 18, weight: FontWeight.w600)
                          .copyWith(height: 21.48046875 / 18))),
              if (busy) ...[
                const SizedBox(width: 8),
                const _PairingProgress(size: 20),
              ],
            ]),
            const SizedBox(height: 8),
            Text(subtitle.tr(args: args),
                style: managementStyle(context,
                        size: 14, color: context.glass.bodySecondary)
                    .copyWith(height: 16.70703125 / 14)),
            const SizedBox(height: 16)
          ]));
  Widget _surface(BuildContext context, List<Widget> children) => ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
          color: context.glass.overlay,
          child: Column(children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(height: 1, thickness: 1, color: context.glass.border),
              children[i],
            ],
          ])));

  /// 원본 빈 상태 박스 — 369×64 r12 #F4F4F4, 16/500/28 #949090, 안쪽 16.
  Widget _emptyBox(BuildContext context, String text) => Container(
      key: const Key('device_add_empty_box'),
      constraints: const BoxConstraints(minHeight: 64),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
          color: context.glass.overlay,
          borderRadius: BorderRadius.circular(12)),
      child: Text(text,
          style: managementStyle(context, color: context.glass.textTertiary)
              .copyWith(height: 28 / 16)));

  (List<Widget>, List<Widget>, Widget?) _scan(BuildContext context,
      DeviceAddState state, DeviceAddFlowController controller) {
    final candidates = [
      for (final candidate in state.candidates)
        if (state.results[candidate.kind]?.canRetry != false) candidate
    ]..sort((a, b) {
        // 이미 등록한 기기는 아래로 — 등록을 마친 기기도 몇 분간 광고해
        // 방금 설치한 기기가 다시 잡힌다(2026-09-21).
        final ra = state.registered.contains(a.physicalId);
        final rb = state.registered.contains(b.physicalId);
        if (ra != rb) return ra ? 1 : -1;
        if (widget.initialKind != null && a.kind != b.kind) {
          return a.kind == widget.initialKind ? -1 : 1;
        }
        return b.rssi.compareTo(a.rssi);
      });
    final body = [
      _heading(context, 'device_add_select_title', 'device_add_select_subtitle',
          busy: state.busy),
      if (candidates.isEmpty)
        _emptyBox(
            context,
            (state.busy ? 'device_add_searching' : 'device_add_no_devices')
                .tr())
      else
        _surface(context, [
          for (final c in candidates)
            Semantics(
                selected: state.selected[c.kind]?.physicalId == c.physicalId,
                child: InkWell(
                    key: Key('device_add_candidate_${c.physicalId}'),
                    onTap: state.results[c.kind]?.canRetry == false
                        ? null
                        : () async {
                            // 등록된 사육장을 다시 연결하면 서버가 새 기기로
                            // 등록한다(UNPAIR) — 이름·그룹·예약·기록이 끊긴다는
                            // 걸 먼저 알린다(2026-09-25).
                            final choosing =
                                state.selected[c.kind]?.physicalId !=
                                    c.physicalId;
                            if (choosing &&
                                c.kind == PairTargetKind.device &&
                                state.registered.contains(c.physicalId)) {
                              final ok = await showVivaModal(context,
                                  message:
                                      'device_add_reconnect_registered_warning'
                                          .tr(),
                                  cancelLabel: 'common_cancel'.tr(),
                                  confirmLabel:
                                      'device_add_continue_anyway'.tr(),
                                  confirmKey: const Key(
                                      'device_add_reconnect_registered_ok'));
                              if (!ok || !mounted) return;
                            }
                            controller.select(c);
                          },
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 64),
                        child: Padding(
                            // Figma 971:1837 — 아이콘 x28(안쪽 16), 체크 우측 16.
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                    Text(c.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: managementStyle(context,
                                            weight: FontWeight.w600,
                                            color: context.glass.textPrimary)),
                                    if (state.registered
                                        .contains(c.physicalId)) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                          key: Key(
                                              'device_add_registered_${c.physicalId}'),
                                          (c.kind == PairTargetKind.camera
                                                  ? 'device_add_already_registered_camera'
                                                  : 'device_add_already_registered')
                                              .tr(),
                                          textAlign: TextAlign.end,
                                          style: managementStyle(context,
                                              size: 14,
                                              color:
                                                  context.glass.bodySecondary)),
                                    ],
                                    const SizedBox(height: 4),
                                    Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Flexible(
                                              child: Text(
                                                  'device_add_signal'
                                                      .tr(args: ['${c.rssi}']),
                                                  style: managementStyle(
                                                      context,
                                                      size: 14,
                                                      color: context.glass
                                                          .textTertiary))),
                                          const SizedBox(width: 4),
                                          FigmaIcon.tinted(
                                              c.rssi >= -60
                                                  ? 'redesign_v2/signal_cellular_alt'
                                                  : c.rssi >= -75
                                                      ? 'redesign_v2/signal_cellular_alt_2_bar'
                                                      : 'redesign_v2/signal_cellular_alt_1_bar',
                                              size: 16,
                                              // Figma 신호 그림 #B4AEAE.
                                              color: context.glass.deviceOff),
                                        ])
                                  ])),
                              const SizedBox(width: 12),
                              FigmaIcon.tinted(
                                  state.selected[c.kind]?.physicalId ==
                                          c.physicalId
                                      ? 'redesign_v2/check_box_400'
                                      : 'redesign_v2/check_box_outline_blank_400',
                                  size: 24,
                                  color: state.selected[c.kind]?.physicalId ==
                                          c.physicalId
                                      ? context.glass.navSelected
                                      : context.glass.deviceOff),
                            ])))))
        ]),
    ];
    // 안 보일 때 할 일 — 카메라는 켜진 뒤 3분만 검색된다(2026-09-25 점검).
    body.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
        child: Text('device_add_scan_hint'.tr(),
            key: const Key('device_add_scan_hint'),
            style: managementStyle(context,
                size: 14, color: context.glass.bodySecondary))));
    // Figma 971:1837/990:11220 — 미선택은 '다시 스캔'(스캔 중 회색), 선택하면
    // '기기 N개 추가'. 재검색은 선택 해제로 되돌아온다(중복 CTA 없음).
    final footer = [
      if (state.selected.isEmpty)
        ManagementButton(
            key: const Key('device_add_rescan'),
            label: 'device_add_rescan'.tr(),
            icon: 'redesign_v2/restart_alt',
            onPressed: state.busy ? null : controller.scan)
      else
        ManagementButton(
            key: const Key('device_add_continue'),
            label: 'device_add_selected'.tr(args: ['${state.selected.length}']),
            onPressed: controller.loadNetworks),
    ];
    // Figma 990:7601 — 1개 선택 시에만 안내(y667).
    final above = state.selected.length == 1 && candidates.length > 1
        ? Text('device_add_selection_hint'.tr(),
            key: const Key('device_add_selection_hint'),
            textAlign: TextAlign.center,
            style: managementStyle(context,
                    size: 14, color: context.glass.bodySecondary)
                .copyWith(height: 16.70703125 / 14))
        : null;
    return (body, footer, above);
  }

  (List<Widget>, List<Widget>, Widget?) _networks(BuildContext context,
      DeviceAddState state, DeviceAddFlowController controller) {
    final body = [
      _heading(
          context, 'device_add_network_title', 'device_add_network_subtitle',
          busy: state.busy),
      if (state.networks.isEmpty)
        _emptyBox(
            context,
            (state.busy
                    ? 'device_add_network_searching'
                    : 'device_add_no_networks')
                .tr())
      else
        _surface(context, [
          for (final ap in state.networks)
            InkWell(
                key: Key('device_add_network_${ap.ssid}'),
                onTap: () => _network(ap.ssid),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 65),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        child: Row(children: [
                          Expanded(
                              child: Text(ap.ssid,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: managementStyle(context,
                                      weight: FontWeight.w600))),
                          const SizedBox(width: 12),
                          // 원본의 잠금 그림은 AP 보안 정보가 없어 그리지 않는다
                          // (P11 결정 대기).
                          FigmaIcon.tinted('redesign_v2/wifi',
                              size: 24, color: context.glass.textPrimary)
                        ]))))
        ]),
    ];
    // 5GHz 전용 공유기는 목록에 안 보인다 — 직접 입력해도 실패만 반복된다.
    body.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
        child: Text('device_add_network_band_hint'.tr(),
            key: const Key('device_add_network_band_hint'),
            style: managementStyle(context,
                size: 14, color: context.glass.bodySecondary))));
    final footer = [
      ManagementButton(
          key: const Key('device_add_network_rescan'),
          label: 'device_add_network_rescan'.tr(),
          icon: 'redesign_v2/restart_alt',
          onPressed: state.busy ? null : controller.loadNetworks),
      _PairingTextButton(
          key: const Key('device_add_manual'),
          onPressed: state.busy ? null : () => _network(''),
          child: Text('device_add_manual'.tr())),
    ];
    return (body, footer, null);
  }

  (List<Widget>, List<Widget>, Widget?) _credentials(BuildContext context,
      DeviceAddState state, DeviceAddFlowController controller) {
    final busy = state.busy || state.step == DeviceAddStep.connecting;
    final body = [
      _heading(
          context,
          'device_add_password_title',
          state.ssid.isEmpty
              ? 'device_add_password_subtitle'
              : 'device_add_selected_network',
          args: state.ssid.isEmpty ? [] : [state.ssid]),
      if (state.ssid.isEmpty) ...[
        _field(context,
            child: TextField(
                controller: _ssid,
                enabled: !busy,
                autocorrect: false,
                style: managementStyle(context),
                decoration: InputDecoration(
                    hintText: 'device_add_ssid'.tr(),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false))),
        const SizedBox(height: 12)
      ],
      // Figma 982:3174 — 369×65 r12 #FAFAFA/#E3E3E3, 글자 x+17, 눈 24 우 17
      // (48 터치면 안에 가운데 → 오른쪽 안쪽 5).
      _field(context,
          padding: const EdgeInsets.only(left: 16, right: 5),
          child: Row(children: [
            Expanded(
                child: TextField(
                    controller: _password,
                    enabled: !busy,
                    obscureText: !state.showPassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: managementStyle(context),
                    onChanged: (_) {
                      ++_fillGeneration;
                      setState(() {});
                    },
                    decoration: InputDecoration(
                        hintText: 'device_add_password'.tr(),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false))),
            IconButton(
                key: const Key('device_add_eye'),
                style: IconButton.styleFrom(
                    padding: EdgeInsets.zero,
                    fixedSize: const Size(48, 48),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: busy ? null : controller.togglePassword,
                tooltip: 'device_add_show_password'.tr(),
                icon: FigmaIcon.tinted(
                    state.showPassword || _password.text.isEmpty
                        ? 'redesign_v2/visibility'
                        : 'redesign_v2/visibility_off',
                    size: 24,
                    color: context.glass.deviceOff)),
          ])),
      const SizedBox(height: 12),
      // Figma remember — 체크 24 x20(안쪽 8) + 4 + 14/500 #3C3C3C.
      Semantics(
          checked: state.remember,
          child: InkWell(
              onTap: busy ? null : () => controller.remember(!state.remember),
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(children: [
                    FigmaIcon.tinted(
                        state.remember
                            ? 'redesign_v2/check_box_300'
                            : 'redesign_v2/check_box_outline_blank_300',
                        size: 24,
                        color: state.remember
                            ? context.glass.navSelected
                            : context.glass.deviceOff),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text('device_add_remember'.tr(),
                            style: managementStyle(context,
                                    size: 14,
                                    color: context.glass.textSecondary)
                                .copyWith(height: 16.70703125 / 14))),
                  ])))),
    ];
    // 빈 비밀번호 비활성은 AP 보안 정보가 없어 보류(개방형 AP 허용) — P11.
    final footer = [
      ManagementButton(
          key: const Key('device_add_connect'),
          label: 'device_add_connect'.tr(),
          onPressed: busy
              ? null
              : () => controller.connect(_ssid.text, _password.text)),
    ];
    return (body, footer, null);
  }

  Widget _field(BuildContext context,
          {required Widget child,
          EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16)}) =>
      Container(
          constraints: const BoxConstraints(minHeight: 65),
          decoration: BoxDecoration(
              color: ManagementColors.nameField(context),
              border: Border.all(color: context.glass.border),
              borderRadius: BorderRadius.circular(12)),
          padding: padding,
          child: child);

  (List<Widget>, List<Widget>, Widget?) _results(BuildContext context,
      DeviceAddState state, DeviceAddFlowController controller) {
    if (state.results.isNotEmpty &&
        state.results.values
            .every((r) => r.outcome == DeviceAddOutcome.wifiUpdated)) {
      return _wifiUpdated(context, state, controller);
    }
    final confirmed = state.results.values
        .where((r) => r.outcome == DeviceAddOutcome.registered)
        .length;
    final updated = state.results.values
        .any((r) => r.outcome == DeviceAddOutcome.wifiUpdated);
    bool isNew(PairTargetKind kind) =>
        state.results[kind]?.outcome == DeviceAddOutcome.registered;
    final retry = state.results.values.any((r) => r.canRetry);
    final pending = state.results.values
        .any((r) => r.outcome == DeviceAddOutcome.registrationPending);
    final titleKey = confirmed == 2
        ? 'device_add_both_done'
        : confirmed == 1
            ? (isNew(PairTargetKind.device)
                ? 'device_add_device_done'
                : 'device_add_camera_done')
            : 'device_add_results';
    final topBar = state.results.values.any((r) => !_succeeded(r));
    final body = [
      // Figma 982:3643 — 체크 64 y308(상단바 없음: 62+16+230), 제목 y396(+24),
      // 부제 y425(+8). 작은 화면은 비율로 줄인다.
      SizedBox(
          height: math.min(
              topBar ? 186 : 230, MediaQuery.sizeOf(context).height * 0.27)),
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
      Text(titleKey.tr(),
          textAlign: TextAlign.center,
          style: managementStyle(context, size: 18, weight: FontWeight.w600)
              .copyWith(height: 21.48046875 / 18)),
      const SizedBox(height: 8),
      // 묶기 실패면 '도마뱀 등록' 안내 대신 아래 실패 문구만 보인다 — 둘이 함께
      // 뜨면 모순된다(2026-09-22).
      if (!retry && !pending && !updated && confirmed > 0 && !state.groupError)
        Text(
            (_joinedGroupId != null && _joinedGroupHasPet
                    ? 'device_add_joined_subtitle'
                    : confirmed == 2 || _joinedGroupId != null
                    ? 'device_add_done_subtitle'
                    : isNew(PairTargetKind.device)
                        ? 'device_add_continue_camera_subtitle'
                        : 'device_add_continue_device_subtitle')
                .tr(),
            textAlign: TextAlign.center,
            style: managementStyle(context, color: context.glass.bodySecondary)
                .copyWith(height: 19.09375 / 16))
      else
        for (final result in state.results.values) _result(context, result),
      // Wi-Fi만 바꾼 카메라와 섞여도 새로 등록한 기기는 기존 사육 환경에
      // 연결할 수 있어야 한다 — 안 그러면 '나중에 하기'만 남는다(2026-09-21).
      // 카메라는 자동으로 옮기지 않는다(사용자가 환경을 고른다).
      if (confirmed == 1 && !pending && _joinedGroupId == null)
        _PairingTextButton(
            key: const Key('device_add_link_existing'),
            onPressed: state.busy
                ? null
                : () {
                    final result = state.results.values.firstWhere(
                        (r) => r.outcome == DeviceAddOutcome.registered);
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
    ];
    final footer = <Widget>[
      if (retry)
        ManagementButton(
            key: const Key('device_add_retry_failed'),
            label: 'device_add_retry_failed'.tr(),
            onPressed: state.busy ? null : () => _network(state.ssid)),
      if (pending)
        _PairingTextButton(
            onPressed: state.busy
                ? null
                : () async {
                    final confirmed = await controller.recheckRegistration();
                    // 눌러도 아무 반응이 없으면 고장으로 읽힌다(2026-09-25).
                    if (!confirmed && mounted) {
                      await _showErrorModal('device_add_recheck_none');
                    }
                  },
            child: Text('device_add_recheck'.tr())),
      if (state.groupError)
        ManagementButton(
            label: 'device_add_retry_group'.tr(),
            onPressed: state.busy ? null : controller.groupConfirmed),
      if (confirmed == 1 && !pending && !updated && _joinedGroupId == null)
        ManagementButton(
            key: const Key('device_add_continue_kind'),
            label: (isNew(PairTargetKind.device)
                    ? 'device_add_continue_camera'
                    : 'device_add_continue_device')
                .tr(),
            onPressed: state.busy ? null : controller.continueAdding),
      if ((confirmed == 2 && !state.groupError) ||
          (_joinedGroupId != null && !_joinedGroupHasPet))
        ManagementButton(
            key: const Key('device_add_pet'),
            label: 'device_add_pet'.tr(),
            onPressed: state.busy
                ? null
                : () => _petChoice(state.groupId ?? _joinedGroupId)),
      _PairingTextButton(
          key: const Key('device_add_later'),
          onPressed: state.busy ? null : _home,
          child: Text('device_add_later'.tr())),
    ];
    return (body, footer, null);
  }

  Future<void> _petChoice(String? groupId) async {
    if (groupId != null) {
      await context.push('/groups/$groupId/choose-pet');
      return;
    }
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

  static bool _succeeded(DeviceAddResult r) =>
      r.outcome == DeviceAddOutcome.registered ||
      (r.outcome == DeviceAddOutcome.wifiUpdated && !r.unconfirmedFailed);

  /// 이미 등록된 카메라의 Wi-Fi만 바꾼 결과(2026-09-21). 새 등록이 아니라서
  /// 도마뱀 등록·기기 이어 추가를 권하지 않는다. 카메라가 재부팅 뒤 끝내 안
  /// 붙으면(저장값이 지워진 경우) 새 카메라로 등록할 길을 연다.
  (List<Widget>, List<Widget>, Widget?) _wifiUpdated(BuildContext context,
      DeviceAddState state, DeviceAddFlowController controller) {
    final result = state.results.values.first;
    final reconnect = result.reconnect;
    final missing = reconnect == CameraReconnect.missing;
    // BLE가 성공을 주지 않은 경우(2026-09-24) — 서버 last_seen_at으로 확인 중엔
    // '확인 중', 끝내 안 붙으면 '연결 실패'(다시 연결 + 새 카메라 등록).
    final checking = result.unconfirmed && reconnect == CameraReconnect.waiting;
    final failed = result.unconfirmedFailed;
    // 끝내 안 붙었으면 "변경완료"라고 쓰지 않는다 — ✕ 아이콘·"다시 연결되지
    // 않았어요"와 제목이 어긋났다(2026-09-25).
    final (titleKey, titleId) = failed
        ? ('device_add_results', 'device_add_wifi_failed')
        : missing
            ? ('device_add_wifi_missing_title', 'device_add_wifi_missing')
            : checking
                ? ('device_add_wifi_checking', 'device_add_wifi_checking')
                : ('device_add_wifi_updated', 'device_add_wifi_updated');
    final body = [
      SizedBox(height: math.min(186, MediaQuery.sizeOf(context).height * 0.27)),
      Center(
          child: FigmaIcon.tinted(
              switch (reconnect) {
                CameraReconnect.waiting => 'redesign_v2/progress_activity',
                CameraReconnect.missing => 'redesign_v2/cancel',
                _ => 'redesign_v2/check_circle',
              },
              size: 64,
              color: context.glass.textPrimary)),
      const SizedBox(height: 24),
      Text(titleKey.tr(),
          key: Key(titleId),
          textAlign: TextAlign.center,
          style: managementStyle(context, size: 18, weight: FontWeight.w600)
              .copyWith(height: 21.48046875 / 18)),
      const SizedBox(height: 8),
      Text(
          switch (reconnect) {
            CameraReconnect.waiting => checking
                ? 'device_add_checking_hint'
                : 'device_add_wifi_updated_waiting',
            CameraReconnect.missing => failed
                ? 'device_add_wifi_updated_failed'
                : 'device_add_wifi_updated_missing',
            _ => 'device_add_wifi_updated_online',
          }
              .tr(),
          textAlign: TextAlign.center,
          style: managementStyle(context, color: context.glass.bodySecondary)
              .copyWith(height: 19.09375 / 16)),
    ];
    final footer = <Widget>[
      if (failed)
        ManagementButton(
            key: const Key('device_add_retry_failed'),
            label: 'device_add_retry_failed'.tr(),
            onPressed: state.busy ? null : () => _network(state.ssid)),
      if (missing)
        ManagementButton(
            key: const Key('device_add_register_new'),
            label: 'device_add_register_new'.tr(),
            onPressed: state.busy
                ? null
                : () async {
                    final ok = await showVivaModal(context,
                        message: 'device_add_register_new_warning'.tr(),
                        cancelLabel: 'common_cancel'.tr(),
                        confirmLabel: 'device_add_continue_anyway'.tr(),
                        confirmKey: const Key('device_add_register_new_ok'));
                    if (!ok || !mounted) return;
                    await controller.registerAsNew(result.candidate.kind);
                    if (mounted) await _network(state.ssid);
                  }),
      ManagementButton(
          key: const Key('device_add_wifi_updated_done'),
          label: 'device_add_confirm'.tr(),
          onPressed: _home),
    ];
    return (body, footer, null);
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
            DeviceAddOutcome.wifiUpdated => (result.unconfirmedFailed
                    ? 'device_add_failed'
                    : result.unconfirmed
                        ? 'device_add_checking'
                        : 'device_add_wifi_updated_line')
                .tr(),
          }}${_issue(result).map((text) => '\n$text').join()}',
          textAlign: TextAlign.center,
          style: managementStyle(context)));

  /// 등록 확인이 안 된 이유 — '등록 확인 대기' 한 줄로는 구 펌웨어와 서버
  /// 등록 실패를 가릴 수 없다(2026-09-21).
  Iterable<String> _issue(DeviceAddResult result) sync* {
    if (result.unconfirmed && result.reconnect == CameraReconnect.waiting) {
      yield 'device_add_checking_hint'.tr(); // 기다리는 이유를 밝힌다.
      return;
    }
    if (result.outcome == DeviceAddOutcome.failed) {
      // 비밀번호 문제가 아니다 — 무엇을 하면 되는지 밝힌다(2026-09-25).
      switch (result.failure) {
        case DeviceProvisionFailure.ble:
          yield 'device_add_ble_failed_hint'.tr();
        case DeviceProvisionFailure.session:
          yield 'device_add_session_failed_hint'.tr();
        case DeviceProvisionFailure.rejected:
          yield 'device_add_rejected_hint'.tr();
        case null:
          break;
      }
      return;
    }
    if (result.outcome != DeviceAddOutcome.registrationPending) return;
    switch (result.issue) {
      case DeviceRegistrationIssue.legacyFirmware:
        yield 'device_add_issue_legacy'.tr();
      case DeviceRegistrationIssue.pairFailed:
        final reason = result.issueDetail;
        yield reason == null || reason.isEmpty
            ? 'device_add_issue_pair_failed'.tr()
            : 'device_add_issue_pair_failed_reason'
                .tr(namedArgs: {'reason': reason});
      case DeviceRegistrationIssue.noPairReply:
        yield 'device_add_issue_no_reply'.tr();
      case null:
        return;
    }
  }

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
          size: widget.size,
          color: widget.size >= 48
              ? context.glass.textSecondary
              : context.glass.textTertiary));
}

/// Figma secondary CTA: 56 high, 18/600, same label role as primary text.
class _PairingTextButton extends StatelessWidget {
  const _PairingTextButton(
      {super.key, required this.onPressed, required this.child});
  final VoidCallback? onPressed;
  final Widget child;
  @override
  Widget build(BuildContext context) => TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          // Figma TextButton 18/600 #3C3C3C.
          foregroundColor: context.glass.textSecondary,
          textStyle: managementStyle(context, size: 18, weight: FontWeight.w600)
              .copyWith(height: 28 / 18)),
      child: child);
}

/// Wi-Fi 연결 대기 (Figma 982:3604) — 흰 dim이 입력을 막고 가운데 62 스피너
/// + 12 + 'WiFi 연결 중' 18/600 #3C3C3C. 상단 닫기까지 가려진다.
class _ConnectingOverlay extends StatelessWidget {
  const _ConnectingOverlay();
  @override
  Widget build(BuildContext context) => Positioned.fill(
      key: const Key('device_add_connecting_overlay'),
      child: AbsorbPointer(
          child: ColoredBox(
              color: context.glass.wallpaper.withValues(alpha: 0.8),
              child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const _PairingProgress(size: 62),
                const SizedBox(height: 12),
                Text('device_add_connecting'.tr(),
                    style: managementStyle(context,
                            size: 18, weight: FontWeight.w600)
                        .copyWith(height: 28 / 18)),
              ])))));
}
