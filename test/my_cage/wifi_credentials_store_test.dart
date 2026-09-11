import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/my_cage/data/wifi_credentials_store.dart';

void main() {
  group('WifiCredentialsStore.decode', () {
    test('정상 JSON 맵을 SSID→비밀번호로 파싱한다', () {
      final raw = jsonEncode({'MyHomeWifi': 'pw1234', '집공유기 5G': 'abcd'});
      expect(WifiCredentialsStore.decode(raw), {
        'MyHomeWifi': 'pw1234',
        '집공유기 5G': 'abcd',
      });
    });

    test('null·빈 문자열은 빈 맵', () {
      expect(WifiCredentialsStore.decode(null), isEmpty);
      expect(WifiCredentialsStore.decode(''), isEmpty);
    });

    test('손상된 JSON·맵이 아닌 JSON은 빈 맵 (자동채움만 포기)', () {
      expect(WifiCredentialsStore.decode('{broken'), isEmpty);
      expect(WifiCredentialsStore.decode('[1,2]'), isEmpty);
      expect(WifiCredentialsStore.decode('"str"'), isEmpty);
    });

    test('문자열이 아닌 값 항목은 건너뛴다', () {
      final raw = jsonEncode({'good': 'pw', 'bad': 42, 'worse': null});
      expect(WifiCredentialsStore.decode(raw), {'good': 'pw'});
    });
  });
}
