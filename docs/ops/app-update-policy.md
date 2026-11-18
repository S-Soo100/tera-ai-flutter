# 앱 업데이트 안내 운영 규칙 (SOT)

> 앱의 강제·권장 업데이트 안내를 켜고 끄는 기준. 값은 운영 Supabase 표 `public.app_release_policy`에 있다.
> 설계: [`docs/superpowers/plans/2026-11-16-store-update-and-push-route.md`](../superpowers/plans/2026-11-16-store-update-and-push-route.md) §1·§2.1·§2.4
> 표 정의: [`supabase/migrations/20261116000000_app_release_policy.sql`](../../supabase/migrations/20261116000000_app_release_policy.sql)
> 최초 작성: 2026-11-16 (앱 0.181.0+530)

## 동작 요약

| 칸 | 뜻 |
|---|---|
| `min_build` | 설치된 빌드 번호가 이보다 **작으면 강제** — "업데이트가 필요해요" 화면만 보인다. [업데이트]·[다시 확인]만 있다. |
| `latest_build` | 이보다 **작으면 권장** — "새 버전이 나왔어요" 확인 창. [나중에]를 직접 누르면 그 `latest_build`에는 다시 안 뜬다(기기 단위). |
| `latest_version` | 안내에 보이는 버전("0.181.0"). 비우면 버전 없이 안내한다. |
| `store_url` | 스토어 주소. **null·빈 값이면 그 플랫폼은 강제·권장 모두 안내하지 않는다.** |

- 비교 기준은 앱의 **빌드 번호(정수)** — pubspec `0.181.0+530`의 `530`. 정식 번들(`com.vivanaut.app`)만 대상이고 iOS 베타(`com.vivanaut.beta`)는 안내하지 않는다.
- 앱은 시작 때 한 번 읽고, 복귀(백그라운드 → 앞으로) 때는 강제 화면이면 **매번**, 아니면 마지막 확인에서 6시간이 지났을 때 다시 읽는다.
- 조회 실패(오프라인 등)는 이전 상태를 유지한다 — 안내가 없던 사람에게 새로 띄우지 않고, 강제 화면을 실패로 풀지도 않는다. 값을 캐시하지 않는다.
- 시드는 android·ios 모두 `0, 0` — 표가 있어도 아무에게도 안 뜬다.

## 운영 규칙 (계획서 §2.4)

1. **Play 서명 유지 검증(기존 APK 위 Play 업데이트 덮어쓰기) 완료 전에는 Android `min_build`를 올리지 않는다** — 서명이 다르면 업데이트가 설치되지 않아 사용자가 강제 화면에 갇힌다.
2. 스토어 심사 통과·배포 완료 확인 후 `latest_build`.
3. `min_build`는 스토어에 있는 빌드 이하로만. 잘못 올렸으면 값을 되돌리면 강제 화면 사용자는 [다시 확인]·복귀 즉시 풀린다.
4. iOS `store_url`은 App Store ID가 나온 뒤.
5. 직접 배포 APK 사용자는 이 기능이 든 빌드를 한 번 받아야 안내를 받는다.

## 값 바꾸기 (Supabase SQL 편집기)

앱에는 쓰기 권한이 없다(anon·authenticated SELECT만). 운영자가 SQL 편집기로만 바꾼다. `min_build <= latest_build`가 아니면 DB가 거부한다.

```sql
-- 현재 값 보기
select platform, min_build, latest_build, latest_version, store_url, updated_at
from public.app_release_policy;

-- 권장: Play에 531(0.182.0) 배포 완료 확인 뒤
update public.app_release_policy
set latest_build = 531, latest_version = '0.182.0', updated_at = now()
where platform = 'android';

-- 강제: 530 미만은 업데이트 화면만 (규칙 1·3 확인 뒤에만)
update public.app_release_policy
set min_build = 530, updated_at = now()
where platform = 'android';

-- 잘못 올린 강제 되돌리기 — 강제 화면 사용자는 [다시 확인]·복귀 즉시 풀린다
update public.app_release_policy
set min_build = 0, updated_at = now()
where platform = 'android';

-- iOS 켜기(App Store ID가 나온 뒤, 규칙 4)
update public.app_release_policy
set store_url = 'https://apps.apple.com/app/id<APP_STORE_ID>', updated_at = now()
where platform = 'ios';
```

## 참고: ABI별로 나눈 APK의 빌드 번호 (2026-11-18 확인)

`flutter build apk --split-per-abi`로 만든 APK는 Flutter가 versionCode에 ABI 값을 더한다(`1000 × ABI + 빌드`). 메인 폴더 `build/app/outputs/flutter-apk/`의 옛 산출물을 `aapt dump badging`으로 확인한 값:

| 파일 | versionName | versionCode |
|---|---|---|
| `app-release.apk`(하나로 묶은 APK) | 0.177.3 | 512 (= pubspec 빌드) |
| `app-armeabi-v7a-release.apk` | 0.125.0 | 1309 |
| `app-arm64-v8a-release.apk` | 0.125.0 | 2309 |
| `app-x86_64-release.apk` | 0.125.0 | 4309 |

- 하나로 묶은 APK·Play 번들은 versionCode = pubspec 빌드라 이 문서의 기준이 그대로 맞는다.
- ABI별 APK가 깔린 기기는 빌드 번호가 수천대로 읽혀 **안내가 뜨지 않고**, Play의 530 같은 낮은 versionCode로는 **업데이트도 되지 않는다**(버전 코드가 내려가는 설치는 막힌다). 고객에게 나간 직접 배포 APK가 어느 쪽으로 만들어졌는지는 확인하지 못했다 — 해당 기기는 앱을 지우고 Play에서 다시 받아야 한다.
