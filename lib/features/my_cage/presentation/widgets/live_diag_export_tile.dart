import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../webrtc_diag_providers.dart';

/// 환경설정 — 라이브 연결 진단(메모리 버퍼)을 텍스트 파일로 공유한다.
/// 지원용 명시 동작이며 자동 발송은 없다(2026-09-23 기획 §6). 파일은 앱 임시
/// 폴더에만 쓰고 갤러리에는 저장하지 않는다.
class LiveDiagExportTile extends ConsumerWidget {
  const LiveDiagExportTile({super.key});

  static const tileKey = Key('live_diag_export_tile');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      key: tileKey,
      leading: const Icon(Icons.bug_report_outlined),
      title: Text('live_diag_export_title'.tr()),
      subtitle: Text('live_diag_export_subtitle'.tr()),
      onTap: () => _export(context, ref),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final buffer = ref.read(webrtcDiagBufferProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (buffer.events.isEmpty) {
      messenger.showSnackBar(
          SnackBar(content: Text('live_diag_export_empty'.tr())));
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
}
