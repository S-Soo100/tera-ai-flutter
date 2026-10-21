// 서버 녹화 목록(F단계, 2026-10-21) — 직결 SELECT keyset·재생/썸네일 URL·
// 서버 전용 삭제·이 폰 녹화와 합치기·계정 전환.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:vivanaut/core/network/auth_session.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/my_cage/data/live_recording_repository.dart';
import 'package:vivanaut/features/my_cage/data/live_recording_server_repository.dart';
import 'package:vivanaut/features/my_cage/data/live_recording_upload_repository.dart';
import 'package:vivanaut/features/my_cage/domain/live_recording.dart';
import 'package:vivanaut/features/my_cage/domain/recording_item.dart';
import 'package:vivanaut/features/my_cage/presentation/live_recording_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/live_recording_upload_queue.dart';
import 'package:vivanaut/features/my_cage/presentation/recording_library_providers.dart';

class _Session implements AuthSession {
  int recovers = 0;
  @override
  Future<String?> accessToken() async => 'tok';
  @override
  Future<bool> recoverFromUnauthorized() async {
    recovers++;
    return true;
  }
}

Map<String, Object?> _row(String id, DateTime at, {String? camera = 'cam'}) => {
      'id': id,
      'camera_id': camera,
      'started_at': at.toUtc().toIso8601String(),
      'duration_ms': 30000,
      'size_bytes': 100,
      'width': 1280,
      'height': 960,
      'has_thumbnail': true,
      'created_at': at.toUtc().toIso8601String(),
    };

User _user(String id) => User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-01-01');

LiveRecordingServerRepository _repo(
        {RecordingRowsLoader? rows,
        http.Client? client,
        AuthSession? session}) =>
    LiveRecordingServerRepository(
      loadRows: rows ?? ({before, required limit}) async => const [],
      baseUrl: 'https://api.test',
      session: session ?? _Session(),
      client: client ?? MockClient((_) async => http.Response('', 599)),
    );

void main() {
  group('LiveRecordingServerRepository', () {
    test('ready 목록을 keyset으로 끝까지 — 마지막 행의 (started_at, id)가 다음 커서', () async {
      final base = DateTime.utc(2026, 10, 21, 12);
      final all = [
        for (var i = 0; i < LiveRecordingServerRepository.pageSize + 3; i++)
          _row('r$i', base.subtract(Duration(minutes: i)))
      ];
      final cursors = <RecordingCursor?>[];
      final repo = _repo(rows: ({before, required limit}) async {
        cursors.add(before);
        final start = before == null
            ? 0
            : all.indexWhere((r) => r['id'] == before.id) + 1;
        return all.skip(start).take(limit).toList();
      });
      final list = await repo.listReady();
      expect(list.length, all.length);
      expect(cursors.length, 2);
      expect(cursors.first, isNull);
      expect(
          cursors.last!.id, 'r${LiveRecordingServerRepository.pageSize - 1}');
      expect(
          cursors.last!.startedAt,
          base.subtract(
              Duration(minutes: LiveRecordingServerRepository.pageSize - 1)));
    });

    test('타입이 틀린 행만 버린다', () async {
      final repo = _repo(
          rows: ({before, required limit}) async => [
                _row('ok', DateTime.utc(2026)),
                {'id': 'bad'},
              ]);
      expect((await repo.listReady()).map((r) => r.id), ['ok']);
    });

    test('재생·썸네일 URL — GET /recordings/{id}/url·thumbnail/url, 401은 갱신 후 1회',
        () async {
      final calls = <String>[];
      var first = true;
      final session = _Session();
      final client = MockClient((req) async {
        calls.add(
            '${req.method} ${req.url.path} ${req.headers['Authorization']}');
        if (req.url.path == '/recordings/s1/url' && first) {
          first = false;
          return http.Response('', 401);
        }
        if (req.url.path == '/recordings/s1/url') {
          return http.Response(
              jsonEncode(
                  {'url': 'https://r2.test/v.mp4?sig', 'expires_in': 3600}),
              200);
        }
        if (req.url.path == '/recordings/s1/thumbnail/url') {
          return http.Response(
              jsonEncode(
                  {'url': 'https://r2.test/t.jpg?sig', 'expires_in': 3600}),
              200);
        }
        return http.Response('', 404);
      });
      final repo = _repo(client: client, session: session);
      expect(await repo.playbackUrl('s1'), 'https://r2.test/v.mp4?sig');
      expect(session.recovers, 1);
      expect(await repo.thumbnailUrl('s1'), 'https://r2.test/t.jpg?sig');
      // 썸네일 없음(404) → null, 재생 404 → 예외.
      expect(await repo.thumbnailUrl('s2'), isNull);
      await expectLater(
          repo.playbackUrl('s2'), throwsA(isA<RecordingApiException>()));
      expect(calls.first, 'GET /recordings/s1/url Bearer tok');
    });

    test('재생 URL 5xx는 상태 코드를 담은 예외', () async {
      final repo =
          _repo(client: MockClient((_) async => http.Response('oops', 502)));
      await expectLater(
          repo.playbackUrl('s1'),
          throwsA(isA<RecordingApiException>()
              .having((e) => e.statusCode, 'statusCode', 502)));
    });
  });

  group('대기열 서버 전용 삭제', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('rec_lib');
      Hive.init(dir.path);
    });
    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    LiveRecordingUploadQueue queue(http.Client client) {
      final api = LiveRecordingUploadRepository(
          baseUrl: 'https://api.test', session: _Session(), client: client);
      return LiveRecordingUploadQueue(
        ownerId: 'u1',
        local: LiveRecordingRepository(baseDir: () async => dir),
        api: () => api,
        currentOwner: () => 'u1',
      );
    }

    test('성공(204·404) → 목록에서 빼고 서버 목록 갱신 신호', () async {
      final deletes = <String>[];
      final q = queue(MockClient((req) async {
        deletes.add('${req.method} ${req.url.path}');
        return http.Response('', req.url.path.endsWith('gone') ? 404 : 204);
      }));
      addTearDown(q.dispose);
      final before = q.state.serverRevision;
      expect(await q.deleteServer('s1'), isTrue);
      expect(await q.deleteServer('gone'), isTrue);
      expect(deletes, ['DELETE /recordings/s1', 'DELETE /recordings/gone']);
      expect(q.state.removedServerIds, {'s1', 'gone'});
      expect(q.state.serverRevision, before + 2);
      // 삭제 뒤 깨운 대기열 순회가 끝나길 기다린다(정리 전에).
      await q.kick(LiveRecordingUploadTrigger.deleted);
    });

    test('실패(5xx·망) → false, 목록에 되돌린다', () async {
      final q = queue(MockClient((_) async => http.Response('', 503)));
      addTearDown(q.dispose);
      expect(await q.deleteServer('s1'), isFalse);
      expect(q.state.removedServerIds, isEmpty);
    });

    test('이 폰 녹화를 지우면 그 서버 id도 바로 서버 목록에서 뺀다', () async {
      final local = LiveRecordingRepository(baseDir: () async => dir);
      final rec = LiveRecording(
          id: 'a',
          ownerId: 'u1',
          cameraId: 'cam',
          startedAt: DateTime.utc(2026),
          durationMs: 10000,
          filePath: 'x.mp4',
          recordingId: 'srv-a',
          uploadState: LiveRecordingUploadState.ready);
      await local.save(rec);
      final gate = Completer<http.Response>();
      final q = queue(MockClient((_) => gate.future));
      addTearDown(q.dispose);
      final deleting = q.delete(rec);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(q.state.removedServerIds, contains('srv-a'));
      gate.complete(http.Response('', 204));
      await deleting;
      await q.kick(LiveRecordingUploadTrigger.deleted);
    });
  });

  group('recordingLibraryProvider', () {
    test('계정이 바뀌면 이전 계정 서버 목록을 쓰지 않는다(빈 목록 → 새 계정 목록)', () async {
      final user = StateProvider<User?>((ref) => _user('a'));
      final gates = <String, Completer<ServerRecordingList?>>{
        'a': Completer(),
        'b': Completer(),
      };
      final c = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => ref.watch(user)),
        liveRecordingsProvider.overrideWith((ref) async => const []),
        liveRecordingUploadQueueProvider.overrideWith((ref) =>
            LiveRecordingUploadQueue(
                ownerId: null,
                local: LiveRecordingRepository(),
                api: () => throw UnimplementedError(),
                currentOwner: () => null)),
        serverLiveRecordingsProvider.overrideWith((ref) {
          final uid = ref.watch(currentUserProvider.select((u) => u?.id));
          return gates[uid]!.future;
        }),
      ]);
      addTearDown(c.dispose);
      final sub = c.listen(recordingLibraryProvider, (_, __) {});
      addTearDown(sub.close);
      gates['a']!.complete((
        ownerId: 'a',
        items: [
          ServerLiveRecording(
              id: 'sa',
              cameraId: 'cam',
              startedAt: DateTime.utc(2026),
              durationMs: 1,
              hasThumbnail: false)
        ]
      ));
      await Future<void>.delayed(Duration.zero);
      await c.read(liveRecordingsProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(sub.read().valueOrNull?.map((r) => r.key), ['rec:srv:sa']);

      c.read(user.notifier).state = _user('b');
      await Future<void>.delayed(Duration.zero);
      // b의 서버 목록이 오기 전 — a의 목록은 보이지 않는다.
      expect(sub.read().valueOrNull, isEmpty);
      gates['b']!
          .complete((ownerId: 'b', items: const <ServerLiveRecording>[]));
      await Future<void>.delayed(Duration.zero);
      expect(sub.read().valueOrNull, isEmpty);
    });

    test('서버 목록이 실패해도 이 폰 녹화는 보인다', () async {
      final rec = LiveRecording(
          id: 'a',
          ownerId: 'u1',
          cameraId: 'cam',
          startedAt: DateTime.utc(2026),
          durationMs: 1,
          filePath: 'a.mp4');
      final c = ProviderContainer(overrides: [
        currentUserProvider.overrideWithValue(_user('u1')),
        liveRecordingsProvider.overrideWith((ref) async => [rec]),
        liveRecordingUploadQueueProvider.overrideWith((ref) =>
            LiveRecordingUploadQueue(
                ownerId: null,
                local: LiveRecordingRepository(),
                api: () => throw UnimplementedError(),
                currentOwner: () => null)),
        serverLiveRecordingsProvider
            .overrideWith((ref) async => throw const SocketException('x')),
      ]);
      addTearDown(c.dispose);
      final sub = c.listen(recordingLibraryProvider, (_, __) {});
      addTearDown(sub.close);
      await c.read(liveRecordingsProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(sub.read().valueOrNull?.map((r) => r.key), ['rec:a']);
    });
  });
}
