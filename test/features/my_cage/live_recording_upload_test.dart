// 직접 녹화 R2 업로드 대기열 — 가짜 HTTP로 합의 결과(2026-10-20) 규칙을 고정한다.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vivanaut/core/network/auth_session.dart';
import 'package:vivanaut/features/my_cage/data/live_recording_repository.dart';
import 'package:vivanaut/features/my_cage/data/live_recording_upload_repository.dart';
import 'package:vivanaut/features/my_cage/domain/live_recording.dart';
import 'package:vivanaut/features/my_cage/presentation/live_recording_upload_queue.dart';

class _Session implements AuthSession {
  int recovers = 0;
  bool recoverOk = true;
  @override
  Future<String?> accessToken() async => 'tok';
  @override
  Future<bool> recoverFromUnauthorized() async {
    recovers++;
    return recoverOk;
  }
}

/// 경로별로 응답을 차례로 꺼내 주는 가짜 서버. 응답이 떨어지면 마지막 것을 반복.
class _Server {
  final calls = <http.Request>[];
  final routes = <String, List<FutureOr<http.Response> Function(http.Request)>>{};

  void on(String key, FutureOr<http.Response> Function(http.Request) r) =>
      (routes[key] ??= []).add(r);

  void json(String key, int code, [Object? body]) => on(
      key,
      (_) => http.Response(body == null ? '' : jsonEncode(body), code,
          headers: {'content-type': 'application/json'}));

  List<String> get keys => [for (final c in calls) _key(c)];
  int count(String key) => keys.where((k) => k == key).length;

  static String _key(http.Request r) {
    if (r.url.host == 'r2.test') return 'PUT ${r.url.path}';
    final path = r.url.path
        .replaceAll(RegExp(r'/recordings/[^/]+/complete'), '/recordings/:id/complete')
        .replaceAll(RegExp(r'/recordings/[^/]+$'), '/recordings/:id');
    return '${r.method} $path';
  }

  MockClient get client => MockClient((req) async {
        calls.add(req);
        final list = routes[_key(req)];
        if (list == null || list.isEmpty) {
          return http.Response('no route ${_key(req)}', 599);
        }
        final r = list.length > 1 ? list.removeAt(0) : list.first;
        return r(req);
      });
}

Map<String, Object?> _reg(String rid,
        {String status = 'pending', bool thumb = true}) =>
    {
      'recording_id': rid,
      'status': status,
      'video_upload_url':
          status == 'ready' ? null : 'https://r2.test/v/$rid.mp4?X-Sig=secret',
      'thumb_upload_url': status == 'ready' || !thumb
          ? null
          : 'https://r2.test/t/$rid.jpg?X-Sig=secret',
      'expires_at': status == 'ready' ? null : '2026-10-21T01:00:00Z',
    };

void main() {
  late Directory dir;
  late LiveRecordingRepository local;
  late _Server server;
  late _Session session;
  late String? owner;
  late DateTime now;
  final queues = <LiveRecordingUploadQueue>[];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('rec_upload');
    Hive.init(dir.path);
    local = LiveRecordingRepository(baseDir: () async => dir);
    server = _Server();
    session = _Session();
    owner = 'u1';
    now = DateTime.utc(2026, 10, 21, 3);
  });

  tearDown(() async {
    for (final q in queues) {
      if (q.mounted) q.dispose();
    }
    queues.clear();
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  LiveRecordingUploadQueue queue() {
    final api = LiveRecordingUploadRepository(
        baseUrl: 'https://api.test', session: session, client: server.client);
    final q = LiveRecordingUploadQueue(
      ownerId: owner,
      local: local,
      api: () => api,
      currentOwner: () => owner,
      now: () => now,
    );
    queues.add(q);
    return q;
  }

  /// 녹화 한 건을 파일과 함께 넣는다. [startMin]이 작을수록 오래된 것.
  Future<LiveRecording> add(String id,
      {int durationMs = 42000,
      int startMin = 0,
      String who = 'u1',
      int bytes = 1000,
      bool thumb = true,
      String? recordingId,
      LiveRecordingUploadState state = LiveRecordingUploadState.pending}) async {
    final video = await local.newPath(who, id, 'mp4');
    await File(video.abs).writeAsBytes(List.filled(bytes, 1));
    String? thumbRel;
    if (thumb) {
      final t = await local.newPath(who, id, 'jpg');
      await File(t.abs).writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
      thumbRel = t.rel;
    }
    final r = LiveRecording(
      id: id,
      ownerId: who,
      cameraId: 'cam-1',
      startedAt: DateTime.utc(2026, 10, 21, 2, startMin),
      durationMs: durationMs,
      filePath: video.rel,
      thumbPath: thumbRel,
      width: 1280,
      height: 960,
      recordingId: recordingId,
      uploadState: state,
    );
    await local.save(r);
    return r;
  }

  Future<LiveRecording?> row(String id) => local.get(id);

  void happy(String rid) {
    server
      ..json('POST /recordings', 201, _reg(rid))
      ..json('PUT /v/$rid.mp4', 200)
      ..json('PUT /t/$rid.jpg', 200)
      ..json('POST /recordings/:id/complete', 200, {'status': 'ready'});
  }

  test('정상: POST → PUT 영상·썸네일 → complete → ready', () async {
    await add('a');
    happy('srv-a');
    await queue().kick(LiveRecordingUploadTrigger.saved);

    expect(server.keys, [
      'POST /recordings',
      'PUT /v/srv-a.mp4',
      'PUT /t/srv-a.jpg',
      'POST /recordings/:id/complete',
    ]);
    final post = server.calls.first;
    expect(post.headers['Authorization'], 'Bearer tok');
    final body = jsonDecode(post.body) as Map<String, Object?>;
    expect(body['camera_id'], 'cam-1');
    expect(body['client_id'], 'a');
    expect(body['duration_ms'], 42000);
    expect(body['size_bytes'], 1000);
    expect(body['width'], 1280);
    expect(body['has_thumbnail'], isTrue);
    expect(body['started_at'], '2026-10-21T02:00:00.000Z');
    final putVideo = server.calls[1];
    expect(putVideo.headers['Content-Type'], 'video/mp4');
    expect(putVideo.headers.containsKey('Authorization'), isFalse);
    expect(putVideo.bodyBytes.length, 1000);
    expect(server.calls[2].headers['Content-Type'], 'image/jpeg');
    expect(server.calls[3].url.path, '/recordings/srv-a/complete');

    final r = (await row('a'))!;
    expect(r.uploadState, LiveRecordingUploadState.ready);
    expect(r.recordingId, 'srv-a');
    expect(r.uploadedAt, now);
    expect(r.uploadBadge, LiveRecordingUploadBadge.none);
  });

  test('등록 응답이 ready면 업로드를 건너뛴다', () async {
    await add('a', recordingId: 'srv-a');
    server.json('POST /recordings', 200, _reg('srv-a', status: 'ready'));
    await queue().kick(LiveRecordingUploadTrigger.appStart);
    expect(server.keys, ['POST /recordings']);
    expect((await row('a'))!.uploadState, LiveRecordingUploadState.ready);
  });

  test('썸네일이 없으면 has_thumbnail=false, 썸네일 PUT 없음', () async {
    await add('a', thumb: false);
    server
      ..json('POST /recordings', 201, _reg('srv-a', thumb: false))
      ..json('PUT /v/srv-a.mp4', 200)
      ..json('POST /recordings/:id/complete', 200, {'status': 'ready'});
    await queue().kick(LiveRecordingUploadTrigger.saved);
    expect(jsonDecode(server.calls.first.body)['has_thumbnail'], isFalse);
    expect(server.count('PUT /t/srv-a.jpg'), 0);
    expect((await row('a'))!.uploadState, LiveRecordingUploadState.ready);
  });

  test('complete 409 upload_missing → 같은 client_id로 다시 등록해 처음부터',
      () async {
    await add('a');
    server
      ..json('POST /recordings', 201, _reg('srv-a'))
      ..json('POST /recordings', 200, _reg('srv-a'))
      ..json('PUT /v/srv-a.mp4', 200)
      ..json('PUT /t/srv-a.jpg', 200)
      ..json('POST /recordings/:id/complete', 409, {
        'detail': {'code': 'upload_missing', 'reason': 'size_mismatch'}
      })
      ..json('POST /recordings/:id/complete', 200, {'status': 'ready'});
    await queue().kick(LiveRecordingUploadTrigger.saved);
    expect(server.count('POST /recordings'), 2);
    expect(server.count('PUT /v/srv-a.mp4'), 2);
    expect(jsonDecode(server.calls[4].body)['client_id'], 'a');
    expect((await row('a'))!.uploadState, LiveRecordingUploadState.ready);
  });

  test('PUT 403(서명 만료) → 다시 등록해 새 URL로', () async {
    await add('a');
    server
      ..json('POST /recordings', 201, _reg('srv-a'))
      ..json('PUT /v/srv-a.mp4', 403)
      ..json('PUT /v/srv-a.mp4', 200)
      ..json('PUT /t/srv-a.jpg', 200)
      ..json('POST /recordings/:id/complete', 200, {'status': 'ready'});
    await queue().kick(LiveRecordingUploadTrigger.saved);
    expect(server.keys, [
      'POST /recordings',
      'PUT /v/srv-a.mp4',
      'POST /recordings',
      'PUT /v/srv-a.mp4',
      'PUT /t/srv-a.jpg',
      'POST /recordings/:id/complete',
    ]);
    expect((await row('a'))!.uploadState, LiveRecordingUploadState.ready);
  });

  test('재등록 응답 recording_id가 바뀌면(23.5시간) 교체 후 처음부터', () async {
    await add('a', recordingId: 'old');
    happy('new');
    await queue().kick(LiveRecordingUploadTrigger.appStart);
    final r = (await row('a'))!;
    expect(r.recordingId, 'new');
    expect(r.uploadState, LiveRecordingUploadState.ready);
    expect(server.calls.last.url.path, '/recordings/new/complete');
  });

  test('409 quota → blocked, 그 자리에서 멈추고 재평가 계기에만 다시', () async {
    await add('old', startMin: 0);
    await add('new', startMin: 5);
    server.json('POST /recordings', 409, {
      'detail': {'code': 'recording_quota_exceeded', 'used': 50, 'limit': 50}
    });
    final q = queue();
    await q.kick(LiveRecordingUploadTrigger.saved);
    expect(server.count('POST /recordings'), 1);
    expect(jsonDecode(server.calls.single.body)['client_id'], 'old');
    final blocked = (await row('old'))!;
    expect(blocked.uploadState, LiveRecordingUploadState.blocked);
    expect(blocked.uploadError, LiveRecordingUploadError.quota);
    expect(blocked.uploadBadge, LiveRecordingUploadBadge.waiting);
    expect((await row('new'))!.uploadState, LiveRecordingUploadState.pending);

    // 망 복귀·타이머는 quota를 다시 보지 않는다.
    await q.kick(LiveRecordingUploadTrigger.network);
    expect(server.count('POST /recordings'), 1);

    // 보관함 진입 → 오래된 것부터 다시. 이번엔 통과.
    server.routes.clear();
    happy('srv-old');
    server.json('POST /recordings', 201, _reg('srv-new'));
    await q.kick(LiveRecordingUploadTrigger.bookmarks);
    expect((await row('old'))!.uploadState, LiveRecordingUploadState.ready);
  });

  test('401 → 세션 갱신 후 1회 재시도', () async {
    await add('a');
    server
      ..json('POST /recordings', 401)
      ..json('POST /recordings', 201, _reg('srv-a'))
      ..json('PUT /v/srv-a.mp4', 200)
      ..json('PUT /t/srv-a.jpg', 200)
      ..json('POST /recordings/:id/complete', 200, {'status': 'ready'});
    await queue().kick(LiveRecordingUploadTrigger.saved);
    expect(session.recovers, 1);
    expect(server.count('POST /recordings'), 2);
    expect((await row('a'))!.uploadState, LiveRecordingUploadState.ready);
  });

  test('401이 또 오면 더 보내지 않고 일시 실패(재시도 예약)', () async {
    await add('a');
    server.json('POST /recordings', 401);
    await queue().kick(LiveRecordingUploadTrigger.saved);
    expect(session.recovers, 1);
    expect(server.count('POST /recordings'), 2);
    final r = (await row('a'))!;
    expect(r.uploadState, LiveRecordingUploadState.pending);
    expect(r.uploadError, 'http_401');
  });

  test('등록 400 → failed, 다시 시도하지 않는다', () async {
    await add('a');
    server.json('POST /recordings', 400, {'detail': 'invalid'});
    final q = queue();
    await q.kick(LiveRecordingUploadTrigger.saved);
    final r = (await row('a'))!;
    expect(r.uploadState, LiveRecordingUploadState.failed);
    expect(r.uploadError, 'http_400');
    expect(r.uploadBadge, LiveRecordingUploadBadge.failed);
    await q.kick(LiveRecordingUploadTrigger.appStart);
    expect(server.count('POST /recordings'), 1);
  });

  test('등록 403·404 → failed, 다음 녹화는 계속', () async {
    await add('a', startMin: 0);
    await add('b', startMin: 1);
    server
      ..json('POST /recordings', 403)
      ..json('POST /recordings', 404)
      ..json('POST /recordings', 404);
    await queue().kick(LiveRecordingUploadTrigger.saved);
    expect((await row('a'))!.uploadError, 'http_403');
    expect((await row('b'))!.uploadError, 'http_404');
  });

  test('5xx → 백오프 예약(30초부터 2배), 기다리는 동안 다시 보내지 않는다',
      () async {
    await add('a');
    server.json('POST /recordings', 502);
    final q = queue();
    await q.kick(LiveRecordingUploadTrigger.saved);
    var r = (await row('a'))!;
    expect(r.uploadState, LiveRecordingUploadState.pending);
    expect(r.uploadAttempts, 1);
    expect(r.nextAttemptAt, now.add(const Duration(seconds: 30)));
    expect(q.scheduledAt, now.add(const Duration(seconds: 30)));
    expect(r.uploadBadge, LiveRecordingUploadBadge.waiting);

    await q.kick(LiveRecordingUploadTrigger.bookmarks);
    expect(server.count('POST /recordings'), 1);

    now = now.add(const Duration(seconds: 31));
    await q.kick(LiveRecordingUploadTrigger.timer);
    r = (await row('a'))!;
    expect(server.count('POST /recordings'), 2);
    expect(r.uploadAttempts, 2);
    expect(r.nextAttemptAt, now.add(const Duration(seconds: 60)));
  });

  test('망 끊김(예외) → 백오프', () async {
    await add('a');
    server.on('POST /recordings',
        (_) => throw const SocketException('down'));
    await queue().kick(LiveRecordingUploadTrigger.saved);
    final r = (await row('a'))!;
    expect(r.uploadError, 'network');
    expect(r.nextAttemptAt, isNotNull);
  });

  test('백오프 상한 30분', () {
    expect(liveRecordingUploadBackoff(1), const Duration(seconds: 30));
    expect(liveRecordingUploadBackoff(3), const Duration(minutes: 2));
    expect(liveRecordingUploadBackoff(20), const Duration(minutes: 30));
  });

  test('서버 길이 한도(60초) 초과 → POST 없이 blocked, 다음 녹화는 올린다',
      () async {
    await add('long', durationMs: kServerRecordingMaxMs + 1, startMin: 0);
    await add('short', startMin: 1);
    happy('srv-short');
    await queue().kick(LiveRecordingUploadTrigger.saved);
    final long = (await row('long'))!;
    expect(long.uploadState, LiveRecordingUploadState.blocked);
    expect(long.uploadError, LiveRecordingUploadError.lengthLimit);
    expect(long.uploadBadge, LiveRecordingUploadBadge.waiting);
    expect(server.count('POST /recordings'), 1);
    expect(jsonDecode(server.calls.first.body)['client_id'], 'short');
  });

  test('30MB 초과 → POST 없이 failed(too_large)', () async {
    final r = await add('big');
    final raf = await File(await local.resolve(r.filePath))
        .open(mode: FileMode.write);
    await raf.setPosition(kServerRecordingMaxBytes);
    await raf.writeByte(0);
    await raf.close();
    await queue().kick(LiveRecordingUploadTrigger.saved);
    expect(server.calls, isEmpty);
    final back = (await row('big'))!;
    expect(back.uploadState, LiveRecordingUploadState.failed);
    expect(back.uploadError, LiveRecordingUploadError.tooLarge);
  });

  test('다른 계정 녹화는 건드리지 않는다', () async {
    await add('mine');
    await add('theirs', who: 'u2', startMin: -5);
    happy('srv-mine');
    await queue().kick(LiveRecordingUploadTrigger.saved);
    expect(server.count('POST /recordings'), 1);
    expect(jsonDecode(server.calls.first.body)['client_id'], 'mine');
    expect((await row('theirs'))!.uploadState,
        LiveRecordingUploadState.pending);
  });

  test('업로드 중 계정이 바뀌면 거기서 멈춘다(다른 계정 토큰으로 안 올림)',
      () async {
    await add('a');
    server
      ..json('POST /recordings', 201, _reg('srv-a'))
      ..on('PUT /v/srv-a.mp4', (_) {
        owner = 'u2'; // 업로드하는 사이 계정 전환
        return http.Response('', 200);
      })
      ..json('PUT /t/srv-a.jpg', 200)
      ..json('POST /recordings/:id/complete', 200, {'status': 'ready'});
    await queue().kick(LiveRecordingUploadTrigger.saved);
    expect(server.keys, ['POST /recordings', 'PUT /v/srv-a.mp4']);
    final r = (await row('a'))!;
    expect(r.uploadState, LiveRecordingUploadState.pending);
    expect(r.recordingId, 'srv-a');
  });

  test('dispose(로그아웃) 뒤엔 kick해도 아무것도 안 보낸다', () async {
    await add('a');
    happy('srv-a');
    final q = queue()..dispose();
    await q.kick(LiveRecordingUploadTrigger.saved);
    expect(server.calls, isEmpty);
  });

  group('삭제 상태 기계', () {
    test('미등록 → 로컬 파일만 지운다(HTTP 없음)', () async {
      final r = await add('a');
      final abs = await local.resolve(r.filePath);
      await queue().delete(r);
      expect(server.calls, isEmpty);
      expect(await row('a'), isNull);
      expect(File(abs).existsSync(), isFalse);
    });

    test('등록됨 → DELETE 204 후 로컬 삭제', () async {
      final r = await add('a',
          recordingId: 'srv-a', state: LiveRecordingUploadState.ready);
      server.json('DELETE /recordings/:id', 204);
      await queue().delete(r);
      expect(server.keys, ['DELETE /recordings/:id']);
      expect(server.calls.single.url.path, '/recordings/srv-a');
      expect(await row('a'), isNull);
    });

    test('DELETE 404 = 이미 없음 → 성공', () async {
      final r = await add('a',
          recordingId: 'srv-a', state: LiveRecordingUploadState.ready);
      server.json('DELETE /recordings/:id', 404);
      await queue().delete(r);
      expect(await row('a'), isNull);
    });

    test('DELETE 실패 → deleting으로 남기고 목록에선 숨김, 다음 계기에 재시도',
        () async {
      final r = await add('a',
          recordingId: 'srv-a', state: LiveRecordingUploadState.ready);
      server
        ..json('DELETE /recordings/:id', 503)
        ..json('DELETE /recordings/:id', 204);
      final q = queue();
      await q.delete(r);
      final kept = (await row('a'))!;
      expect(kept.uploadState, LiveRecordingUploadState.deleting);
      expect(kept.nextAttemptAt, isNotNull);
      expect(await local.list('u1'), isEmpty);
      expect((await local.listAll('u1')).single.id, 'a');

      await q.kick(LiveRecordingUploadTrigger.appStart); // 백오프 무시
      expect(server.count('DELETE /recordings/:id'), 2);
      expect(await row('a'), isNull);
    });

    test('업로드 중 → 업로드를 끊은 뒤 DELETE(complete 안 부름)', () async {
      final r = await add('a');
      final putStarted = Completer<void>();
      final putRelease = Completer<void>();
      server
        ..json('POST /recordings', 201, _reg('srv-a'))
        ..on('PUT /v/srv-a.mp4', (_) async {
          putStarted.complete();
          await putRelease.future;
          return http.Response('', 200);
        })
        ..json('PUT /t/srv-a.jpg', 200)
        ..json('POST /recordings/:id/complete', 200, {'status': 'ready'})
        ..json('DELETE /recordings/:id', 204);
      final q = queue();
      final run = q.kick(LiveRecordingUploadTrigger.saved);
      await putStarted.future;
      expect(q.state.activeId, 'a');
      expect((await row('a'))!.uploadBadge, LiveRecordingUploadBadge.uploading);

      final deleting = q.delete(r);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // 누르자마자 목록에서 빠진다.
      expect(await local.list('u1'), isEmpty);
      putRelease.complete();
      await deleting;
      await run;
      expect(server.count('POST /recordings/:id/complete'), 0);
      expect(server.count('PUT /t/srv-a.jpg'), 0);
      expect(server.count('DELETE /recordings/:id'), 1);
      expect(await row('a'), isNull);
    });

    test('다른 계정 녹화는 지우지 않는다', () async {
      final r = await add('a', who: 'u2', recordingId: 'srv-a');
      await queue().delete(r);
      expect(server.calls, isEmpty);
      expect(await row('a'), isNotNull);
    });
  });

  test('오류 본문 코드 해석', () {
    expect(
        LiveRecordingUploadRepository.errorCodeOf(
            '{"detail":{"code":"upload_missing"}}'),
        'upload_missing');
    expect(
        LiveRecordingUploadRepository.errorCodeOf(
            '{"detail":"recording_quota_exceeded"}'),
        'recording_quota_exceeded');
    expect(LiveRecordingUploadRepository.errorCodeOf('{"detail":"Bad thing"}'),
        isNull);
    expect(LiveRecordingUploadRepository.errorCodeOf('<html>'), isNull);
  });

  test('등록 응답 파싱 — ready면 URL 없음', () {
    final r = RecordingRegistration.tryParse(_reg('x', status: 'ready'))!;
    expect(r.isReady, isTrue);
    expect(r.videoUploadUrl, isNull);
    expect(RecordingRegistration.tryParse({'status': 'pending'}), isNull);
  });
}
