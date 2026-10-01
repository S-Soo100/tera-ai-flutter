import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/safe_hive.dart';
import '../domain/live_recording.dart';

/// 라이브 직접 녹화 보관(기기 안). 메타는 Hive `live_recordings` 박스에
/// JSON 문자열로(어댑터 없이 — 실험 기능이라 되돌릴 때 typeId를 남기지 않는다),
/// mp4·썸네일은 문서 디렉토리 `live_recordings/<계정>/`에 둔다.
/// 계정 격리는 [LiveRecording.ownerId] 필터.
class LiveRecordingRepository {
  LiveRecordingRepository({Future<Directory> Function()? baseDir})
      : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  static const _boxName = 'live_recordings';
  final Future<Directory> Function() _baseDir;

  Future<Box<String>> _box() => openBoxSafely<String>(_boxName);

  /// 새 녹화 파일을 쓸 상대 경로(디렉토리는 만들어 둔다).
  Future<({String rel, String abs})> newPath(
      String ownerId, String id, String ext) async {
    final rel = 'live_recordings/${Uri.encodeComponent(ownerId)}/$id.$ext';
    final abs = await resolve(rel);
    await File(abs).parent.create(recursive: true);
    return (rel: rel, abs: abs);
  }

  Future<String> resolve(String rel) async => '${(await _baseDir()).path}/$rel';

  Future<List<LiveRecording>> list(String ownerId) async {
    final box = await _box();
    final out = <LiveRecording>[];
    for (final raw in box.values) {
      try {
        final r = LiveRecording.tryFromJson(
            jsonDecode(raw) as Map<String, dynamic>);
        if (r != null && r.ownerId == ownerId) out.add(r);
      } catch (_) {}
    }
    out.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return out;
  }

  Future<void> save(LiveRecording r) async =>
      (await _box()).put(r.id, jsonEncode(r.toJson()));

  Future<void> delete(LiveRecording r) async {
    await (await _box()).delete(r.id);
    for (final rel in [r.filePath, r.thumbPath]) {
      if (rel == null) continue;
      try {
        await File(await resolve(rel)).delete();
      } catch (_) {}
    }
  }

  /// 저장 실패·짧은 녹화로 버리는 파일 정리.
  Future<void> discardFile(String abs) async {
    try {
      await File(abs).delete();
    } catch (_) {}
  }
}

final liveRecordingRepositoryProvider =
    Provider<LiveRecordingRepository>((ref) => LiveRecordingRepository());
