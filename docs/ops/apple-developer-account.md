# Apple 개발자 계정·iOS 배포 현황 (SOT)

> iOS 배포 계정·번들 ID·법인 정보의 단일 기준. 바뀌면 이 문서를 먼저 고친다.
> 최종 갱신: 2026-11-16

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
- 예전 무료 팀 `8NDUMK7C65`(arthurbaek)는 TestFlight 불가. arthurbaek 계정은 Apple이 등록 자격을 거절했다(지원 케이스 진행 중).

## 번들 ID·앱

| 번들 ID | App Store Connect 앱 | 용도 |
|---|---|---|
| `com.vivanaut.beta` | 비바나트 베타 (SKU `vivanaut-beta`) | TestFlight 전용. **스토어 출시 금지**(중복 앱 반려 위험) |
| `com.vivanaut.app` | (미생성) | 정식 출시용. Android와 같은 ID. 팀 등록 가능 여부 확인 필요(예전 무료 팀이 잡고 있을 수 있음) |

- 업로드: `tools/testflight.sh` (스킬 `testflight`). 베타 값은 빌드할 때만 임시로 바꾸며 main의 `project.pbxproj`에는 넣지 않는다.
- 업로드 경고: 배포 대상 iOS 14.0 → 2027년 4월부터 15.0 이상 필요(ITMS-90068).
- 암호화 수출 규정 답변: "OS 암호화를 대체하거나 병행하는 표준 알고리즘"(Flutter BoringSSL·WebRTC DTLS/SRTP), 프랑스 배포 없음.
