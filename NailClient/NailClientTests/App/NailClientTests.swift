//
//  NailClientTests.swift
//  NailClientTests
//
//  Created by 김대환 on 2/15/26.
//

import Foundation
import Testing
@testable import NailClient

@MainActor
struct NailClientTests {

    @Test
    func start_자동로그인지연시_로그인라우트로복귀한다() async {
        let authService = MockAuthService(behavior: .respectTimeoutAndFail)
        let viewModel = AppViewModel(
            authService: authService,
            launchTiming: .init(
                minimumSplashDuration: .milliseconds(20),
                autoLoginTimeout: .milliseconds(120)
            )
        )

        let clock = ContinuousClock()
        let startedAt = clock.now
        await viewModel.start()
        let elapsed = startedAt.duration(to: clock.now)

        #expect(viewModel.launchPhase == .ready)
        #expect(viewModel.route == .login)
        #expect(viewModel.errorMessage == nil)
        #expect(elapsed < .seconds(1))

        let clearCallCount = await authService.clearLocalSessionCallCount
        #expect(clearCallCount == 1)
    }

    @Test
    func start_자동로그인세션만료시_로그인안내메시지를표시한다() async {
        let authService = MockAuthService(
            behavior: .immediateFailure(
                EdgeAPIError(
                    statusCode: 401,
                    message: "refresh token expired",
                    code: "AUTH_REFRESH_EXPIRED",
                    errorId: "AUTH-T-1"
                )
            )
        )
        let viewModel = AppViewModel(
            authService: authService,
            launchTiming: .init(
                minimumSplashDuration: .milliseconds(20),
                autoLoginTimeout: .milliseconds(120)
            )
        )

        await viewModel.start()

        #expect(viewModel.launchPhase == .ready)
        #expect(viewModel.route == .login)
        #expect(viewModel.errorMessage == "세션이 만료되었어요. 다시 로그인해 주세요.")

        let clearCallCount = await authService.clearLocalSessionCallCount
        #expect(clearCallCount == 1)
    }

    @Test
    func start_자동로그인성공시_홈으로이동한다() async {
        let user = AppTestFixtures.makeUser(nickname: "home-user", profileImageURL: nil)
        let result = AppTestFixtures.makeAuthResult(
            session: AppTestFixtures.makeSession(),
            user: user,
            needsOnboarding: false
        )

        let viewModel = AppViewModel(
            authService: MockAuthService(behavior: .immediate(result)),
            launchTiming: .init(
                minimumSplashDuration: .milliseconds(10),
                autoLoginTimeout: .milliseconds(120)
            )
        )

        await viewModel.start()

        #expect(viewModel.launchPhase == .ready)
        #expect(viewModel.route == .home)
        #expect(viewModel.currentUser?.id == user.id)
        #expect(viewModel.onboardingPrefill == nil)
    }

    @Test
    func start_홈진입시_첫12개썸네일rawbytes를디스크프리패치한다() async throws {
        let session = AppTestFixtures.makeSession()
        let user = AppTestFixtures.makeUser(nickname: "prefetch-user", profileImageURL: nil)
        let authResult = AppTestFixtures.makeAuthResult(
            session: session,
            user: user,
            needsOnboarding: false
        )
        let listResponse = NailGenListResponse(
            items: (0..<15).map { index in
                NailGenerationTestFixtures.makeListItem(
                    jobId: UUID(),
                    parentJobId: nil,
                    refinementTurn: 0,
                    resultImageURL: "https://example.com/result-\(index).jpg",
                    thumbnailImageURL: "https://example.com/thumb-\(index).jpg"
                )
            },
            nextCursor: "next-page"
        )
        let recorder = ImagePrefetchRecorder()
        let viewModel = AppViewModel(
            authService: MockAuthService(
                behavior: .immediate(authResult),
                completedNailGenerationListBehavior: .success(
                    response: listResponse,
                    session: session
                )
            ),
            imagePrefetch: recorder.prefetch,
            launchTiming: .init(
                minimumSplashDuration: .milliseconds(10),
                autoLoginTimeout: .milliseconds(120)
            )
        )

        await viewModel.start()

        #expect(recorder.calls.count == 1)
        let call = try #require(recorder.calls.first)
        #expect(call.urls.count == 12)
        #expect(call.urls == (0..<12).compactMap { URL(string: "https://example.com/thumb-\($0).jpg") })
        #expect(call.targetSize == nil)
        #expect(call.resizeMode == .fill)
        #expect(call.destination == .diskCache)
    }

    @Test
    func start_온보딩필요시_온보딩으로이동한다() async {
        let user = AppTestFixtures.makeUser(
            nickname: "new-user",
            profileImageURL: "https://example.com/profile.png"
        )
        let result = AppTestFixtures.makeAuthResult(
            session: AppTestFixtures.makeSession(),
            user: user,
            needsOnboarding: true
        )

        let viewModel = AppViewModel(
            authService: MockAuthService(behavior: .immediate(result)),
            launchTiming: .init(
                minimumSplashDuration: .milliseconds(10),
                autoLoginTimeout: .milliseconds(120)
            )
        )

        await viewModel.start()

        #expect(viewModel.launchPhase == .ready)
        #expect(viewModel.route == .onboarding)
        #expect(viewModel.onboardingPrefill?.nickname == "new-user")
        #expect(viewModel.onboardingPrefill?.profileImageURL == "https://example.com/profile.png")
    }

    @Test
    func updateMyProfile_성공시_유저정보를갱신한다() async {
        let currentSession = AppTestFixtures.makeSession()
        let updatedSession = AppTestFixtures.makeSession(
            accessToken: "access-new",
            refreshToken: "refresh-new"
        )
        let currentUser = AppTestFixtures.makeUser(
            nickname: "before-update",
            profileImageURL: "https://example.com/profile.png"
        )
        let updatedUser = AppUser(
            id: currentUser.id,
            role: currentUser.role,
            nickname: "after-update",
            profileImageURL: currentUser.profileImageURL,
            defaultRegionID: nil,
            defaultRegionLabel: nil,
            defaultServiceRegionID: nil,
            createdAt: currentUser.createdAt,
            updatedAt: currentUser.updatedAt
        )

        let authService = MockAuthService(
            behavior: .immediate(
                AppTestFixtures.makeAuthResult(
                    session: currentSession,
                    user: currentUser,
                    needsOnboarding: false
                )
            ),
            updateMyProfileBehavior: .success(user: updatedUser, session: updatedSession)
        )

        let viewModel = AppViewModel(
            authService: authService,
            launchTiming: .init(
                minimumSplashDuration: .milliseconds(10),
                autoLoginTimeout: .milliseconds(120)
            )
        )

        await viewModel.start()
        let success = await viewModel.updateMyProfile(nickname: "after-update")

        #expect(success == true)
        #expect(viewModel.currentUser?.nickname == "after-update")
        #expect(viewModel.session?.accessToken == "access-new")
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func updateMyProfile_실패시_에러메시지를설정하고유저정보를유지한다() async {
        let currentSession = AppTestFixtures.makeSession()
        let currentUser = AppTestFixtures.makeUser(
            nickname: "before-update",
            profileImageURL: "https://example.com/profile.png"
        )

        let authService = MockAuthService(
            behavior: .immediate(
                AppTestFixtures.makeAuthResult(
                    session: currentSession,
                    user: currentUser,
                    needsOnboarding: false
                )
            ),
            updateMyProfileBehavior: .failure(MockAuthError.profileUpdateFailed)
        )

        let viewModel = AppViewModel(
            authService: authService,
            launchTiming: .init(
                minimumSplashDuration: .milliseconds(10),
                autoLoginTimeout: .milliseconds(120)
            )
        )

        await viewModel.start()
        let success = await viewModel.updateMyProfile(nickname: "after-update")

        #expect(success == false)
        #expect(viewModel.currentUser?.nickname == "before-update")
        #expect(viewModel.errorMessage?.contains("프로필 수정 실패") == true)
    }

    @Test
    func deleteMyAccount_성공시_세션을정리하고로그인으로이동한다() async {
        let session = AppTestFixtures.makeSession()
        let currentUser = AppTestFixtures.makeUser(
            nickname: "delete-user",
            profileImageURL: "https://example.com/profile.png"
        )

        let authService = MockAuthService(
            behavior: .immediate(
                AppTestFixtures.makeAuthResult(
                    session: session,
                    user: currentUser,
                    needsOnboarding: false
                )
            ),
            deleteMyAccountBehavior: .success
        )

        let viewModel = AppViewModel(
            authService: authService,
            launchTiming: .init(
                minimumSplashDuration: .milliseconds(10),
                autoLoginTimeout: .milliseconds(120)
            )
        )

        await viewModel.start()
        let success = await viewModel.deleteMyAccount(reason: nil)

        #expect(success == true)
        #expect(viewModel.route == .login)
        #expect(viewModel.currentUser == nil)
        #expect(viewModel.session == nil)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func deleteMyAccount_실패시_세션을유지하고에러메시지를설정한다() async {
        let session = AppTestFixtures.makeSession()
        let currentUser = AppTestFixtures.makeUser(
            nickname: "delete-user",
            profileImageURL: "https://example.com/profile.png"
        )

        let authService = MockAuthService(
            behavior: .immediate(
                AppTestFixtures.makeAuthResult(
                    session: session,
                    user: currentUser,
                    needsOnboarding: false
                )
            ),
            deleteMyAccountBehavior: .failure(MockAuthError.deleteFailed)
        )

        let viewModel = AppViewModel(
            authService: authService,
            launchTiming: .init(
                minimumSplashDuration: .milliseconds(10),
                autoLoginTimeout: .milliseconds(120)
            )
        )

        await viewModel.start()
        let success = await viewModel.deleteMyAccount(reason: nil)

        #expect(success == false)
        #expect(viewModel.route == .home)
        #expect(viewModel.currentUser?.id == currentUser.id)
        #expect(viewModel.session == session)
        #expect(viewModel.errorMessage?.contains("회원 탈퇴 실패") == true)
    }

    @Test
    func signInWithGoogle_성공시_홈으로이동한다() async {
        let user = AppTestFixtures.makeUser(nickname: "google-user", profileImageURL: nil)
        let result = AppTestFixtures.makeAuthResult(
            session: AppTestFixtures.makeSession(
                accessToken: "google-access",
                refreshToken: "google-refresh"
            ),
            user: user,
            needsOnboarding: false
        )

        let authService = MockAuthService(
            behavior: .immediate(nil),
            signInWithGoogleResult: .success(result)
        )
        let viewModel = AppViewModel(authService: authService)

        await viewModel.signInWithGoogle()

        #expect(viewModel.route == .home)
        #expect(viewModel.currentUser?.id == user.id)
        #expect(viewModel.session?.accessToken == "google-access")
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func signInWithGoogle_실패시_로그인으로복귀한다() async {
        let authService = MockAuthService(
            behavior: .immediate(nil),
            signInWithGoogleResult: .failure(
                EdgeAPIError(statusCode: 401, message: "google failed", code: "AUTH_GOOGLE_VERIFY_FAILED", errorId: "G-1")
            )
        )
        let viewModel = AppViewModel(authService: authService)

        await viewModel.signInWithGoogle()

        #expect(viewModel.route == .login)
        #expect(viewModel.currentUser == nil)
        #expect(viewModel.session == nil)
        #expect(viewModel.errorMessage?.contains("Google 로그인 실패") == true)
    }

    @Test
    func signInWithApple_성공시_홈으로이동한다() async {
        let user = AppTestFixtures.makeUser(nickname: "apple-user", profileImageURL: nil)
        let result = AppTestFixtures.makeAuthResult(
            session: AppTestFixtures.makeSession(
                accessToken: "apple-access",
                refreshToken: "apple-refresh"
            ),
            user: user,
            needsOnboarding: false
        )

        let authService = MockAuthService(
            behavior: .immediate(nil),
            signInWithAppleResult: .success(result)
        )
        let viewModel = AppViewModel(authService: authService)

        await viewModel.signInWithApple()

        #expect(viewModel.route == .home)
        #expect(viewModel.currentUser?.id == user.id)
        #expect(viewModel.session?.accessToken == "apple-access")
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func signInWithApple_실패시_로그인으로복귀한다() async {
        let authService = MockAuthService(
            behavior: .immediate(nil),
            signInWithAppleResult: .failure(
                EdgeAPIError(statusCode: 401, message: "apple failed", code: "AUTH_APPLE_VERIFY_FAILED", errorId: "A-1")
            )
        )
        let viewModel = AppViewModel(authService: authService)

        await viewModel.signInWithApple()

        #expect(viewModel.route == .login)
        #expect(viewModel.currentUser == nil)
        #expect(viewModel.session == nil)
        #expect(viewModel.errorMessage?.contains("Apple 로그인 실패") == true)
    }

    @Test
    func refreshPushAuthorizationState_권한상태를갱신한다() async {
        let pushManager = MockPushNotificationManager(
            requestAuthorizationResult: false,
            authorizationState: .denied
        )
        let viewModel = AppViewModel(
            authService: MockAuthService(behavior: .immediate(nil)),
            pushManager: pushManager
        )

        await viewModel.refreshPushAuthorizationState()
        #expect(viewModel.pushAuthorizationState == .denied)

        pushManager.authorizationState = .allowed
        await viewModel.refreshPushAuthorizationState()
        #expect(viewModel.pushAuthorizationState == .allowed)
        #expect(pushManager.fetchAuthorizationStateCallCount == 2)
    }

    @Test
    func preparePushNotificationsForAIGeneration_권한거부시_토큰등록을시도하지않는다() async {
        let session = AppTestFixtures.makeSession()
        let user = AppTestFixtures.makeUser(nickname: "push-user", profileImageURL: nil)
        let authService = MockAuthService(
            behavior: .immediate(
                AppTestFixtures.makeAuthResult(
                    session: session,
                    user: user,
                    needsOnboarding: false
                )
            )
        )
        let pushManager = MockPushNotificationManager(
            requestAuthorizationResult: false,
            authorizationState: .denied
        )
        let viewModel = AppViewModel(
            authService: authService,
            pushManager: pushManager,
            launchTiming: .init(
                minimumSplashDuration: .milliseconds(10),
                autoLoginTimeout: .milliseconds(120)
            )
        )

        await viewModel.start()
        pushManager.latestDeviceTokenHex = "deadbeef"

        await viewModel.preparePushNotificationsForAIGeneration()

        #expect(viewModel.pushAuthorizationState == .denied)
        #expect(pushManager.requestAuthorizationCallCount == 1)
        let upsertCount = await authService.upsertPushTokenCallCount
        #expect(upsertCount == 0)
    }

    @Test
    func preparePushNotificationsForAIGeneration_권한허용시_토큰등록을시도한다() async {
        let session = AppTestFixtures.makeSession()
        let user = AppTestFixtures.makeUser(nickname: "push-user", profileImageURL: nil)
        let authService = MockAuthService(
            behavior: .immediate(
                AppTestFixtures.makeAuthResult(
                    session: session,
                    user: user,
                    needsOnboarding: false
                )
            )
        )
        let pushManager = MockPushNotificationManager(
            requestAuthorizationResult: true,
            authorizationState: .allowed
        )
        let viewModel = AppViewModel(
            authService: authService,
            pushManager: pushManager,
            launchTiming: .init(
                minimumSplashDuration: .milliseconds(10),
                autoLoginTimeout: .milliseconds(120)
            )
        )

        await viewModel.start()
        pushManager.latestDeviceTokenHex = "deadbeef"

        await viewModel.preparePushNotificationsForAIGeneration()

        #expect(viewModel.pushAuthorizationState == .allowed)
        #expect(pushManager.requestAuthorizationCallCount == 1)
        let upsertCount = await authService.upsertPushTokenCallCount
        #expect(upsertCount == 1)
    }

}
