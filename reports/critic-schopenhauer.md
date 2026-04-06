## 쇼펜하우어의 비관 보고서

### 고통 지수: 7/10

---

### 마야의 베일 목록

| # | 위치 | 환상적 보호 | 실제 위험 |
|---|------|-----------|----------|
| 1 | `pet_repository.dart` | "로컬 전용이니 안전" | Hive **암호화 없이 평문** 저장. 루팅/ADB로 개체이름, 메모, 사진경로 접근 가능 |
| 2 | `pet_detail_screen.dart:171` | photoPath로 Image.file() | 경로 검증 없음. Hive 변조 시 임의 파일 접근 시도 가능 |
| 3 | `pet_add_screen.dart` | TextFormField 검증 | 이름 빈값 체크만. 체중 음수 가능. 메모 길이 제한 없음. Hive 직접 접근 시 모든 검증 무의미 |
| 4 | image_picker | pubspec에 있지만 import 0건 | photoPath 필드 존재 + 렌더링 코드 준비 → EXIF GPS 메타데이터 스트립 로직 없음 |

### 고통의 예정 (P2 폭탄)

1. **미사용 의존성 4개** — dio, flutter_secure_storage, connectivity_plus, image_picker가 아무 일도 안 하면서 빌드 크기와 공격 표면만 키움
2. **PetRepository 추상화 부재** — Hive 직접 접근. Supabase 교체 시 전체 재작성
3. **connectivity_provider.dart** — `return true` 하드코딩. 오프라인 시 조용한 실패
4. **Pet ID가 클라이언트 UUID** — Supabase UUID와 충돌/마이그레이션 문제
5. **Hive typeId 관리** — P2에서 새 모델 추가 시 typeId 실수하면 기존 데이터 전체 손상

### 사육장의 고통

**법규 면책 조항 완전 부재** — 가장 위험한 부재
- guide_screen.dart 전체에 "이 정보는 참고용" 면책 없음
- guide_steps.json의 sources가 화면에 렌더링 안 됨
- WIMS URL 변경 시 앱 업데이트 없이 수정 불가
- 과태료 금액 정보 변경 시 구버전 사용자가 틀린 정보를 사실로 믿게 됨
- `last_updated` 표시 안 됨

### 긍정적 관찰
- AndroidManifest.xml 릴리즈 빌드에 INTERNET 권한 없음 (올바른 판단)

### 판정
**법규 면책 조항 하나 넣는 건 선택이야. 지금 안 하면 나중에 더 큰 고통으로 돌아와.** 미사용 의존성 4개 정리도 급함.
