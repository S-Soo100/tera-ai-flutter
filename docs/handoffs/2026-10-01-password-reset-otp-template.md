# 비밀번호 재설정 메일 양식 변경 요청 (2026-10-01)

## 배경

앱 0.145.0부터 로그인 화면에 **비밀번호 재설정**이 생겼다(UX-01). 앱에 딥링크 설정이 없어,
메일 링크 대신 가입 인증과 같은 **6자리 인증번호** 방식으로 만들었다.

- 앱 호출: `auth.resetPasswordForEmail(email)` → `auth.verifyOTP(type: recovery, token)` → `auth.updateUser(password)`
- 코드: `lib/features/auth/data/auth_repository.dart`, `lib/features/auth/presentation/password_reset_screen.dart`

## 필요한 운영 설정 (Supabase 대시보드 → Authentication → Email Templates → Reset Password)

기본 양식에는 링크(`{{ .ConfirmationURL }}`)만 있어서 **인증번호가 메일에 안 찍힌다.**
양식 본문에 `{{ .Token }}`을 넣어야 한다. 예:

```html
<h2>비바나트 비밀번호 재설정</h2>
<p>아래 6자리 인증번호를 앱에 입력해 주세요.</p>
<p style="font-size:24px;font-weight:bold;letter-spacing:4px">{{ .Token }}</p>
<p>요청하지 않았다면 이 메일을 무시해 주세요. 비밀번호는 바뀌지 않습니다.</p>
```

## 함께 확인할 것

- **Auth → Providers → Email → Minimum password length / Password requirements**: 앱은 가입·재설정·변경에서
  "영문+숫자+특수문자 6~12자"를 검사한다. 서버 최소 길이가 6을 넘거나 문자 조건이 더 엄격하면 알려 달라
  (앱 규칙보다 서버가 엄격하면 앱 검사를 통과한 비밀번호가 서버에서 거절된다 — 거절 시 한글 안내는 뜬다).
- 인증번호 유효 시간(Email OTP Expiration)과 메일 발송 한도(rate limit). 한도 초과 시 앱은
  "요청이 너무 많아요" 안내를 보인다.

## 상태

- 앱 구현: 완료(0.145.0). 위젯 테스트로 단계 전환·오류 안내 확인.
- **실제 메일·코드 수신: 미검증** — 위 양식 변경 후 실기기로 확인해야 한다.
