import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _session = PetFormSession(
        id: widget.original?.id ?? const Uuid().v4(),
        original: widget.original,
        initialGroupId: widget.initialGroupId);
    _name = TextEditingController(text: _session.initial.name);
    _weight = TextEditingController(text: _session.initial.weight);
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

  Future<void> _photo() async {
    final draft = ref.read(petFormProvider(_session)).draft;
    final action = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                    title: Text(draft.photoPath == null
                        ? 'pet_form_photo_add'.tr()
                        : 'pet_form_photo_replace'.tr()),
                    onTap: () => Navigator.pop(ctx, 'pick')),
                if (draft.photoPath != null)
                  ListTile(
                      title: Text('pet_form_photo_remove'.tr()),
                      onTap: () => Navigator.pop(ctx, 'remove')),
              ]),
            ));
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
    final picked = await showDatePicker(
        context: context,
        initialDate: old == null || old.isAfter(now) ? now : old,
        firstDate: first,
        lastDate: now,
        helpText: (birth ? 'pet_form_birth' : 'pet_form_adoption').tr());
    if (mounted && picked != null) {
      _change((d) => birth
          ? d.copyWith(birthDate: picked)
          : d.copyWith(adoptionDate: picked));
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
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  12, 16, 12, 24 + MediaQuery.paddingOf(context).bottom),
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
                                                      color: p.textTertiary,
                                                      size: 40),
                                                  Text(
                                                      'pet_form_photo_add'.tr(),
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
                                          width: 36,
                                          height: 36,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                              color: p.surfaceTint,
                                              shape: BoxShape.circle),
                                          child: FigmaIcon.tinted(
                                              FigmaIcons.edit,
                                              color: p.textSecondary,
                                              size: 24))),
                              ])),
                        ))),
                const SizedBox(height: 24),
                _Field(
                    label: 'pet_form_name'.tr(),
                    child: TextFormField(
                      key: const ValueKey('pet-form-name'),
                      controller: _name,
                      style: petFormText(context),
                      onChanged: (value) =>
                          _change((d) => d.copyWith(name: value)),
                      decoration: petFormDecoration(context).copyWith(
                          errorText: nameError?.tr(),
                          suffixText: '${d.name.characters.length}/10',
                          suffixStyle: petFormText(context)
                              .copyWith(color: p.textTertiary)),
                    )),
                _Field(
                    label: 'pet_form_species'.tr(),
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: d.speciesId,
                      style: petFormText(context),
                      decoration: petFormDecoration(context).copyWith(
                          // Figma 765:6880: 24px icon + 20.5px each side = 65.
                          // Dense dropdown height grows with scaled text;
                          // do not impose a fixed outer height.
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 17, vertical: 20.5),
                          errorText: state.submitted && d.speciesId == null
                              ? 'pet_form_required'.tr()
                              : null),
                      icon: FigmaIcon.tinted('redesign_v2/arrow_drop_down',
                          color: p.textSecondary, size: 24),
                      items: [
                        if (legacy)
                          DropdownMenuItem(
                              value: _session.initial.speciesId,
                              child: Text(_session.initial.speciesName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                        if (!legacy)
                          DropdownMenuItem(
                              value: 'crested-gecko',
                              child: Text('pet_form_crested'.tr(),
                                  maxLines: 1, overflow: TextOverflow.ellipsis))
                      ],
                      onChanged: legacy
                          ? null
                          : (value) => _change((d) => d.copyWith(
                              speciesId: value,
                              speciesName: 'pet_form_crested'.tr())),
                    )),
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
                                      onTap: () =>
                                          _change((d) => d.copyWith(sex: sex)),
                                      child: Container(
                                          height: 40,
                                          color: d.sex == sex
                                              ? AppTheme.brandNavy
                                              : p.surfaceTint,
                                          child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                if (d.sex == sex) ...[
                                                  FigmaIcon.tinted(
                                                      'redesign_v2/check',
                                                      color: p.surfaceHeader,
                                                      size: 24),
                                                  const SizedBox(width: 4)
                                                ],
                                                Text('pet_form_sex_$sex'.tr(),
                                                    style: petFormText(context)
                                                        .copyWith(
                                                            color: d.sex == sex
                                                                ? p.surfaceHeader
                                                                : p.textSecondary)),
                                              ])),
                                    ))),
                        ]))),
                _dateField(d.birthDate, true),
                _dateField(d.adoptionDate, false),
                _Field(
                    label: 'pet_form_weight'.tr(),
                    child: TextFormField(
                      controller: _weight,
                      style: petFormText(context),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) =>
                          _change((d) => d.copyWith(weight: value)),
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
                      controller: _memo,
                      style: petFormText(context),
                      maxLines: 4,
                      onChanged: (value) =>
                          _change((d) => d.copyWith(memo: value)),
                      decoration: petFormDecoration(context)
                          .copyWith(contentPadding: const EdgeInsets.all(17)),
                    )),
                if (state.errorKey != null)
                  Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Text(state.errorKey!.tr(),
                          style: petFormText(context)
                              .copyWith(color: p.navSelected, fontSize: 12))),
                petFormButton(
                    context,
                    state.saving
                        ? 'pet_form_saving'.tr()
                        : 'pet_form_save'.tr(),
                    state.saving ? null : _save),
              ],
            )),
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
            onTap: () => _date(birth),
            onClear: date == null
                ? null
                : () => _change((d) => birth
                    ? d.copyWith(birthDate: null)
                    : d.copyWith(adoptionDate: null))),
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

InputDecoration petFormDecoration(BuildContext context) => InputDecoration(
      filled: true,
      fillColor: _fieldColor(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 23),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.glass.textTertiary)),
      errorStyle: petFormText(context)
          .copyWith(fontSize: 12, color: context.glass.navSelected),
    );

AppBar petFormAppBar(BuildContext context, String title, VoidCallback onBack) =>
    AppBar(
      backgroundColor: context.glass.surfaceHeader,
      surfaceTintColor: context.glass.surfaceHeader,
      toolbarHeight: 44,
      centerTitle: true,
      leading: IconButton(
          onPressed: onBack,
          tooltip: 'pet_form_back'.tr(),
          icon: FigmaIcon.tinted(FigmaIcons.arrowPrevious,
              color: context.glass.textSecondary, size: 24)),
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
                foregroundColor: context.glass.surfaceHeader,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: petFormText(context)
                    .copyWith(fontSize: 18, fontWeight: FontWeight.w600)),
            child: Text(label)));

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, this.bottom = 24});
  final String label;
  final Widget child;
  final double bottom;
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text(label,
                style: petFormText(context).copyWith(
                    color: context.glass.textTertiary, height: 19 / 16))),
        child,
      ]));
}

class _Selection extends StatelessWidget {
  const _Selection(
      {required this.label,
      required this.icon,
      this.onTap,
      this.onClear,
      this.muted = false,
      this.actionLabel});
  final String label;
  final String icon;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final bool muted;
  final String? actionLabel;
  @override
  Widget build(BuildContext context) => Material(
      color: _fieldColor(context),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
              constraints: const BoxConstraints(minHeight: 65),
              padding: const EdgeInsets.symmetric(horizontal: 17),
              child: Row(children: [
                Expanded(
                    child: Text(label,
                        style: petFormText(context).copyWith(
                            color: muted
                                ? context.glass.textTertiary
                                : context.glass.textPrimary))),
                if (onClear != null)
                  IconButton(
                      onPressed: onClear,
                      tooltip: 'pet_form_clear'.tr(),
                      icon: FigmaIcon.tinted('redesign_v2/cancel',
                          color: context.glass.textTertiary, size: 20)),
                if (actionLabel != null)
                  Text(actionLabel!,
                      style: petFormText(context).copyWith(
                          color: context.glass.navSelected,
                          fontWeight: FontWeight.w600)),
                FigmaIcon.tinted(icon,
                    color: context.glass.textSecondary, size: 24),
              ]))));
}

class PetFormPhoto extends StatelessWidget {
  const PetFormPhoto({super.key, this.path, required this.size});
  final String? path;
  final double size;
  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
        color: context.glass.surfaceHeader,
        child: Center(
            child: Image(
                image: FigmaImages.petPlaceholder, width: 56, height: 56)));
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
