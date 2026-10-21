import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/viva_modal.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/live_recording_repository.dart';
import '../domain/live_recording.dart';
import '../domain/player_entry.dart';
import '../domain/recording_item.dart';
import 'clip_memo_providers.dart';
import 'live_recording_upload_queue.dart';

/// 녹화 썸네일(폰 JPEG, 상대 경로) → 파일. 없으면 null.
final liveRecordingThumbFileProvider =
    FutureProvider.autoDispose.family<File?, String>((ref, rel) async {
  final file =
      File(await ref.watch(liveRecordingRepositoryProvider).resolve(rel));
  return await file.exists() ? file : null;
});

/// 녹화 삭제 확인창(보관함 카드·플레이어 공용).
Future<bool> confirmLiveRecordingDelete(BuildContext context) => showVivaModal(
      context,
      message: 'live_recording_delete_title'.tr(),
      cancelLabel: 'common_cancel'.tr(),
      confirmLabel: 'live_recording_delete_confirm'.tr(),
      confirmColor: AppTheme.danger,
    );

/// 녹화를 지운다 — 업로드 대기열에 맡기고(목록에서는 바로 빠지고 서버
/// DELETE는 대기열이 재시도) 그 녹화의 메모(`rec:<id>`)도 지운다.
///
/// 화면이 닫힌 뒤에도 메모 삭제가 끝나야 해서 위젯 ref가 아니라 앱 수명
/// provider의 ref로 돈다.
final liveRecordingDeleterProvider =
    Provider<Future<void> Function(LiveRecording rec)>((ref) => (rec) async {
          unawaited(
              ref.read(liveRecordingUploadQueueProvider.notifier).delete(rec));
          if (ref.read(clipMemoAccountProvider) != rec.ownerId) return;
          final key =
              (ownerId: rec.ownerId, clipId: RecordingEntry(rec.id).key);
          try {
            final memos = await ref.read(clipMemoRepositoryProvider.future);
            await memos.remove(key.ownerId, key.clipId);
          } catch (_) {
            // 메모가 남아도 녹화가 없으면 어디에도 보이지 않는다.
            return;
          }
          ref.invalidate(clipMemoProvider(key));
        });

/// 서버에만 있는 녹화를 지운다 — 대기열(`deleteServer`, 서버 DELETE)에 맡기고
/// 성공하면 그 녹화의 메모(`rec:srv:<id>`)도 지운다. false = 서버 삭제 실패.
final _serverRecordingDeleterProvider =
    Provider<Future<bool> Function(String serverId)>((ref) => (serverId) async {
          final ok = await ref
              .read(liveRecordingUploadQueueProvider.notifier)
              .deleteServer(serverId);
          if (!ok) return false;
          final owner = ref.read(clipMemoAccountProvider);
          if (owner == null) return true;
          final key =
              (ownerId: owner, clipId: ServerRecordingEntry(serverId).key);
          try {
            final memos = await ref.read(clipMemoRepositoryProvider.future);
            await memos.remove(key.ownerId, key.clipId);
            ref.invalidate(clipMemoProvider(key));
          } catch (_) {}
          return true;
        });

/// 녹화 한 건 삭제(이 폰·서버 공용). 이 폰 녹화는 대기열에 맡기고 바로
/// true(서버 DELETE는 대기열이 재시도), 서버에만 있는 녹화는 서버 결과를
/// 기다린다.
final recordingItemDeleterProvider =
    Provider<Future<bool> Function(RecordingItem item)>((ref) => (item) async {
          if (item.local case final local?) {
            unawaited(ref.read(liveRecordingDeleterProvider)(local));
            return true;
          }
          return ref.read(_serverRecordingDeleterProvider)(item.server!.id);
        });

/// 직접 녹화를 어디서 읽을지 — 폰 파일 또는 서버 녹화 id.
typedef RecordingSource = ({File? file, String? serverId});

/// 녹화 키(`rec:<id>`·`rec:srv:<id>`) → 재생·저장·공유할 곳.
///
/// 이 폰 녹화는 폰 파일이 우선이고, 파일이 없는데 업로드가 끝났으면 서버
/// URL로 받는다(그것도 안 되면 파일 경로를 그대로 돌려줘 호출부가 실패로
/// 안내한다). 서버에만 있는 녹화는 서버 id. 이 계정 녹화가 아니면 예외.
final recordingSourceResolverProvider =
    Provider<Future<RecordingSource> Function(String key)>((ref) => (key) async {
          switch (PlayerEntry.parse(key)) {
            case ServerRecordingEntry(:final serverId):
              return (file: null, serverId: serverId);
            case RecordingEntry(:final recordingId):
              final uid = ref.read(currentUserProvider)?.id;
              if (uid == null) throw StateError('signed out');
              final repo = ref.read(liveRecordingRepositoryProvider);
              final rec = (await repo.list(uid))
                  .where((r) => r.id == recordingId)
                  .firstOrNull;
              if (rec == null) throw StateError('recording not found');
              final file = File(await repo.resolve(rec.filePath));
              final serverId = RecordingItem.local(rec).serverId;
              if (serverId != null && !await file.exists()) {
                return (file: null, serverId: serverId);
              }
              return (file: file, serverId: null);
            case ClipEntry():
              throw ArgumentError.value(key, 'key', 'not a recording');
          }
        });

/// 저장·공유 임시 파일 이름 — 항목 키의 `:`를 뺀다(`rec:srv:<id>` → `rec_srv_<id>`).
String exportFileName(String key) => key.replaceAll(':', '_');

/// 녹화 한 건을 여는 경로 — 이 폰 녹화는 `/crecam/recordings/<로컬 id>`,
/// 서버에만 있는 녹화는 플레이어에 항목 키(`rec:srv:<id>`)를 그대로.
String recordingOpenPath(RecordingItem item) => switch (item.entry) {
      RecordingEntry(:final recordingId) => '/crecam/recordings/$recordingId',
      final entry => '/crecam/player/${Uri.encodeComponent(entry.key)}',
    };
