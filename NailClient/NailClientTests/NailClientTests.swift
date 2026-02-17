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
            phone: "010-1111-2222",
            profileImageURL: "https://example.com/profile.png"
        )
        let updatedUser = AppUser(
            id: currentUser.id,
            role: currentUser.role,
            nickname: "after-update",
            phone: "010-9999-8888",
            profileImageURL: currentUser.profileImageURL,
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
        let success = await viewModel.updateMyProfile(
            nickname: "after-update",
            phone: "010-9999-8888"
        )

        #expect(success == true)
        #expect(viewModel.currentUser?.nickname == "after-update")
        #expect(viewModel.currentUser?.phone == "010-9999-8888")
        #expect(viewModel.session?.accessToken == "access-new")
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func updateMyProfile_실패시_에러메시지를설정하고유저정보를유지한다() async {
        let currentSession = AppSession(accessToken: "access", refreshToken: "refresh")
        let currentUser = makeUser(
            nickname: "before-update",
            phone: "010-1111-2222",
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
        let success = await viewModel.updateMyProfile(
            nickname: "after-update",
            phone: "010-9999-8888"
        )

        #expect(success == false)
        #expect(viewModel.currentUser?.nickname == "before-update")
        #expect(viewModel.currentUser?.phone == "010-1111-2222")
        #expect(viewModel.errorMessage?.contains("프로필 수정 실패") == true)
    }

    private func makeUser(
        nickname: String?,
        phone: String? = nil,
        profileImageURL: String?
    ) -> AppUser {
        AppUser(
            id: UUID(),
            role: nil,
            nickname: nickname,
            phone: phone,
            profileImageURL: profileImageURL,
            createdAt: nil,
            updatedAt: nil
        )
    }
}

private enum MockAutoLoginBehavior {
    case immediate(AuthResult?)
    case respectTimeoutAndFail
}

private enum MockAuthError: Error {
    case timeout
    case unsupported
    case profileUpdateFailed
}

private enum MockUpdateMyProfileBehavior {
    case unsupported
    case success(user: AppUser, session: AppSession)
    case failure(Error)
}

private actor MockAuthService: AuthServicing {
    let behavior: MockAutoLoginBehavior
    let updateMyProfileBehavior: MockUpdateMyProfileBehavior
    private(set) var clearLocalSessionCallCount: Int = 0

    init(
        behavior: MockAutoLoginBehavior,
        updateMyProfileBehavior: MockUpdateMyProfileBehavior = .unsupported
    ) {
        self.behavior = behavior
        self.updateMyProfileBehavior = updateMyProfileBehavior
    }

    func tryAutoLogin(traceId: String, timeout: Duration) async throws -> AuthResult? {
        switch behavior {
        case .immediate(let result):
            return result
        case .respectTimeoutAndFail:
            try await Task.sleep(for: timeout + .milliseconds(80))
            throw MockAuthError.timeout
        }
    }

    func signInWithKakao(traceId: String) async throws -> AuthResult {
        throw MockAuthError.unsupported
    }

    func completeOnboarding(
        traceId: String,
        session: AppSession,
        nickname: String,
        phone: String?,
        profileImageURL: String?
    ) async throws -> (user: AppUser, needsOnboarding: Bool, session: AppSession) {
        throw MockAuthError.unsupported
    }

    func updateMyProfile(
        traceId: String,
        session: AppSession,
        nickname: String,
        phone: String?,
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

    func fetchFeedDetail(
        traceId: String,
        session: AppSession,
        postId: UUID
    ) async throws -> (response: FeedDetailResponse, session: AppSession) {
        throw MockAuthError.unsupported
    }

    func signOut(traceId: String) async {
    }

    func clearLocalSession() async {
        clearLocalSessionCallCount += 1
    }
}
