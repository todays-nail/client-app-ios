# iOS Preview Guide

## 원칙

- SwiftUI 프리뷰는 작은 뷰와 상태 단위 검증에 사용합니다.
- 화면 플로우, 네비게이션, 외부 SDK 연동은 시뮬레이터 또는 실제 기기에서 확인합니다.
- 프리뷰는 실제 네트워크, 인증, 푸시, 외부 SDK 초기화를 수행하지 않아야 합니다.
- 프리뷰용 fixture, mock, stub은 `PreviewSupport/`와 각 ViewModel의 `previewState(...)`에 모읍니다.

## 이 저장소에서 프리뷰를 쓰는 방법

- `HomeView`처럼 순수 화면은 화면 단위 프리뷰를 유지합니다.
- `AINailGenerationView`, `FittedAIImagesView`처럼 상태가 많은 화면은 preview host + preview state 조합으로 상태별 프리뷰를 만듭니다.
- `SettingsView`, `ProfileView`처럼 컨테이너와 서비스 바인딩이 있는 화면은 `SettingsScreen`, `ProfileScreen` 같은 순수 화면 레벨에서 프리뷰합니다.
- `RootView`, `MainTabContainerView`처럼 앱 전체를 끌어올리는 프리뷰는 기본 진입점으로 사용하지 않습니다.

## Preview Fixture 규칙

- 네트워크나 실제 세션 대신 `AppViewModel.preview(...)`를 사용합니다.
- ViewModel 상태 프리뷰는 `previewState(...)`에서 완결되게 구성합니다.
- 이미지가 필요한 프리뷰는 `PreviewFixtures`의 임시 로컬 이미지 데이터를 사용합니다.
- 프리뷰 전용 코드는 가능하면 `#if DEBUG`로 감쌉니다.

## 느릴 때 체크리스트

1. 프리뷰가 `RootView`, `MainTabContainerView`, 전체 플로우 컨테이너를 직접 띄우고 있지 않은지 확인합니다.
2. `.task`, `.onAppear`, `.onReceive`에서 실제 서비스 바인딩이나 네트워크가 수행되는지 확인합니다.
3. `PreviewExecutionContext.isActive` 분기가 외부 SDK 초기화와 푸시 설정을 막고 있는지 확인합니다.
4. 상태별 프리뷰가 fixture 기반인지, 실제 API 응답이나 실제 로그인 상태를 기대하지 않는지 확인합니다.
5. 그래도 느리면 해당 기능은 시뮬레이터 검증으로 넘기고 leaf view 프리뷰만 유지합니다.

## Canvas 진단과 리셋

- Xcode Canvas가 비정상적으로 느리거나 깨지면 `Editor > Canvas > Diagnostics`를 먼저 확인합니다.
- 프리뷰 전용 시뮬레이터 캐시를 정리할 때는 `xcrun simctl --set previews delete all`을 사용합니다.
- 진단 후에도 동일하면 Xcode를 재시작하고, 그래도 반복되면 시뮬레이터로 전환해 개발을 이어갑니다.

## Simulator 우선 전환 기준

- 탭 전체, 로그인 이후 전체 앱 라우팅, 푸시/딥링크, 카메라/포토 피커/크롭 흐름
- 외부 SDK 상태가 개입하는 기능
- 프리뷰 로딩 시간이 작은 수정에도 반복적으로 길어지는 화면

## Xcode 버전별 우회책 기록 위치

- `Legacy Previews Execution` 같은 우회 설정은 `AGENTS.md`에 고정 규칙으로 넣지 않습니다.
- Xcode 버전별 이슈와 임시 workaround는 이 문서 하단에 날짜와 Xcode 버전을 함께 남깁니다.

## Workaround Log

- 2026-03-09 / Xcode 26.3: 공용 디자인/UI를 `Packages/NailUI`로 분리하고, 앱 부팅 부작용을 `PreviewExecutionContext`로 차단했습니다.
