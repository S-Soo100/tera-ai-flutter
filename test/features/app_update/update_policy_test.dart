import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/app_update/domain/update_policy.dart';

const _store = 'https://play.google.com/store/apps/details?id=com.vivanaut.app';

UpdatePolicy _policy({int min = 530, int latest = 540, String? url = _store}) =>
    UpdatePolicy(
        minBuild: min,
        latestBuild: latest,
        latestVersion: '0.182.0',
        storeUrl: url);

void main() {
  group('decideUpdate', () {
    test('현재 < min → 강제', () {
      expect(decideUpdate('529', _policy(), null), AppUpdateStatus.required);
    });

    test('현재 < min이면 [나중에] 기록이 있어도 강제', () {
      expect(decideUpdate('529', _policy(), 540), AppUpdateStatus.required);
    });

    test('min ≤ 현재 < latest → 권장', () {
      expect(decideUpdate('530', _policy(), null), AppUpdateStatus.recommended);
      expect(decideUpdate('539', _policy(), null), AppUpdateStatus.recommended);
    });

    test('[나중에]로 넘긴 빌드가 latest와 같으면 안내 없음', () {
      expect(decideUpdate('535', _policy(), 540), AppUpdateStatus.none);
    });

    test('[나중에] 뒤 latest가 더 올라가면 다시 권장', () {
      expect(decideUpdate('535', _policy(latest: 545), 540),
          AppUpdateStatus.recommended);
    });

    test('store_url이 null·빈 값·주소 아님 → 강제 기준이어도 안내 없음', () {
      expect(decideUpdate('1', _policy(url: null), null), AppUpdateStatus.none);
      expect(decideUpdate('1', _policy(url: ''), null), AppUpdateStatus.none);
      expect(decideUpdate('1', _policy(url: '   '), null), AppUpdateStatus.none);
      expect(decideUpdate('1', _policy(url: 'not a url'), null),
          AppUpdateStatus.none);
    });

    test('현재 ≥ latest → 안내 없음', () {
      expect(decideUpdate('540', _policy(), null), AppUpdateStatus.none);
      expect(decideUpdate('600', _policy(), null), AppUpdateStatus.none);
    });

    test('정책 없음(null) → 안내 없음', () {
      expect(decideUpdate('1', null, null), AppUpdateStatus.none);
    });

    test('빌드 번호를 숫자로 못 읽으면 안내 없음', () {
      for (final build in [null, '', 'abc', '1.2', '529a']) {
        expect(decideUpdate(build, _policy(), null), AppUpdateStatus.none,
            reason: '$build');
      }
    });

    test('시드 값(0,0)은 아무에게도 안 뜬다', () {
      expect(decideUpdate('1', _policy(min: 0, latest: 0), null),
          AppUpdateStatus.none);
    });
  });

  group('updatePlatformFor — 적용 대상', () {
    test('정식 번들만 대상, 플랫폼 이름을 돌려준다', () {
      expect(
          updatePlatformFor(
              packageName: 'com.vivanaut.app',
              platform: TargetPlatform.android),
          'android');
      expect(
          updatePlatformFor(
              packageName: 'com.vivanaut.app', platform: TargetPlatform.iOS),
          'ios');
    });

    test('iOS 베타 번들(com.vivanaut.beta)은 제외', () {
      expect(
          updatePlatformFor(
              packageName: 'com.vivanaut.beta', platform: TargetPlatform.iOS),
          isNull);
    });

    test('그 밖의 플랫폼은 제외', () {
      expect(
          updatePlatformFor(
              packageName: 'com.vivanaut.app', platform: TargetPlatform.macOS),
          isNull);
    });
  });

  group('UpdatePolicy.fromJson', () {
    test('DB 행을 읽는다', () {
      final p = UpdatePolicy.fromJson({
        'platform': 'android',
        'min_build': 530,
        'latest_build': 540,
        'latest_version': '0.182.0',
        'store_url': _store,
        'updated_at': '2026-11-16T00:00:00Z',
      });
      expect(p, isNotNull);
      expect(p!.minBuild, 530);
      expect(p.latestBuild, 540);
      expect(p.latestVersion, '0.182.0');
      expect(p.storeUri, Uri.parse(_store));
    });

    test('store_url null·latest_version 누락은 허용(안내 없음·버전 생략)', () {
      final p = UpdatePolicy.fromJson(
          {'min_build': 0, 'latest_build': 0, 'store_url': null});
      expect(p, isNotNull);
      expect(p!.latestVersion, '');
      expect(p.storeUri, isNull);
    });

    test('빌드 번호 타입이 틀리면 null(조회 실패로 본다)', () {
      expect(
          UpdatePolicy.fromJson(
              {'min_build': '530', 'latest_build': 540, 'store_url': _store}),
          isNull);
      expect(UpdatePolicy.fromJson({'latest_build': 540}), isNull);
    });

    test('정수형 실수(530.0)는 받아 준다', () {
      final p = UpdatePolicy.fromJson(
          {'min_build': 530.0, 'latest_build': 540, 'store_url': _store});
      expect(p?.minBuild, 530);
    });
  });
}
