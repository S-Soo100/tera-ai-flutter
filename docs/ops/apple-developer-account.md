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
| 형태 | 개인 멤버십 (2026-11-10 활성화) |
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

실제 경로: developer.apple.com/contact → (bss.rol20 로그인) → 멤버십 및 계정 → 하위 주제 **기타 멤버십 또는 계정 질문** → 이메일. 하위 주제에 '조직 전환' 항목은 없고, 주제를 고르면 바로 이메일/전화 선택이 나온다.
보낸 메일: 제목 `Request to convert individual membership to organization (Team ID XYNNB47RN3)`, 본문에 팀 ID·법인명·D-U-N-S·주소·웹사이트·요청자 권한(공동창업자·등기이사·CTO)을 적고 ① 기존 앱·번들 ID·TestFlight 빌드 유지 여부 ② 필요한 서류·절차를 물었다. 서류 요청이 오면 법인 등기사항전부증명서(영문 번역)를 낸다.

처음 쓴 요청 문구 초안:

> I would like to convert my individual Apple Developer Program membership (Team ID XYNNB47RN3) to an organization membership for terraai Co.,Ltd. (D-U-N-S 697129769, website https://www.vivanaut.co.kr). I am a co-founder, registered director and CTO of the company and have legal authority to bind it to Apple agreements. Please confirm that existing apps and TestFlight builds on this team will remain after the conversion.
- 예전 무료 팀 `8NDUMK7C65`(arthurbaek)는 TestFlight 불가. arthurbaek 계정은 Apple이 등록 자격을 거절했다(지원 케이스 진행 중).

## 번들 ID·앱

| 번들 ID | App Store Connect 앱 | 용도 |
|---|---|---|
| `com.vivanaut.beta` | 비바나트 베타 (SKU `vivanaut-beta`) | TestFlight 전용. **스토어 출시 금지**(중복 앱 반려 위험) |
| `com.vivanaut.app` | (미생성) | 정식 출시용. Android와 같은 ID. 팀 등록 가능 여부 확인 필요(예전 무료 팀이 잡고 있을 수 있음) |

- 업로드: `tools/testflight.sh` (스킬 `testflight`). 베타 값은 빌드할 때만 임시로 바꾸며 main의 `project.pbxproj`에는 넣지 않는다.
- 업로드 경고: 배포 대상 iOS 14.0 → 2027년 4월부터 15.0 이상 필요(ITMS-90068).
- 암호화 수출 규정 답변: "OS 암호화를 대체하거나 병행하는 표준 알고리즘"(Flutter BoringSSL·WebRTC DTLS/SRTP), 프랑스 배포 없음.

## TestFlight 업로드 절차 원문 (CLAUDE.md에서 옮김)

`CLAUDE.md`(커밋 `5675f3b2`)의 문단을 문장 그대로 옮겼다(2026-11-21).

**iOS TestFlight 업로드(2026-11-10)**: `tools/testflight.sh`(스킬 `testflight`) — 최신 origin/main을 임시 작업 공간에서 팀 `XYNNB47RN3`(개인 멤버십)·번들 `com.vivanaut.beta`("비바나트 베타")로만 바꿔 빌드·업로드하고 지운다. 이 두 값을 main의 `project.pbxproj`에 넣지 말 것(`com.vivanaut.app`은 법인 팀용). 업로드는 Xcode에 bss.rol20이 로그인된 이 Mac에서만 된다. `--dry-run`은 빌드까지만. 계정·D-U-N-S·번들 ID 현황 SOT는 [`docs/ops/apple-developer-account.md`](../../docs/ops/apple-developer-account.md).
