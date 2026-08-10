import 'package:flutter_test/flutter_test.dart';
import 'package:vivananunt/features/my_cage/presentation/enclosure_settings_screen.dart';
import 'package:vivananunt/features/my_pets/data/pet_assignment_service.dart';
import 'package:vivananunt/features/my_pets/data/supabase_pet_repository.dart';

Map<String, dynamic> _row({
  Object? enclosureId = _absent,
}) {
  return {
    'id': 'pet-1',
    'name': '젤리',
    'species_id': 'crested_gecko',
    'species_name': '크레스티드 게코',
    'sex': 'unknown',
    if (!identical(enclosureId, _absent)) 'enclosure_id': enclosureId,
    'created_at': '2026-08-01T00:00:00Z',
    'updated_at': '2026-08-05T00:00:00Z',
  };
}

const _absent = Object();

class _FakeSync {
  int calls = 0;
  Future<void> call() async => calls++;
}

void main() {
  _errorMessageTests();

  group('petFromRow — 서버 행 → Pet 매핑', () {
    test('enclosure_id를 복원한다 (sync 왕복 보존의 핵심)', () {
      expect(petFromRow(_row(enclosureId: 'enc-1')).enclosureId, 'enc-1');
    });

    test('enclosure_id가 null이면 미배정', () {
      expect(petFromRow(_row(enclosureId: null)).enclosureId, isNull);
    });

    test('컬럼 자체가 없어도 죽지 않는다 (구버전 서버 방어)', () {
      expect(petFromRow(_row()).enclosureId, isNull);
    });

    test('나머지 필드도 그대로 매핑된다', () {
      final p = petFromRow(_row(enclosureId: 'enc-1'));
      expect(p.id, 'pet-1');
      expect(p.name, '젤리');
      expect(p.speciesId, 'crested_gecko');
      expect(p.speciesName, '크레스티드 게코');
    });
  });

  group('PetAssignmentService.assign', () {
    test('RPC를 정확히 1번 호출한다 (UPDATE 다단계 금지)', () async {
      final calls = <Map<String, String?>>[];
      final svc = PetAssignmentService(
        rpc: ({required petId, required enclosureId}) async {
          calls.add({'pet': petId, 'enc': enclosureId});
        },
        resync: () async {},
      );

      await svc.assign(petId: 'pet-1', enclosureId: 'enc-1');

      expect(calls, [
        {'pet': 'pet-1', 'enc': 'enc-1'}
      ]);
    });

    test('성공하면 서버에서 재동기화한다', () async {
      final sync = _FakeSync();
      final svc = PetAssignmentService(
        rpc: ({required petId, required enclosureId}) async {},
        resync: sync.call,
      );

      await svc.assign(petId: 'pet-1', enclosureId: 'enc-1');

      expect(sync.calls, 1);
    });

    test('RPC가 실패하면 재동기화하지 않고 예외를 전파한다 — 로컬 선반영 금지',
        () async {
      final sync = _FakeSync();
      final svc = PetAssignmentService(
        rpc: ({required petId, required enclosureId}) async {
          throw StateError('ownership mismatch');
        },
        resync: sync.call,
      );

      await expectLater(
        svc.assign(petId: 'pet-1', enclosureId: 'enc-1'),
        throwsStateError,
      );
      expect(sync.calls, 0);
    });

    test('해제는 enclosureId=null 로 같은 RPC를 쓴다', () async {
      final calls = <String?>[];
      final svc = PetAssignmentService(
        rpc: ({required petId, required enclosureId}) async {
          calls.add(enclosureId);
        },
        resync: () async {},
      );

      await svc.assign(petId: 'pet-1', enclosureId: null);

      expect(calls, [null]);
    });

    test('재동기화가 실패하면 그것도 전파한다 (조용한 성공 위장 금지)', () async {
      final svc = PetAssignmentService(
        rpc: ({required petId, required enclosureId}) async {},
        resync: () async => throw StateError('sync down'),
      );

      await expectLater(
        svc.assign(petId: 'pet-1', enclosureId: 'enc-1'),
        throwsStateError,
      );
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// 서버 예외 → 사용자 문구 매핑
// (easy_localization 미초기화 상태에서 .tr()은 키를 그대로 반환하므로
//  키 자체로 분기를 검증한다.)

void _errorMessageTests() {
  group('assignmentErrorMessage', () {
    test('소유권 거부는 전용 안내로 매핑', () {
      expect(
        assignmentErrorMessage(
            StateError('ownership mismatch: pets.user_id=a owner_id=b')),
        'enclosure_settings_assign_denied',
      );
      expect(
        assignmentErrorMessage(StateError('pet x is not owned by caller')),
        'enclosure_settings_assign_denied',
      );
      expect(
        assignmentErrorMessage(StateError('not authenticated')),
        'enclosure_settings_assign_denied',
      );
    });

    test('미로그인은 로그인 안내', () {
      expect(
        assignmentErrorMessage(StateError('로그인이 필요합니다')),
        'enclosure_settings_login_required',
      );
    });

    test('그 외는 일반 실패 문구 — 원문 노출 금지', () {
      final msg = assignmentErrorMessage(
          StateError('duplicate key value violates unique constraint'));
      expect(msg, 'enclosure_settings_assign_failed');
      expect(msg, isNot(contains('duplicate')));
    });
  });
}
