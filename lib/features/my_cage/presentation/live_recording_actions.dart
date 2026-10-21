import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/viva_modal.dart';
import '../data/live_recording_repository.dart';
import '../domain/live_recording.dart';
import '../domain/player_entry.dart';
import 'clip_memo_providers.dart';
import 'live_recording_controller.dart';
import 'live_recording_upload_queue.dart';

/// 보관함 목록에서 녹화 한 건. 플레이어 상단 날짜·필름스트립 썸네일용 —
/// 목록은 업로드 상태가 바뀔 때마다 다시 읽히지만 재생 컨트롤러는 플레이어가
/// 따로 들고 있어 재생이 처음으로 돌아가지 않는다.
final liveRecordingByIdProvider = Provider.autoDispose
    .family<LiveRecording?, String>((ref, id) => ref
        .watch(liveRecordingsProvider)
        .valueOrNull
        ?.where((r) => r.id == id)
        .firstOrNull);

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
