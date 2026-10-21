import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/connectivity_provider.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/live_recording_repository.dart';
import '../data/live_recording_thumb.dart';
import '../data/live_recording_upload_repository.dart';
import '../domain/live_recording.dart';

/// 대기열을 깨우는 계기.
enum LiveRecordingUploadTrigger {
  /// 로그인 상태로 대기열이 처음 만들어질 때(앱 시작·계정 전환).
  appStart,

  /// 녹화 저장 직후.
  saved,

  /// 보관함(북마크) 진입.
  bookmarks,

  /// 망 복귀.
  network,

  /// 카드 삭제 뒤.
  deleted,

  /// 백오프 시각 도달.
  timer;

  /// 계정 한도(quota)로 보류된 녹화를 다시 시도해 볼 계기 — 사용자가 지웠을
  /// 수 있는 때(앱 시작·녹화 직후·보관함 진입·카드 삭제 뒤).
  bool get reevaluatesQuota =>
      this == appStart || this == saved || this == bookmarks || this == deleted;

  /// 백오프 대기를 무시하고 바로 시도할 계기 — 망이 돌아왔거나 새로 켰다.
  bool get ignoresBackoff => this == appStart || this == network;
}

/// 일시 실패(5xx·망) 백오프 — 30초부터 2배, 최대 30분.
Duration liveRecordingUploadBackoff(int attempts) {
  const base = Duration(seconds: 30);
  const cap = Duration(minutes: 30);
  final shift = math.min(math.max(attempts - 1, 0), 10);
  final d = base * (1 << shift);
  return d > cap ? cap : d;
}

/// 한 녹화에서 URL 재발급(만료·upload_missing·새 id)을 다시 해 보는 횟수.
const int _kMaxRounds = 3;

class LiveRecordingUploadQueueState {
  const LiveRecordingUploadQueueState({this.revision = 0, this.activeId});

  /// 녹화 행이 바뀔 때마다 +1 — 보관함 목록이 다시 읽는다.
  final int revision;

  /// 지금 올리는 녹화 id(로컬).
  final String? activeId;
}

class _Cancelled implements Exception {
  const _Cancelled();
}

/// 진행 중 업로드 한 건 — 취소(삭제·계정 전환)하면 PUT을 끊는다.
class _Job {
  _Job(this.id);
  final String id;
  final _abort = Completer<void>();
  final done = Completer<void>();
  bool get cancelled => _abort.isCompleted;
  Future<void> get abortTrigger => _abort.future;
  void cancel() {
    if (!_abort.isCompleted) _abort.complete();
  }
}

enum _Outcome { next, stop }

/// 직접 녹화 R2 업로드 대기열 — 계정(owner) 하나분.
///
/// 오래된 녹화부터 **한 번에 하나씩** 올린다. 모든 망에서 올린다(2026-10-21
/// 사용자 결정 — 셀룰러 설정은 후속). 상태는 Hive 녹화 행에 남겨 앱을
/// 껐다 켜도 이어 간다(같은 `client_id`로 다시 등록하면 서버가 같은 행 +
/// 새 URL을 준다).
///
/// 오류 규칙(합의 결과 절):
/// - 등록 400 → failed(재시도 없음), 403·404 → failed.
/// - 401 → 저장소가 세션 갱신 후 1회 재시도, 그래도 401이면 일시 실패.
/// - 409 `recording_quota_exceeded` → blocked(quota), **그 자리에서 멈춤**.
///   [LiveRecordingUploadTrigger.reevaluatesQuota] 계기에 다시 시도.
/// - PUT 403(서명 만료)·4xx, complete 409 `upload_missing`·404 → 같은
///   `client_id`로 다시 등록해 새 URL로 처음부터.
/// - 등록 응답 `recording_id`가 바뀌면(23시간 30분) 교체 후 처음부터.
/// - 5xx·망 → [liveRecordingUploadBackoff].
///
/// 로그아웃·계정 전환이면 provider가 이 대기열을 버리고(dispose) 진행 중
/// 업로드를 끊는다 — 다른 계정 토큰으로 올리지 않는다.
class LiveRecordingUploadQueue
    extends StateNotifier<LiveRecordingUploadQueueState> {
  LiveRecordingUploadQueue({
    required this.ownerId,
    required LiveRecordingRepository local,
    required LiveRecordingUploadRepository Function() api,
    required String? Function() currentOwner,
    DateTime Function()? now,
    Future<Uint8List?> Function(Uint8List bytes)? toJpeg,
  })  : _local = local,
        _api = api,
        _currentOwner = currentOwner,
        _now = now ?? DateTime.now,
        _toJpeg = toJpeg ?? toJpegBytes,
        super(const LiveRecordingUploadQueueState());

  /// null = 로그아웃(아무것도 안 한다).
  final String? ownerId;
  final LiveRecordingRepository _local;
  final LiveRecordingUploadRepository Function() _api;
  final String? Function() _currentOwner;
  final DateTime Function() _now;
  final Future<Uint8List?> Function(Uint8List bytes) _toJpeg;

  Future<void>? _loop;
  bool _again = false;
  bool _wantQuota = false;
  bool _wantIgnoreBackoff = false;
  _Job? _job;
  Timer? _timer;
  DateTime? _timerAt;
  bool _disposed = false;

  /// 이 대기열이 아직 이 계정 것인지 — 아니면 HTTP를 더 보내지 않는다.
  bool get _alive =>
      !_disposed && ownerId != null && _currentOwner() == ownerId;

  /// 대기열을 깨운다. 돌고 있으면 끝난 뒤 한 번 더 돈다. 반환은 이번 순회가
  /// 끝날 때(테스트용 — 화면은 기다리지 않는다).
  Future<void> kick(LiveRecordingUploadTrigger trigger) {
    if (!kLiveRecordingEnabled || ownerId == null || _disposed) {
      return Future.value();
    }
    _wantQuota |= trigger.reevaluatesQuota;
    _wantIgnoreBackoff |= trigger.ignoresBackoff;
    _again = true;
    debugPrint('[rec-upload] kick ${trigger.name}');
    return _loop ??= _runLoop().whenComplete(() => _loop = null);
  }

  Future<void> _runLoop() async {
    await Future<void>.value(); // provider build 중 호출돼도 상태를 바로 바꾸지 않게
    while (_again && _alive) {
      _again = false;
      final quota = _wantQuota;
      final ignoreBackoff = _wantIgnoreBackoff;
      _wantQuota = false;
      _wantIgnoreBackoff = false;
      try {
        await _runOnce(retryQuota: quota, ignoreBackoff: ignoreBackoff);
      } catch (e) {
        debugPrint('[rec-upload] run failed: $e');
      }
    }
  }

  bool _due(LiveRecording r, bool ignoreBackoff) {
    final at = r.nextAttemptAt;
    return ignoreBackoff || at == null || !at.isAfter(_now());
  }

  Future<void> _runOnce(
      {required bool retryQuota, required bool ignoreBackoff}) async {
    final owner = ownerId!;
    // 오래된 것부터.
    final rows = (await _local.listAll(owner)).reversed.toList();

    // 1) 서버 삭제가 밀린 것부터 — 계정 한도를 비운다.
    for (final r in rows) {
      if (!_alive) return;
      if (r.uploadState != LiveRecordingUploadState.deleting) continue;
      if (!_due(r, ignoreBackoff)) {
        _scheduleTimer(r.nextAttemptAt!);
        continue;
      }
      await _remoteDelete(r);
    }

    // 2) 업로드. 계정 한도로 멈춘 게 있으면 그 계기가 아닌 한 손대지 않는다
    //    (뒤 녹화도 같은 409를 받는다).
    final quotaBlocked = rows.any((r) =>
        r.uploadState == LiveRecordingUploadState.blocked &&
        r.uploadError == LiveRecordingUploadError.quota);
    if (quotaBlocked && !retryQuota) {
      debugPrint('[rec-upload] quota blocked — 다음 재평가까지 대기');
      return;
    }
    for (final listed in rows) {
      if (!_alive) return;
      final r = await _local.get(listed.id);
      if (r == null || r.ownerId != owner) continue;
      final eligible = switch (r.uploadState) {
        LiveRecordingUploadState.pending ||
        LiveRecordingUploadState.uploading =>
          true,
        LiveRecordingUploadState.blocked =>
          r.uploadError == LiveRecordingUploadError.quota
              ? retryQuota
              : r.durationMs <= kServerRecordingMaxMs,
        _ => false,
      };
      if (!eligible) continue;
      if (!_due(r, ignoreBackoff)) {
        _scheduleTimer(r.nextAttemptAt!);
        // 오래된 것이 백오프 중이면 뒤 것도 기다린다(순서 유지·서버 보호).
        return;
      }
      if (await _upload(r) == _Outcome.stop) return;
    }
  }

  Future<_Outcome> _upload(LiveRecording rec) async {
    // 서버 길이 한도 — 등록하지 않고 "업로드 대기"로 둔다(400에 의존하지 않음).
    if (rec.durationMs > kServerRecordingMaxMs) {
      if (rec.uploadState != LiveRecordingUploadState.blocked) {
        await _patch(rec.id, 'blocked(length)',
            (r) => r.copyWith(
                uploadState: LiveRecordingUploadState.blocked,
                uploadError: LiveRecordingUploadError.lengthLimit));
      }
      return _Outcome.next;
    }
    final abs = await _local.resolve(rec.filePath);
    final file = File(abs);
    if (!await file.exists()) {
      await _fail(rec.id, LiveRecordingUploadError.fileMissing);
      return _Outcome.next;
    }
    final size = await file.length();
    if (size > kServerRecordingMaxBytes) {
      await _fail(rec.id, LiveRecordingUploadError.tooLarge);
      return _Outcome.next;
    }
    final thumb = await _thumbJpeg(rec);

    final job = _Job(rec.id);
    _job = job;
    _setActive(rec.id);
    var current = await _patch(rec.id, 'uploading',
        (r) => r.copyWith(uploadState: LiveRecordingUploadState.uploading));
    if (current == null) {
      _finishJob(job);
      return _Outcome.next;
    }
    try {
      final api = _api();
      for (var round = 0; round < _kMaxRounds; round++) {
        _check(job);
        final reg = await api.register(RecordingRegisterRequest(
          cameraId: current!.cameraId,
          clientId: current.id,
          startedAt: current.startedAt,
          durationMs: current.durationMs,
          sizeBytes: size,
          hasThumbnail: thumb != null,
          width: current.width,
          height: current.height,
        ));
        if (reg.recordingId != current.recordingId) {
          // 처음 등록이거나 23시간 30분이 지나 서버가 새로 만들었다 — 바꾸고
          // 처음부터. 취소됐더라도 id는 남긴다(삭제할 때 필요).
          debugPrint('[rec-upload] ${_short(rec.id)} recording_id '
              '${current.recordingId} → ${reg.recordingId}');
          current = await _local.update(
                  rec.id, (r) => r.copyWith(recordingId: reg.recordingId)) ??
              (throw const _Cancelled());
        }
        if (reg.isReady) {
          await _ready(rec.id);
          return _Outcome.next;
        }
        final videoUrl = reg.videoUploadUrl;
        if (videoUrl == null) {
          throw const RecordingApiException(502, 'missing_upload_url');
        }
        _check(job);
        try {
          await api.putFile(videoUrl, abs, 'video/mp4',
              label: 'video', abort: job.abortTrigger);
          _check(job);
          final thumbUrl = reg.thumbUploadUrl;
          if (thumb != null && thumbUrl != null) {
            await api.putBytes(thumbUrl, thumb, 'image/jpeg',
                label: 'thumb', abort: job.abortTrigger);
          }
        } on RecordingApiException catch (e) {
          // 서명 만료(403)·서명 불일치 등 4xx — 새 URL로 처음부터.
          if (e.statusCode >= 400 && e.statusCode < 500) {
            debugPrint('[rec-upload] ${_short(rec.id)} PUT ${e.statusCode} '
                '→ 다시 등록');
            continue;
          }
          rethrow;
        }
        _check(job);
        try {
          final status = await api.complete(reg.recordingId);
          if (status == 'ready') {
            await _ready(rec.id);
            return _Outcome.next;
          }
          debugPrint('[rec-upload] ${_short(rec.id)} complete status=$status');
        } on RecordingApiException catch (e) {
          if (e.isUploadMissing || e.statusCode == 404) {
            debugPrint('[rec-upload] ${_short(rec.id)} complete '
                '${e.statusCode} ${e.code} → 처음부터');
            continue;
          }
          rethrow;
        }
      }
      return _transient(rec.id, 'rounds_exhausted');
    } on _Cancelled {
      debugPrint('[rec-upload] ${_short(rec.id)} cancelled');
      await _patch(rec.id, 'pending(cancelled)',
          (r) => r.copyWith(uploadState: LiveRecordingUploadState.pending));
      return _Outcome.stop;
    } on RecordingApiException catch (e) {
      if (job.cancelled || !_alive) {
        await _patch(rec.id, 'pending(cancelled)',
            (r) => r.copyWith(uploadState: LiveRecordingUploadState.pending));
        return _Outcome.stop;
      }
      return _classify(rec.id, e);
    } catch (e) {
      // 망 끊김·타임아웃·PUT 중단.
      if (job.cancelled || !_alive) {
        await _patch(rec.id, 'pending(cancelled)',
            (r) => r.copyWith(uploadState: LiveRecordingUploadState.pending));
        return _Outcome.stop;
      }
      debugPrint('[rec-upload] ${_short(rec.id)} network ${e.runtimeType}');
      return _transient(rec.id, 'network');
    } finally {
      _finishJob(job);
    }
  }

  Future<_Outcome> _classify(String id, RecordingApiException e) async {
    if (e.isQuota) {
      await _patch(id, 'blocked(quota)',
          (r) => r.copyWith(
              uploadState: LiveRecordingUploadState.blocked,
              uploadError: LiveRecordingUploadError.quota,
              nextAttemptAt: null));
      return _Outcome.stop;
    }
    final code = e.statusCode;
    if (code == 400 || code == 403 || code == 404) {
      await _fail(id, 'http_$code');
      return _Outcome.next;
    }
    return _transient(id, 'http_$code');
  }

  Future<_Outcome> _transient(String id, String error) async {
    final row = await _patch(id, 'pending(backoff $error)', (r) {
      final attempts = r.uploadAttempts + 1;
      return r.copyWith(
        uploadState: LiveRecordingUploadState.pending,
        uploadError: error,
        uploadAttempts: attempts,
        nextAttemptAt: _now().add(liveRecordingUploadBackoff(attempts)),
      );
    });
    if (row?.nextAttemptAt != null) _scheduleTimer(row!.nextAttemptAt!);
    return _Outcome.stop;
  }

  Future<void> _fail(String id, String error) => _patch(
      id,
      'failed($error)',
      (r) => r.copyWith(
          uploadState: LiveRecordingUploadState.failed,
          uploadError: error,
          nextAttemptAt: null));

  Future<void> _ready(String id) => _patch(
      id,
      'ready',
      (r) => r.copyWith(
            uploadState: LiveRecordingUploadState.ready,
            uploadedAt: _now(),
            uploadError: null,
            uploadAttempts: 0,
            nextAttemptAt: null,
          ));

  /// 업로드 상태를 고친다. 사용자가 그새 지웠으면(행 없음·deleting) 손대지
  /// 않는다 — 삭제 흐름이 우선이다.
  Future<LiveRecording?> _patch(String id, String label,
      LiveRecording Function(LiveRecording r) change) async {
    final cur = await _local.get(id);
    if (cur == null || cur.uploadState == LiveRecordingUploadState.deleting) {
      return null;
    }
    final next = change(cur);
    await _local.save(next);
    debugPrint('[rec-upload] ${_short(id)} ${cur.uploadState.name} → $label');
    _bump();
    return next;
  }

  void _check(_Job job) {
    if (job.cancelled || !_alive) throw const _Cancelled();
  }

  Future<Uint8List?> _thumbJpeg(LiveRecording r) async {
    final rel = r.thumbPath;
    if (rel == null) return null;
    try {
      final bytes = await File(await _local.resolve(rel)).readAsBytes();
      return await _toJpeg(bytes);
    } catch (_) {
      return null;
    }
  }

  // ── 삭제 ─────────────────────────────────────────────────────────────────

  /// 보관함에서 지운다. 바로 목록에서 숨기고(deleting), 올리는 중이면 업로드를
  /// 끊은 뒤, 서버에 등록돼 있으면 DELETE하고 로컬 파일을 지운다. DELETE가
  /// 실패하면 deleting으로 남겨 다음 계기에 다시 지운다(404는 성공).
  /// 화면은 기다리지 않아도 된다.
  Future<void> delete(LiveRecording rec) async {
    if (ownerId == null || rec.ownerId != ownerId) return;
    final cur = await _local.get(rec.id);
    if (cur == null) return;
    await _local.save(cur.copyWith(
        uploadState: LiveRecordingUploadState.deleting,
        uploadAttempts: 0,
        nextAttemptAt: null));
    debugPrint('[rec-upload] ${_short(rec.id)} ${cur.uploadState.name} → '
        'deleting');
    _bump();
    final job = _job;
    if (job != null && job.id == rec.id) {
      job.cancel();
      await job.done.future;
    }
    // 업로드가 끊기기 전에 등록이 끝났을 수 있어 다시 읽는다.
    final marked = await _local.get(rec.id);
    if (marked == null) return;
    if (marked.recordingId == null) {
      await _local.delete(marked);
      debugPrint('[rec-upload] ${_short(rec.id)} 로컬만 삭제(미등록)');
      _bump();
    } else {
      await _remoteDelete(marked);
    }
    unawaited(kick(LiveRecordingUploadTrigger.deleted));
  }

  Future<void> _remoteDelete(LiveRecording r) async {
    final rid = r.recordingId;
    if (rid == null) {
      await _local.delete(r);
      _bump();
      return;
    }
    if (!_alive) return;
    try {
      await _api().delete(rid);
    } on RecordingApiException catch (e) {
      if (e.statusCode >= 500 || e.statusCode == 401 || e.statusCode == 429) {
        await _deleteLater(r, 'http_${e.statusCode}');
        return;
      }
      // 400·403 — 다시 해도 같다. 사용자는 지웠으니 폰에서는 지운다
      // (서버 남은 행은 사용자 계정 한도에 남을 수 있다 — 로그로 추적).
      debugPrint('[rec-upload] ${_short(r.id)} DELETE ${e.statusCode} → '
          '로컬만 삭제');
    } catch (e) {
      await _deleteLater(r, 'network');
      return;
    }
    await _local.delete(r);
    debugPrint('[rec-upload] ${_short(r.id)} deleting → 삭제 완료');
    _bump();
  }

  Future<void> _deleteLater(LiveRecording r, String error) async {
    final cur = await _local.get(r.id);
    if (cur == null) return;
    final attempts = cur.uploadAttempts + 1;
    final at = _now().add(liveRecordingUploadBackoff(attempts));
    await _local.save(cur.copyWith(
        uploadError: error, uploadAttempts: attempts, nextAttemptAt: at));
    debugPrint('[rec-upload] ${_short(r.id)} DELETE 실패($error) → 다시 시도 예정');
    _bump();
    _scheduleTimer(at);
  }

  // ── 내부 ─────────────────────────────────────────────────────────────────

  void _scheduleTimer(DateTime at) {
    if (_disposed) return;
    if (_timer != null && _timerAt != null && !at.isBefore(_timerAt!)) return;
    _timer?.cancel();
    _timerAt = at;
    var delay = at.difference(_now());
    if (delay.isNegative) delay = Duration.zero;
    _timer = Timer(delay, () {
      _timer = null;
      _timerAt = null;
      unawaited(kick(LiveRecordingUploadTrigger.timer));
    });
  }

  /// 테스트용 — 예약된 다음 시도 시각.
  @visibleForTesting
  DateTime? get scheduledAt => _timerAt;

  void _finishJob(_Job job) {
    if (identical(_job, job)) _job = null;
    if (!job.done.isCompleted) job.done.complete();
    _setActive(null);
  }

  void _setActive(String? id) {
    if (!mounted) return;
    state = LiveRecordingUploadQueueState(
        revision: state.revision + 1, activeId: id);
  }

  void _bump() {
    if (!mounted) return;
    state = LiveRecordingUploadQueueState(
        revision: state.revision + 1, activeId: state.activeId);
  }

  static String _short(String id) => id.length > 8 ? id.substring(0, 8) : id;

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    // 계정 전환·로그아웃 — 진행 중 업로드를 끊는다.
    _job?.cancel();
    super.dispose();
  }
}

/// 이 계정의 업로드 대기열. 계정이 바뀌면 새로 만들어지고(옛 것은 dispose로
/// 업로드를 끊는다) 로그인 상태면 바로 한 번 돈다(앱 시작 계기).
final liveRecordingUploadQueueProvider = StateNotifierProvider<
    LiveRecordingUploadQueue, LiveRecordingUploadQueueState>((ref) {
  final uid = ref.watch(currentUserProvider.select((u) => u?.id));
  final queue = LiveRecordingUploadQueue(
    ownerId: kLiveRecordingEnabled ? uid : null,
    local: ref.watch(liveRecordingRepositoryProvider),
    api: () => ref.read(liveRecordingUploadRepositoryProvider),
    currentOwner: () => ref.read(currentUserProvider)?.id,
  );
  if (uid != null && kLiveRecordingEnabled) {
    unawaited(queue.kick(LiveRecordingUploadTrigger.appStart));
    // 망 복귀.
    ref.listen<AsyncValue<bool>>(connectivityProvider, (prev, next) {
      if (prev?.valueOrNull == false && next.valueOrNull == true) {
        unawaited(queue.kick(LiveRecordingUploadTrigger.network));
      }
    });
  }
  return queue;
});

/// 녹화 저장 직후 대기열을 깨우는 함수 — 위젯 테스트가 비운다.
final liveRecordingSavedHookProvider = Provider<void Function()>((ref) => () {
      unawaited(ref
          .read(liveRecordingUploadQueueProvider.notifier)
          .kick(LiveRecordingUploadTrigger.saved));
    });

/// 보관함 진입 — 화면이 watch하면 한 번 깨운다(autoDispose라 들어올 때마다).
final liveRecordingBookmarksEntryProvider =
    Provider.autoDispose<void>((ref) {
  unawaited(ref
      .read(liveRecordingUploadQueueProvider.notifier)
      .kick(LiveRecordingUploadTrigger.bookmarks));
});
