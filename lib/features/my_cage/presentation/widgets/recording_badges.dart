import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/live_recording.dart';

/// 업로드 상태 표시 문구 키 — 올라간 녹화는 표시 없음(null).
String? recordingUploadLabelKey(LiveRecordingUploadBadge badge) =>
    switch (badge) {
      LiveRecordingUploadBadge.uploading => 'live_recording_upload_uploading',
      LiveRecordingUploadBadge.waiting => 'live_recording_upload_waiting',
      LiveRecordingUploadBadge.failed => 'live_recording_upload_failed',
      LiveRecordingUploadBadge.none => null,
    };

/// "직접 녹화 · 0:42" 배지 문구.
String recordingLengthLabel(Duration duration) {
  final secs = duration.inSeconds;
  return 'live_recording_badge'.tr(namedArgs: {
    'len': '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}'
  });
}

/// 녹화 썸네일 위 작은 글자 칩(길이 배지·업로드 상태 공용). 보관함 카드는
/// 기본 크기, 카메라 탭 3열 칸은 [compact](작은 칸에 맞춰 글자·여백을 줄이고
/// 넘치면 줄여 그린다).
class RecordingChip extends StatelessWidget {
  const RecordingChip(this.label, {super.key, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 1,
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: compact ? 10 : 12,
        height: compact ? 12 / 10 : null,
        fontWeight: FontWeight.w600,
        color: AppTheme.liveOnDark,
      ),
    );
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.liveScrim,
        borderRadius: BorderRadius.circular(compact ? 4 : 8),
      ),
      child: compact ? FittedBox(fit: BoxFit.scaleDown, child: text) : text,
    );
  }
}

/// 올리는 중인 녹화 칸·카드의 흐림 정도(누를 수 없음과 함께).
const double kRecordingUploadingOpacity = 0.4;
