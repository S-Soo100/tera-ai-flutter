import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../wiki/data/care_info_repository.dart';
import '../domain/pet.dart';
import 'my_pets_providers.dart';

class PetEditScreen extends ConsumerStatefulWidget {
  final String petId;

  const PetEditScreen({super.key, required this.petId});

  @override
  ConsumerState<PetEditScreen> createState() => _PetEditScreenState();
}

class _PetEditScreenState extends ConsumerState<PetEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _customSpeciesController;
  late final TextEditingController _morphController;
  late final TextEditingController _weightController;
  late final TextEditingController _memoController;

  String? _selectedSpeciesId;
  String? _selectedMorph;
  String _sex = 'unknown';
  DateTime? _birthDate;
  DateTime? _adoptionDate;
  bool _isCustomSpecies = false;
  bool _initialized = false;

  static final List<MapEntry<String, String>> _speciesOptions = [
    ...CareInfoRepository.speciesNames.entries,
    const MapEntry('custom', '기타 (직접입력)'),
  ];

  static const Map<String, List<String>> _morphsBySpecies = {
    'leopard-gecko': [
      '노멀',
      '하이 옐로',
      '탱제린',
      '슈퍼 하이포 탱제린',
      '마크 벨 알비노',
      '트렘퍼 알비노',
      '레인워터 알비노',
      '블리자드',
      '머피 패턴리스',
      '엑립스',
      '라프터',
      '볼드 스트라이프',
      '정글',
      '자이언트',
      '슈퍼 자이언트',
      '블랙 나이트',
    ],
    'crested-gecko': [
      '노멀',
      '플레임',
      '할리퀸',
      '달마시안',
      '릴리 화이트',
      '핀스트라이프',
      '팬텀',
      '트라이 컬러',
      '레드',
      '옐로',
      '크림',
    ],
    'fat-tailed-gecko': [
      '노멀',
      '화이트 아웃',
      '오레오',
      '제로',
      '파타너리스',
      '스트라이프',
      '탱제린',
      '알비노',
      '카라멜 알비노',
    ],
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _customSpeciesController = TextEditingController();
    _morphController = TextEditingController();
    _weightController = TextEditingController();
    _memoController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customSpeciesController.dispose();
    _morphController.dispose();
    _weightController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  void _initFromPet(Pet pet) {
    if (_initialized) return;
    _initialized = true;

    _nameController.text = pet.name;
    _sex = pet.sex;
    _birthDate = pet.birthDate;
    _adoptionDate = pet.adoptionDate;
    _memoController.text = pet.memo ?? '';

    if (pet.weight != null) {
      _weightController.text = pet.weight.toString();
    }

    // 종 판별
    if (CareInfoRepository.speciesNames.containsKey(pet.speciesId)) {
      _selectedSpeciesId = pet.speciesId;
      _isCustomSpecies = false;
    } else {
      _isCustomSpecies = true;
      _customSpeciesController.text = pet.speciesName;
    }

    // 모프 판별
    final morphList = _morphsBySpecies[pet.speciesId] ?? [];
    if (morphList.contains(pet.morph)) {
      _selectedMorph = pet.morph;
    } else {
      _morphController.text = pet.morph ?? '';
    }
  }

  List<String> get _currentMorphList {
    if (_selectedSpeciesId == null || _isCustomSpecies) return [];
    return _morphsBySpecies[_selectedSpeciesId] ?? [];
  }

  Future<void> _pickDate({required bool isBirth}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isBirth ? (_birthDate ?? now) : (_adoptionDate ?? now),
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

  Future<void> _save(Pet original) async {
    if (!_formKey.currentState!.validate()) return;

    final speciesId = _isCustomSpecies ? 'custom' : _selectedSpeciesId!;
    final speciesName = _isCustomSpecies
        ? _customSpeciesController.text.trim()
        : CareInfoRepository.speciesNames[_selectedSpeciesId] ?? '';

    final morph = _currentMorphList.isNotEmpty
        ? _selectedMorph
        : _morphController.text.trim().isNotEmpty
            ? _morphController.text.trim()
            : null;

    final weight = _weightController.text.trim().isNotEmpty
        ? double.tryParse(_weightController.text.trim())
        : null;

    original.name = _nameController.text.trim();
    original.speciesId = speciesId;
    original.speciesName = speciesName;
    original.morph = morph;
    original.sex = _sex;
    original.birthDate = _birthDate;
    original.adoptionDate = _adoptionDate;
    original.weight = weight;
    original.memo = _memoController.text.trim().isNotEmpty
        ? _memoController.text.trim()
        : null;

    await ref.read(petListProvider.notifier).update(original);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    // petList를 watch해서 최신 상태 반영
    ref.watch(petListProvider);
    final pet = ref.watch(petDetailProvider(widget.petId));

    if (pet == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('개체 수정')),
        body: const Center(child: Text('개체를 찾을 수 없습니다')),
      );
    }

    _initFromPet(pet);

    return Scaffold(
      appBar: AppBar(
        title: const Text('개체 수정'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                if (v == 'custom' &&
                    _customSpeciesController.text.trim().isEmpty) {
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
            if (_currentMorphList.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedMorph,
                decoration: const InputDecoration(
                  labelText: '모프',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('선택 안 함')),
                  ..._currentMorphList.map(
                    (m) => DropdownMenuItem(value: m, child: Text(m)),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedMorph = v),
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
              onPressed: () => _save(pet),
              child: const Text('저장'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
