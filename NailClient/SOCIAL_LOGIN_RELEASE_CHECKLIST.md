# 소셜 로그인 버튼 릴리즈 체크리스트

## 범위
- 로그인 화면이 `Sign in with:` + Apple/Google/Kakao 네모 아이콘 버튼 3개로 고정되어 있는지 확인
- 버튼 접근성 식별자
  - `apple_sign_in_button`
  - `google_sign_in_button`
  - `kakao_sign_in_button`
  - `social_sign_in_header`
  - `social_sign_in_row`

## 배포 전 점검
- Debug/Release 빌드 성공
- `NailClientUITests.testLoginScreenShowsOnlyOfficialSocialButtons` 통과
- 실기기에서 Apple/Google/Kakao 로그인 진입 확인
- TestFlight 리뷰용 스크린샷(라이트/다크) 첨부

## 리스크
- Apple 로그인 버튼은 iOS 네이티브 권장인 `ASAuthorizationAppleIDButton` 대신 아이콘형 에셋을 사용한다.
- App Review에서 Apple 로그인 버튼 표현 방식에 대한 추가 보완 요청이 발생할 수 있다.

## 롤백 절차
- `AppleLoginButton.swift`를 `ASAuthorizationAppleIDButton` 기반 렌더링으로 복원
- `LoginEntryView.swift`를 버튼별 세로형 공식 버튼 레이아웃으로 복원
- UI 테스트를 공식 버튼 레이아웃 기준으로 복원 후 재실행
