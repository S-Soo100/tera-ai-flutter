// 영상 선택 모드의 직접 녹화(2026-10-21 사용자 결정) — 다운로드·공유는 폰
// 파일이 있으면 그것, 없으면 서버 URL로 받아서, 삭제는 녹화 삭제(대기열 경유).
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vivanaut/core/network/auth_session.dart';
import 'package:vivanaut/features/my_cage/data/clip_visibility_repository.dart';
import 'package:vivanaut/features/my_cage/data/live_recording_server_repository.dart';
import 'package:vivanaut/features/my_cage/data/video_export_service.dart';
import 'package:vivanaut/features/my_cage/domain/live_recording.dart';
import 'package:vivanaut/features/my_cage/domain/recording_item.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_selection_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_visibility_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/live_recording_actions.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/recording_library_providers.dart';

class _Export extends Fake implements VideoExportService {
  final saved = <String>[];
  final downloaded = <String>[];
  List<File>? shared;

  @override
  Future<void> clearTemp() async {}
  @override
  Future<bool> ensureGalleryAccess() async => true;
  @override
  Future<File> downloadToTemp(String clipId, String url,
      {void Function(double fraction)? onProgress,
      ExportCancelToken? cancel}) async {
    downloaded.add('$clipId<-$url');
    final file = File('${Directory.systemTemp.path}/rec_sel_$clipId.mp4');
    await file.writeAsString(url);
    return file;
  }

  @override
  Future<void> putVideo(File file) async => saved.add(file.path);
  @override
  Future<void> shareFiles(List<File> files) async => shared = files;
}

class _Session implements AuthSession {
  @override
  Future<String?> accessToken() async => null;
  @override
  Future<bool> recoverFromUnauthorized() async => false;
}

class _ServerRepo extends LiveRecordingServerRepository {
  _ServerRepo()
      : super(
            loadRows: ({before, required limit}) async => const [],
            baseUrl: 'https://api.test',
            session: _Session(),
            client: MockClient((_) async => http.Response('', 599)));
  @override
  Future<String> playbackUrl(String id) async => 'https://r2.test/$id.mp4';
}

class _Visibility implements ClipVisibilityRepository {
  final hidden = <String>{};
  @override
  Future<Set<String>> hiddenClipIds(String owner) async => {...hidden};
  @override
  Future<void> hide(String owner, String clip) async => hidden.add(clip);
}

void main() {
  late _Export export;
  late _Visibility visibility;
  late ProviderContainer container;
  late File localFile;
  final deleted = <String>[];
  const scope = ClipSelectionScope.feed;

  final local = LiveRecording(
      id: 'a',
      ownerId: 'u1',
      cameraId: 'cam',
      startedAt: DateTime.utc(2026, 10, 21, 10),
      durationMs: 30000,
      filePath: 'a.mp4');
  final server = ServerLiveRecording(
      id: 's',
      cameraId: 'cam',
      startedAt: DateTime.utc(2026, 10, 21, 9),
      durationMs: 30000,
      hasThumbnail: false);

  setUp(() async {
    export = _Export();
    visibility = _Visibility();
    deleted.clear();
    localFile = File('${Directory.systemTemp.path}/rec_sel_local_a.mp4');
    await localFile.writeAsString('local');
    container = ProviderContainer(overrides: [
      videoExportServiceProvider.overrideWithValue(export),
      liveRecordingServerRepositoryProvider.overrideWithValue(_ServerRepo()),
      clipVisibilityRepositoryProvider.overrideWithValue(visibility),
      clipVisibilityAccountProvider.overrideWithValue('u1'),
      recordingSourceResolverProvider
          .overrideWithValue((key) async => switch (key) {
                'rec:a' => (file: localFile, serverId: null),
                'rec:srv:s' => (file: null, serverId: 's'),
                _ => throw StateError('none'),
              }),
      recordingLibraryProvider.overrideWith((ref) => AsyncData([
            RecordingItem.local(local),
            RecordingItem.server(server),
          ])),
      recordingItemDeleterProvider.overrideWithValue((item) async {
        deleted.add(item.key);
        return item.server == null;
      }),
    ]);
    container.listen(clipBatchProvider(scope), (_, __) {});
    container.listen(recordingLibraryProvider, (_, __) {});
  });
  tearDown(() => container.dispose());

  ClipBatchController batch() =>
      container.read(clipBatchProvider(scope).notifier);

  test('다운로드 — 폰 녹화는 폰 파일 그대로, 서버 녹화는 서버 URL로 받아서', () async {
    final result = await batch().save(['rec:a', 'rec:srv:s']);
    expect(result.succeeded, 2);
    expect(export.saved.first, localFile.path);
    // 임시 파일 이름에 ':'를 쓰지 않는다.
    expect(export.downloaded, ['rec_srv_s<-https://r2.test/s.mp4']);
  });

  test('공유 — 두 파일을 한 번에', () async {
    final result = await batch().share(['rec:a', 'rec:srv:s']);
    expect(result.succeeded, 2);
    expect(export.shared!.first.path, localFile.path);
  });

  test('삭제 — 일반 영상은 숨김, 녹화는 녹화 삭제 경유(서버 실패는 실패로)', () async {
    final result = await batch().delete(['c1', 'rec:a', 'rec:srv:s', 'rec:x']);
    expect(visibility.hidden, {'c1'});
    expect(deleted, ['rec:a', 'rec:srv:s']);
    expect(result.succeeded, 2);
    // 서버 삭제 실패·목록에 없는 녹화는 골라진 채 남는다.
    expect(result.failed, ['rec:srv:s', 'rec:x']);
  });

  test('exportFileName', () {
    expect(exportFileName('rec:srv:abc'), 'rec_srv_abc');
    expect(exportFileName('clip-1'), 'clip-1');
  });
}
