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

    private func makeUser(nickname: String?, profileImageURL: String?) -> AppUser {
        AppUser(
            id: UUID(),
            role: nil,
            nickname: nickname,
            phone: nil,
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
}

private actor MockAuthService: AuthServicing {
    let behavior: MockAutoLoginBehavior
    private(set) var clearLocalSessionCallCount: Int = 0

    init(behavior: MockAutoLoginBehavior) {
        self.behavior = behavior
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

    func signOut(traceId: String) async {
    }

    func clearLocalSession() async {
        clearLocalSessionCallCount += 1
    }
}
