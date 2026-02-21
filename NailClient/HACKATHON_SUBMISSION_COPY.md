# 해커톤 제출 문안 (앱 화면 기준 · 현재 구현 우선)

작성일: 2026-02-19
기준: iOS 앱 현재 구현 + Notion 기준 문서 정합

---

## 1) 상세설명
오늘네일은 손 사진과 디자인 이미지를 결합해, 내 손에 어울리는 네일을 AI로 빠르게 피팅해보는 iOS 서비스입니다.  
사용자는 소셜 로그인 후 선호 스타일을 설정하고, AI 네일 생성 화면에서 손 사진·디자인 이미지·네일 모양·연장 여부를 선택해 개인화된 결과를 생성할 수 있습니다.

생성된 이미지는 `생성 결과 보기`에서 모아보고, 좋아요/상세 확인/삭제로 관리할 수 있어 다음 방문 전 원하는 스타일을 정리하기 쉽습니다.  
AI 생성 완료/실패는 푸시 알림으로 안내되어 대기 부담을 줄입니다.

[현재 MVP 범위]  
- AI 네일 피팅 생성(손 사진 + 디자인 이미지 + 모양/연장 선택)  
- 생성 결과 보관함(전체/좋아요 필터, 상세 보기, 삭제)  
- 소셜 로그인 및 프로필/선호 스타일 온보딩

[확장 방향]  
- 견적/예약/시술 연계 플로우는 파트너 샵 연동과 함께 순차적으로 확장 예정입니다.

---

## 2) 고객의 문제점과 해결방안
- 네일을 자주 하는 20~30대 고객: 하고 싶은 디자인은 많은데 내 손에 어울릴지 확신이 없고, 원하는 느낌을 말로 설명하기 어렵다.  
해결: `손 사진 + 디자인 이미지 기반 AI 피팅으로 결과를 미리 확인하고, 생성 이미지를 저장해 상담 전 기준 이미지를 명확히 만든다.`

- 바쁜 고객: 마음에 드는 디자인을 저장해도 앨범/SNS/메신저에 흩어져 재탐색 시간이 길어진다.  
해결: 생성 결과 보기에서 좋아요/상세/삭제로 결과를 한곳에서 관리해 재방문·재선택 시간을 줄인다.

- 네일샵 사장님: 고객 요청이 추상적이면 상담 시간이 늘고 결과 기대치가 어긋나기 쉽다.  
해결: 고객이 사전에 생성한 피팅 이미지를 상담 기준으로 활용해 커뮤니케이션 정확도를 높인다.

---

## 3) 비즈니스 모델 캔버스
- Key Partners: 파트너 네일샵, AI/클라우드 인프라(OpenAI/Supabase), SNS 크리에이터
- Key Activities: AI 피팅 품질 개선, 생성 결과 관리 UX 고도화, 파트너 샵 온보딩
- Key Resources: 이미지 처리 파이프라인, 생성 결과 데이터, 스타일 자산/디자인 시스템
- Value Propositions: 내 손 기준 사전 시뮬레이션, 결과 아카이브 기반 재상담 효율, 상담 전 시각 기준 제공
- Customer Relationships: 온보딩 개인화, 좋아요/보관 기반 리텐션, 푸시 알림 기반 재유입
- Channels: iOS 앱, SNS/커뮤니티, 파트너 모집/소개 페이지
- Customer Segments: 네일 고빈도 20~30대 고객, 재방문 고객, 상담 효율화가 필요한 네일샵
- Cost Structure: AI 생성 비용, 스토리지/트래픽 비용, 제품 개발·운영비, 사용자 획득비
- Revenue Streams: 예약/결제 중개 수수료(검증 가설), 샵 구독 플랜(검증 가설), 추가 AI 생성 크레딧(검증 가설)

---

## 검증 체크리스트
1. “현재 제공 기능” 문장이 실제 iOS 탭/화면과 일치하는지 확인
2. 예약/견적/시술 관련 문장이 확정형이 아닌 “확장/예정”으로 표기됐는지 확인
3. 문제-해결 문장이 앱에서 체감 가능한 가치(생성/저장/관리)에 연결되는지 확인
4. BMC 수익축이 “가설”로 표기되어 과장 리스크가 없는지 확인

---

## 근거 소스
- iOS 탭 구조: `/Users/dkim/DKim/10_Project/hackerton_nail_project/client-app-ios/NailClient/NailClient/Features/Home/Views/MainTabContainerView.swift:19`
- AI 생성 핵심 UX: `/Users/dkim/DKim/10_Project/hackerton_nail_project/client-app-ios/NailClient/NailClient/Features/AIGeneration/Views/AINailGenerationView.swift:237`
- 생성 CTA/실행: `/Users/dkim/DKim/10_Project/hackerton_nail_project/client-app-ios/NailClient/NailClient/Features/AIGeneration/Views/AINailGenerationView.swift:560`
- 결과 보관/상세/삭제 진입: `/Users/dkim/DKim/10_Project/hackerton_nail_project/client-app-ios/NailClient/NailClient/Features/Profile/Views/FittedAIImagesView.swift:33`
- 홈 카드의 “원스톱/예정” 문구: `/Users/dkim/DKim/10_Project/hackerton_nail_project/client-app-ios/NailClient/NailClient/Features/Home/Views/Components/HomeTrendExploreCardView.swift:47`
- 소개 페이지 외부 이동: `/Users/dkim/DKim/10_Project/hackerton_nail_project/client-app-ios/NailClient/NailClient/Features/Home/Views/HomeView.swift:51`
- Notion 기준 문서:
  - [🧩 기능 명세](https://www.notion.so/30862d8950ca80adac2ece2f572c40b6)
  - [🙏 요구사항 명세서](https://www.notion.so/2c462d8950ca81948de9c54c8d6ca690)
  - [🚀 MVP](https://www.notion.so/30862d8950ca8052bbd4fccf44ec6043)
  - [📑 시나리오](https://www.notion.so/30862d8950ca80769a4de712942dc599)
  - [🗒️ 기능 구현](https://www.notion.so/2c462d8950ca8119a762f97c920a8c48)

