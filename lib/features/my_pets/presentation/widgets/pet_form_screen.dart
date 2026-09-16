import 'dart:io';
import 'dart:ui' show SemanticsValidationResult;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' as math;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/glass_palette.dart';
import '../../../../core/theme/viva_colors.dart';
import '../../../../shared/widgets/figma_icon.dart';
import '../../../my_cage/domain/redesign_management.dart';
import '../../../my_cage/presentation/widgets/link_confirm_screen.dart';
import '../../../my_cage/presentation/widgets/management_widgets.dart';
import '../../../wiki/presentation/wiki_providers.dart';
import '../../domain/pet.dart';
import '../../domain/pet_form_draft.dart';
import '../../domain/pet_form_state.dart';
import '../../domain/pet_registration_catalog.dart';
import '../my_pets_providers.dart';
import '../pet_form_providers.dart';

class PetFormScreen extends ConsumerStatefulWidget {
  const PetFormScreen(
      {super.key,
      this.original,
      this.groups = const [],
      this.onSave,
      this.initialGroupId});
  final Pet? original;
  final List<PetFormGroupOption> groups;
  final PetFormSave? onSave;
  final String? initialGroupId;
  @override
  ConsumerState<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends ConsumerState<PetFormScreen> {
  late final PetFormSession _session;
  late final TextEditingController _name;
  late final TextEditingController _weight;
  late final TextEditingController _memo;
  bool _exitDialogOpen = false;
  final _speciesAnchor = GlobalKey();
  final _photoAnchor = GlobalKey();

  @override
  void initState() {
    super.initState();
    _session = PetFormSession(
        id: widget.original?.id ?? const Uuid().v4(),
        original: widget.original,
        initialGroupId: widget.initialGroupId);
    _name = TextEditingController(text: _session.initial.name);
    _weight =
        TextEditingController(text: _weightWithUnit(_session.initial.weight));
    _memo = TextEditingController(text: _session.initial.memo);
  }

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    _memo.dispose();
    super.dispose();
  }

  void _change(PetFormDraft Function(PetFormDraft) update) {
    final notifier = ref.read(petFormProvider(_session).notifier);
    notifier.change(update(ref.read(petFormProvider(_session)).draft));
  }

  Future<void> _exit() async {
    final state = ref.read(petFormProvider(_session));
    if (state.saving || _exitDialogOpen) return;
    if (!state.saved && !state.draft.sameInput(_session.initial)) {
      _exitDialogOpen = true;
      final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                title: Text('pet_form_discard_title'.tr()),
                content: Text('pet_form_discard_body'.tr()),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('pet_form_keep'.tr())),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('pet_form_discard'.tr()))
                ],
              ));
      _exitDialogOpen = false;
      if (discard != true || !mounted) return;
    }
    if (!mounted) return;
    ref.read(petFormProvider(_session).notifier).confirmExit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _species() async {
    final box = _speciesAnchor.currentContext!.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final choice = await showMenu<String>(
      context: context,
      color: context.glass.surfaceHeader,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      menuPadding: const EdgeInsets.symmetric(vertical: 4),
      constraints: BoxConstraints.tightFor(width: box.size.width),
      position: RelativeRect.fromRect(
          Rect.fromLTWH(
              origin.dx, origin.dy + box.size.height, box.size.width, 0),
          Offset.zero & overlay.size),
      items: [
        PopupMenuItem(
            value: 'crested-gecko',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('pet_form_crested'.tr(),
                style: petFormText(context).copyWith(
                    fontSize: 18,
                    height: 28 / 18,
                    letterSpacing: -.36,
                    color: context.glass.textSecondary)))
      ],
    );
    if (choice != null && mounted) {
      _change((d) =>
          d.copyWith(speciesId: choice, speciesName: 'pet_form_crested'.tr()));
    }
  }

  Future<void> _photo() async {
    final draft = ref.read(petFormProvider(_session)).draft;
    final String? action;
    if (draft.photoPath != null) {
      final box = _photoAnchor.currentContext!.findRenderObject()! as RenderBox;
      final overlay =
          Overlay.of(context).context.findRenderObject()! as RenderBox;
      final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
      final palette = context.glass;
      action = await showMenu<String>(
        context: context,
        color: palette.surfaceHeader,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: palette.textPrimary.withValues(alpha: .12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        constraints: const BoxConstraints.tightFor(width: 106),
        menuPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        position: RelativeRect.fromRect(
            Rect.fromLTWH(origin.dx + box.size.width - 106,
                origin.dy + box.size.height + 4, 106, 0),
            Offset.zero & overlay.size),
        items: [
          for (final item in [
            ('pick', 'pet_form_photo_replace'),
            ('remove', 'pet_form_photo_remove')
          ])
            PopupMenuItem<String>(
              value: item.$1,
              height: 44,
              padding: EdgeInsets.zero,
              child: Container(
                height: 44,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: item.$1 == 'pick'
                    ? BoxDecoration(
                        border:
                            Border(bottom: BorderSide(color: palette.border)))
                    : null,
                child: Text(item.$2.tr(),
                    style: petFormText(context).copyWith(
                        fontSize: 18,
                        height: 28 / 18,
                        letterSpacing: -.36,
                        color: palette.textSecondary)),
              ),
            ),
        ],
      );
    } else {
      action = await showModalBottomSheet<String>(
          context: context,
          builder: (ctx) => SafeArea(
                child: ListTile(
                    title: Text('pet_form_photo_add'.tr()),
                    onTap: () => Navigator.pop(ctx, 'pick')),
              ));
    }
    if (!mounted) return;
    if (action == 'remove') {
      _change((d) => d.copyWith(photoPath: null));
      return;
    }
    if (action != 'pick') return;
    try {
      final photo = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 80);
      if (mounted && photo != null) {
        _change((d) => d.copyWith(photoPath: photo.path));
      }
    } catch (_) {
      if (mounted) {
        ref
            .read(petFormProvider(_session).notifier)
            .showError('pet_form_photo_failed');
      }
    }
  }

  Future<void> _date(bool birth) async {
    final draft = ref.read(petFormProvider(_session)).draft;
    final old = birth ? draft.birthDate : draft.adoptionDate;
    final now = DateUtils.dateOnly(DateTime.now());
    final first =
        old != null && old.isBefore(DateTime(1900)) ? old : DateTime(1900);
    var selected = old == null || old.isAfter(now) ? now : old;
    final picked = await showDialog<({DateTime? value})>(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
              final labels = MaterialLocalizations.of(ctx);
              return AlertDialog(
                backgroundColor: ctx.glass.surfaceHeader,
                surfaceTintColor: Colors.transparent,
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title:
                    Text((birth ? 'pet_form_birth' : 'pet_form_adoption').tr()),
                content: SizedBox(
                  width: 328,
                  height: 336,
                  child: CalendarDatePicker(
                    initialDate: selected,
                    firstDate: first,
                    lastDate: now,
                    onDateChanged: (date) =>
                        setDialogState(() => selected = date),
                  ),
                ),
                actions: [
                  if (old != null)
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, (value: null)),
                        child: Text('pet_form_none'.tr())),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(labels.cancelButtonLabel)),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, (value: selected)),
                      child: Text(labels.okButtonLabel)),
                ],
              );
            }));
    if (mounted && picked != null) {
      _change((d) => birth
          ? d.copyWith(birthDate: picked.value)
          : d.copyWith(adoptionDate: picked.value));
    }
  }

  Future<void> _morph() async {
    final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const _MorphSelectionScreen()));
    if (mounted && result != null) {
      _change((d) => d.copyWith(morph: result));
    }
  }

  Future<void> _groups() async {
    if (widget.onSave == null) {
      ref
          .read(petFormProvider(_session).notifier)
          .showError('pet_form_group_unavailable');
      return;
    }
    // Figma 1043:3649 — 전체 화면 그룹 카드 선택. 폼 draft만 바꾸고 저장은
    // 기존 저장 시점에 한 번 한다.
    final current = ref.read(petFormProvider(_session)).draft.groupId;
    final result = await Navigator.of(context).push<({String? value})>(
        MaterialPageRoute(
            builder: (_) => _GroupSelectionScreen(
                groups: widget.groups, initialGroupId: current)));
    if (mounted && result != null) {
      _change((d) => d.copyWith(groupId: result.value));
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final PetFormSave persist =
        widget.onSave ?? ref.read(petFormDefaultSaveProvider);
    Pet? savedPet;
    final saved = await ref.read(petFormProvider(_session).notifier).save(
        persist: (pet, groupId) async {
          await persist(pet, groupId);
          savedPet = pet;
        },
        storePhoto: ref.read(petFormPhotoStoreProvider),
        peers: ref.read(petListProvider));
    if (saved && mounted) {
      final isNew = widget.original == null;
      // 그룹을 안 고르고 등록했는데 기기가 있는 그룹이 딱 하나면 연결 카드
      // (Figma 994:13307, 2026-09-16 사용자 결정). 여러 개·없음이면 완료 화면.
      final groupId = ref.read(petFormProvider(_session)).draft.groupId;
      final candidates = groupId == null
          ? widget.groups.where((g) => g.hasDevice || g.hasCamera).toList()
          : const <PetFormGroupOption>[];
      final link = candidates.length == 1 ? candidates.single : null;
      final pet = savedPet;
      // PopScope receives the committed state before leaving.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (isNew) {
          // Figma 1035:2735 — 신규 등록 성공에만 완료 화면. 폼 라우트를 교체하므로
          // 뒤로가기로 폼에 돌아와 같은 개체를 또 만들지 않는다.
          Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
              builder: (_) => _PetRegisteredScreen(
                  link: link,
                  onLink: link == null || pet == null
                      ? null
                      : () => persist(pet, link.id))));
        } else {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(petFormProvider(_session));
    final peers = ref.watch(petListProvider);
    final d = state.draft;
    final p = context.glass;
    final nameError = (state.submitted || d.name.isNotEmpty)
        ? validatePetName(d.name, peers, excludingId: _session.id)
        : null;
    final weightError = validatePetWeight(d.weight);
    final canSave = !state.saving &&
        d.speciesId != null &&
        validatePetName(d.name, peers, excludingId: _session.id) == null &&
        weightError == null;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final saveBottom = keyboardOpen
        ? 16.0
        : (MediaQuery.paddingOf(context).bottom + 16)
            .clamp(100.0, double.infinity);
    final scrollBottom =
        saveBottom + 56 + 24 + (state.errorKey != null ? 64 : 0);
    final editorScrollPadding = EdgeInsets.fromLTRB(20, 20, 20, scrollBottom);
    final groupNames = {for (final g in widget.groups) g.id: g.name};
    final legacy = _session.initial.speciesId != null &&
        _session.initial.speciesId != 'crested-gecko';
    return PopScope(
      canPop: !state.saving &&
          (state.saved || state.exitConfirmed || d.sameInput(_session.initial)),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        backgroundColor: p.surfaceHeader,
        appBar: petFormAppBar(context, 'pet_form_title'.tr(), _exit),
        body: AbsorbPointer(
            absorbing: state.saving,
            child: Stack(children: [
              ListView(
                padding: EdgeInsets.fromLTRB(12, 16, 12, scrollBottom),
                children: [
                  Center(
                      child: Semantics(
                          button: true,
                          label: 'pet_form_photo_add'.tr(),
                          child: InkWell(
                            onTap: _photo,
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                                width: 180,
                                height: 180,
                                child: Stack(fit: StackFit.expand, children: [
                                  ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: d.photoPath == null
                                          ? ColoredBox(
                                              color: p.outline,
                                              child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    FigmaIcon.tinted(
                                                        'redesign_v2/add_photo_alternate',
                                                        color: p.deviceOff,
                                                        size: 40),
                                                    Text(
                                                        'pet_form_photo_add'
                                                            .tr(),
                                                        style: petFormText(
                                                                context)
                                                            .copyWith(
                                                                color: p
                                                                    .textTertiary,
                                                                height: 1.75)),
                                                  ]))
                                          : PetFormPhoto(
                                              path: d.photoPath, size: 180)),
                                  if (d.photoPath != null)
                                    Positioned(
                                        right: 12,
                                        bottom: 12,
                                        child: Container(
                                            key: _photoAnchor,
                                            width: 36,
                                            height: 36,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                                color: p.surfaceTint,
                                                shape: BoxShape.circle),
                                            child: FigmaIcon.tinted(
                                                FigmaIcons.edit,
                                                color: p.textSecondary,
                                                size: 36))),
                                ])),
                          ))),
                  const SizedBox(height: 24),
                  _Field(
                      label: 'pet_form_name'.tr(),
                      errorText: nameError?.tr(),
                      child: TextFormField(
                        key: const ValueKey('pet-form-name'),
                        controller: _name,
                        scrollPadding: editorScrollPadding,
                        style: petFormText(context),
                        onChanged: (value) =>
                            _change((d) => d.copyWith(name: value)),
                        decoration: petFormDecoration(context,
                                invalid: nameError != null)
                            .copyWith(
                                // Unlike suffixText, the counter stays visible on an
                                // empty, unfocused field.
                                suffixIconConstraints: const BoxConstraints(),
                                suffixIcon: Padding(
                                  padding: const EdgeInsets.only(right: 17),
                                  child: Text('${d.name.characters.length}/10',
                                      style: petFormText(context)
                                          .copyWith(color: p.textTertiary)),
                                )),
                      )),
                  _Field(
                      label: 'pet_form_species'.tr(),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            KeyedSubtree(
                                key: const ValueKey('pet-form-species'),
                                child: KeyedSubtree(
                                    key: _speciesAnchor,
                                    child: _Selection(
                                        label: legacy
                                            ? _session.initial.speciesName
                                            : d.speciesId == null
                                                ? ''
                                                : 'pet_form_crested'.tr(),
                                        icon: 'redesign_v2/arrow_drop_down',
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 17, vertical: 20.5),
                                        onTap: legacy ? null : _species))),
                            if (state.submitted && d.speciesId == null)
                              Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(17, 8, 17, 0),
                                  child: Text('pet_form_required'.tr(),
                                      style: petFormText(context).copyWith(
                                          fontSize: 12, color: p.navSelected))),
                          ])),
                  _Field(
                      label: 'pet_form_morph'.tr(),
                      child: _Selection(
                          label: d.morph ?? 'pet_form_none'.tr(),
                          icon: 'redesign_v2/search',
                          onTap: legacy ? null : _morph,
                          muted: d.morph == null)),
                  _Field(
                      label: 'pet_form_sex'.tr(),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Row(children: [
                            for (final sex in ['male', 'female', 'unknown'])
                              Expanded(
                                  child: Semantics(
                                      selected: d.sex == sex,
                                      button: true,
                                      child: InkWell(
                                        onTap: () => _change(
                                            (d) => d.copyWith(sex: sex)),
                                        child: Container(
                                            height: 40,
                                            decoration: BoxDecoration(
                                                color: d.sex == sex
                                                    ? AppTheme.brandNavy
                                                    : p.surfaceTint,
                                                border: (sex == 'male' &&
                                                            d.sex ==
                                                                'unknown') ||
                                                        (sex == 'female' &&
                                                            d.sex == 'male')
                                                    ? Border(
                                                        right: BorderSide(
                                                            color: p.border))
                                                    : null),
                                            child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  if (d.sex == sex) ...[
                                                    SizedBox(
                                                        width: 24,
                                                        height: 24,
                                                        child: Center(
                                                            child: FigmaIcon.tinted(
                                                                'redesign_v2/check',
                                                                color: VivaColors
                                                                    .fillBack,
                                                                size: 11))),
                                                    const SizedBox(width: 4)
                                                  ],
                                                  Text('pet_form_sex_$sex'.tr(),
                                                      style: petFormText(
                                                              context)
                                                          .copyWith(
                                                              color: d.sex ==
                                                                      sex
                                                                  ? VivaColors
                                                                      .fillBack
                                                                  : p.textSecondary)),
                                                ])),
                                      ))),
                          ]))),
                  _dateField(d.birthDate, true),
                  _dateField(d.adoptionDate, false),
                  _Field(
                      label: 'pet_form_weight'.tr(),
                      child: TextFormField(
                        key: const ValueKey('pet-form-weight'),
                        controller: _weight,
                        scrollPadding: editorScrollPadding,
                        inputFormatters: [const _WeightUnitFormatter()],
                        style: petFormText(context),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (value) => _change((d) =>
                            d.copyWith(weight: _weightWithoutUnit(value))),
                        decoration: petFormDecoration(context)
                            .copyWith(errorText: weightError?.tr()),
                      )),
                  _Field(
                      label: 'pet_form_group'.tr(),
                      child: _Selection(
                          label: d.groupId == null
                              ? 'pet_form_no_group'.tr()
                              : groupNames[d.groupId] ??
                                  'pet_form_current_group'.tr(),
                          icon: FigmaIcons.arrowNext,
                          actionLabel: 'pet_form_group_settings'.tr(),
                          onTap: _groups,
                          muted: d.groupId == null)),
                  _Field(
                      label: 'pet_form_memo'.tr(),
                      bottom: 12,
                      child: TextFormField(
                        key: const ValueKey('pet-form-memo'),
                        controller: _memo,
                        scrollPadding: editorScrollPadding,
                        style: petFormText(context),
                        minLines: 5,
                        maxLines: 5,
                        onChanged: (value) =>
                            _change((d) => d.copyWith(memo: value)),
                        decoration: petFormDecoration(context).copyWith(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 13, vertical: 17.5)),
                      )),
                ],
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: saveBottom,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (state.errorKey != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: p.surfaceHeader,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Semantics(
                                  liveRegion: true,
                                  child: Text(state.errorKey!.tr(),
                                      textAlign: TextAlign.center,
                                      style: petFormText(context).copyWith(
                                          color: p.navSelected, fontSize: 12))),
                            ),
                          ),
                        ),
                      KeyedSubtree(
                        key: const ValueKey('pet-form-save'),
                        child: petFormButton(
                            context,
                            state.saving
                                ? 'pet_form_saving'.tr()
                                : 'pet_form_save'.tr(),
                            canSave ? _save : null),
                      ),
                    ]),
              ),
            ])),
      ),
    );
  }

  Widget _dateField(DateTime? date, bool birth) => _Field(
        label: (birth ? 'pet_form_birth' : 'pet_form_adoption').tr(),
        child: _Selection(
            label: date == null
                ? 'pet_form_none'.tr()
                : '${date.year}. ${date.month}. ${date.day}',
            icon: 'redesign_v2/calendar_month',
            muted: date == null,
            onTap: () => _date(birth)),
      );
}

TextStyle petFormText(BuildContext context) => TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 16,
    height: 19 / 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.32,
    color: context.glass.textPrimary);

Color _fieldColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? VivaColors.fillBack
        : context.glass.overlayFaint;

InputDecoration petFormDecoration(BuildContext context,
        {bool invalid = false}) =>
    InputDecoration(
      filled: true,
      fillColor: _fieldColor(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 23),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: invalid
                  ? Theme.of(context).colorScheme.error
                  : context.glass.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: invalid
                  ? Theme.of(context).colorScheme.error
                  : context.glass.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: invalid
                  ? Theme.of(context).colorScheme.error
                  : context.glass.textTertiary)),
      errorStyle: petFormText(context)
          .copyWith(fontSize: 12, color: context.glass.navSelected),
    );

AppBar petFormAppBar(BuildContext context, String title, VoidCallback onBack) =>
    AppBar(
      backgroundColor: context.glass.surfaceHeader,
      surfaceTintColor: context.glass.surfaceHeader,
      toolbarHeight: 44,
      centerTitle: true,
      leadingWidth: 56,
      leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton(
              onPressed: onBack,
              tooltip: 'pet_form_back'.tr(),
              icon: FigmaIcon.tinted(FigmaIcons.arrowPrevious,
                  color: context.glass.textSecondary, size: 24))),
      title: Text(title,
          style: petFormText(context).copyWith(fontWeight: FontWeight.w700)),
    );

Widget petFormButton(
        BuildContext context, String label, VoidCallback? onPressed) =>
    SizedBox(
        height: 56,
        child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
                backgroundColor: context.glass.textPrimary,
                foregroundColor: VivaColors.fillBack,
                disabledBackgroundColor: context.glass.border,
                disabledForegroundColor: VivaColors.fillBack,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: petFormText(context).copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 28 / 18,
                    letterSpacing: -0.36)),
            child: Text(label)));

class _Field extends StatelessWidget {
  const _Field(
      {required this.label,
      required this.child,
      this.bottom = 24,
      this.errorText});
  final String label;
  final Widget child;
  final double bottom;
  final String? errorText;
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text(label,
                style: petFormText(context).copyWith(
                    color: context.glass.textTertiary, height: 19 / 16))),
        Semantics(
            validationResult: errorText == null
                ? SemanticsValidationResult.none
                : SemanticsValidationResult.invalid,
            child: child),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Semantics(
                liveRegion: true,
                child: Text(errorText!,
                    style: petFormText(context).copyWith(
                        fontSize: 12,
                        height: 14 / 12,
                        letterSpacing: -.24,
                        color: context.glass.navSelected))),
          ),
      ]));
}

class _Selection extends StatelessWidget {
  const _Selection(
      {required this.label,
      required this.icon,
      this.onTap,
      this.muted = false,
      this.actionLabel,
      this.padding = const EdgeInsets.symmetric(horizontal: 17)});
  final EdgeInsets padding;
  final String label;
  final String icon;
  final VoidCallback? onTap;
  final bool muted;
  final String? actionLabel;
  @override
  Widget build(BuildContext context) => Material(
      color: _fieldColor(context),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: context.glass.border)),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
              constraints: const BoxConstraints(minHeight: 65),
              padding: padding,
              child: Row(children: [
                Expanded(
                    child: Text(label,
                        style: petFormText(context).copyWith(
                            color: muted
                                ? context.glass.textTertiary
                                : context.glass.textPrimary))),
                if (actionLabel != null)
                  Text(actionLabel!,
                      style: petFormText(context).copyWith(
                          color: context.glass.navSelected,
                          fontWeight: FontWeight.w600)),
                if (actionLabel != null) const SizedBox(width: 4),
                FigmaIcon.tinted(icon,
                    color: actionLabel != null
                        ? context.glass.navSelected
                        : context.glass.deviceOff,
                    size: actionLabel != null ? 18 : 24),
              ]))));
}

class PetFormPhoto extends StatelessWidget {
  const PetFormPhoto(
      {super.key, this.path, required this.size, this.placeholderSize = 56});
  final String? path;
  final double size;
  final double placeholderSize;
  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
        color: context.glass.surfaceHeader,
        child: Center(
            child: Image(
                image: FigmaImages.petPlaceholder,
                width: placeholderSize,
                height: placeholderSize,
                fit: BoxFit.contain)));
    final photo = path;
    if (photo == null || photo.isEmpty) return fallback;
    if (photo.startsWith('http://') || photo.startsWith('https://')) {
      return Image.network(photo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback);
    }
    return Image.file(File(photo),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback);
  }
}

final _morphSearchProvider = StateProvider.autoDispose<String>((ref) => '');

class _MorphSelectionScreen extends ConsumerStatefulWidget {
  const _MorphSelectionScreen();
  @override
  ConsumerState<_MorphSelectionScreen> createState() =>
      _MorphSelectionScreenState();
}

class _MorphSelectionScreenState extends ConsumerState<_MorphSelectionScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clear() {
    _search.clear();
    ref.read(_morphSearchProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(_morphSearchProvider).trim();
    final catalog = ref.watch(morphDataProvider('crested-gecko'));
    final glass = context.glass;
    return Scaffold(
      backgroundColor: glass.surfaceHeader,
      appBar: petFormAppBar(
          context, 'pet_form_morph_title'.tr(), () => Navigator.pop(context)),
      body: SafeArea(
          top: false,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 13, 12, 0),
              child: SizedBox(
                  height: 65,
                  child: TextField(
                    controller: _search,
                    style: petFormText(context),
                    decoration: petFormDecoration(context).copyWith(
                        hintText: 'pet_form_morph_search'.tr(),
                        hintStyle: petFormText(context)
                            .copyWith(color: glass.textTertiary),
                        // Figma 1043:4873 — X 24 at x340 (field right inset 17).
                        suffixIconConstraints:
                            const BoxConstraints(minWidth: 24, minHeight: 24),
                        suffixIcon: query.isEmpty
                            ? null
                            : Padding(
                                padding: const EdgeInsets.only(right: 7),
                                child: IconButton(
                                  key: const ValueKey('pet-form-morph-clear'),
                                  style: IconButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      fixedSize: const Size(44, 44),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap),
                                  tooltip: 'pet_form_morph_clear'.tr(),
                                  onPressed: _clear,
                                  icon: FigmaIcon.tinted(FigmaIcons.cancel,
                                      color: glass.deviceOff, size: 24),
                                ))),
                    onChanged: (value) =>
                        ref.read(_morphSearchProvider.notifier).state = value,
                  )),
            ),
            Expanded(
                child: catalog.when(
              data: (data) {
                final choices = petRegistrationChoices(data);
                if (query.isEmpty) {
                  final groups = petRegistrationGroups(choices);
                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final group in groups.entries) ...[
                        Padding(
                          padding: EdgeInsets.fromLTRB(12,
                              group.key == groups.keys.first ? 20 : 16, 12, 0),
                          child: Text(group.key,
                              style: petFormText(context)
                                  .copyWith(color: glass.textTertiary)),
                        ),
                        for (final morph in group.value)
                          _MorphRow(id: morph.id, name: morph.name),
                      ]
                    ],
                  );
                }
                final hits = petRegistrationSearch(choices, query);
                if (hits.isEmpty) {
                  // Figma 1043:5003 — Title x12/y184/w369/h35, text y200 h19.
                  return Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: SizedBox(
                          width: double.infinity,
                          child: Text('pet_form_morph_empty'.tr(),
                              textAlign: TextAlign.center,
                              style: petFormText(context)
                                  .copyWith(color: glass.textTertiary))),
                    ),
                  );
                }
                // Figma 1043:4873 — SelectList y184, first row y188.
                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  children: [
                    for (final hit in hits)
                      _MorphRow(
                          id: hit.choice.id,
                          name: hit.choice.name,
                          ranges: hit.ranges),
                  ],
                );
              },
              loading: () => Center(child: Text('pet_form_loading'.tr())),
              error: (_, __) => Center(
                  child: TextButton(
                onPressed: () =>
                    ref.invalidate(morphDataProvider('crested-gecko')),
                child: Text('pet_form_retry'.tr()),
              )),
            )),
          ])),
    );
  }
}

/// One 44pt catalog row. Matched rune [ranges] are drawn in `navSelected`
/// (Figma #C00306); everything else keeps the approved secondary text colour.
class _MorphRow extends StatelessWidget {
  const _MorphRow(
      {required this.id, required this.name, this.ranges = const []});
  final String id;
  final String name;
  final List<(int, int)> ranges;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final base = petFormText(context).copyWith(
        fontSize: 18,
        height: 28 / 18,
        letterSpacing: -0.36,
        color: glass.textSecondary);
    return SizedBox(
        height: 44,
        child: DecoratedBox(
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: glass.border))),
          child: InkWell(
            key: ValueKey(id),
            onTap: () => Navigator.pop(context, name),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text.rich(
                    _highlighted(name, ranges, base, glass.navSelected)),
              ),
            ),
          ),
        ));
  }

  static TextSpan _highlighted(
      String name, List<(int, int)> ranges, TextStyle base, Color accent) {
    if (ranges.isEmpty) return TextSpan(text: name, style: base);
    final runes = name.runes.toList();
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final (start, end) in ranges) {
      if (start > cursor) {
        spans.add(
            TextSpan(text: String.fromCharCodes(runes.sublist(cursor, start))));
      }
      spans.add(TextSpan(
          text: String.fromCharCodes(runes.sublist(start, end)),
          style: TextStyle(color: accent)));
      cursor = end;
    }
    if (cursor < runes.length) {
      spans.add(TextSpan(text: String.fromCharCodes(runes.sublist(cursor))));
    }
    return TextSpan(style: base, children: spans);
  }
}

String _weightWithoutUnit(String text) =>
    text.endsWith('g') ? text.substring(0, text.length - 1) : text;

String _weightWithUnit(String text) => text.isEmpty ? '' : '${text}g';

/// The draft always holds a number; the editor renders a trailing unit.
class _WeightUnitFormatter extends TextInputFormatter {
  const _WeightUnitFormatter();
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (!newValue.composing.isCollapsed) return newValue;
    final value = _weightWithoutUnit(newValue.text);
    if (value.isEmpty) return TextEditingValue.empty;
    return TextEditingValue(
      text: _weightWithUnit(value),
      selection: TextSelection(
          baseOffset: newValue.selection.baseOffset.clamp(0, value.length),
          extentOffset: newValue.selection.extentOffset.clamp(0, value.length)),
    );
  }
}

/// 개체의 사육 환경(그룹) 선택 — Figma 1043:3649. 제목 y228, 카드 345×78 r12
/// #F4F4F4(자동 이름 16/500 #949090 + 이름 16/600), 사육장→카메라 36 아이콘,
/// 체크 24. 하단 '이 사육 환경에서 키우기'(미선택 비활성) y696, '나중에 하기'
/// y752는 변경 없이 닫는다(그룹 해제는 사육장 연동 화면 담당).
class _GroupSelectionScreen extends StatefulWidget {
  const _GroupSelectionScreen({required this.groups, this.initialGroupId});
  final List<PetFormGroupOption> groups;
  final String? initialGroupId;
  @override
  State<_GroupSelectionScreen> createState() => _GroupSelectionScreenState();
}

class _GroupSelectionScreenState extends State<_GroupSelectionScreen> {
  late String? _selected = widget.initialGroupId;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final safeTop = MediaQuery.paddingOf(context).top;
    return Scaffold(
        backgroundColor: glass.surfaceHeader,
        body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
          final titleTop = constraints.maxHeight < 650
              ? 24.0
              : (228 - safeTop).clamp(24.0, constraints.maxHeight * .3);
          return Stack(children: [
            ListView(
                padding: EdgeInsets.fromLTRB(24, titleTop, 24, 112 + 10 + 16),
                children: [
                  Text('pet_form_group_pick_title'.tr(),
                      textAlign: TextAlign.center,
                      style: petFormText(context).copyWith(
                          fontSize: 18,
                          height: 21.48046875 / 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.36,
                          color: glass.textSecondary)),
                  const SizedBox(height: 8),
                  Text('pairing_pet_subtitle'.tr(),
                      textAlign: TextAlign.center,
                      style: petFormText(context)
                          .copyWith(color: glass.bodySecondary)),
                  const SizedBox(height: 24),
                  for (final (index, group) in widget.groups.indexed) ...[
                    if (index > 0) const SizedBox(height: 8),
                    _GroupCard(
                        group: group,
                        selected: _selected == group.id,
                        onTap: () => setState(() => _selected =
                            _selected == group.id ? null : group.id)),
                  ],
                ]),
            Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ManagementButton(
                      key: const ValueKey('pet-form-group-confirm'),
                      label: 'pairing_pet_primary_action'.tr(),
                      onPressed: _selected == null
                          ? null
                          : () => Navigator.pop(context, (value: _selected))),
                  SizedBox(
                      height: 56,
                      child: TextButton(
                          key: const ValueKey('pet-form-group-later'),
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                              minimumSize: const Size(double.infinity, 56),
                              foregroundColor: glass.textSecondary,
                              textStyle: petFormText(context).copyWith(
                                  fontSize: 18,
                                  height: 28 / 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.36)),
                          child: Text('pairing_pet_later'.tr()))),
                ])),
          ]);
        })));
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard(
      {required this.group, required this.selected, required this.onTap});
  final PetFormGroupOption group;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return InkWell(
        key: ValueKey('pet-form-group-${group.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
            height: 78,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
                color: glass.overlay, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    if (group.number case final number?) ...[
                      Text('pet_form_group_auto'.tr(args: ['$number']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: petFormText(context)
                              .copyWith(color: glass.textTertiary)),
                      const SizedBox(height: 16),
                    ],
                    Text(group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: petFormText(context).copyWith(
                            fontWeight: FontWeight.w600,
                            color: glass.textSecondary)),
                  ])),
              const SizedBox(width: 4),
              // 아이콘 순서: 사육장 → 카메라 (→ 개체는 이 화면에 없음).
              if (group.hasDevice) ...[
                const ManagementItemIcon(ManagementKind.device),
                const SizedBox(width: 8),
              ],
              if (group.hasCamera) ...[
                const ManagementItemIcon(ManagementKind.camera),
                const SizedBox(width: 8),
              ],
              FigmaIcon.tinted(
                  selected
                      ? 'redesign_v2/check_box_400'
                      : 'redesign_v2/check_box_outline_blank_400',
                  size: 24,
                  color: selected ? glass.navSelected : glass.deviceOff),
            ])));
  }
}

/// 신규 등록 완료 — Figma 1035:2735. 체크 64 y308, 제목 y396, 부제 y425,
/// '기기 추가 하기' y696 → 기기 추가 흐름, '나중에 하기' y752 → 목록으로.
class _PetRegisteredScreen extends StatelessWidget {
  const _PetRegisteredScreen({this.link, this.onLink});

  /// 기기가 있는 유일한 그룹 — 있으면 완료 화면 대신 연결 카드(994:13307).
  final PetFormGroupOption? link;
  final Future<void> Function()? onLink;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final safeTop = MediaQuery.paddingOf(context).top;
    if (link case final group? when onLink != null) {
      return LinkConfirmScreen(
          title: 'pet_form_link_title'.tr(),
          subtitle: 'pet_form_link_subtitle'.tr(),
          rows: [
            if (group.hasDevice)
              LinkConfirmRow(
                  icon: FigmaIcons.homeGlyph,
                  label: 'management_kind_device'.tr(),
                  name: group.deviceName ?? 'management_kind_device'.tr()),
            if (group.hasCamera)
              LinkConfirmRow(
                  icon: FigmaIcons.cameraGlyph,
                  label: 'management_kind_camera'.tr(),
                  name: group.cameraName ?? 'management_kind_camera'.tr()),
          ],
          primaryKey: const ValueKey('pet-form-link-confirm'),
          secondaryKey: const ValueKey('pet-form-done-later'),
          primaryLabel: 'pet_form_link_confirm'.tr(),
          secondaryLabel: 'pairing_pet_later'.tr(),
          failureText: (e) =>
              e is PetFormValidationException ? e.key.tr() : '$e',
          onPrimary: onLink!);
    }
    return Scaffold(
        backgroundColor: glass.surfaceHeader,
        body: SafeArea(
            child: Stack(children: [
          Padding(
              padding: EdgeInsets.only(
                  top: math.min(
                      308 - safeTop, MediaQuery.sizeOf(context).height * 0.29)),
              child: Column(children: [
                Center(
                    child: FigmaIcon.tinted('redesign_v2/check_circle',
                        size: 64, color: glass.textPrimary)),
                const SizedBox(height: 24),
                Text('pet_form_done_title'.tr(),
                    textAlign: TextAlign.center,
                    style: petFormText(context).copyWith(
                        fontSize: 18,
                        height: 21.48046875 / 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.36,
                        color: glass.textSecondary)),
                const SizedBox(height: 8),
                Text('pet_form_done_subtitle'.tr(),
                    textAlign: TextAlign.center,
                    style: petFormText(context)
                        .copyWith(color: glass.bodySecondary)),
              ])),
          Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ManagementButton(
                    key: const ValueKey('pet-form-done-devices'),
                    label: 'pet_form_done_devices'.tr(),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/devices/add');
                    }),
                SizedBox(
                    height: 56,
                    child: TextButton(
                        key: const ValueKey('pet-form-done-later'),
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            foregroundColor: glass.textSecondary,
                            textStyle: petFormText(context).copyWith(
                                fontSize: 18,
                                height: 28 / 18,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.36)),
                        child: Text('pairing_pet_later'.tr()))),
              ])),
        ])));
  }
}
