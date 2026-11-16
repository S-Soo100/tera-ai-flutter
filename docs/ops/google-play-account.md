# Google Play 개발자 계정·Android 스토어 배포 현황 (SOT)

> Android 스토어 배포 계정·서명·출시 준비의 단일 기준. 바뀌면 이 문서를 먼저 고친다.
> 법인(D-U-N-S) 정보는 [`apple-developer-account.md`](apple-developer-account.md)와 같다.
> 최종 갱신: 2026-11-16

## 현재 상태 한눈에

- **계정:** 조직 계정 생성·등록비 결제·계정 확인 완료(2026-11-16, 본인 인증 완료 알림 수신).
- **앱:** "비바나트"(`com.vivanaut.app`, 앱 ID `4975696317866126203`) 생성. Play 앱 서명 키 = 기존 릴리즈 키(아래).
- **내부 테스트:** 최신 526 (0.179.0) 출시(2026-11-17, 처리방침·웹 계정 삭제 링크 포함, 검토 오류·경고 0). 첫 출시 523 (0.178.8, 11-16) — 트랙 활성, 테스터 목록 "terra ai 내부 테스터"(terraaidev@gmail.com, bss.rol20@gmail.com). 참여 링크 https://play.google.com/apps/internaltest/4700061742254258722 . 앱 설정·검토 전까지 Play에 임시 이름 `com.vivanaut.app (unreviewed)`로 보인다.
- **다음 확인:** 기존 APK가 깔린 기기에서 참여 링크로 Play 업데이트가 덮어써지는지(서명 유지).
- **웹페이지 준비됨(2026-11-16):** 개인정보처리방침 https://www.vivanaut.co.kr/privacy · 계정 삭제 요청 https://www.vivanaut.co.kr/account-deletion (홍보 사이트 커밋 `7900bd4`, 운영 본문 확인).
- **앱 안 링크(0.179.0+526):** 마이 페이지 '개인정보처리방침' 줄, 회원 탈퇴 화면 '웹에서 계정 삭제 요청하기'. 내부 테스트 526으로 배포됨.
- **탈퇴 서버 회신(2026-11-17, [gwanhun/terra-server#67](https://github.com/gwanhun/terra-server/pull/67), `docs/BACKEND_REPLY_DELETE_ACCOUNT_2026-11-17.md`):** Edge Function 대신 terra-server `POST /account/delete`, **소프트 삭제**(로그인 차단·기기 연결 해제, DB·R2·Storage 데이터는 남음, 보관 기간 N일 미정). 회신엔 "11-17 배포"로 적혔으나 11-17 확인 시 PR은 OPEN(미머지). 공개한 처리방침·삭제 페이지의 "탈퇴 즉시 전부 삭제"와 맞지 않아 N일 결정과 문구 수정, 커뮤니티 글 숨김, 앱 호출 전환(409·500 문구)이 남았다.
- **프로덕션 차단 요소:** 회원 탈퇴(위 회신 반영·N일 삭제 작업) — 아래 [출시 전 막힌 것](#출시-전-막힌-것).

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

### 계정 확인 진행 (앱 만들기 전 필수 — 2026-11-16 모두 완료)

| 단계 | 상태 | 할 일 |
|---|---|---|
| 조직 웹사이트 인증 | ✅ 2026-11-16 | — |
| 판매자(거래자) 상태 선언 | ✅ 2026-11-16 | EU 디지털서비스법 항목. 법인이므로 "판매자임" 권장 — EU 사용자에게 주소·전화·메일 공개(이미 공개 프로필과 같은 정보) |
| 본인 확인(서류) | ✅ 2026-11-16 | 사업자등록증 컬러 스캔 + 대표자 신분증(유효·컬러·사본 아님). 도움말 표현은 "계정 소유자 또는 권한 있는 대표자" — 등기이사 신분증으로 내고, 반려되면 대표이사 신분증. 영문 사업자등록증명(홈택스)도 준비해 두면 안전. 심사 며칠 |
| 전화번호 인증 | ✅ 2026-11-16 | 위 둘이 승인된 뒤 열린다 |

## 앱·서명

| 항목 | 값 |
|---|---|
| 패키지명 | `com.vivanaut.app` (첫 업로드 순간 고정) |
| 릴리즈 키스토어 | `/Users/baek/vivanaut-release.jks` (PKCS12, 별칭 `vivanaut`, RSA 2048, 2026-09-21 생성, **2054-02-06까지** 유효). 레포 밖 백업 완료(사용자 확인) |
| 인증서 SHA-256 | `E9:72:4A:11:1E:BD:14:57:DD:60:81:01:80:CB:B5:5E:B3:BD:08:BC:A7:4C:2B:9B:70:8A:87:8F:73:1F:8D:79` |
| 인증서 SHA-1 | `E5:81:A7:AB:CE:34:87:38:7E:04:63:C9:E2:A4:47:77:EA:FE:FD:A4` |
| 시험 빌드 | 2026-11-16 `flutter build appbundle --release` 성공 — 0.178.6+521, 78.6MB, targetSdk 36 / minSdk 24, 위 키로 서명 확인 |

### 앱 서명 (2026-11-16 설정 완료)

- 0.123.0+307부터 고객에게 직접 준 APK는 모두 위 키로 서명됐다. 서명이 다르면 기존 설치 위에 업데이트가 안 된다.
- 그래서 **Play 앱 서명 키를 이 기존 키로 바꿨다.** 앱을 만들면 Google이 자기 키를 먼저 만들어 두므로(설치 0%), 앱 서명 → [키 변경] → "Java Keystore의 키 내보내기 및 업로드" → Console에서 받은 `pepk.jar`·`encryption_public_key.pem`으로 암호화 ZIP을 만들어 올렸다(`--include-cert --rsa-aes-encryption`, 인증서 지문 확인 후). Console의 앱 서명 키 SHA-256이 위 값과 같음을 확인. 공개 테스트·프로덕션 배포 뒤에는 바꿀 수 없다.
- 암호화 ZIP은 Google만 열 수 있어 백업 가치가 없다 — 보관하지 않는다. 진짜 백업은 `.jks`와 비밀번호.
- **업로드 키는 분리하지 않았다**(사용자 결정, 같은 키가 업로드 키 겸용). APK 직접 배포가 이어지는 동안 서명 설정을 한 벌로 두기 위해서다. 직접 배포를 끝내면 Play Console [재설정 요청]으로 업로드 키를 분리한다(Google 승인 대기 있음).
- Play 업로드용 AAB도, 고객 직접 배포용 APK도 **같은 키로 빌드**한다.
- 키 유효기간은 2033-10-22 이후여야 한다 → 2054년까지라 충족.

### 매니페스트 권한 (릴리즈 병합 결과)

INTERNET, ACCESS_NETWORK_STATE, BLUETOOTH_SCAN(`neverForLocation`)·CONNECT, BLUETOOTH·BLUETOOTH_ADMIN·ACCESS_FINE_LOCATION(API 30 이하만), POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, SCHEDULE_EXACT_ALARM, VIBRATE, WAKE_LOCK, MODIFY_AUDIO_SETTINGS, WRITE_EXTERNAL_STORAGE(API 29 이하), FCM 수신.

- 카메라·마이크·미디어 읽기·백그라운드 위치·포그라운드 서비스 없음 → 민감 권한 신고 부담 작음.
- `SCHEDULE_EXACT_ALARM`은 Play Console 신고 대상이 아니다(신고 필요한 것은 `USE_EXACT_ALARM`). 사용자 기능(팬 타이머 정시 알림)이 있어 근거 충분. Android 14+는 기본 거부이며 앱은 이미 inexact로 물러선다.

## 출시 전 막힌 것

1. **개인정보처리방침 URL** — 모든 앱 필수. 공개·로그인 불필요·PDF 아님·SSL·이 앱에 해당하는 내용. 앱 안에도 링크 필요. ✅ **https://www.vivanaut.co.kr/privacy** 공개(2026-11-16, 레포 `~/terra-ai-promotion-website` 커밋 `7900bd4`). 적용 범위에 비바나트 앱(Android·iOS)·회원 서비스 포함, 13개 조항, 시행일 2026-11-16, 문의 bss.rol20@vivanaut.co.kr, 보호책임자 이병무 대표이사.
   - 수탁자·국외 이전: Supabase(서울), AWS Lightsail(서울, terra-server), Fly.io(일본, petcam-api), Cloudflare R2(아시아·태평양), Google(FCM·GA, 미국), Vercel(미국). 영상 AI는 자체 모델을 회사 내부 서버에서 실행(사용자 확인) — Gemini는 방침에서 제외. 14세 미만 조항은 넣지 않음(사용자 결정).
   - ✅ 앱 안 링크: 0.179.0+526부터 마이 페이지 '개인정보처리방침' 줄(외부 브라우저, `shared/providers/external_url_launcher.dart`의 `LegalLinks`).
   - 미결: 고객 앱 영상을 사람 라벨링(petcam-lab 라벨링 도구)에 쓰는지 — 쓰면 처리 목적에 "AI 모델 개선(영상 라벨링)"을 추가해야 한다.
2. **계정 삭제** — 계정을 만들 수 있는 앱은 ① 앱 안에서 찾기 쉬운 삭제 시작 경로 ② 앱 밖 웹 경로(Data safety에 URL 입력) 둘 다 필요. 웹 페이지는 앱 이름 또는 개발자 이름을 적고, 재설치 없이 요청할 수 있어야 하며, 보존 데이터가 있으면 기간을 알린다(간단한 폼·메일 안내 허용).
   - 현재 앱의 회원 탈퇴는 서버 함수 `delete-account`를 부르는데 **운영 Supabase에 배포돼 있지 않다**(2026-11-16 함수 목록 조회: `notification-ingest`, `dispatch-push`만). 그래서 누르면 "아직 준비되지 않았습니다". 2026-09-16 서버 요청서 [`docs/handoffs/2026-09-16-mypage-server-requests.md`](../handoffs/2026-09-16-mypage-server-requests.md) 항목.
   - ✅ 앱 밖 웹 경로: **https://www.vivanaut.co.kr/account-deletion** (앱 이름·개발자 표시, 앱 안 경로 + 메일 요청, 삭제·보관 데이터 안내). Data safety의 계정 삭제 URL에 넣는다.
   - **삭제 기준(사용자 확정 2026-11-16): 탈퇴 즉시 전부 삭제** — 기기 연결 해제, 영상·사진 삭제, 식별 불가 통계만 남김. 서버 구현도 이 기준.
   - **서버 요청서 초안:** [`docs/handoffs/2026-11-16-delete-account-server-request.md`](../handoffs/2026-11-16-delete-account-server-request.md) — 백승수가 이관훈님께 전달 예정. 운영 DB 실측상 `user_profiles`·`commands.issued_by` 등이 NO ACTION 외래키라 지금은 `deleteUser`만으로는 누구도 못 지운다.
   - Play 기준으로는 완전한 인앱 삭제가 권장이고, 앱 안에 **삭제 요청 웹페이지로 가는 링크**만 있어도 된다. 다만 iOS App Store는 앱 안에서 삭제를 시작할 수 있어야 하므로 함수 배포가 근본 해결이다.
3. **심사용 앱 접근 정보** — 로그인 필요 앱이라 영어로 데모 계정(만료 없음·OTP 없음)과 안내를 넣는다. 사육장·카메라 기기가 있어야 보이는 화면은 기기가 연결된 데모 계정을 주고 기기 없이 볼 수 있는 범위를 영어로 설명(공식 문서엔 하드웨어 안내 규칙이 따로 없음).
4. 그 밖의 앱 콘텐츠 양식: Data safety(수집 항목: 이메일·계정, 기기 텔레메트리, 영상, 푸시 토큰 등), 콘텐츠 등급, 타겟층, 광고 여부, 스토어 등록정보(아이콘 512, 그래픽 이미지 1024×500, 휴대전화 스크린샷).

## 출시 순서

1. ✅ 앱 만들기: 앱 이름 "비바나트", 기본 언어 한국어, 앱, 무료(게시 후 유료 전환 불가 — 인앱결제는 가능).
2. ✅ 내부 테스트 523 (0.178.8) 출시, 앱 서명 키 변경, 테스터 2명(2026-11-16). AAB 78.6MB → 기기별 신규 설치 24.1MB. 검토 경고는 "테스터 미지정" 하나였고 테스터 등록으로 해소.
3. 내부 테스트로 기존 APK 설치 기기에 Play 업데이트가 덮어써지는지 확인(서명 유지 검증).
4. 앱 콘텐츠 양식·스토어 등록정보 완료 → 프로덕션(조직 계정은 개인 계정의 "12명·14일 비공개 테스트" 요건 대상 아님 — 도움말에 "개인 계정만"으로 명시).

- 타깃 API: 2026-08-31부터 새 앱·업데이트는 **API 36 이상** — 현재 36으로 충족.
- 빌드: `flutter build appbundle --release` (`android/key.properties` 필요 — 작업 공간에는 없으니 메인 폴더 것을 쓰거나 잠시 복사 후 삭제).
- AAB가 78MB라 Claude in Chrome 파일 업로드(10MB 한도)로는 못 올린다. Finder에서 Console 업로드 칸으로 끌어다 놓는다. 버전 코드는 올릴 때마다 커야 한다(pubspec 빌드 번호).

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
