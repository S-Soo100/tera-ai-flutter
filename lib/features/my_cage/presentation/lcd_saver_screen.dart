import 'dart:async';
import '../../../shared/domain/keep_all_words.dart';
import '../../../shared/widgets/word_joiner_span.dart';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/figma_icon.dart';
import '../../../shared/widgets/inline_retry.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../../../shared/widgets/viva_modal.dart';
import '../../../shared/widgets/viva_stepper.dart';
import '../../home/presentation/widgets/control_feedback.dart';
import '../../home/presentation/widgets/control_loading_overlay.dart';
import '../../home/presentation/widgets/env_setting_widgets.dart';
import '../domain/lcd_photo_codec.dart';
import '../domain/lcd_screen_state.dart';
import 'lcd_screen_providers.dart';
import 'lcd_settings_screen.dart' show LcdSwitch;
import 'management_colors.dart';
import 'supabase_module_providers.dart';
import 'widgets/management_widgets.dart';

/// 보호기 시간 표기 — 60초 배수는 "N분", 1분 미만은 "N초", 그 밖(웹에서 90초
/// 등)은 "M분 S초". 칸 밖 서버값도 실제 값 그대로 읽히게(§11-4).
String lcdSaverSecondsLabel(int seconds) {
  if (seconds < 60) return 'lcd_saver_seconds'.tr(args: ['$seconds']);
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (s == 0) return 'lcd_saver_minutes'.tr(args: ['$m']);
  return 'lcd_saver_minutes_seconds'.tr(args: ['$m', '$s']);
}

/// 화면 보호 사진 설정(Figma 1659:6396 사진 없음 / 1660:6700 사진 있음).
///
/// 393 기준: 바닥 #F4F4F4(헤더도 같은 면), 헤더 y62 h44. 사진 칸 x84 y130
/// 225×180 r12 — 빈 칸 #E3E3E3 + 아이콘 40(y186, #B4AEAE) + "사진 추가" 16/500
/// 행간 28 #949090(y226). 사진 있음 = 서버 미리보기(cover) + 연필 36 원 #F4F4F4
/// (x261 y262 — 칸 오른쪽·아래 12 안쪽) → 흰 r12 메뉴 106×96(x191 y301).
/// 목록 x24 y334 w345 r16: 보호기 줄 55(18/600) / 1 / 사진 노출 56(18/500) / 1 /
/// 온습도 표시 56(18/500) — 줄 사이 1은 바닥이 비쳐 선처럼 보인다(Figma 줄
/// 57의 아래 1을 같은 선으로 그렸다). 스위치 80×32 우 8, stepper 120×32 우 12.
/// 각주 x36 y511 14/500 행간 18 #949090. 완료 CTA x12 w369 h56 r12(안전영역
/// 위 66) — 꺼짐 시간 화면과 같은 배치.
///
/// 사진은 고르는 즉시 올리고(D4) 교체·삭제도 즉시 — 완료는 보호기 설정만
/// 보낸다. 저장 안 한 변경은 뒤로 가면 버린다(확인 없음, §11-4).
class LcdSaverScreen extends ConsumerStatefulWidget {
  const LcdSaverScreen({super.key, required this.deviceId});

  final String deviceId;

  static const photoBoxKey = Key('lcd_saver_photo_box');
  static const photoAddKey = Key('lcd_saver_photo_add');
  static const photoPreviewKey = Key('lcd_saver_photo_preview');
  static const photoLoadingKey = Key('lcd_saver_photo_loading');
  static const sendingBadgeKey = Key('lcd_saver_sending_badge');
  static const editButtonKey = Key('lcd_saver_edit');
  static const menuReplaceKey = Key('lcd_saver_menu_replace');
  static const menuRemoveKey = Key('lcd_saver_menu_remove');
  static const deleteConfirmKey = Key('lcd_saver_delete_confirm');
  static const toggleRowKey = Key('lcd_saver_toggle_row');
  static const switchKey = Key('lcd_saver_switch');
  static const imageRowKey = Key('lcd_saver_image_row');
  static const infoRowKey = Key('lcd_saver_info_row');
  static const groupPendingKey = Key('lcd_saver_group_pending');
  static const noteKey = Key('lcd_saver_note');
  static const needPhotoNoteKey = Key('lcd_saver_need_photo_note');
  static const offlineNoteKey = Key('lcd_saver_offline_note');
  static const updateNoteKey = Key('lcd_saver_update_note');
  static const retryKey = Key('lcd_saver_retry');
  static const doneKey = Key('lcd_saver_done');

  @override
  ConsumerState<LcdSaverScreen> createState() => _LcdSaverScreenState();
}

class _LcdSaverScreenState extends ConsumerState<LcdSaverScreen> {
  final _editAnchor = GlobalKey();

  /// 미리보기 로드가 실패해 `GET /lcd`를 다시 읽힌 URL — 한 번만(§8 만료).
  String? _retriedUrl;

  String get _id => widget.deviceId;
  LcdCommandKey get _imageKey => (_id, LcdCommandKind.image);
  LcdCommandKey get _saverKey => (_id, LcdCommandKind.saver);

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final view = ref.watch(lcdScreenViewProvider(_id));
    final v = view.valueOrNull;
    final draft = ref.watch(lcdSaverDraftProvider(_id));
    final online = ref.watch(moduleOnlineProvider(_id));
    final image = ref.watch(lcdCommandProvider(_imageKey));
    final saver = ref.watch(lcdCommandProvider(_saverKey));

    final supported = v?.support == LcdSupport.supported;
    final loaded = supported && draft.loaded;
    final hasImage = v?.screen.hasImage ?? false;
    // 편집(스위치·stepper)은 보호기 명령 대기 중 잠근다(재진입, §11-4).
    final canEdit = loaded && online && !saver.pending;
    // 사진 칸·연필은 사진 명령 대기 중 잠근다(연속 업로드 = busy, §12-3).
    final canPhoto = loaded && online && !image.pending;
    // 사진 없이 켜는 변경은 보내지 않는다(고친 뒤 사진을 지운 경우).
    final turningOnWithoutPhoto =
        draft.enabledChanged && draft.enabled && !hasImage;
    final canSubmit =
        canEdit && draft.changed && !image.pending && !turningOnWithoutPhoto;

    // 그릴 값 — 불러오기 전엔 구 펌웨어 등 기기 행 값으로(흐리게).
    final shown = draft.loaded
        ? draft
        : v == null
            ? null
            : LcdSaverDraftState.of(v.screen.saverOrDefault);
    final failed = v == null && view.hasError && !view.isLoading;

    final inset = MediaQuery.paddingOf(context).bottom;
    final ctaBottom = inset + 66;

    return Scaffold(
      backgroundColor: glass.surfaceTint,
      body: Stack(children: [
        Column(children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ManagementTopBar(
                  title: 'lcd_saver_title'.tr(),
                  onBack: () => Navigator.of(context).maybePop()),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, ctaBottom + 56 + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: failed
                    ? [
                        Text('lcd_settings_load_failed'.tr(),
                            textAlign: TextAlign.center,
                            style: _noteStyle(context)),
                        InlineRetry(
                            key: LcdSaverScreen.retryKey,
                            onRetry: () {
                              ref.invalidate(lcdSnapshotProvider(_id));
                              ref.invalidate(lcdLinkRefreshProvider(_id));
                            }),
                      ]
                    : [
                        Center(
                          child: _photoBox(context,
                              view: v,
                              loaded: loaded,
                              hasImage: hasImage,
                              image: image,
                              canPhoto: canPhoto),
                        ),
                        const SizedBox(height: 24),
                        if (shown == null)
                          const _GroupSkeleton()
                        else
                          _group(context,
                              shown: shown,
                              hasImage: hasImage,
                              canEdit: canEdit,
                              online: online,
                              loaded: loaded,
                              pending: saver.pending),
                        ..._notes(context,
                            view: v,
                            supported: supported,
                            hasImage: hasImage,
                            online: online),
                      ],
              ),
            ),
          ),
        ]),
        Positioned(
          left: 12,
          right: 12,
          bottom: ctaBottom,
          child: SizedBox(
            height: 56,
            child: FilledButton(
              key: LcdSaverScreen.doneKey,
              onPressed:
                  canSubmit && v != null ? () => _submit(draft, v) : null,
              style: FilledButton.styleFrom(
                  backgroundColor: glass.textPrimary,
                  disabledBackgroundColor: glass.border,
                  foregroundColor: ManagementColors.buttonForeground(context),
                  disabledForegroundColor:
                      ManagementColors.buttonForeground(context),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: managementStyle(context,
                          size: 18, weight: FontWeight.w600)
                      .copyWith(height: 28 / 18)),
              child: Text('lcd_done'.tr()),
            ),
          ),
        ),
      ]),
    );
  }

  // ── 사진 칸 ────────────────────────────────────────────────────────────────

  Widget _photoBox(
    BuildContext context, {
    required LcdScreenView? view,
    required bool loaded,
    required bool hasImage,
    required LcdCommandState image,
    required bool canPhoto,
  }) {
    final glass = context.glass;
    final target = image.target;
    final uploading = target is LcdImageTarget && !target.isDelete;
    final deleting = target is LcdImageTarget && target.isDelete;

    Widget content;
    var showEdit = false;
    if (view == null || (view.support == LcdSupport.supported && !loaded)) {
      content = const SkeletonLoading(
          key: LcdSaverScreen.photoLoadingKey,
          width: 225,
          height: 180,
          borderRadius: 12);
    } else if (uploading) {
      // 201의 서버 미리보기(기기 화면과 같은 색·자르기) — 오기 전엔 자른 사진.
      // 같은 바이트를 그대로 써야 다시 그릴 때 이미지를 새로 읽지 않는다.
      final raw = target.bytes!;
      final bytes = raw is Uint8List ? raw : Uint8List.fromList(raw);
      final url = image.uploadPreviewUrl;
      content = url == null
          ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
          : Image.network(url,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) =>
                  Image.memory(bytes, fit: BoxFit.cover));
    } else if (hasImage) {
      content = _preview(context, view, image);
      showEdit = !deleting;
    } else {
      content = _emptyBox(context);
    }

    final sending = uploading || deleting;
    return SizedBox(
      key: LcdSaverScreen.photoBoxKey,
      width: 225,
      height: 180,
      child: Stack(fit: StackFit.expand, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: !hasImage && !uploading && view != null && loaded
              ? Semantics(
                  button: true,
                  enabled: canPhoto,
                  child: GestureDetector(
                    key: LcdSaverScreen.photoAddKey,
                    behavior: HitTestBehavior.opaque,
                    onTap: canPhoto ? _pickAndUpload : null,
                    child: Opacity(opacity: canPhoto ? 1 : 0.4, child: content),
                  ),
                )
              : content,
        ),
        if (sending)
          Positioned(
            left: 8,
            top: 8,
            child: _SendingBadge(
                text: (deleting ? 'lcd_photo_deleting' : 'lcd_photo_sending')
                    .tr()),
          ),
        if (showEdit)
          Positioned(
            right: 12,
            bottom: 12,
            child: Semantics(
              button: true,
              enabled: canPhoto,
              label: 'lcd_photo_edit'.tr(),
              excludeSemantics: true,
              child: Opacity(
                opacity: canPhoto ? 1 : 0.4,
                child: GestureDetector(
                  key: LcdSaverScreen.editButtonKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: canPhoto ? _openMenu : null,
                  child: Container(
                    key: _editAnchor,
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: glass.surfaceTint, shape: BoxShape.circle),
                    child: FigmaIcon.tinted(FigmaIcons.edit,
                        size: 36, color: glass.textSecondary),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  /// 빈 칸 — 아이콘 40 + "사진 추가"(칸 가운데, 위아래 56).
  Widget _emptyBox(BuildContext context) {
    final glass = context.glass;
    return ColoredBox(
      color: glass.border,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FigmaIcon.tinted('redesign_v2/add_photo_alternate',
              size: 40, color: glass.deviceOff),
          Text('lcd_photo_add'.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: envSettingText(context,
                  size: 16,
                  weight: FontWeight.w500,
                  lineHeight: 28,
                  color: glass.textTertiary)),
        ],
      ),
    );
  }

  /// 서버 미리보기(1시간 presigned, 디스크 캐시 없음 — `Image.network`).
  Widget _preview(
      BuildContext context, LcdScreenView view, LcdCommandState image) {
    final key = view.screen.imageKey!;
    final preview = ref.watch(lcdPreviewUrlProvider((_id, key)));
    // 방금 올린 사진이면 새 URL을 받는 동안 201 미리보기를 그대로 둔다.
    final fallback = image.result?.isOk == true ? image.uploadPreviewUrl : null;
    final url = preview.valueOrNull ?? fallback;
    if (url == null) {
      return preview.isLoading
          ? const SkeletonLoading(
              key: LcdSaverScreen.photoLoadingKey,
              width: 225,
              height: 180,
              borderRadius: 12)
          : ColoredBox(color: context.glass.border);
    }
    return Image.network(
      url,
      key: LcdSaverScreen.photoPreviewKey,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, _, __) {
        _retryPreviewOnce(url);
        return ColoredBox(color: context.glass.border);
      },
    );
  }

  /// 미리보기 로드 실패(만료 등) — `GET /lcd`를 한 번 다시 읽는다(§8).
  void _retryPreviewOnce(String url) {
    if (_retriedUrl == url) return;
    _retriedUrl = url;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(lcdSnapshotProvider(_id));
    });
  }

  // ── 목록 ───────────────────────────────────────────────────────────────────

  Widget _group(
    BuildContext context, {
    required LcdSaverDraftState shown,
    required bool hasImage,
    required bool canEdit,
    required bool online,
    required bool loaded,
    required bool pending,
  }) {
    final draft = ref.read(lcdSaverDraftProvider(_id).notifier);
    final enabled = shown.enabled;
    // 사진이 없으면 켜기만 막는다 — 켜져 있으면 끌 수는 있다(§11-4).
    final canToggle = canEdit && (enabled || hasImage);
    VoidCallback? stepper(LcdSaverTime which, LcdStepper s, int value, int d) =>
        canEdit && s.canStep(value, d) ? () => draft.step(which, d) : null;

    final group = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SaverRow(
            key: LcdSaverScreen.toggleRowKey,
            minHeight: 55,
            rightPadding: 8,
            title: 'lcd_saver_toggle'.tr(args: [
              (enabled ? 'lcd_state_on' : 'lcd_state_off').tr(),
            ]),
            weight: FontWeight.w600,
            dimmed: !loaded,
            trailing: LcdSwitch(
              key: LcdSaverScreen.switchKey,
              value: enabled,
              enabled: canToggle,
              dimmed: loaded && !canToggle && !pending,
              onChanged: draft.setEnabled,
            ),
          ),
          const SizedBox(height: 1),
          _SaverRow(
            key: LcdSaverScreen.imageRowKey,
            minHeight: 56,
            rightPadding: 12,
            title: 'lcd_saver_image_sec'.tr(),
            weight: FontWeight.w500,
            dimmed: !loaded,
            trailing: VivaStepper(
              value: lcdSaverSecondsLabel(shown.imageSec),
              onDecrease: stepper(
                  LcdSaverTime.image, kLcdImageSecStepper, shown.imageSec, -1),
              onIncrease: stepper(
                  LcdSaverTime.image, kLcdImageSecStepper, shown.imageSec, 1),
            ),
          ),
          const SizedBox(height: 1),
          _SaverRow(
            key: LcdSaverScreen.infoRowKey,
            minHeight: 56,
            rightPadding: 12,
            title: 'lcd_saver_info_sec'.tr(),
            weight: FontWeight.w500,
            dimmed: !loaded,
            trailing: VivaStepper(
              value: lcdSaverSecondsLabel(shown.infoSec),
              onDecrease: stepper(
                  LcdSaverTime.info, kLcdInfoSecStepper, shown.infoSec, -1),
              onIncrease: stepper(
                  LcdSaverTime.info, kLcdInfoSecStepper, shown.infoSec, 1),
            ),
          ),
        ],
      ),
    );
    if (!pending) return group;
    // 보호기 명령 대기 중 재진입 — 확인될 때까지 편집 잠금(§11-4).
    return Stack(children: [
      group,
      Positioned.fill(
        child: ControlLoadingOverlay(
            key: LcdSaverScreen.groupPendingKey,
            borderRadius: BorderRadius.circular(16)),
      ),
    ]);
  }

  List<Widget> _notes(
    BuildContext context, {
    required LcdScreenView? view,
    required bool supported,
    required bool hasImage,
    required bool online,
  }) {
    if (view == null) return const [];
    if (!supported) {
      return [
        _Note('lcd_needs_update_note'.tr(),
            textKey: LcdSaverScreen.updateNoteKey),
      ];
    }
    final imageOnly = view.screen.saverOrDefault.mode == LcdSaverMode.image;
    return [
      _Note((imageOnly ? 'lcd_saver_note_image' : 'lcd_saver_note').tr(),
          textKey: LcdSaverScreen.noteKey),
      if (!hasImage)
        _Note('lcd_photo_need_photo'.tr(),
            textKey: LcdSaverScreen.needPhotoNoteKey),
      if (!online)
        _Note('lcd_offline_note'.tr(),
            textKey: LcdSaverScreen.offlineNoteKey,
            color: Theme.of(context).colorScheme.error),
    ];
  }

  // ── 동작 ───────────────────────────────────────────────────────────────────

  /// 보호기 설정을 보내고 바로 돌아간다 — 대기는 설정 화면 줄의 반짝임(§11-4).
  void _submit(LcdSaverDraftState draft, LcdScreenView view) {
    final settings = draft.toSettings(view.screen.saverOrDefault);
    unawaited(ref
        .read(lcdCommandProvider(_saverKey).notifier)
        .run(LcdSaverTarget(settings)));
    unawaited(Navigator.of(context).maybePop());
  }

  /// 사진첩 → 자르기 → 업로드(D4). 결과 안내는 실행기가 화면 밖에서도 한다.
  Future<void> _pickAndUpload() async {
    final picker = ref.read(lcdPhotoPickerProvider);
    final feedback = ControlFeedback.of(context);
    final pick = await picker(context, _id);
    if (!mounted) return;
    switch (pick) {
      case LcdPhotoCancelled():
        return;
      case LcdPhotoUnreadable():
        feedback.show('lcd_photo_unreadable'.tr());
        return;
      case LcdPhotoPicked(:final bytes):
        if (bytes.length > kLcdPhotoMaxBytes) {
          feedback.show('lcd_photo_too_big'.tr());
          return;
        }
        final view = ref.read(lcdScreenViewProvider(_id)).valueOrNull;
        await ref.read(lcdCommandProvider(_imageKey).notifier).run(
            LcdImageTarget.upload(bytes,
                previousKey: view?.rawImageKey,
                previousUpdatedAt: view?.screen.updatedAt),
            onResult: (r) => _announcePhoto(feedback, r));
    }
  }

  Future<void> _delete() async {
    final feedback = ControlFeedback.of(context);
    final ok = await showVivaModal(context,
        message: 'lcd_photo_delete_confirm'.tr(),
        detail: 'lcd_photo_delete_detail'.tr(),
        cancelLabel: 'common_cancel'.tr(),
        confirmLabel: 'lcd_photo_delete_ok'.tr(),
        confirmKey: LcdSaverScreen.deleteConfirmKey);
    if (!ok || !mounted) return;
    final view = ref.read(lcdScreenViewProvider(_id)).valueOrNull;
    await ref.read(lcdCommandProvider(_imageKey).notifier).run(
        LcdImageTarget.delete(
            previousKey: view?.rawImageKey,
            previousUpdatedAt: view?.screen.updatedAt),
        onResult: (r) => _announcePhoto(feedback, r));
  }

  /// 사진 결과 안내 — 성공은 조용히(배지가 사라진다), 실패는 이유(§12-2).
  /// 화면이 사라진 뒤에도 불린다 — 루트 Overlay만 쓴다.
  static void _announcePhoto(ControlFeedback feedback, LcdCommandResult r) {
    final key = r.messageKeyFor(LcdCommandKind.image);
    if (key != null) feedback.show(key.tr());
  }

  /// 연필 → `사진 교체 / 사진 삭제` 메뉴(흰 r12 106×96, 연필 아래 3·오른쪽
  /// 끝 맞춤 — Figma x191 y301). 모양은 개체 정보 입력의 같은 메뉴와 같다
  /// (그림자·항목 사이 선 — Figma 프레임엔 그림자 없음).
  Future<void> _openMenu() async {
    final anchor = _editAnchor.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (anchor == null || overlay == null) return;
    final origin = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    final glass = context.glass;
    const width = 106.0;
    final action = await showMenu<String>(
      context: context,
      color: glass.surfaceHeader,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shadowColor: glass.textPrimary.withValues(alpha: .12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      constraints: const BoxConstraints.tightFor(width: width),
      menuPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      position: RelativeRect.fromRect(
          Rect.fromLTWH(origin.dx + anchor.size.width - width,
              origin.dy + anchor.size.height + 3, width, 0),
          Offset.zero & overlay.size),
      items: [
        for (final (value, label, key) in [
          ('replace', 'lcd_photo_replace', LcdSaverScreen.menuReplaceKey),
          ('remove', 'lcd_photo_remove', LcdSaverScreen.menuRemoveKey),
        ])
          PopupMenuItem<String>(
            key: key,
            value: value,
            height: 44,
            padding: EdgeInsets.zero,
            child: Container(
              height: 44,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: value == 'replace'
                  ? BoxDecoration(
                      border: Border(bottom: BorderSide(color: glass.border)))
                  : null,
              child: Text(label.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: envSettingText(context,
                      size: 18,
                      weight: FontWeight.w500,
                      lineHeight: 28,
                      color: glass.textSecondary)),
            ),
          ),
      ],
    );
    if (!mounted || action == null) return;
    // 메뉴가 떠 있는 사이 오프라인·다른 사진 대기가 됐을 수 있다.
    final online = ref.read(moduleOnlineProvider(_id));
    if (!online || ref.read(lcdCommandProvider(_imageKey)).pending) return;
    if (action == 'replace') {
      await _pickAndUpload();
    } else {
      await _delete();
    }
  }
}

TextStyle _noteStyle(BuildContext context, {Color? color}) =>
    envSettingText(context,
        size: 14,
        weight: FontWeight.w500,
        lineHeight: 18,
        color: color ?? context.glass.textTertiary);

/// 목록 아래 각주 — 위 8, 왼쪽 12(x36).
class _Note extends StatelessWidget {
  const _Note(this.text, {required this.textKey, this.color});
  final String text;
  final Key textKey;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, left: 12, right: 12),
        child: Text.rich(wordJoinerSpan(keepAllWords(text)),
            key: textKey, style: _noteStyle(context, color: color)),
      );
}

/// 목록 줄 — 흰 면, 제목 18 행간 21.48 #3C3C3C 왼쪽 12. 최소 높이는 Figma
/// 값이고 글자를 키우면 늘어난다.
class _SaverRow extends StatelessWidget {
  const _SaverRow({
    super.key,
    required this.title,
    required this.weight,
    required this.minHeight,
    required this.rightPadding,
    required this.trailing,
    this.dimmed = false,
  });

  final String title;
  final FontWeight weight;
  final double minHeight;
  final double rightPadding;
  final Widget trailing;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    Widget row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: EdgeInsets.only(left: 12, right: rightPadding),
        child: Row(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(title,
                  style: envSettingText(context,
                      size: 18,
                      weight: weight,
                      lineHeight: 21.48,
                      color: glass.textSecondary)),
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ]),
      ),
    );
    if (dimmed) {
      row = IgnorePointer(child: Opacity(opacity: 0.4, child: row));
    }
    return ColoredBox(color: glass.surfaceHeader, child: row);
  }
}

/// 불러오는 중 목록 자리.
class _GroupSkeleton extends StatelessWidget {
  const _GroupSkeleton();

  @override
  Widget build(BuildContext context) => const SkeletonLoading(
      width: double.infinity, height: 169, borderRadius: 16);
}

/// "기기로 보내는 중" 배지 — 사진 칸 왼쪽 위 8 안쪽, 짙은 반투명 r8 + 밝은
/// 12/600 글자(Figma 밖).
class _SendingBadge extends StatelessWidget {
  const _SendingBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Container(
      key: LcdSaverScreen.sendingBadgeKey,
      constraints: const BoxConstraints(maxWidth: 209),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: glass.textPrimary.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: envSettingText(context,
              size: 12,
              weight: FontWeight.w600,
              lineHeight: 16,
              color: ManagementColors.buttonForeground(context))),
    );
  }
}
