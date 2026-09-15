import 'dart:io';
import 'dart:ui' show SemanticsValidationResult;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/glass_palette.dart';
import '../../../../core/theme/viva_colors.dart';
import '../../../../shared/widgets/figma_icon.dart';
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
    final result = await showModalBottomSheet<({String? value})>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _MorphSearchSheet());
    if (mounted && result != null) {
      _change((d) => d.copyWith(morph: result.value));
    }
  }

  Future<void> _groups() async {
    if (widget.onSave == null) {
      ref
          .read(petFormProvider(_session).notifier)
          .showError('pet_form_group_unavailable');
      return;
    }
    final result = await showModalBottomSheet<({String? value})>(
        context: context,
        builder: (ctx) => SafeArea(
              child: ListView(shrinkWrap: true, children: [
                ListTile(
                    title: Text('pet_form_no_group'.tr()),
                    onTap: () => Navigator.pop(ctx, (value: null))),
                for (final group in widget.groups)
                  ListTile(
                      title: Text(group.name),
                      onTap: () => Navigator.pop(ctx, (value: group.id))),
              ]),
            ));
    if (mounted && result != null) {
      _change((d) => d.copyWith(groupId: result.value));
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final saved = await ref.read(petFormProvider(_session).notifier).save(
        persist: widget.onSave ?? ref.read(petFormDefaultSaveProvider),
        storePhoto: ref.read(petFormPhotoStoreProvider),
        peers: ref.read(petListProvider));
    if (saved && mounted) {
      // PopScope receives the committed state before leaving.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
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

class _MorphSearchSheet extends ConsumerWidget {
  const _MorphSearchSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(_morphSearchProvider).trim().toLowerCase();
    final catalog = ref.watch(morphDataProvider('crested-gecko'));
    return SafeArea(
        child: Padding(
      padding: EdgeInsets.fromLTRB(
          12, 24, 12, MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: Column(children: [
            TextField(
                autofocus: true,
                style: petFormText(context),
                decoration: petFormDecoration(context).copyWith(
                    hintText: 'pet_form_morph_search'.tr(),
                    prefixIcon: FigmaIcon.tinted('redesign_v2/search',
                        color: context.glass.textSecondary, size: 24)),
                onChanged: (value) =>
                    ref.read(_morphSearchProvider.notifier).state = value),
            Expanded(
                child: catalog.when(
                    data: (data) => ListView(children: [
                          ListTile(
                              title: Text('pet_form_none'.tr()),
                              onTap: () =>
                                  Navigator.pop(context, (value: null))),
                          // Preserve existing registration choices with separate source IDs.
                          for (final morph in petRegistrationChoices(data)
                              .where((m) => '${m.name} ${m.englishName ?? ''}'
                                  .toLowerCase()
                                  .contains(query)))
                            ListTile(
                                key: ValueKey(morph.id),
                                title: Text(morph.name),
                                subtitle: morph.englishName == null
                                    ? null
                                    : Text(morph.englishName!),
                                onTap: () => Navigator.pop(
                                    context, (value: morph.name))),
                        ]),
                    loading: () => Center(child: Text('pet_form_loading'.tr())),
                    error: (_, __) => Center(
                        child: TextButton(
                            onPressed: () => ref
                                .invalidate(morphDataProvider('crested-gecko')),
                            child: Text('pet_form_retry'.tr()))))),
          ])),
    ));
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
