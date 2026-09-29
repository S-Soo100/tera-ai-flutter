import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// 라이브 시청자 = 이 앱 설치(2026-09-30, 서버 라이브 시청 제한).
///
/// [id]는 설치마다 고정 — 서버가 "같은 기기의 재연결"과 "다른 기기"를 가른다.
/// [label]은 다른 기기 화면에 보일 이름: iOS `iPhone 15`, Android는 마케팅
/// 이름을 OS가 주지 않아 **제조사 + 모델 코드**(`Samsung SM-S921N`, 사용자 결정
/// — 설정의 기기 이름은 개인 이름이 섞일 수 있어 쓰지 않는다).
class LiveViewer {
  const LiveViewer({required this.id, required this.label});
  final String id;
  final String label;
}

/// 설치 ID·기기 이름. 실패해도 라이브를 막지 않는다 — 이름은 OS 이름, ID는
/// 이번 실행 동안만 쓰는 값으로 대신한다(서버는 같은 실행 안에선 같은 기기로 본다).
final liveViewerProvider = FutureProvider<LiveViewer>((ref) async {
  return LiveViewer(id: await _installId(), label: await _deviceLabel());
});

const _kViewerIdKey = 'live_viewer_id';

Future<String> _installId() async {
  try {
    if (Hive.isBoxOpen('app_settings')) {
      final box = Hive.box('app_settings');
      final existing = box.get(_kViewerIdKey);
      if (existing is String && Uuid.isValidUUID(fromString: existing)) {
        return existing;
      }
      final id = const Uuid().v4();
      await box.put(_kViewerIdKey, id);
      return id;
    }
  } catch (_) {}
  return const Uuid().v4();
}

Future<String> _deviceLabel() async {
  try {
    final info = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final ios = await info.iosInfo;
      return _pick(ios.modelName, ios.model, 'iPhone');
    }
    if (Platform.isAndroid) {
      final a = await info.androidInfo;
      return _pick(androidLabel(a.manufacturer, a.model), null, 'Android');
    }
  } catch (_) {}
  return Platform.isIOS ? 'iPhone' : 'Android';
}

String _pick(String? a, String? b, String fallback) {
  for (final v in [a, b]) {
    final t = v?.trim() ?? '';
    if (t.isNotEmpty) return t;
  }
  return fallback;
}

/// `samsung` + `SM-S921N` → `Samsung SM-S921N`. 모델에 제조사가 이미 들어
/// 있으면(`Pixel 8`은 아니지만 `Xiaomi 13T`처럼) 겹치지 않게 모델만.
String androidLabel(String manufacturer, String model) {
  final m = model.trim();
  final maker = manufacturer.trim();
  if (maker.isEmpty) return m;
  if (m.toLowerCase().startsWith(maker.toLowerCase())) return m;
  final cap = maker[0].toUpperCase() + maker.substring(1);
  return m.isEmpty ? cap : '$cap $m';
}
