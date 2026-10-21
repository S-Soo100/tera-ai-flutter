import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:hive/hive.dart';
import 'package:vivanaut/features/my_cage/data/live_recording_repository.dart';
import 'package:vivanaut/features/my_cage/data/mp4_info.dart';
import 'package:vivanaut/features/my_cage/domain/live_limit.dart';
import 'package:vivanaut/features/my_cage/domain/live_recording.dart';
import 'package:vivanaut/features/my_cage/presentation/live_recording_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/webrtc_live_controller.dart';

class _FakeTrack implements MediaStreamTrack {
  @override
  Future<ByteBuffer> captureFrame() async => Uint8List.fromList([1, 2]).buffer;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeRecorder implements LiveVideoRecorder {
  String? path;
  bool stopped = false;
  bool failStart = false;

  @override
  Future<void> start(String path, MediaStreamTrack track) async {
    if (failStart) throw Exception('no');
    this.path = path;
    await File(path).writeAsBytes([0]);
  }

  @override
  Future<void> stop() async => stopped = true;
}

const _streaming = WebRtcLiveState(phase: WebRtcLivePhase.streaming);
const _failed = WebRtcLiveState(phase: WebRtcLivePhase.failed);

/// 끊김·이탈 저장은 화면 흐름을 막지 않게 뒤에서 돈다(`unawaited(stop)`). 고정
/// 시간만 기다리면 전체 테스트를 병렬로 돌릴 때 저장이 끝나기 전에 검사해 결과가
/// null로 보이고, tearDown이 쓰는 중인 폴더를 지우다 실패했다(2026-10-21).
/// 그래서 조건이 맞을 때까지(최대 5초) 기다린다.
Future<void> _until(FutureOr<bool> Function() done) async {
  final sw = Stopwatch()..start();
  while (!await done()) {
    if (sw.elapsed > const Duration(seconds: 5)) {
      fail('5초 안에 저장이 끝나지 않았다');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  group('canStartLiveRecording', () {
    final now = DateTime(2026, 10, 1, 12);
    test('영상이 나와야 한다', () {
      expect(
          canStartLiveRecording(streaming: false, liveUntil: null, now: now),
          isFalse);
      expect(canStartLiveRecording(streaming: true, liveUntil: null, now: now),
          isTrue);
    });
    test('시청 제한까지 3초 이하면 막고, 2분이 안 남아도 시작은 한다', () {
      expect(
          canStartLiveRecording(
              streaming: true,
              liveUntil: now.add(const Duration(seconds: 3)),
              now: now),
          isFalse);
      expect(
          canStartLiveRecording(
              streaming: true,
              liveUntil: now.add(const Duration(seconds: 4)),
              now: now),
          isTrue);
    });
    test('3초 미만은 버린다', () {
      expect(shouldKeepLiveRecording(const Duration(milliseconds: 2999)),
          isFalse);
      expect(shouldKeepLiveRecording(const Duration(seconds: 3)), isTrue);
    });
  });

  test('JSON 왕복', () {
    final r = LiveRecording(
      id: 'a',
      ownerId: 'u',
      cameraId: 'c',
      startedAt: DateTime.utc(2026, 10, 1),
      durationMs: 60000,
      filePath: 'live_recordings/u/a.mp4',
      thumbPath: 'live_recordings/u/a.png',
    );
    final back = LiveRecording.tryFromJson(r.toJson())!;
    expect(back.id, 'a');
    expect(back.duration, const Duration(minutes: 1));
    expect(back.thumbPath, r.thumbPath);
    expect(LiveRecording.tryFromJson({'id': 1}), isNull);
  });

  group('LiveRecordingController', () {
    late Directory dir;
    late LiveRecordingRepository repo;
    late _FakeRecorder recorder;
    String? owner;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('live_rec');
      Hive.init(dir.path);
      repo = LiveRecordingRepository(baseDir: () async => dir);
      recorder = _FakeRecorder();
      owner = 'u1';
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    LiveRecordingController make() => LiveRecordingController(
          cameraId: 'cam',
          repository: repo,
          recorderFactory: () => recorder,
          ownerId: () => owner,
          trackOf: (live) => live.phase.hasVideo ? _FakeTrack() : null,
        );

    test('영상이 안 나오면 시작하지 않는다', () async {
      final c = make();
      await c.start(_failed);
      expect(c.state.phase, LiveRecordingPhase.idle);
      expect(recorder.path, isNull);
      c.dispose();
    });

    test('정지 → 저장, 목록에 보인다', () async {
      final c = make();
      await c.start(_streaming);
      expect(c.state.phase, LiveRecordingPhase.recording);
      await Future<void>.delayed(const Duration(milliseconds: 3100));
      await c.stop(LiveRecordingEnd.userStopped);
      expect(recorder.stopped, isTrue);
      expect(c.state.result, LiveRecordingResult.saved);
      final list = await repo.list('u1');
      expect(list, hasLength(1));
      expect(list.single.cameraId, 'cam');
      expect(list.single.thumbPath, isNotNull);
      expect(await repo.list('other'), isEmpty);
      c.dispose();
    });

    test('저장 길이는 파일 실제 길이·크기, 저장 직후 대기열을 깨운다', () async {
      var kicked = 0;
      final c = LiveRecordingController(
        cameraId: 'cam',
        repository: repo,
        recorderFactory: () => recorder,
        ownerId: () => owner,
        trackOf: (live) => live.phase.hasVideo ? _FakeTrack() : null,
        probe: (_) async =>
            const Mp4Info(durationMs: 2400, width: 1280, height: 960),
        onSaved: () => kicked++,
      );
      await c.start(_streaming);
      await Future<void>.delayed(const Duration(milliseconds: 3100));
      await c.stop(LiveRecordingEnd.userStopped);
      final r = (await repo.list('u1')).single;
      expect(r.durationMs, 2400);
      expect(r.width, 1280);
      expect(r.uploadState, LiveRecordingUploadState.pending);
      expect(kicked, 1);
      c.dispose();
    });

    test('끊기면 거기까지 저장(부분 저장 안내)', () async {
      final c = make();
      await c.start(_streaming);
      await Future<void>.delayed(const Duration(milliseconds: 3100));
      c.onLiveState(_failed);
      await _until(() => c.state.result != null);
      expect(c.state.result, LiveRecordingResult.savedPartial);
      expect(c.state.resultSeconds, 3);
      expect(await repo.list('u1'), hasLength(1));
      c.dispose();
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('시청 제한 시각 도달(cooldown) → 저장 완료로 안내', () async {
      final c = make();
      await c.start(_streaming);
      await Future<void>.delayed(const Duration(milliseconds: 3100));
      expect(c.recordedSoFar, greaterThanOrEqualTo(const Duration(seconds: 3)));
      c.onLiveState(const WebRtcLiveState(
          phase: WebRtcLivePhase.limited,
          limit: LiveLimit(LiveLimitKind.cooldown)));
      await _until(() => c.state.result != null);
      expect(c.state.result, LiveRecordingResult.saved);
      expect(await repo.list('u1'), hasLength(1));
      expect(c.recordedSoFar, Duration.zero);
      c.dispose();
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('다른 기기가 가져가면(takenOver) 끊김으로 부분 저장', () async {
      final c = make();
      await c.start(_streaming);
      await Future<void>.delayed(const Duration(milliseconds: 3100));
      c.onLiveState(const WebRtcLiveState(
          phase: WebRtcLivePhase.limited,
          limit: LiveLimit(LiveLimitKind.takenOver)));
      await _until(() => c.state.result != null);
      expect(c.state.result, LiveRecordingResult.savedPartial);
      c.dispose();
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('이미 끝난 녹화에 또 stop → 무시(멱등)', () async {
      final c = make();
      await c.start(_streaming);
      await Future<void>.delayed(const Duration(milliseconds: 3100));
      await c.stop(LiveRecordingEnd.userStopped);
      final seq = c.state.resultSeq;
      await c.stop(LiveRecordingEnd.userStopped);
      expect(c.state.resultSeq, seq);
      expect(await repo.list('u1'), hasLength(1));
      c.dispose();
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('3초 미만은 버리고 파일도 지운다', () async {
      final c = make();
      await c.start(_streaming);
      final path = recorder.path!;
      await c.stop(LiveRecordingEnd.userStopped);
      expect(c.state.result, LiveRecordingResult.tooShort);
      expect(await repo.list('u1'), isEmpty);
      expect(File(path).existsSync(), isFalse);
      c.dispose();
    });

    test('녹화기 시작 실패 → 실패 안내', () async {
      recorder.failStart = true;
      final c = make();
      await c.start(_streaming);
      expect(c.state.phase, LiveRecordingPhase.idle);
      expect(c.state.result, LiveRecordingResult.failed);
      c.dispose();
    });

    test('로그아웃 상태면 시작하지 않는다', () async {
      owner = null;
      final c = make();
      await c.start(_streaming);
      expect(c.state.phase, LiveRecordingPhase.idle);
      c.dispose();
    });

    test('화면을 떠나면(dispose) 찍던 걸 저장한다', () async {
      final c = make();
      await c.start(_streaming);
      await Future<void>.delayed(const Duration(milliseconds: 3100));
      c.dispose();
      await _until(() async => (await repo.list('u1')).isNotEmpty);
      expect(recorder.stopped, isTrue);
      expect(await repo.list('u1'), hasLength(1));
    });
  });
}
