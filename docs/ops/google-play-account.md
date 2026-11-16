# Google Play 개발자 계정·Android 스토어 배포 현황 (SOT)

> Android 스토어 배포 계정·서명·출시 준비의 단일 기준. 바뀌면 이 문서를 먼저 고친다.
> 법인(D-U-N-S) 정보는 [`apple-developer-account.md`](apple-developer-account.md)와 같다.
> 최종 갱신: 2026-11-16

## 현재 상태 한눈에

- **계정:** 조직 계정 생성·등록비 결제 완료(2026-11-16).
- **계정 확인:** 웹사이트 ✅ / 판매자 상태·본인 확인·전화번호 ⏳. 이 넷이 끝나기 전에는 **앱을 만들 수 없다**(Play Console 홈 "앱을 만들려면 계정 확인을 완료하세요").
- **출시 차단 요소:** 개인정보처리방침 웹페이지 없음, 회원 탈퇴 미작동(서버 함수 미배포), 계정 삭제 웹페이지 없음 — 아래 [출시 전 막힌 것](#출시-전-막힌-것).

## 개발자 계정

| 항목 | 값 |
|---|---|
| 계정 유형 | **조직**(회사 또는 비즈니스). 조직→개인 전환은 불가 |
| 개발자 계정 ID | `5861934716131206696` |
| 계정 소유자 | `terraaidev@gmail.com` (백승수 등기이사·CTO). **가입 후 소유 Google 계정은 바꿀 수 없다**고 가입 화면에 명시. Play는 회사 도메인 메일 계정을 권했으나 사용자 결정으로 유지 |
| 공개 개발자 이름 | `terra ai` (최대 50자, 띄어쓰기 허용 확인, 언제든 변경 가능) |
| 결제 프로필 | 조직 유형, D-U-N-S `697129769`로 생성. 유형·국가·D-U-N-S는 이후 변경 불가 |
| 조직 이름·주소(결제 프로필, D&B 한글 등재) | (주)테라에이아이 / 경기도 안산시 단원구 연수원로 104-14 310호 (원곡동,안산정보산업진흥센터) 15432 |
| 조직 규모 | 1~10 |
| 조직 전화(비공개) | 백승수 휴대폰. 입력 형식은 공백·하이픈 없는 `+8210…`이어야 통과 |
| 조직 웹사이트 | `https://www.vivanaut.co.kr` — Search Console 도메인 속성 `vivanaut.co.kr`(소유자 terraaidev, Cloudflare DNS 자동 인증) → Play **웹사이트 확인됨** |
| 공개 개발자 이메일 | `bss.rol20@vivanaut.co.kr` (Cloudflare 라우팅) |

- Apple 쪽에 걱정했던 영문 소문자 법인명 `terraai Co.,Ltd.`은 Play에 쓰이지 않는다. Google이 D&B에서 받은 값은 **한글 법인명·주소**다. 제출 서류(사업자등록증)는 이 한글 값과 일치해야 한다.
- 다른 사람은 소유 계정을 넘기지 말고 **사용자 및 권한**에서 각자 메일로 초대한다. 결제 프로필 연결은 소유자만 할 수 있다.

### 계정 확인 진행 (앱 만들기 전 필수)

| 단계 | 상태 | 할 일 |
|---|---|---|
| 조직 웹사이트 인증 | ✅ 2026-11-16 | — |
| 판매자(거래자) 상태 선언 | ⏳ | EU 디지털서비스법 항목. 법인이므로 "판매자임" 권장 — EU 사용자에게 주소·전화·메일 공개(이미 공개 프로필과 같은 정보) |
| 본인 확인(서류) | ⏳ | 사업자등록증 컬러 스캔 + 대표자 신분증(유효·컬러·사본 아님). 도움말 표현은 "계정 소유자 또는 권한 있는 대표자" — 등기이사 신분증으로 내고, 반려되면 대표이사 신분증. 영문 사업자등록증명(홈택스)도 준비해 두면 안전. 심사 며칠 |
| 전화번호 인증 | ⏳ | 위 둘이 승인된 뒤 열린다 |

## 앱·서명

| 항목 | 값 |
|---|---|
| 패키지명 | `com.vivanaut.app` (첫 업로드 순간 고정) |
| 릴리즈 키스토어 | `/Users/baek/vivanaut-release.jks` (PKCS12, 별칭 `vivanaut`, RSA 2048, 2026-09-21 생성, **2054-02-06까지** 유효). 레포 밖 백업 완료(사용자 확인) |
| 인증서 SHA-256 | `E9:72:4A:11:1E:BD:14:57:DD:60:81:01:80:CB:B5:5E:B3:BD:08:BC:A7:4C:2B:9B:70:8A:87:8F:73:1F:8D:79` |
| 인증서 SHA-1 | `E5:81:A7:AB:CE:34:87:38:7E:04:63:C9:E2:A4:47:77:EA:FE:FD:A4` |
| 시험 빌드 | 2026-11-16 `flutter build appbundle --release` 성공 — 0.178.6+521, 78.6MB, targetSdk 36 / minSdk 24, 위 키로 서명 확인 |

### 앱 서명 결정 (첫 업로드 전에 반드시)

- 0.123.0+307부터 고객에게 직접 준 APK는 모두 위 키로 서명됐다. 서명이 다르면 기존 설치 위에 업데이트가 안 된다.
- 그래서 **Play 앱 서명 키는 Google 생성 키가 아니라 이 기존 키를 올린다.** 첫 릴리스 만들 때 앱 서명 → "앱 서명 키 변경" → "Java 키 저장소에서 키 내보내기 및 업로드"(PEPK 도구, Console에서 받는 암호화 공개키 사용). 공개 테스트·프로덕션에 배포한 뒤에는 바꿀 수 없다.
- 업로드 키는 따로 만드는 것이 권장(분리 안 하면 같은 키가 업로드 키 겸용). 분리하면 업로드 키를 잃어도 Google에 재설정을 요청할 수 있다. 결정 대기.
- 키 유효기간은 2033-10-22 이후여야 한다 → 2054년까지라 충족.

### 매니페스트 권한 (릴리즈 병합 결과)

INTERNET, ACCESS_NETWORK_STATE, BLUETOOTH_SCAN(`neverForLocation`)·CONNECT, BLUETOOTH·BLUETOOTH_ADMIN·ACCESS_FINE_LOCATION(API 30 이하만), POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, SCHEDULE_EXACT_ALARM, VIBRATE, WAKE_LOCK, MODIFY_AUDIO_SETTINGS, WRITE_EXTERNAL_STORAGE(API 29 이하), FCM 수신.

- 카메라·마이크·미디어 읽기·백그라운드 위치·포그라운드 서비스 없음 → 민감 권한 신고 부담 작음.
- `SCHEDULE_EXACT_ALARM`은 Play Console 신고 대상이 아니다(신고 필요한 것은 `USE_EXACT_ALARM`). 사용자 기능(팬 타이머 정시 알림)이 있어 근거 충분. Android 14+는 기본 거부이며 앱은 이미 inexact로 물러선다.

## 출시 전 막힌 것

1. **개인정보처리방침 URL** — 모든 앱 필수. 공개·로그인 불필요·PDF 아님·SSL·이 앱에 해당하는 내용. 앱 안에도 링크 필요. 현재 `www.vivanaut.co.kr/privacy`는 홈으로 돌아간다(페이지 없음). 사이트는 별도 프로젝트(Vercel `terra-ai-promotion-website`).
2. **계정 삭제** — 계정을 만들 수 있는 앱은 ① 앱 안에서 찾기 쉬운 삭제 시작 경로 ② 앱 밖 웹 경로(Data safety에 URL 입력) 둘 다 필요. 웹 페이지는 앱 이름 또는 개발자 이름을 적고, 재설치 없이 요청할 수 있어야 하며, 보존 데이터가 있으면 기간을 알린다(간단한 폼·메일 안내 허용).
   - 현재 앱의 회원 탈퇴는 서버 함수 `delete-account`를 부르는데 **운영 Supabase에 배포돼 있지 않다**(2026-11-16 함수 목록 조회: `notification-ingest`, `dispatch-push`만). 그래서 누르면 "아직 준비되지 않았습니다". 2026-09-16 서버 요청서 [`docs/handoffs/2026-09-16-mypage-server-requests.md`](../handoffs/2026-09-16-mypage-server-requests.md) 항목.
   - Play 기준으로는 완전한 인앱 삭제가 권장이고, 앱 안에 **삭제 요청 웹페이지로 가는 링크**만 있어도 된다. 다만 iOS App Store는 앱 안에서 삭제를 시작할 수 있어야 하므로 함수 배포가 근본 해결이다.
3. **심사용 앱 접근 정보** — 로그인 필요 앱이라 영어로 데모 계정(만료 없음·OTP 없음)과 안내를 넣는다. 사육장·카메라 기기가 있어야 보이는 화면은 기기가 연결된 데모 계정을 주고 기기 없이 볼 수 있는 범위를 영어로 설명(공식 문서엔 하드웨어 안내 규칙이 따로 없음).
4. 그 밖의 앱 콘텐츠 양식: Data safety(수집 항목: 이메일·계정, 기기 텔레메트리, 영상, 푸시 토큰 등), 콘텐츠 등급, 타겟층, 광고 여부, 스토어 등록정보(아이콘 512, 그래픽 이미지 1024×500, 휴대전화 스크린샷).

## 출시 순서 (계정 확인 후)

1. 앱 만들기: 앱 이름 "비바나트", 기본 언어 한국어, 앱, 무료.
2. 테스트 → **내부 테스트**(최대 100명, 몇 분 안에 배포, 표준 심사를 거치지 않을 수 있음) 릴리스 생성 → **앱 서명 키 변경(위 결정)** → AAB 업로드.
3. 내부 테스트로 기존 APK 설치 기기에 Play 업데이트가 덮어써지는지 확인(서명 유지 검증).
4. 앱 콘텐츠 양식·스토어 등록정보 완료 → 프로덕션(조직 계정은 개인 계정의 "12명·14일 비공개 테스트" 요건 대상 아님 — 도움말에 "개인 계정만"으로 명시).

- 타깃 API: 2026-08-31부터 새 앱·업데이트는 **API 36 이상** — 현재 36으로 충족.
- 빌드: `flutter build appbundle --release` (`android/key.properties` 필요 — 작업 공간에는 없으니 메인 폴더 것을 쓰거나 잠시 복사 후 삭제).

## 참고: Play 밖 APK 배포 (Android developer verification)

- 인증된 Android 기기에 앱을 설치하려면 개발자 신원 인증 + 패키지명 등록이 필요해진다. 2026-09-30 브라질·인도네시아·싱가포르·태국부터, **2027년 전 세계 확대**(구체 일정 미발표). 한국 APK 직접 배포는 아직 영향 없음.
- 이 Play Console 계정으로 Play 밖 배포 앱까지 등록할 수 있고, Play 앱 서명을 쓰는 앱은 자동 등록된다. 서명 키를 잃으면 패키지 등록이 불가하다.

## 출처 (2026-11-16 확인)

- 계정 유형·필수 정보: https://support.google.com/googleplay/android-developer/answer/13628312
- 시작하기(등록비 US$25, 테스트·기기 인증은 개인 계정만): https://support.google.com/googleplay/android-developer/answer/6112435
- 조직 인증·서류: https://support.google.com/googleplay/android-developer/answer/12778236 , https://support.google.com/googleplay/android-developer/answer/15633622
- 웹사이트 인증: https://support.google.com/googleplay/android-developer/answer/13205715
- 계정 삭제: https://support.google.com/googleplay/android-developer/answer/13327111
- 사용자 데이터·개인정보처리방침: https://support.google.com/googleplay/android-developer/answer/10144311
- 타깃 API: https://developer.android.com/google/play/requirements/target-sdk
- 앱 서명: https://support.google.com/googleplay/android-developer/answer/9842756
- 앱 접근(로그인 정보): https://support.google.com/googleplay/android-developer/answer/15748846
- 테스트 트랙: https://support.google.com/googleplay/android-developer/answer/9845334 , 개인 계정 테스트 요건 https://support.google.com/googleplay/android-developer/answer/14151465
- 정확한 알람: https://support.google.com/googleplay/android-developer/answer/16558241
- developer verification: https://developer.android.com/developer-verification/guides
