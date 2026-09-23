import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'webrtc_diag_providers.dart';

/// 라이브 연결 진단(메모리 버퍼)을 텍스트 파일로 공유한다. 진입점은 마이페이지
/// "라이브 연결 진단 내보내기" 행. 지원용 명시 동작이며 자동 발송은 없다
/// (2026-09-23 기획 §6). 파일은 앱 임시 폴더에만 쓰고 갤러리에는 저장하지 않는다.
Future<void> shareLiveDiag(BuildContext context, WidgetRef ref) async {
  final buffer = ref.read(webrtcDiagBufferProvider);
  final messenger = ScaffoldMessenger.of(context);
  if (buffer.events.isEmpty) {
    messenger
        .showSnackBar(SnackBar(content: Text('live_diag_export_empty'.tr())));
    return;
  }
  // 헤더에는 앱·OS 버전만 — 계정 정보는 넣지 않는다.
  final info = await PackageInfo.fromPlatform();
  final header = 'vivanaut ${info.version}+${info.buildNumber} '
      '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  final dir = await getTemporaryDirectory();
  final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
  final file = File('${dir.path}/live-diag-$stamp.txt');
  await file.writeAsString(buffer.export(header: header));
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], subject: 'vivanaut live diag'),
  );
}
