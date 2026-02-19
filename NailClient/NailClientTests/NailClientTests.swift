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
        let user = makeUser(nickname: "home-user", profileImageURL: nil)
        let result = AuthResult(
            session: AppSession(accessToken: "access", refreshToken: "refresh"),
            user: user,
            needsOnboarding: false,
            onboardingPrefill: nil
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
    func start_온보딩필요시_온보딩으로이동한다() async {
        let user = makeUser(nickname: "new-user", profileImageURL: "https://example.com/profile.png")
        let result = AuthResult(
            session: AppSession(accessToken: "access", refreshToken: "refresh"),
            user: user,
            needsOnboarding: true,
            onboardingPrefill: nil
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
        let currentSession = AppSession(accessToken: "access", refreshToken: "refresh")
        let updatedSession = AppSession(accessToken: "access-new", refreshToken: "refresh-new")
        let currentUser = makeUser(
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
                AuthResult(
                    session: currentSession,
                    user: currentUser,
                    needsOnboarding: false,
                    onboardingPrefill: nil
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
        let currentSession = AppSession(accessToken: "access", refreshToken: "refresh")
        let currentUser = makeUser(
            nickname: "before-update",
            profileImageURL: "https://example.com/profile.png"
        )

        let authService = MockAuthService(
            behavior: .immediate(
                AuthResult(
                    session: currentSession,
                    user: currentUser,
                    needsOnboarding: false,
                    onboardingPrefill: nil
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
        let session = AppSession(accessToken: "access", refreshToken: "refresh")
        let currentUser = makeUser(
            nickname: "delete-user",
            profileImageURL: "https://example.com/profile.png"
        )

        let authService = MockAuthService(
            behavior: .immediate(
                AuthResult(
                    session: session,
                    user: currentUser,
                    needsOnboarding: false,
                    onboardingPrefill: nil
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
        let session = AppSession(accessToken: "access", refreshToken: "refresh")
        let currentUser = makeUser(
            nickname: "delete-user",
            profileImageURL: "https://example.com/profile.png"
        )

        let authService = MockAuthService(
            behavior: .immediate(
                AuthResult(
                    session: session,
                    user: currentUser,
                    needsOnboarding: false,
                    onboardingPrefill: nil
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
        let user = makeUser(nickname: "google-user", profileImageURL: nil)
        let result = AuthResult(
            session: AppSession(accessToken: "google-access", refreshToken: "google-refresh"),
            user: user,
            needsOnboarding: false,
            onboardingPrefill: nil
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
        let user = makeUser(nickname: "apple-user", profileImageURL: nil)
        let result = AuthResult(
            session: AppSession(accessToken: "apple-access", refreshToken: "apple-refresh"),
            user: user,
            needsOnboarding: false,
            onboardingPrefill: nil
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

    private func makeUser(
        nickname: String?,
        profileImageURL: String?
    ) -> AppUser {
        AppUser(
            id: UUID(),
            role: nil,
            nickname: nickname,
            profileImageURL: profileImageURL,
            defaultRegionID: nil,
            defaultRegionLabel: nil,
            defaultServiceRegionID: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }
}

private enum MockAutoLoginBehavior {
    case immediate(AuthResult?)
    case immediateFailure(Error)
    case respectTimeoutAndFail
}

private enum MockAuthError: Error {
    case timeout
    case unsupported
    case profileUpdateFailed
    case deleteFailed
}

private enum MockUpdateMyProfileBehavior {
    case unsupported
    case success(user: AppUser, session: AppSession)
    case failure(Error)
}

private enum MockDeleteMyAccountBehavior {
    case unsupported
    case success
    case failure(Error)
}

private actor MockAuthService: AuthServicing {
    let behavior: MockAutoLoginBehavior
    let signInWithGoogleResult: Result<AuthResult, Error>?
    let signInWithAppleResult: Result<AuthResult, Error>?
    let updateMyProfileBehavior: MockUpdateMyProfileBehavior
    let deleteMyAccountBehavior: MockDeleteMyAccountBehavior
    private(set) var clearLocalSessionCallCount: Int = 0

    init(
        behavior: MockAutoLoginBehavior,
        signInWithGoogleResult: Result<AuthResult, Error>? = nil,
        signInWithAppleResult: Result<AuthResult, Error>? = nil,
        updateMyProfileBehavior: MockUpdateMyProfileBehavior = .unsupported,
        deleteMyAccountBehavior: MockDeleteMyAccountBehavior = .unsupported
    ) {
        self.behavior = behavior
        self.signInWithGoogleResult = signInWithGoogleResult
        self.signInWithAppleResult = signInWithAppleResult
        self.updateMyProfileBehavior = updateMyProfileBehavior
        self.deleteMyAccountBehavior = deleteMyAccountBehavior
    }

    func tryAutoLogin(traceId: String, timeout: Duration) async throws -> AuthResult? {
        switch behavior {
        case .immediate(let result):
            return result
        case .immediateFailure(let error):
            throw error
        case .respectTimeoutAndFail:
            try await Task.sleep(for: timeout + .milliseconds(80))
            throw MockAuthError.timeout
        }
    }

    func signInWithKakao(traceId: String) async throws -> AuthResult {
        throw MockAuthError.unsupported
    }

    func signInWithGoogle(traceId: String) async throws -> AuthResult {
        guard let signInWithGoogleResult else {
            throw MockAuthError.unsupported
        }
        return try signInWithGoogleResult.get()
    }

    func signInWithApple(traceId: String) async throws -> AuthResult {
        guard let signInWithAppleResult else {
            throw MockAuthError.unsupported
        }
        return try signInWithAppleResult.get()
    }

    func completeOnboarding(
        traceId: String,
        session: AppSession,
        nickname: String,
        profileImageURL: String?
    ) async throws -> (user: AppUser, needsOnboarding: Bool, session: AppSession) {
        throw MockAuthError.unsupported
    }

    func updateMyProfile(
        traceId: String,
        session: AppSession,
        nickname: String,
        profileImageURL: String?
    ) async throws -> (user: AppUser, session: AppSession) {
        switch updateMyProfileBehavior {
        case .unsupported:
            throw MockAuthError.unsupported
        case let .success(user, session):
            return (user, session)
        case let .failure(error):
            throw error
        }
    }

    func issueNailGenerationUploadURL(
        traceId: String,
        session: AppSession,
        kind: NailGenUploadKind,
        ext: String,
        contentType: String,
        bytes: Int,
        jobId: UUID?
    ) async throws -> (response: NailGenUploadURLResponse, session: AppSession) {
        throw MockAuthError.unsupported
    }

    func uploadImageToSignedURL(
        traceId: String,
        signedUploadURL: String,
        contentType: String,
        imageData: Data
    ) async throws {
        throw MockAuthError.unsupported
    }

    func createNailGenerationJob(
        traceId: String,
        session: AppSession,
        shape: NailGenShape,
        userPrompt: String,
        handObjectPath: String,
        referenceObjectPath: String
    ) async throws -> (response: NailGenCreateJobResponse, session: AppSession) {
        throw MockAuthError.unsupported
    }

    func refineNailGenerationJob(
        traceId: String,
        session: AppSession,
        sourceJobId: UUID,
        shape: NailGenShape,
        userPrompt: String
    ) async throws -> (response: NailGenRefineJobResponse, session: AppSession) {
        throw MockAuthError.unsupported
    }

    func getNailGenerationJobStatus(
        traceId: String,
        session: AppSession,
        jobId: UUID
    ) async throws -> (response: NailGenJobStatusResponse, session: AppSession) {
        throw MockAuthError.unsupported
    }

    func fetchFeedList(
        traceId: String,
        session: AppSession,
        limit: Int,
        cursor: String?,
        styles: [String],
        category: FeedListCategory,
        reservationDate: String?,
        startTime: String?,
        endTime: String?
    ) async throws -> (response: FeedListResponse, session: AppSession) {
        throw MockAuthError.unsupported
    }

    func fetchLikedFeedList(
        traceId: String,
        session: AppSession,
        limit: Int,
        cursor: String?
    ) async throws -> (response: FeedListResponse, session: AppSession) {
        throw MockAuthError.unsupported
    }

    func fetchFeedDetail(
        traceId: String,
        session: AppSession,
        postId: UUID
    ) async throws -> (response: FeedDetailResponse, session: AppSession) {
        throw MockAuthError.unsupported
    }

    func setFeedLike(
        traceId: String,
        session: AppSession,
        postId: UUID,
        isLiked: Bool
    ) async throws -> (response: FeedLikeResponse, session: AppSession) {
        throw MockAuthError.unsupported
    }

    func searchShops(
        traceId: String,
        session: AppSession,
        query: String,
        limit: Int,
        regionId: UUID?
    ) async throws -> (response: ShopSearchResponse, session: AppSession) {
        _ = regionId
        throw MockAuthError.unsupported
    }

    func fetchShopDetail(
        traceId: String,
        session: AppSession,
        shopId: UUID
    ) async throws -> (response: ShopDetailResponse, session: AppSession) {
        throw MockAuthError.unsupported
    }

    func fetchShopRecommendations(
        traceId: String,
        session: AppSession,
        sido: String?,
        sigungu: String?,
        limit: Int
    ) async throws -> (response: ShopRecommendResponse, session: AppSession) {
        throw MockAuthError.unsupported
    }

    func fetchReservationSlots(
        traceId: String,
        session: AppSession,
        referenceId: UUID,
        fromDate: String,
        days: Int
    ) async throws -> (response: ReservationSlotsResponse, session: AppSession) {
        throw MockAuthError.unsupported
    }

    func createReservation(
        traceId: String,
        session: AppSession,
        referenceId: UUID,
        slotId: UUID,
        selectedOptionsSnapshot: [String: Int]?,
        attachedImageURL: String?,
        aiGenerationId: UUID?
    ) async throws -> (response: ReservationCreateResponse, session: AppSession) {
        throw MockAuthError.unsupported
    }

    func fetchReservationList(
        traceId: String,
        session: AppSession,
        segment: ReservationListSegment,
        limit: Int,
        cursor: String?
    ) async throws -> (response: ReservationListResponse, session: AppSession) {
        throw MockAuthError.unsupported
    }

    func deleteMyAccount(
        traceId: String,
        session: AppSession,
        reason: String?
    ) async throws {
        switch deleteMyAccountBehavior {
        case .unsupported:
            throw MockAuthError.unsupported
        case .success:
            return
        case let .failure(error):
            throw error
        }
    }

    func signOut(traceId: String) async {
    }

    func clearLocalSession() async {
        clearLocalSessionCallCount += 1
    }
}
