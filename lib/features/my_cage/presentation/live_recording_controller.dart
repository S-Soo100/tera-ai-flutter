import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/live_recording_repository.dart';
import '../domain/live_recording.dart';
import 'webrtc_live_controller.dart';

/// 원격 영상 트랙을 파일로 남기는 녹화기 — 테스트에서 교체한다.
abstract class LiveVideoRecorder {
  Future<void> start(String path, MediaStreamTrack track);
  Future<void> stop();
}

class _WebRtcVideoRecorder implements LiveVideoRecorder {
  final _recorder = MediaRecorder();

  @override
  Future<void> start(String path, MediaStreamTrack track) =>
      _recorder.start(path, videoTrack: track);

  @override
  Future<void> stop() async => _recorder.stop();
}

final liveVideoRecorderFactoryProvider =
    Provider<LiveVideoRecorder Function()>((ref) => _WebRtcVideoRecorder.new);

/// 결과 안내 표시 시간.
const kLiveRecordingResultShown = Duration(seconds: 4);

enum LiveRecordingPhase { idle, starting, recording, saving }

/// 끝난 녹화의 결과 — 화면이 한 번 안내한다([LiveRecordingState.resultSeq]).
enum LiveRecordingResult { saved, savedPartial, tooShort, failed }

class LiveRecordingState {
  const LiveRecordingState({
    this.phase = LiveRecordingPhase.idle,
    this.elapsed = Duration.zero,
    this.result,
    this.resultSeconds = 0,
    this.resultSeq = 0,
  });

  final LiveRecordingPhase phase;
  final Duration elapsed;
  final LiveRecordingResult? result;
  final int resultSeconds;

  /// 결과가 날 때마다 +1(테스트·진단용).
  final int resultSeq;

  bool get busy => phase != LiveRecordingPhase.idle;

  Duration get remaining {
    final r = kLiveRecordingLength - elapsed;
    return r.isNegative ? Duration.zero : r;
  }
}

/// 라이브 직접 녹화 한 카메라분. 가로 전체화면이 쓰고, 화면을 떠나면
/// (autoDispose) 그때까지 찍은 걸 저장한다.
///
/// 시청([WebRtcLiveController])과 분리돼 있다 — 시청 상태를 구독만 하고,
/// 영상이 끊기거나(`hasVideo` 아님) renderer가 바뀌면(재연결 = 새 세대)
/// 그 녹화는 거기서 끝낸다. 이어 붙이지 않는다(기획 §2-5).
class LiveRecordingController extends StateNotifier<LiveRecordingState> {
  LiveRecordingController({
    required this.cameraId,
    required LiveRecordingRepository repository,
    required LiveVideoRecorder Function() recorderFactory,
    required String? Function() ownerId,
    DateTime Function()? now,
    MediaStreamTrack? Function(WebRtcLiveState live)? trackOf,
  })  : _repo = repository,
        _trackOf = trackOf ?? _rendererVideoTrack,
        _recorderFactory = recorderFactory,
        _ownerId = ownerId,
        _now = now ?? DateTime.now,
        super(const LiveRecordingState());

  final String cameraId;
  final LiveRecordingRepository _repo;
  final LiveVideoRecorder Function() _recorderFactory;
  final String? Function() _ownerId;
  final DateTime Function() _now;
  final MediaStreamTrack? Function(WebRtcLiveState live) _trackOf;

  static MediaStreamTrack? _rendererVideoTrack(WebRtcLiveState live) =>
      live.renderer?.srcObject?.getVideoTracks().firstOrNull;

  LiveVideoRecorder? _recorder;
  RTCVideoRenderer? _renderer;
  Timer? _ticker;
  Timer? _resultHide;
  final _watch = Stopwatch();
  ({String rel, String abs})? _file;
  String? _thumbRel;
  String? _owner;
  String? _id;
  DateTime? _startedAt;

  /// 시청 상태가 바뀔 때 — provider가 넘겨준다.
  void onLiveState(WebRtcLiveState live) {
    if (state.phase != LiveRecordingPhase.recording &&
        state.phase != LiveRecordingPhase.starting) {
      return;
    }
    if (!live.phase.hasVideo ||
        (live.renderer != null && !identical(live.renderer, _renderer))) {
      unawaited(stop(LiveRecordingEnd.interrupted));
    }
  }

  Future<void> start(WebRtcLiveState live) async {
    if (state.busy) return;
    final owner = _ownerId();
    final track = _trackOf(live);
    if (owner == null ||
        track == null ||
        !canStartLiveRecording(
            streaming: live.phase == WebRtcLivePhase.streaming,
            liveUntil: live.liveUntil,
            now: _now())) {
      return;
    }
    _resultHide?.cancel();
    state = LiveRecordingState(
        phase: LiveRecordingPhase.starting, resultSeq: state.resultSeq);
    _renderer = live.renderer;
    _owner = owner;
    _id = const Uuid().v4();
    _startedAt = _now();
    try {
      _file = await _repo.newPath(owner, _id!, 'mp4');
      // 첫 장면을 보관함 썸네일로 — 실패해도 녹화는 한다.
      _thumbRel = await _captureThumb(track, owner, _id!);
      if (!mounted || state.phase != LiveRecordingPhase.starting) return;
      final file = _file!;
      final recorder = _recorderFactory();
      _recorder = recorder;
      await recorder.start(file.abs, track);
      if (!mounted || state.phase != LiveRecordingPhase.starting) {
        // 시작하는 사이 끊기거나 화면을 떠났다 — 붙은 녹화기를 떼고 버린다.
        try {
          await recorder.stop();
        } catch (_) {}
        await _repo.discardFile(file.abs);
        return;
      }
    } catch (_) {
      if (mounted) await _cleanupFailed();
      return;
    }
    _watch
      ..reset()
      ..start();
    state = LiveRecordingState(
        phase: LiveRecordingPhase.recording, resultSeq: state.resultSeq);
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      if (_watch.elapsed >= kLiveRecordingLength) {
        unawaited(stop(LiveRecordingEnd.completed));
      } else {
        state = LiveRecordingState(
          phase: LiveRecordingPhase.recording,
          elapsed: _watch.elapsed,
          resultSeq: state.resultSeq,
        );
      }
    });
  }

  Future<String?> _captureThumb(
      MediaStreamTrack track, String owner, String id) async {
    try {
      final bytes = await track.captureFrame();
      final p = await _repo.newPath(owner, id, 'png');
      await File(p.abs).writeAsBytes(bytes.asUint8List());
      return p.rel;
    } catch (_) {
      return null;
    }
  }

  /// 녹화를 끝내고 남길지 정한다. 이미 끝났으면 무시.
  Future<void> stop(LiveRecordingEnd end) async {
    if (state.phase == LiveRecordingPhase.starting) {
      // 녹화기가 아직 안 붙었다 — 시작을 취소한다.
      _setPhase(LiveRecordingPhase.saving);
      await _cleanupFailed(silent: true);
      return;
    }
    if (state.phase != LiveRecordingPhase.recording) return;
    _ticker?.cancel();
    _watch.stop();
    final recorded = _watch.elapsed > kLiveRecordingLength
        ? kLiveRecordingLength
        : _watch.elapsed;
    _setPhase(LiveRecordingPhase.saving);
    final recorder = _recorder;
    final file = _file;
    final owner = _owner;
    final id = _id;
    final startedAt = _startedAt;
    final thumb = _thumbRel;
    _reset();

    var ok = recorder != null && file != null;
    if (ok) {
      try {
        await recorder.stop();
      } catch (_) {
        ok = false;
      }
    }
    final LiveRecordingResult result;
    if (!ok) {
      result = LiveRecordingResult.failed;
    } else if (!shouldKeepLiveRecording(recorded)) {
      result = LiveRecordingResult.tooShort;
    } else {
      await _repo.save(LiveRecording(
        id: id!,
        ownerId: owner!,
        cameraId: cameraId,
        startedAt: startedAt!,
        durationMs: recorded.inMilliseconds,
        filePath: file!.rel,
        thumbPath: thumb,
      ));
      result = end == LiveRecordingEnd.completed ||
              end == LiveRecordingEnd.userStopped
          ? LiveRecordingResult.saved
          : LiveRecordingResult.savedPartial;
    }
    if (result != LiveRecordingResult.saved &&
        result != LiveRecordingResult.savedPartial) {
      if (file != null) await _repo.discardFile(file.abs);
      if (thumb != null) await _repo.discardFile(await _repo.resolve(thumb));
    }
    if (!mounted) return;
    _announce(result, recorded.inSeconds);
  }

  /// 결과 안내를 [kLiveRecordingResultShown] 동안 띄웠다 지운다.
  void _announce(LiveRecordingResult? result, int seconds) {
    _resultHide?.cancel();
    state = LiveRecordingState(
      result: result,
      resultSeconds: seconds,
      resultSeq: state.resultSeq + 1,
    );
    if (result == null) return;
    _resultHide = Timer(kLiveRecordingResultShown, () {
      if (mounted && state.phase == LiveRecordingPhase.idle) {
        state = LiveRecordingState(resultSeq: state.resultSeq);
      }
    });
  }

  Future<void> _cleanupFailed({bool silent = false}) async {
    final file = _file;
    final thumb = _thumbRel;
    final recorder = _recorder;
    _reset();
    if (recorder != null) {
      try {
        await recorder.stop();
      } catch (_) {}
    }
    if (file != null) await _repo.discardFile(file.abs);
    if (thumb != null) await _repo.discardFile(await _repo.resolve(thumb));
    if (!mounted) return;
    _announce(silent ? null : LiveRecordingResult.failed, 0);
  }

  void _setPhase(LiveRecordingPhase p) {
    if (!mounted) return;
    state = LiveRecordingState(
        phase: p, elapsed: state.elapsed, resultSeq: state.resultSeq);
  }

  void _reset() {
    _ticker?.cancel();
    _ticker = null;
    _recorder = null;
    _renderer = null;
    _file = null;
    _thumbRel = null;
    _owner = null;
    _id = null;
    _startedAt = null;
  }

  @override
  void dispose() {
    // 화면 이탈 — 찍던 게 있으면 마저 저장한다(StateNotifier가 닫혀도
    // 저장소 쓰기는 끝까지 간다).
    if (state.phase == LiveRecordingPhase.recording) {
      unawaited(stop(LiveRecordingEnd.left));
    } else if (state.phase == LiveRecordingPhase.starting) {
      unawaited(_cleanupFailed(silent: true));
    }
    _ticker?.cancel();
    _resultHide?.cancel();
    super.dispose();
  }
}

final liveRecordingControllerProvider = StateNotifierProvider.autoDispose
    .family<LiveRecordingController, LiveRecordingState, String>(
        (ref, cameraId) {
  final controller = LiveRecordingController(
    cameraId: cameraId,
    repository: ref.watch(liveRecordingRepositoryProvider),
    recorderFactory: ref.watch(liveVideoRecorderFactoryProvider),
    ownerId: () => ref.read(currentUserProvider)?.id,
  );
  ref.listen<WebRtcLiveState>(webrtcLiveControllerProvider(cameraId),
      (_, next) => controller.onLiveState(next));
  return controller;
});

/// 이 계정의 직접 녹화 목록(최신순). autoDispose — 보관함에 들어올 때마다
/// 다시 읽어 방금 찍은 녹화가 바로 보인다.
final liveRecordingsProvider =
    FutureProvider.autoDispose<List<LiveRecording>>((ref) async {
  final uid = ref.watch(currentUserProvider.select((u) => u?.id));
  if (uid == null || !kLiveRecordingEnabled) return const [];
  return ref.watch(liveRecordingRepositoryProvider).list(uid);
});
