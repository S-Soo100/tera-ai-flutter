import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_pets/domain/pet.dart';
import 'package:vivanaut/features/my_pets/domain/pet_form_state.dart';
import 'package:vivanaut/features/my_pets/presentation/pet_form_providers.dart';

void main() {
  test('pairing group preselect is part of initial draft and survives save',
      () async {
    final notifier = PetFormNotifier(
        PetFormSession(id: 'new', initialGroupId: 'paired-group'));
    addTearDown(notifier.dispose);
    expect(notifier.state.draft.groupId, 'paired-group');
    expect(notifier.state.draft.sameInput(notifier.session.initial), isTrue);
    notifier.change(notifier.state.draft.copyWith(
        name: '크레', speciesId: 'crested-gecko', speciesName: '크레스티드 게코'));
    String? savedGroup;
    expect(
        await notifier.save(
            persist: (_, group) async {
              savedGroup = group;
            },
            storePhoto: (_, __) async => throw StateError('no photo'),
            peers: []),
        isTrue);
    expect(savedGroup, 'paired-group');
  });
  test('failed save preserves input and photo; retry reuses uploaded photo',
      () async {
    final original = Pet(
        id: 'one',
        name: '원본',
        speciesId: 'custom',
        speciesName: '기존종',
        photoPath: 'old.jpg');
    final notifier =
        PetFormNotifier(PetFormSession(id: original.id, original: original));
    addTearDown(notifier.dispose);
    notifier.change(
        notifier.state.draft.copyWith(name: '수정', photoPath: 'new.jpg'));
    var uploads = 0;
    Future<String> upload(String id, String path) async {
      uploads++;
      return 'https://example.com/unique.jpg';
    }

    expect(
        await notifier.save(
            persist: (_, __) async => throw Exception('offline'),
            storePhoto: upload,
            peers: [original]),
        isFalse);
    expect(notifier.state.draft.name, '수정');
    expect(notifier.state.draft.photoPath, 'new.jpg');
    expect(notifier.state.saving, isFalse);
    expect(original.name, '원본');
    expect(original.photoPath, 'old.jpg');
    Pet? saved;
    expect(
        await notifier.save(
            persist: (pet, _) async {
              saved = pet;
            },
            storePhoto: upload,
            peers: [original]),
        isTrue);
    expect(uploads, 1);
    expect(saved?.photoPath, 'https://example.com/unique.jpg');
  });
  test('submit rejects latest duplicate without storing a photo', () async {
    final notifier = PetFormNotifier(PetFormSession(id: 'new'));
    addTearDown(notifier.dispose);
    notifier.change(notifier.state.draft.copyWith(
        name: '도도', speciesId: 'crested-gecko', speciesName: '크레스티드 게코'));
    final saved = await notifier.save(
        persist: (_, __) async => fail('must not persist'),
        storePhoto: (_, __) async => throw StateError('must not upload'),
        peers: [
          Pet(
              id: 'other',
              name: ' 도도 ',
              speciesId: 'crested-gecko',
              speciesName: '크레스티드 게코')
        ]);
    expect(saved, isFalse);
    expect(notifier.state.submitted, isTrue);
  });
}
