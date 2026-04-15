import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../wiki/data/care_info_repository.dart';
import '../../wiki/presentation/wiki_providers.dart';
import '../domain/pet.dart';
import 'my_pets_providers.dart';
import 'widgets/photo_picker_button.dart';

class PetAddScreen extends ConsumerStatefulWidget {
  const PetAddScreen({super.key});

  @override
  ConsumerState<PetAddScreen> createState() => _PetAddScreenState();
}

class _PetAddScreenState extends ConsumerState<PetAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _customSpeciesController = TextEditingController();
  final _morphController = TextEditingController();
  final _weightController = TextEditingController();
  final _memoController = TextEditingController();

  String? _selectedSpeciesId;
  String? _selectedMorph;
  String _sex = 'unknown';
  DateTime? _birthDate;
  DateTime? _adoptionDate;
  bool _isCustomSpecies = false;
  File? _selectedPhoto;

  // 3종 + 기타
  static final List<MapEntry<String, String>> _speciesOptions = [
    ...CareInfoRepository.speciesNames.entries,
    const MapEntry('custom', '기타 (직접입력)'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _customSpeciesController.dispose();
    _morphController.dispose();
    _weightController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isBirth}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: isBirth ? '생년월 추정' : '입양일',
    );
    if (picked != null) {
      setState(() {
        if (isBirth) {
          _birthDate = picked;
        } else {
          _adoptionDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '선택 안 함';
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final speciesId = _isCustomSpecies ? 'custom' : _selectedSpeciesId!;
    final speciesName = _isCustomSpecies
        ? _customSpeciesController.text.trim()
        : CareInfoRepository.speciesNames[_selectedSpeciesId] ?? '';

    final morph = _selectedMorph ??
        (_morphController.text.trim().isNotEmpty
            ? _morphController.text.trim()
            : null);

    final weight = _weightController.text.trim().isNotEmpty
        ? double.tryParse(_weightController.text.trim())
        : null;

    final pet = Pet(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      speciesId: speciesId,
      speciesName: speciesName,
      morph: morph,
      sex: _sex,
      birthDate: _birthDate,
      adoptionDate: _adoptionDate,
      weight: weight,
      photoPath: _selectedPhoto?.path,
      memo: _memoController.text.trim().isNotEmpty
          ? _memoController.text.trim()
          : null,
    );

    await ref.read(petListProvider.notifier).add(pet);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('개체 등록'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 사진
            PhotoPickerButton(
              currentPhoto: _selectedPhoto,
              onPhotoPicked: (file) => setState(() => _selectedPhoto = file),
            ),
            const SizedBox(height: 16),

            // 이름
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '이름 *',
                hintText: '개체 이름을 입력하세요',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '이름을 입력해주세요' : null,
            ),
            const SizedBox(height: 16),

            // 종 선택
            DropdownButtonFormField<String>(
              value: _isCustomSpecies ? 'custom' : _selectedSpeciesId,
              decoration: const InputDecoration(
                labelText: '종 *',
                border: OutlineInputBorder(),
              ),
              items: _speciesOptions.map((e) {
                return DropdownMenuItem(value: e.key, child: Text(e.value));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  if (value == 'custom') {
                    _isCustomSpecies = true;
                    _selectedSpeciesId = null;
                  } else {
                    _isCustomSpecies = false;
                    _selectedSpeciesId = value;
                  }
                  _selectedMorph = null;
                  _morphController.clear();
                });
              },
              validator: (v) {
                if (v == null) return '종을 선택해주세요';
                if (v == 'custom' && _customSpeciesController.text.trim().isEmpty) {
                  return '종 이름을 입력해주세요';
                }
                return null;
              },
            ),
            if (_isCustomSpecies) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _customSpeciesController,
                decoration: const InputDecoration(
                  labelText: '종 이름',
                  hintText: '직접 입력',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '종 이름을 입력해주세요' : null,
              ),
            ],
            const SizedBox(height: 16),

            // 모프
            if (_selectedSpeciesId != null && !_isCustomSpecies)
              Consumer(
                builder: (context, ref, _) {
                  final morphAsync =
                      ref.watch(morphDataProvider(_selectedSpeciesId!));
                  return morphAsync.when(
                    data: (data) {
                      final morphNames = data.allSelectableNames;
                      if (morphNames.isEmpty) {
                        return TextFormField(
                          controller: _morphController,
                          decoration: const InputDecoration(
                            labelText: '모프',
                            hintText: '모프 정보 (선택사항)',
                            border: OutlineInputBorder(),
                          ),
                        );
                      }
                      // 현재 선택된 모프가 목록에 없으면 리셋
                      if (_selectedMorph != null &&
                          !morphNames.contains(_selectedMorph)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _selectedMorph = null);
                        });
                      }
                      return DropdownButtonFormField<String>(
                        value: morphNames.contains(_selectedMorph)
                            ? _selectedMorph
                            : null,
                        decoration: const InputDecoration(
                          labelText: '모프',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('선택 안 함')),
                          ...morphNames.map(
                            (m) => DropdownMenuItem(value: m, child: Text(m)),
                          ),
                        ],
                        onChanged: (v) => setState(() => _selectedMorph = v),
                      );
                    },
                    loading: () => const InputDecorator(
                      decoration: InputDecoration(
                        labelText: '모프',
                        border: OutlineInputBorder(),
                      ),
                      child: Text('로딩 중...'),
                    ),
                    error: (_, __) => TextFormField(
                      controller: _morphController,
                      decoration: const InputDecoration(
                        labelText: '모프',
                        hintText: '모프 정보 (선택사항)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  );
                },
              )
            else
              TextFormField(
                controller: _morphController,
                decoration: const InputDecoration(
                  labelText: '모프',
                  hintText: '모프 정보 (선택사항)',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 16),

            // 성별
            Text(
              '성별',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'male', label: Text('수컷')),
                ButtonSegment(value: 'female', label: Text('암컷')),
                ButtonSegment(value: 'unknown', label: Text('미확인')),
              ],
              selected: {_sex},
              onSelectionChanged: (v) => setState(() => _sex = v.first),
            ),
            const SizedBox(height: 16),

            // 생년월 추정
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('생년월 추정'),
              subtitle: Text(_formatDate(_birthDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(isBirth: true),
            ),

            // 입양일
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('입양일'),
              subtitle: Text(_formatDate(_adoptionDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(isBirth: false),
            ),
            const SizedBox(height: 8),

            // 체중
            TextFormField(
              controller: _weightController,
              decoration: const InputDecoration(
                labelText: '체중 (g)',
                hintText: '그램 단위',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
            ),
            const SizedBox(height: 16),

            // 메모
            TextFormField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: '메모',
                hintText: '특이사항, 건강 정보 등',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // 저장
            FilledButton(
              onPressed: _save,
              child: const Text('저장'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
