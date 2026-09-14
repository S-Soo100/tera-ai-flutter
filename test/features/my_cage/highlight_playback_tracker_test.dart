import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:vivnanaut/features/my_cage/domain/highlight_publication.dart';
import 'package:vivnanaut/features/my_cage/data/highlight_read_store.dart';

void main() {
  test('진입 초기화 버퍼링 시크로는 읽지 않고 실제 재생 진전 1회만 읽는다', () {
    final tracker = HighlightPlaybackTracker();
    tracker.resetPosition(const Duration(seconds: 8));
    expect(tracker.observe(position: const Duration(seconds: 8), playing: true),
        false);
    expect(
        tracker.observe(
            position: const Duration(seconds: 9),
            playing: true,
            buffering: true),
        false);
    expect(
        tracker.observe(
            position: const Duration(seconds: 20),
            playing: true,
            seeking: true),
        false);
    expect(
        tracker.observe(position: const Duration(seconds: 20), playing: false),
        false);
    expect(
        tracker.observe(
            position: const Duration(milliseconds: 20500), playing: true),
        true);
    expect(
        tracker.observe(position: const Duration(seconds: 21), playing: true),
        false);
  });
  test('공개시각 없는 동적 하이라이트는 도착으로 변환하지 않는다', () {
    expect(HighlightPublication.fromJson({'batch_id': 'x', 'status': 'ready'}),
        isNull);
    final p = HighlightPublication(
        batchId: 'x',
        captureStart: DateTime(2026, 9, 1, 22),
        captureEnd: DateTime(2026, 9, 2, 6),
        publishedAt: DateTime(2026, 9, 2, 8),
        status: 'ready');
    expect(p.availableAt(DateTime(2026, 9, 2, 7)), false);
    expect(p.availableAt(DateTime(2026, 9, 2, 9)), true);
  });
  test('읽음은 계정 카메라 배치별 격리되고 재시작 뒤 유지된다', () async {
    final dir = await Directory.systemTemp.createTemp('highlight-read-');
    Hive.init(dir.path);
    await Hive.openBox('app_settings');
    addTearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });
    const store = HighlightReadStore();
    const key = (ownerId: 'a', cameraId: 'cam', batchId: 'batch');
    await store.markRead(key);
    await Hive.close();
    await Hive.openBox('app_settings');
    expect(store.read(key), true);
    expect(
        store.read((ownerId: 'b', cameraId: 'cam', batchId: 'batch')), false);
    expect(
        store.read((ownerId: 'a', cameraId: 'other', batchId: 'batch')), false);
    expect(store.read((ownerId: 'a', cameraId: 'cam', batchId: 'new')), false);
  });
}
