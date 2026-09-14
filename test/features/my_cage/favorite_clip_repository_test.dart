import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivnanaut/features/my_cage/data/favorite_clip_repository.dart';
import 'package:vivnanaut/features/my_cage/data/motion_clip_repository.dart';
import 'package:vivnanaut/features/my_cage/domain/favorite_clip.dart';
import 'package:vivnanaut/features/my_cage/domain/motion_clip.dart';

class _UnusedMotion extends Fake implements MotionClipRepository {
  int calls = 0;
  @override
  Future<MotionClip?> getById(String id) async {
    calls++;
    return null;
  }
}

void main() {
  late Directory root;
  late Box<FavoriteClip> box;
  late String owner;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('bookmark-test-');
    Hive.init(root.path);
    final adapter = FavoriteClipAdapter();
    if (!Hive.isAdapterRegistered(adapter.typeId)) {
      Hive.registerAdapter(adapter);
    }
    box = await Hive.openBox<FavoriteClip>('favorite_clips');
    await Hive.openBox('app_settings');
    owner = 'a';
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });
  test('다운로드 중 계정 변경은 다른 계정에 저장하지 않는다', () async {
    final pending = Completer<http.Response>();
    final repo = FavoriteClipRepository(
        supabase: SupabaseClient('https://example.test', 'test'),
        downloadClient: MockClient((r) => pending.future),
        directoryProvider: () async => root,
        ownerIdProvider: () => owner);
    final result = repo.add(
        MotionClip(
            id: 'clip',
            cameraId: 'cam',
            startedAt: DateTime(2026),
            durationSec: 2),
        'https://example.test/video');
    final assertion = expectLater(result, throwsStateError);
    owner = 'b';
    pending.complete(http.Response('video', 200));
    await assertion;
    expect(box.values, isEmpty);
    expect(Directory('${root.path}/b').existsSync(), false);
  });
  test('오프라인 삭제는 tombstone을 남기고 동기화가 클립을 복원하지 않는다', () async {
    var deletes = 0;
    final client = SupabaseClient('https://example.test', 'test',
        httpClient: MockClient((r) async {
      if (r.method == 'DELETE') {
        deletes++;
        return http.Response('{}', 503);
      }
      return http.Response('[{"clip_id":"clip"}]', 200,
          headers: {'content-type': 'application/json'});
    }));
    final repo = FavoriteClipRepository(
        supabase: client,
        directoryProvider: () async => root,
        ownerIdProvider: () => owner);
    final file = await File('${root.path}/clip.mp4').writeAsString('video');
    await box.put(
        'clip',
        FavoriteClip(
            clipId: 'clip',
            cameraId: 'cam',
            startedAt: DateTime(2026),
            durationSec: 2,
            filePath: file.path,
            sizeBytes: 5,
            favoritedAt: DateTime(2026),
            ownerId: 'a'));
    owner = 'b';
    expect(await repo.remove('clip'), null);
    expect(file.existsSync(), true);
    owner = 'a';
    expect(await repo.remove('clip'), 'cam');
    expect(file.existsSync(), false);
    expect(box.containsKey('clip'), false);
    final motion = _UnusedMotion();
    await repo.syncFromCloud(motion);
    expect(motion.calls, 0);
    expect(deletes, 2);
    expect(Hive.box('app_settings').get('bookmark_removed/a/clip'), true);
  });
}
