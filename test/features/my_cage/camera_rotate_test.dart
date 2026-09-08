import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/home/domain/enclosure_set.dart';
import 'package:vivnanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivnanaut/features/my_cage/data/camera_repository.dart';
import 'package:vivnanaut/features/my_cage/domain/enclosure.dart';
import 'package:vivnanaut/features/my_cage/domain/terra_camera.dart';
import 'package:vivnanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivnanaut/features/my_cage/presentation/widgets/camera_rotate_tile.dart';

/// 회전 계약(회신 2026-09-08) — 모델 파싱 + 토글 노출/호출.

class _FakeCameraRepo implements CameraRepository {
  final calls = <(String, bool)>[];

  @override
  Future<void> setRotate180(String cameraUuid, bool on) async {
    calls.add((cameraUuid, on));
  }

  @override
  Future<List<TerraCamera>> listAll() async => const [];

  @override
  Future<TerraCamera?> getById(String id) async => null;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> assignEnclosure(String cameraId, String? enclosureId) async {}
}

TerraCamera _camera({bool capable = true, bool rotate180 = false}) =>
    TerraCamera(
      id: 'cam-uuid-1',
      cameraId: 'p4cam-test',
      name: '테스트캠',
      isOnline: true,
      createdAt: DateTime(2026, 9, 8),
      rotate180: rotate180,
      rotate180Capable: capable,
    );

EnclosureSet _set(TerraCamera? camera) => EnclosureSet(
      enclosure: Enclosure(
          id: 'enc-1', name: '1번 사육장', createdAt: DateTime(2026, 9, 8)),
      device: null,
      camera: camera,
      pet: null,
    );

Future<void> _pump(
  WidgetTester tester, {
  required TerraCamera? camera,
  _FakeCameraRepo? repo,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentSetProvider.overrideWith((ref) async => _set(camera)),
        cameraRepositoryProvider
            .overrideWithValue(repo ?? _FakeCameraRepo()),
      ],
      child: const MaterialApp(
        home: Scaffold(body: CameraRotateTile()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('TerraCamera.fromJson — rotate_180/capabilities 파싱', () {
    test('신 펌웨어: capabilities.rotate_180=true → capable', () {
      final c = TerraCamera.fromJson({
        'id': 'x',
        'camera_id': 'p4cam-1',
        'name': 'c',
        'rotate_180': true,
        'capabilities': {'rotate_180': true},
      });
      expect(c.rotate180, isTrue);
      expect(c.rotate180Capable, isTrue);
    });

    test('구 펌웨어: capabilities null/키 없음 → not capable + 기본 정방향', () {
      final noCaps = TerraCamera.fromJson(
          {'id': 'x', 'camera_id': 'p4cam-1', 'name': 'c'});
      expect(noCaps.rotate180, isFalse);
      expect(noCaps.rotate180Capable, isFalse);

      final nullCaps = TerraCamera.fromJson({
        'id': 'x',
        'camera_id': 'p4cam-1',
        'name': 'c',
        'capabilities': null,
      });
      expect(nullCaps.rotate180Capable, isFalse);

      final otherCaps = TerraCamera.fromJson({
        'id': 'x',
        'camera_id': 'p4cam-1',
        'name': 'c',
        'capabilities': {'led_dimmable': true},
      });
      expect(otherCaps.rotate180Capable, isFalse);
    });
  });

  group('CameraRotateTile', () {
    testWidgets('capable 카메라 → 토글 노출 + PATCH 호출(id, 값)', (tester) async {
      final repo = _FakeCameraRepo();
      await _pump(tester, camera: _camera(capable: true), repo: repo);
      expect(find.byKey(CameraRotateTile.tileKey), findsOneWidget);

      await tester.tap(find.byKey(CameraRotateTile.tileKey));
      await tester.pumpAndSettle();
      expect(repo.calls, [('cam-uuid-1', true)]);
    });

    testWidgets('구 펌웨어(미보고) → 타일째 숨김(회신 §4)', (tester) async {
      await _pump(tester, camera: _camera(capable: false));
      expect(find.byKey(CameraRotateTile.tileKey), findsNothing);
    });

    testWidgets('세트에 카메라 없음 → 숨김', (tester) async {
      await _pump(tester, camera: null);
      expect(find.byKey(CameraRotateTile.tileKey), findsNothing);
    });
  });
}
