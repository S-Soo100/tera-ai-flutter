import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/notification/data/push_messaging_service.dart';
import 'package:vivanaut/features/notification/domain/push_consent_flow.dart';

/// Figma 권한 요청 시나리오(1179:4464) — 프리팝업 선택 × 시스템 권한 상태.
class _Harness {
  _Harness(this.permission);
  PushPermission permission;
  final requests = <bool>[]; // retry 플래그 기록
  final topics = <PushTopic, bool>{};
  final seen = <PushTopic>{};

  late final flow = PushConsentFlow(
    currentPermission: () async => permission,
    requestPermission: ({bool retry = false}) async => requests.add(retry),
    setTopic: (topic, on) async => topics[topic] = on,
    isAsked: seen.contains,
    markAsked: (topic) async => seen.add(topic),
  );
}

void main() {
  group('알림 받기', () {
    test('시스템 팝업을 한 번도 안 띄웠으면 주제를 켜고 시스템 권한을 요청한다', () async {
      final h = _Harness(PushPermission.notDetermined);
      final optOut = await h.flow.resolve(PushTopic.highlight, accept: true);
      expect(h.topics, {PushTopic.highlight: true});
      expect(h.requests, [false]);
      expect(optOut, isFalse);
    });

    test('이미 허용했으면 시스템 팝업 없이 해당 알림만 켠다', () async {
      final h = _Harness(PushPermission.authorized);
      await h.flow.resolve(PushTopic.community, accept: true);
      expect(h.topics, {PushTopic.community: true});
      expect(h.requests, isEmpty);
    });

    test('거절했었으면 다시 요청하고 막혀 있으면 설정으로 보낸다(retry)', () async {
      final h = _Harness(PushPermission.denied);
      await h.flow.resolve(PushTopic.highlight, accept: true);
      expect(h.topics, {PushTopic.highlight: true});
      expect(h.requests, [true]);
    });

    test('시스템 권한이 없는 플랫폼(iOS)은 주제만 켠다', () async {
      final h = _Harness(PushPermission.unavailable);
      await h.flow.resolve(PushTopic.highlight, accept: true);
      expect(h.topics, {PushTopic.highlight: true});
      expect(h.requests, isEmpty);
    });
  });

  group('알림 받지 않기', () {
    test('시스템 알림이 켜져 있으면 주제를 끄고 수신 거부 완료를 알린다', () async {
      final h = _Harness(PushPermission.authorized);
      final optOut = await h.flow.resolve(PushTopic.community, accept: false);
      expect(h.topics, {PushTopic.community: false});
      expect(optOut, isTrue);
      expect(h.requests, isEmpty);
    });

    test('시스템 권한을 아직 안 물었거나 거절했으면 팝업만 닫힌다', () async {
      for (final p in [PushPermission.notDetermined, PushPermission.denied]) {
        final h = _Harness(p);
        final optOut = await h.flow.resolve(PushTopic.highlight, accept: false);
        expect(h.topics, {PushTopic.highlight: false});
        expect(optOut, isFalse, reason: '$p');
        expect(h.requests, isEmpty);
      }
    });

    test('시스템 권한이 없는 플랫폼(iOS)도 마이페이지 재설정 안내를 보인다', () async {
      final h = _Harness(PushPermission.unavailable);
      expect(await h.flow.resolve(PushTopic.highlight, accept: false), isTrue);
    });
  });

  test('주제별로 한 번만 묻는다', () async {
    final h = _Harness(PushPermission.authorized);
    expect(h.flow.claim(PushTopic.highlight), isTrue);
    expect(h.flow.claim(PushTopic.highlight), isFalse);
    expect(h.flow.claim(PushTopic.community), isTrue);
    expect(h.seen, {PushTopic.highlight, PushTopic.community});
  });
}
