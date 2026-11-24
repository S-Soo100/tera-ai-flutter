# Apple 개발자 계정·iOS 배포 현황 (SOT)

> iOS 배포 계정·번들 ID·법인 정보의 단일 기준. 바뀌면 이 문서를 먼저 고친다.
> 최종 갱신: 2026-11-17

## 법인 (D-U-N-S)

| 항목 | 값 |
|---|---|
| D-U-N-S 번호 | **`697129769`** (2026-11-16 발급 확인, Apple 메일) |
| 영문 법인명 (D&B 등재) | `terraai Co.,Ltd.` |
| 현지 사업자명 | (주)테라에이아이 |
| 본사 주소 (D&B 등재) | Room 310, 104-14 Yeonsuwon-ro, Danwon-gu, Ansan-si, Gyeonggi-do, KR 15432 |
| 신청 | 2026-11-05~06쯤 Apple 경유 D&B 신청 |

- 영문 법인명이 소문자·붙여 쓰기로 등재돼 있다. 법인 전환 후 App Store 판매자 이름이 이 표기를 따를 수 있으니, 바꾸려면 **전환 요청 전에** D&B(한국은 NICE D&B)에 수정을 요청한다.

## Apple 개발자 팀

| 항목 | 값 |
|---|---|
| 팀 ID | `XYNNB47RN3` |
| 형태 | **조직** (2026-11-10 개인 멤버십 활성화 → 2026-11-24 조직 전환 완료, 법인 terraai Co.,Ltd.) |
| 계정 소유자 | 백승수 (등기이사·CTO), Apple 계정 bss.rol20 |
| 알림 메일 | `bss.rol20@vivanaut.co.kr` (Cloudflare 라우팅) |

- **법인 전환 계획:** 승수님이 공동창업자·등기이사라 개인→조직 전환 자격이 있다. D-U-N-S가 Apple에 반영되면(발급 후 1~2일) developer.apple.com/contact → 멤버십 및 계정에서 `XYNNB47RN3`의 조직 전환을 요청한다. 별도 법인 계정·앱 이전이 필요 없다. 앱이 그대로 유지되는지는 요청할 때 Apple에 확인한다.
- Apple이 회사 연락처로 권한 확인 전화를 할 수 있다. 대표님께 미리 알린다.

### 법인 전환 요청 준비 (2026-11-17)

| 준비물 | 상태 |
|---|---|
| D-U-N-S `697129769` (Apple 조회에서 검색됨) | ✅ |
| 회사 웹사이트 https://www.vivanaut.co.kr (응답 200, 개인정보처리방침 `/privacy`에 회사 표기) | ✅ |
| 회사 도메인 메일 `bss.rol20@vivanaut.co.kr` | ✅ |
| 요청자 권한: 등기이사·CTO (공동창업자) | ✅ — 증빙 요청 시 법인 등기부등본 |
| 대표님께 Apple 확인 연락 사전 공유 | ✅ 2026-11-23 공유(Apple 확인 전화가 오면 "백승수 이사 진행 맞다"고 확인) |
| 진행 중인 TestFlight 업로드 완료 후 요청 | ✅ — 0.178.10(525) 업로드 뒤 제출 |

**제출 (2026-11-17): 케이스 ID `30000017939787`**. 6일째 이메일 회신이 없어 2026-11-23(월) 전화(developer.apple.com/contact → 전화, 회신 전화 방식) → 같은 날 `koreadev@apple.com`(한국 개발자 지원)에서 절차 안내 메일 수신.

#### Apple 안내 조건 (2026-11-23 메일) — 준비되면 **그 메일에 회신**해 전환을 시작한다
| 조건 | 우리 상태 |
|---|---|
| ① 프로그램 등록 Apple 계정(bss.rol20) 이중 인증 켜짐 | ✅ 켜짐 — 2026-11-23 account.apple.com 로그인 시 문자로 6자리 코드 수신(신뢰할 수 있는 전화번호 방식) |
| ② 공개 확인 가능한 조직 웹사이트, 도메인이 조직과 연관 | ✅ www.vivanaut.co.kr 응답 200, 본문에 "주식회사 테라에이아이(terra ai)" 표기(2026-11-23 확인) |
| ③ 전환 중에는 Certificates, Identifiers & Profiles 포털 사용 불가(App Store Connect 등은 유지) | 자동 서명 프로필 갱신·새 번들 ID 등록이 막힐 수 있다 → **회신 전에 필요한 TestFlight 업로드를 끝내 두고, 전환 중엔 업로드를 미룬다** |
| ④ 완료 후 법인 이름이 모든 앱 판매자명에 적용 | 원하는 결과 |
| ⑤ 완료 후 개인 멤버십 판매·추세 보고서 미제공 | 유료 앱·판매 없음 → 영향 없음 |
| ⑥ 유료 앱·인앱 수입은 전환 시작 시 활성 은행 계좌로 송금 | 유료 앱·인앱 없음 → 영향 없음 |

**전환 진행 회신 발송 (2026-11-23):** 안내 메일에 답장(같은 케이스)으로 조건 확인 결과와 팀 ID·법인명·D-U-N-S·주소·웹사이트·요청자 권한을 적고 전환 진행을 요청했다. 서류는 첨부하지 않았다(요청 시 사업자등록증, 법인 등기사항전부증명서 — 주민번호 뒷자리 비공개로 발급). TestFlight에 당장 올릴 빌드 없음(마지막 552). **이제 Apple 회신(서류 요청 또는 전환 시작 안내) 대기 — 전환 중 Certificates/Profiles 포털이 막히니 TestFlight 업로드는 끝날 때까지 미룬다.**

**전환 시작 (2026-11-23):** 같은 날 두 메일 수신 — ① `koreadev@apple.com`(Saedee, 같은 케이스): 전환 시작 확인, 등록 링크가 담긴 자동 메일이 갔다, 전환이 끝날 때까지 Certificates·Identifiers·Profiles 포털 접근 불가, [회사 등록 정보 제출](https://developer.apple.com/enroll/migrate) 뒤 다음 단계 안내. 취소·등록 중 경고 해결은 그 메일에 회신. ② Apple Developer Relations 자동 메일: 사용권 계약 양도 요청 접수, 조직 정보로 등록 내용을 [업데이트](https://developer.apple.com/enroll)하라, 양도 완료까지 멤버십 혜택 일시 중단. **→ 지금 할 일: bss.rol20으로 developer.apple.com/enroll/migrate에서 회사 등록 정보 제출.** 입력값은 위 "법인 (D-U-N-S)" 표 그대로(법인명은 D&B 표기 `terraai Co.,Ltd.`와 글자까지 같게, 업무 메일은 웹사이트와 같은 도메인 `bss.rol20@vivanaut.co.kr`, 직책 CTO, 법적 구속 권한 있음). 회사 전화번호는 사용자가 직접 입력한다(레포에 적지 않음).

**회사 등록 정보 제출 (2026-11-23): 등록 ID `QQ7VH5R7Z8`** — "등록 신청을 처리하는 중입니다." 법인 유형 회사/기관, 법인명·D-U-N-S·주소는 D&B 자동 채움(주소에 Room 310 빠짐, 수정 불가), 서명 권한은 "대표/설립자로서 구속할 권한 있음", 직장 이메일 코드 인증 완료. **다음: Apple이 서명 권한을 확인(회사 연락처로 전화 가능 — 대표님께 공유됨)하면 등록 완료 방법을 메일로 보낸다.** 그 메일이 오면 이 문서를 갱신한다. 전환 완료 전까지 TestFlight 업로드 보류.

**서류 요청 (2026-11-23):** 접수 확인 메일(Apple 계정 메일 bss.rol20@gmail.com, 업무 메일 bss.rol20@vivanaut.co.kr, 법인 terraai Co.,Ltd.) 뒤에 Apple Developer Relations가 "신원과 등록 기관과의 연관성을 확인할 수 없다"며 서류 사본을 요청했다. 업로드: https://developer.apple.com/contact/file-upload/ (등록 ID `QQ7VH5R7Z8`). 언어는 한국어·영어 가능, 그 밖의 언어는 공증 영문 번역 첨부.

| 요청 서류 | 준비 계획 |
|---|---|
| 신청자 정부 발급 사진 신분증 | 여권 권장(영문 이름 `Seungsoo Baek` 표기가 계정과 맞음). 주민등록증·운전면허증이면 주민번호 뒷자리를 가린다 |
| 신청자 고용 상태 확인 | **법인 등기사항전부증명서**(주민번호 뒷자리 비공개 발급) — 임원 란에 사내이사로 올라 있는 것이 공식 증빙. 승수님은 무급 등기이사라 급여 기반 재직증명서가 없다(2026-11-23 확인) — 고용 관계를 꾸며 내지 않는다. 보강이 필요하면 대표이사 명의 영문 확인서(사내이사·CTO이며 회사를 대표해 Apple 등록을 진행함, 법인 직인)를 덧붙인다 |
| 사업자 등록 서류 1종 | **영문 사업자등록증명**(홈택스, 법인 인증서로 발급). 고유번호증은 비영리 단체용이라 해당 없음 |

서류 업로드는 사용자가 직접 한다(신분증 등 개인정보는 레포·슬랙에 올리지 않는다).

**서류 업로드 (2026-11-23):** 사용자가 file-upload 페이지에 신분증·법인 등기사항전부증명서·영문 사업자등록증명 3건을 올렸다(첨부 상한 3개). 대표 확인서는 내지 않았다 — Apple이 소속 증빙을 더 요구하면 그때 낸다. 이제 Apple 검토 → 등록 완료 안내 메일 대기.

**등록 요청 수락 (2026-11-24 수신):** Apple Developer Relations — 조직 등록 요청이 수락됐다. 마무리: 웹사이트로 등록했으므로 https://developer.apple.com/enroll 에 bss.rol20으로 로그인 → **Apple Developer Program 사용권 계약 동의 → 멤버십 구입**. 계약 동의·결제는 사용자가 직접 한다. 개인 멤버십을 2026-11-10에 결제했으므로 구입 화면 금액이 전액이면 중복 결제인지 결제 전에 확인한다.

**✅ 조직 전환 완료 (2026-11-24 확인, 멤버십 세부 사항 화면):** 법인명 terraai Co.,Ltd. / **팀 ID `XYNNB47RN3` 그대로** / 등록 유형 **조직** / 계정 소유자 Seungsoo Baek(계정 소유자 역할) / 갱신일·기기 재설정 날짜 2027-11-11(개인 멤버십 기간 그대로 이어짐) / 연회비 ₩129,000. 인증서·ID·프로파일 포털 다시 열림 → TestFlight 업로드 재개 가능(팀 ID가 같아 `tools/testflight.sh` 수정 불필요).
- 남은 정리: ① App Store Connect 판매자명·계약(무료 앱 계약) 상태 확인 ② "베타=XYNNB47RN3 / `com.vivanaut.app`=법인 팀" 구분이 이제 같은 팀이 됨 — main `project.pbxproj`는 아직 옛 무료 팀 `8NDUMK7C65`. 정식 번들 `com.vivanaut.app` 등록과 main 팀 ID 교체는 사용자 결정 뒤 별도 작업.

실제 경로: developer.apple.com/contact → (bss.rol20 로그인) → 멤버십 및 계정 → 하위 주제 **기타 멤버십 또는 계정 질문** → 이메일. 하위 주제에 '조직 전환' 항목은 없고, 주제를 고르면 바로 이메일/전화 선택이 나온다.
보낸 메일: 제목 `Request to convert individual membership to organization (Team ID XYNNB47RN3)`, 본문에 팀 ID·법인명·D-U-N-S·주소·웹사이트·요청자 권한(공동창업자·등기이사·CTO)을 적고 ① 기존 앱·번들 ID·TestFlight 빌드 유지 여부 ② 필요한 서류·절차를 물었다. 서류 요청이 오면 법인 등기사항전부증명서(영문 번역)를 낸다.

처음 쓴 요청 문구 초안:

> I would like to convert my individual Apple Developer Program membership (Team ID XYNNB47RN3) to an organization membership for terraai Co.,Ltd. (D-U-N-S 697129769, website https://www.vivanaut.co.kr). I am a co-founder, registered director and CTO of the company and have legal authority to bind it to Apple agreements. Please confirm that existing apps and TestFlight builds on this team will remain after the conversion.
- 예전 무료 팀 `8NDUMK7C65`(arthurbaek)는 TestFlight 불가. arthurbaek 계정은 Apple이 등록 자격을 거절했다(지원 케이스 진행 중).

## 번들 ID·앱

| 번들 ID | App Store Connect 앱 | 용도 |
|---|---|---|
| `com.vivanaut.beta` | 비바나트 베타 (SKU `vivanaut-beta`) | TestFlight 전용. **스토어 출시 금지**(중복 앱 반려 위험) |
| `com.vivanaut.app` | (미생성) | 정식 출시용. Android와 같은 ID. **2026-11-24 팀 XYNNB47RN3 등록 거절**("An App ID with Identifier 'com.vivanaut.app' is not available") — 옛 무료 개인 팀 `8NDUMK7C65`(arthurbaek, "승수 백")이 잡고 있다. 근거: 이 Mac의 프로필 `8NDUMK7C65.com.vivanaut.app`(생성 2026-11-19, 만료 2026-11-26, 무료 팀 7일 프로필). 해제 요청·재시도 경과는 아래 |

- **App ID 점유 해제 (2026-11-24~):** 무료 팀은 포털에 접근할 수 없어 직접 지울 수 없다. ① 이 번들로 무료 팀 실기기 실행(`flutter run`, Xcode 실행)을 멈춰 7일 프로필이 갱신되지 않게 한다 ② Apple 지원(케이스 30000017939787 메일)에 8NDUMK7C65에서 해제 요청 ③ 프로필 만료(11-26) 뒤 등록 재시도. **② 발송 (2026-11-24):** 케이스 30000017939787 메일 스레드에 답장 — 개인 팀 8NDUMK7C65(arthurbaek@icloud.com, 본인)의 `com.vivanaut.app` 해제 요청, Android 동일 번들 출시 사유. Apple 회신 대기. 해제가 안 되면 iOS 번들 변경을 사용자와 재결정.
- **App Store Connect 비즈니스 확인 (2026-11-24, U0-2):** 법인 terraai Co.,Ltd. — **무료 앱 계약 활성(2026-11-09~2027-11-10)** → 새 앱 생성 가능. 유료 앱 계약 "신규"(유료·인앱 없으니 불필요). 옛 개인 법인 "Seungsoo Baek"은 사용 중지됨·계약 없음. 대기 작업 3개: ① EU DSA 거래자 정보(대한민국만 배포라 출시엔 불필요) ② **대한민국 비즈니스 연락처 정보**(국가 번호·연락처 전화·이메일·유효한 사업자등록번호 보유 여부) — 한국 App Store 제품 페이지에 **공개 표시**되므로 값은 사용자가 정해 입력(2026-11-24 사용자 결정: 전화 = 백승수 휴대폰(번호는 레포에 적지 않음), 이메일 bss.rol20@vivanaut.co.kr, 사업자등록번호 보유 "예") → **✅ 2026-11-24 입력·검증 완료**(App Store Connect 메일 "business contact information was verified", 전자상거래법 준수 정보로 한국 App Store에 게시됨) ③ 유료 앱 계약 전 법인 정보 업데이트(불필요). 앱 목록에는 "비바나트 베타"만 — `com.vivanaut.app` 중복 앱 없음.
- 업로드: `tools/testflight.sh` (스킬 `testflight`). 베타 값은 빌드할 때만 임시로 바꾸며 main의 `project.pbxproj`에는 넣지 않는다.
- 업로드 경고: 배포 대상 iOS 14.0 → 2027년 4월부터 15.0 이상 필요(ITMS-90068).
- 암호화 수출 규정 답변: "OS 암호화를 대체하거나 병행하는 표준 알고리즘"(Flutter BoringSSL·WebRTC DTLS/SRTP), 프랑스 배포 없음.

## TestFlight 업로드 절차 원문 (CLAUDE.md에서 옮김)

`CLAUDE.md`(커밋 `5675f3b2`)의 문단을 문장 그대로 옮겼다(2026-11-21).

**iOS TestFlight 업로드(2026-11-10)**: `tools/testflight.sh`(스킬 `testflight`) — 최신 origin/main을 임시 작업 공간에서 팀 `XYNNB47RN3`(개인 멤버십)·번들 `com.vivanaut.beta`("비바나트 베타")로만 바꿔 빌드·업로드하고 지운다. 이 두 값을 main의 `project.pbxproj`에 넣지 말 것(`com.vivanaut.app`은 법인 팀용). 업로드는 Xcode에 bss.rol20이 로그인된 이 Mac에서만 된다. `--dry-run`은 빌드까지만. 계정·D-U-N-S·번들 ID 현황 SOT는 [`docs/ops/apple-developer-account.md`](../../docs/ops/apple-developer-account.md).
