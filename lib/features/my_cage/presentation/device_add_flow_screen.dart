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
import '../../../shared/widgets/floating_cta_inset.dart';
import '../../../shared/widgets/viva_modal.dart';
import '../../notification/domain/push_consent_flow.dart';
import '../../notification/presentation/push_pre_popup.dart';
import '../domain/device_add_flow.dart';
import '../domain/network_manage.dart';
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
/// 종류별(`_device` 짝) 결과 문구 키 — 테스트가 ko.json에 짝이 모두 있는지 본다.
abstract final class DeviceAddFlowScreenKeys {
  static const kindKeyed = {
    'device_add_wifi_updated',
    'device_add_wifi_updated_waiting',
    'device_add_wifi_updated_online',
    'device_add_wifi_updated_missing',
    'device_add_wifi_missing_title',
    'device_add_wifi_checking',
    'device_add_checking_hint',
    'device_add_wifi_updated_failed',
    'device_add_register_new',
    'device_add_register_new_warning',
  };
}

class DeviceAddFlowScreen extends ConsumerStatefulWidget {
  const DeviceAddFlowScreen(
      {super.key,
      this.initialKind,
      this.onProvisioned,
      this.flowKey,
      this.wifiTarget,
      this.networkManage})
      : assert(wifiTarget == null || networkManage == null);
  final PairTargetKind? initialKind;

  /// 네트워크 관리로 열었으면 그 요청(2026-11-19, Figma 1913:6570) — 근처의 이
  /// 계정 기기 여러 대에 등록 없이 Wi-Fi만. [NetworkManageRequest.preferredIds]가
  /// 목록 맨 위로 온다.
  final NetworkManageRequest? networkManage;

  /// [Wi-Fi 바꾸기]로 열었으면 그 기기(2026-09-28) — 목록은 같은 종류만,
  /// 대상으로 보이는 기기는 미리 골라 두고, 끝나면 연 화면으로 돌아간다.
  final WifiChangeTarget? wifiTarget;
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
    final draft = GroupEditDraft.existing(group, inventory)
        .select(ManagementItem(key: newKey, name: newName, groupId: null));
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

  bool get _networkMode => widget.networkManage != null;

  Future<void> _close() async {
    final state = ref.read(deviceAddFlowProvider(_key));
    if (state.step == DeviceAddStep.results) {
      _home();
      return;
    }
    // Figma 987:4507 — 공용 확인창(문구 500/18/28 #1E1E1E, [계속 연결] 검정 ·
    // [중단] 빨강). 전엔 글자 버튼 두 개짜리 자체 대화상자였다.
    final yes = await showVivaModal(context,
        message: 'device_add_cancel_title'.tr(),
        cancelLabel: 'device_add_keep_connecting'.tr(),
        confirmLabel: 'device_add_stop'.tr());
    if (yes == true && mounted) _home();
  }

  void _home() {
    if (!mounted) return;
    // 네트워크 관리는 메뉴·기기 상세·신호 약함 모달·라이브에서 연다 — 결과 ✕·
    // 중단 모두 들어온 화면으로 돌아간다(돌아갈 곳이 없으면 홈).
    if (_networkMode) {
      _pop();
      return;
    }
    // Wi-Fi 바꾸기는 기기 상세·라이브에서 열었다 — 그 화면으로 돌아간다.
    if (widget.wifiTarget != null && context.canPop()) {
      context.pop();
      return;
    }
    context.go('/home');
  }

  /// 종류별 문구 — 결과 문구는 원래 카메라 전용이었다. 사육장도 Wi-Fi만 바꾸게
  /// 되면서(2026-09-28) `_device` 짝을 둔다. 짝이 없으면 키가 그대로 보이므로
  /// 쓰는 키는 [DeviceAddFlowScreenKeys.kindKeyed]에 모으고 테스트가 ko.json의 짝을 확인한다.
  static String _byKind(String key, PairTargetKind kind) {
    assert(DeviceAddFlowScreenKeys.kindKeyed.contains(key),
        'DeviceAddFlowScreenKeys.kindKeyed에 $key 추가');
    return kind == PairTargetKind.device ? '${key}_device' : key;
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
    // 네트워크 관리 완료 화면(Figma 1913:7778)만 상단바가 없다 — 기기별 결과는
    // 확인 중이어도 닫기가 있어야 한다.
    final showsTopBar = _networkMode
        ? step != DeviceAddStep.results ||
            state.networkResults != NetworkResultsState.allConnected
        : step != DeviceAddStep.results ||
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
                      // Figma 1912:5758 — Wi-Fi 바꾸기는 상단 제목만 바뀐다.
                      // 네트워크 관리는 모든 단계가 "네트워크 관리".
                      title: (_networkMode
                              ? 'network_manage_title'
                              : widget.wifiTarget == null
                                  ? 'device_add_title'
                                  : 'device_wifi_title')
                          .tr(),
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
                                      key:
                                          const Key('device_add_open_settings'),
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
          if (step == DeviceAddStep.connecting)
            _ConnectingOverlay(progress: _networkProgress(state)),
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
          {List<String> args = const [],
          bool busy = false,
          double subtitleLineHeight = 16.70703125}) =>
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
                    .copyWith(height: subtitleLineHeight / 14)),
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
    if (_networkMode) return _networkScan(context, state, controller);
    final candidates = [
      for (final candidate in state.candidates)
        if (state.resultOf(candidate.kind)?.canRetry != false) candidate
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
    final target = widget.wifiTarget;
    // Figma 1912:5758 — Wi-Fi 바꾸기도 본문은 기기 추가와 같다. 대상 이름·
    // 안내문을 덧붙이지 않는다(2026-11-16 기획자 지적).
    final body = [
      _heading(context, 'device_add_select_title', 'device_add_select_subtitle',
          busy: state.busy),
      if (state.targetGone)
        _emptyBox(context, 'device_wifi_target_gone'.tr())
      else if (candidates.isEmpty)
        _emptyBox(
            context,
            (state.busy ? 'device_add_searching' : 'device_add_no_devices')
                .tr())
      else
        _surface(context, [
          for (final c in candidates)
            Semantics(
                selected: state.selected.containsKey(c.physicalId),
                child: InkWell(
                    key: Key('device_add_candidate_${c.physicalId}'),
                    onTap: state.resultOf(c.kind)?.canRetry == false
                        ? null
                        : () async {
                            // 등록된 사육장을 다시 연결하면 서버가 새 기기로
                            // 등록한다(UNPAIR) — 이름·그룹·예약·기록이 끊긴다는
                            // 걸 먼저 알린다(2026-09-25).
                            final choosing =
                                !state.selected.containsKey(c.physicalId);
                            // Wi-Fi 바꾸기에서 대상으로 못 알아본 기기 — 맞는지
                            // 확인한다. 틀려도 그 기기 Wi-Fi만 바뀌고 등록은
                            // 그대로다(최종 판정은 대상 행의 서버 신호).
                            if (choosing &&
                                target != null &&
                                !state.matched.contains(c.physicalId)) {
                              final ok = await showVivaModal(context,
                                  message: 'device_wifi_confirm_other'
                                      .tr(namedArgs: {'name': target.name}),
                                  cancelLabel: 'common_cancel'.tr(),
                                  confirmLabel:
                                      'device_wifi_confirm_other_ok'.tr(),
                                  confirmKey: const Key(
                                      'device_wifi_confirm_other_ok'));
                              if (!ok || !context.mounted) return;
                            }
                            // 사육장 Wi-Fi 바꾸기를 끈 빌드에서만 — 켜져 있으면
                            // 등록된 사육장은 Wi-Fi만 바꾼다(2026-09-28).
                            if (choosing &&
                                target == null &&
                                !supportsWifiChange(c.kind) &&
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
                                    if (target == null &&
                                        state.registered
                                            .contains(c.physicalId)) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                          key: Key(
                                              'device_add_registered_${c.physicalId}'),
                                          (supportsWifiChange(c.kind)
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
                                              networkSignalIcon(c.rssi),
                                              size: 16,
                                              // Figma 신호 그림 #B4AEAE.
                                              color: context.glass.deviceOff),
                                        ])
                                  ])),
                              const SizedBox(width: 12),
                              FigmaIcon.tinted(
                                  state.selected.containsKey(c.physicalId)
                                      ? 'redesign_v2/check_box_400'
                                      : 'redesign_v2/check_box_outline_blank_400',
                                  size: 24,
                                  color:
                                      state.selected.containsKey(c.physicalId)
                                          ? context.glass.navSelected
                                          : context.glass.deviceOff),
                            ])))))
        ]),
    ];
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
            label: target == null
                ? 'device_add_selected'.tr(args: ['${state.selected.length}'])
                : 'device_wifi_next'.tr(),
            onPressed: controller.loadNetworks),
    ];
    // Figma 990:7601 — 1개 선택 시에만 안내(y667). Wi-Fi 바꾸기는 한 대뿐이다.
    final above =
        target == null && state.selected.length == 1 && candidates.length > 1
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
    // 연결 CTA 하나(위 안내 없음)를 비켜 포커스한 칸을 올린다.
    final scrollPadding = FloatingCtaInset.scrollPadding(
        _footerBottom(1, MediaQuery.viewInsetsOf(context).bottom > 0) + 56);
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
                scrollPadding: scrollPadding,
                autocorrect: false,
                // Figma 982:3500 — 입력 글자 500/16 #1E1E1E.
                style:
                    managementStyle(context, color: context.glass.textPrimary),
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
                    scrollPadding: scrollPadding,
                    obscureText: !state.showPassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: managementStyle(context,
                        color: context.glass.textPrimary),
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
    if (_networkMode) return _networkResults(context, state, controller);
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
        state.resultOf(kind)?.outcome == DeviceAddOutcome.registered;
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
              // Figma — 대기 원호는 #B4AEAE(990:11291 실측), 완료·실패 아이콘은 검정.
              color: pending
                  ? context.glass.progressTrack
                  : context.glass.textPrimary)),
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
    final kind = result.candidate.kind;
    final target = widget.wifiTarget;
    final reconnect = result.reconnect;
    final missing = reconnect == CameraReconnect.missing;
    // BLE가 성공을 주지 않은 경우(2026-09-24) — 서버 last_seen_at으로 확인 중엔
    // '확인 중', 끝내 안 붙으면 '연결 실패'(다시 연결 + 새 카메라 등록).
    final checking = result.unconfirmed && reconnect == CameraReconnect.waiting;
    final failed = result.unconfirmedFailed;
    // 대상 신호는 왔지만 고른 기기가 대상인지 모른다 — "변경완료"라고 단정하지
    // 않는다(대상이 원래 Wi-Fi로 계속 연결돼 있었을 수 있다).
    final unverified = target != null &&
        result.unverified &&
        reconnect == CameraReconnect.online;
    // 끝내 안 붙었으면 "변경완료"라고 쓰지 않는다 — ✕ 아이콘·"다시 연결되지
    // 않았어요"와 제목이 어긋났다(2026-09-25).
    final (titleKey, titleId) = failed
        ? ('device_add_results', 'device_add_wifi_failed')
        : missing
            ? (
                _byKind('device_add_wifi_missing_title', kind),
                'device_add_wifi_missing'
              )
            : checking
                ? (
                    _byKind('device_add_wifi_checking', kind),
                    'device_add_wifi_checking'
                  )
                : (
                    _byKind('device_add_wifi_updated', kind),
                    'device_add_wifi_updated'
                  );
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
              color: reconnect == CameraReconnect.waiting
                  ? context.glass.progressTrack
                  : context.glass.textPrimary)),
      const SizedBox(height: 24),
      Text(
          unverified
              ? 'device_wifi_unverified_title'
                  .tr(namedArgs: {'name': target.name})
              : titleKey.tr(),
          key: Key(unverified ? 'device_wifi_unverified' : titleId),
          textAlign: TextAlign.center,
          style: managementStyle(context, size: 18, weight: FontWeight.w600)
              .copyWith(height: 21.48046875 / 18)),
      const SizedBox(height: 8),
      Text(
          // Wi-Fi 바꾸기에서 대상 신호가 끝내 안 오면 — 다른 기기를 골랐을 수
          // 있다. 비밀번호 탓이 아니라 기기 확인이 먼저다.
          unverified
              ? 'device_wifi_unverified'.tr(namedArgs: {'name': target.name})
              : missing && target != null
                  ? 'device_wifi_target_missing'
                      .tr(namedArgs: {'name': target.name})
                  : _byKind(
                          switch (reconnect) {
                            CameraReconnect.waiting => checking
                                ? 'device_add_checking_hint'
                                : 'device_add_wifi_updated_waiting',
                            CameraReconnect.missing => failed
                                ? 'device_add_wifi_updated_failed'
                                : 'device_add_wifi_updated_missing',
                            _ => 'device_add_wifi_updated_online',
                          },
                          kind)
                      .tr(),
          textAlign: TextAlign.center,
          style: managementStyle(context, color: context.glass.bodySecondary)
              .copyWith(height: 19.09375 / 16)),
    ];
    final footer = <Widget>[
      // 대상을 잘못 골랐을 수 있으니 기기 선택부터 다시 한다.
      if ((missing || unverified) && target != null)
        ManagementButton(
            key: const Key('device_wifi_retry'),
            label: 'device_wifi_retry'.tr(),
            onPressed: state.busy ? null : controller.continueAdding)
      else if (result.canRetry)
        ManagementButton(
            key: const Key('device_add_retry_failed'),
            label: 'device_add_retry_failed'.tr(),
            onPressed: state.busy ? null : () => _network(state.ssid)),
      if (missing)
        ManagementButton(
            key: const Key('device_add_register_new'),
            label: _byKind('device_add_register_new', kind).tr(),
            onPressed: state.busy
                ? null
                : () async {
                    final ok = await showVivaModal(context,
                        message:
                            _byKind('device_add_register_new_warning', kind)
                                .tr(),
                        cancelLabel: 'common_cancel'.tr(),
                        confirmLabel: 'device_add_continue_anyway'.tr(),
                        confirmKey: const Key('device_add_register_new_ok'));
                    if (!ok || !mounted) return;
                    await controller.registerAsNew(result.candidate.physicalId);
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
        // 네트워크 관리(2026-11-19) — 그 모드는 기기별 결과 줄이 따로 그린다.
        case DeviceProvisionFailure.notOwned:
          yield 'network_manage_result_not_owned'.tr();
        case DeviceProvisionFailure.notChecked:
          yield 'network_manage_result_not_checked'.tr();
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

  /// 연결 중 "n/N · 기기 이름"(Figma 밖) — 네트워크 관리에서만.
  String? _networkProgress(DeviceAddState state) {
    if (!_networkMode ||
        state.connectingIndex <= 0 ||
        state.connectingTotal <= 0) {
      return null;
    }
    final id = state.activePhysicalId;
    final name = (id == null ? null : state.owned[id]?.device.name) ??
        (id == null ? null : state.selected[id]?.name) ??
        '';
    return 'network_manage_progress'.tr(
        args: ['${state.connectingIndex}', '${state.connectingTotal}', name]);
  }

  /// 네트워크 관리 기기 선택(Figma 1913:6462·6570) — 알아본 이 계정 기기만,
  /// 같은 종류 여러 대. 끝난(다시 못 고르는) 기기는 빠진다.
  (List<Widget>, List<Widget>, Widget?) _networkScan(BuildContext context,
      DeviceAddState state, DeviceAddFlowController controller) {
    final preferred = widget.networkManage?.preferredIds ?? const <String>{};
    final rows = [
      for (final c in state.candidates)
        if (state.owned[c.physicalId] case final match?)
          if (state.results[c.physicalId]?.canRetry != false) (c, match)
    ]..sort((a, b) => compareNetworkRows(a.$2, b.$2, preferred));
    final body = [
      _heading(context, 'network_manage_select_title',
          'network_manage_select_subtitle',
          busy: state.busy, subtitleLineHeight: 20),
      // 목록을 못 읽었으면 아무것도 못 알아본다 — 빈 상태보다 먼저 밝힌다.
      if (state.ownedLoadFailed) ...[
        _emptyBox(context, 'network_manage_load_failed'.tr()),
        if (rows.isNotEmpty) const SizedBox(height: 12),
      ] else if (rows.isEmpty)
        _emptyBox(
            context,
            (state.busy ? 'device_add_searching' : 'device_add_no_devices')
                .tr()),
      if (rows.isNotEmpty)
        _surface(context, [
          for (final (c, match) in rows)
            _NetworkDeviceRow(
                key: Key('network_manage_row_${c.physicalId}'),
                candidate: c,
                device: match.device,
                selected: state.selected.containsKey(c.physicalId),
                onTap: () => controller.select(c)),
        ]),
    ];
    // Figma 1913:6573 — 미선택은 [다시 스캔], 고르면 "기기 N개 네트워크 연결".
    // 기기 추가의 한 대 선택 안내(990:7601)는 이 모드에 없다.
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
            label: 'network_manage_selected'
                .tr(args: ['${state.selected.length}']),
            onPressed: controller.loadNetworks),
    ];
    return (body, footer, null);
  }

  /// 네트워크 관리 결과 — 전부 새 접속이 확인되면 완료 화면(Figma 1913:7778),
  /// 아니면 기기별 결과(Figma 밖). 새 기기로 등록하는 길은 없다.
  (List<Widget>, List<Widget>, Widget?) _networkResults(BuildContext context,
      DeviceAddState state, DeviceAddFlowController controller) {
    final verdict = state.networkResults;
    if (verdict == NetworkResultsState.allConnected) {
      return (
        [
          // 체크 64 y321.5(상단바 없음: 62+16+243.5). 작은 화면은 비율로 줄인다.
          SizedBox(
              height:
                  math.min(243.5, MediaQuery.sizeOf(context).height * 0.29)),
          Center(
              child: FigmaIcon.tinted('redesign_v2/check_circle',
                  size: 64, color: context.glass.textPrimary)),
          const SizedBox(height: 24),
          Text('network_manage_done'.tr(),
              key: const Key('network_manage_done'),
              textAlign: TextAlign.center,
              style: managementStyle(context, size: 18, weight: FontWeight.w600)
                  .copyWith(height: 21.48046875 / 18)),
        ],
        [
          ManagementButton(
              key: const Key('network_manage_confirm'),
              label: 'common_confirm'.tr(),
              onPressed: _pop),
        ],
        null
      );
    }
    final body = [
      // 기존 결과 제목("연결 결과") 18/600 + 16 — 부제는 없다.
      Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Text('device_add_results'.tr(),
              style: managementStyle(context, size: 18, weight: FontWeight.w600)
                  .copyWith(height: 21.48046875 / 18))),
      _surface(context, [
        for (final entry in state.results.entries)
          _NetworkResultRow(
              key: Key('network_manage_result_${entry.key}'),
              name: state.owned[entry.key]?.device.name ??
                  entry.value.candidate.name,
              status: _networkStatus(entry.value).tr()),
      ]),
    ];
    // 확인 중인 기기가 있으면 다시 찾지 않는다 — 그 기기 판정이 끝나기 전이다.
    final footer = [
      if (verdict == NetworkResultsState.someFailed)
        ManagementButton(
            key: const Key('device_wifi_retry'),
            label: 'device_wifi_retry'.tr(),
            onPressed: state.busy ? null : controller.continueAdding),
    ];
    return (body, footer, null);
  }

  /// 기기별 결과 문구 키(계획서 Task 5 표).
  static String _networkStatus(DeviceAddResult r) => switch (r.outcome) {
        DeviceAddOutcome.failed => switch (r.failure) {
            DeviceProvisionFailure.notOwned =>
              'network_manage_result_not_owned',
            DeviceProvisionFailure.notChecked =>
              'network_manage_result_not_checked',
            _ => 'network_manage_result_failed',
          },
        DeviceAddOutcome.wifiFailed => 'network_manage_result_wifi_failed',
        DeviceAddOutcome.wifiUpdated => switch (r.reconnect) {
            CameraReconnect.waiting => 'network_manage_result_checking',
            CameraReconnect.online => r.unverified
                ? 'network_manage_result_unverified'
                : 'network_manage_result_ok',
            CameraReconnect.missing => 'network_manage_result_missing',
            // 서버로 확인하지 못했다 — 붙었다고 단정하지 않는다.
            null => 'network_manage_result_unverified',
          },
        // 이 모드는 등록하지 않는다 — 오면 확인 못 함으로 보인다.
        DeviceAddOutcome.registered ||
        DeviceAddOutcome.registrationPending =>
          'network_manage_result_unverified',
      };

  /// 완료 화면 [확인] — 들어온 화면으로 돌아간다. 돌아갈 곳이 없으면 홈.
  void _pop() {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    context.go('/home');
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
          // Figma 982:3561(20)·982:3602(62) 원호 색 #B4AEAE(export 실측).
          color: context.glass.progressTrack));
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
  const _ConnectingOverlay({this.progress});

  /// 네트워크 관리의 "n/N · 기기 이름" 한 줄(Figma 밖). null이면 없다.
  final String? progress;
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
                if (progress case final line?) ...[
                  const SizedBox(height: 8),
                  Text(line,
                      key: const Key('network_manage_progress'),
                      textAlign: TextAlign.center,
                      style: managementStyle(context,
                          size: 14, color: context.glass.bodySecondary)),
                ],
              ])))));
}

/// 네트워크 관리 목록 줄(Figma 1913:6570) — 줄 64·안쪽 16, 아이콘 36 + 12 +
/// 이름 600/16 #3C3C3C / 4 / `hw_id` 500/14 #949090. 오른쪽 정렬로 Wi-Fi 이름
/// 600/16 #1E1E1E(한 줄 말줄임) / 4 / dBm 500/14 #949090 + 신호 16 #B4AEAE,
/// 오프라인이면 "네트워크 연결 없음" 600/14 #949090 한 줄. 체크 24(글과 사이 12).
class _NetworkDeviceRow extends ConsumerWidget {
  const _NetworkDeviceRow(
      {super.key,
      required this.candidate,
      required this.device,
      required this.selected,
      required this.onTap});
  final DeviceAddCandidate candidate;
  final OwnedNetworkDevice device;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = networkOffline(device);
    final serverSsid = device.wifiSsid;
    // 서버 보고가 우선, 없으면 이 폰이 붙인 이름(사용자 결정 1). 오프라인이면
    // 이름을 보이지 않으니 기억도 읽지 않는다.
    final ssid = offline
        ? null
        : serverSsid ??
            ref
                .watch(deviceWifiNameProvider((device.kind, device.id)))
                .valueOrNull;
    final rssi = offline ? null : device.wifiRssi;
    final id = candidate.physicalId;
    final hw = device.hardwareId;
    final tertiary = context.glass.textTertiary;
    final right = <Widget>[
      if (offline)
        Text('network_manage_no_connection'.tr(),
            textAlign: TextAlign.end,
            style: managementStyle(context,
                size: 14, weight: FontWeight.w600, color: tertiary)),
      if (ssid != null && ssid.isNotEmpty)
        Text(ssid,
            key: Key('network_manage_ssid_$id'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: managementStyle(context,
                weight: FontWeight.w600, color: context.glass.textPrimary)),
      if (rssi != null) ...[
        if (ssid != null && ssid.isNotEmpty) const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Flexible(
              child: Text('network_manage_dbm'.tr(args: ['$rssi']),
                  key: Key('network_manage_dbm_$id'),
                  textAlign: TextAlign.end,
                  style: managementStyle(context, size: 14, color: tertiary))),
          const SizedBox(width: 4),
          FigmaIcon.tinted(networkSignalIcon(rssi),
              size: 16, color: context.glass.deviceOff),
        ]),
      ],
    ];
    return Semantics(
        selected: selected,
        child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(children: [
                      ManagementItemIcon(device.kind == PairTargetKind.device
                          ? ManagementKind.device
                          : ManagementKind.camera),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(device.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: managementStyle(context,
                                    weight: FontWeight.w600)),
                            if (hw != null && hw.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(hw,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: managementStyle(context,
                                      size: 14, color: tertiary)),
                            ],
                          ])),
                      if (right.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Flexible(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: right)),
                      ],
                      const SizedBox(width: 12),
                      FigmaIcon.tinted(
                          selected
                              ? 'redesign_v2/check_box_400'
                              : 'redesign_v2/check_box_outline_blank_400',
                          size: 24,
                          color: selected
                              ? context.glass.navSelected
                              : context.glass.deviceOff),
                    ])))));
  }
}

/// 네트워크 관리 기기별 결과 줄(Figma 밖) — 목록 줄과 같은 면, 이름 600/16 +
/// 상태 500/14 #626262.
class _NetworkResultRow extends StatelessWidget {
  const _NetworkResultRow(
      {super.key, required this.name, required this.status});
  final String name;
  final String status;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
      // 면 Column이 가운데 정렬이라 폭을 채워 왼쪽에 붙인다.
      constraints:
          const BoxConstraints(minHeight: 64, minWidth: double.infinity),
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: managementStyle(context, weight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(status,
                    style: managementStyle(context,
                        size: 14, color: context.glass.bodySecondary)),
              ])));
}
