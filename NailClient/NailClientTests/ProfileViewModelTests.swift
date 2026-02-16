//
//  ProfileViewModelTests.swift
//  NailClientTests
//

import Foundation
import Testing
@testable import NailClient

@MainActor
struct ProfileViewModelTests {
    @Test
    func 닉네임_전화번호_유효성검증을수행한다() {
        let viewModel = ProfileViewModel()

        viewModel.nickname = ""
        #expect(viewModel.nicknameValidationMessage != nil)

        viewModel.nickname = "a"
        #expect(viewModel.nicknameValidationMessage != nil)

        viewModel.nickname = "valid_user"
        #expect(viewModel.nicknameValidationMessage == nil)

        viewModel.phone = "010-12"
        #expect(viewModel.phoneValidationMessage != nil)

        viewModel.phone = "010-1234-5678"
        #expect(viewModel.phoneValidationMessage == nil)
    }

    @Test
    func 동일값이면_저장버튼이비활성화된다() {
        let user = makeUser(nickname: "tester", phone: "010-1234-5678")
        let viewModel = ProfileViewModel()

        viewModel.sync(from: user)

        #expect(viewModel.hasChanges == false)
        #expect(viewModel.isSaveEnabled == false)
    }

    @Test
    func save_성공시_시트를닫고에러를초기화한다() async {
        let currentSession = AppSession(accessToken: "access", refreshToken: "refresh")
        let updatedSession = AppSession(accessToken: "access-new", refreshToken: "refresh-new")
        let currentUser = makeUser(nickname: "before", phone: "010-0000-0000")
        let updatedUser = AppUser(
            id: currentUser.id,
            role: currentUser.role,
            nickname: "after",
            phone: "010-9999-9999",
            profileImageURL: currentUser.profileImageURL,
            createdAt: currentUser.createdAt,
            updatedAt: currentUser.updatedAt
        )

        let authService = ProfileMockAuthService(
            autoLoginResult: AuthResult(
                session: currentSession,
                user: currentUser,
                needsOnboarding: false,
                onboardingPrefill: nil
            ),
            updateResult: .success((updatedUser, updatedSession))
        )

        let appViewModel = AppViewModel(
            authService: authService,
            launchTiming: .init(
                minimumSplashDuration: .milliseconds(10),
                autoLoginTimeout: .milliseconds(120)
            )
        )
        await appViewModel.start()

        let viewModel = ProfileViewModel()
        viewModel.beginEdit(from: appViewModel.currentUser)
        viewModel.nickname = "after"
        viewModel.phone = "010-9999-9999"

        await viewModel.save(appViewModel: appViewModel)

        #expect(viewModel.isSaving == false)
        #expect(viewModel.isEditSheetPresented == false)
        #expect(viewModel.saveErrorMessage == nil)
        #expect(appViewModel.currentUser?.nickname == "after")
    }

    @Test
    func save_실패시_시트를유지하고에러메시지를보여준다() async {
        let session = AppSession(accessToken: "access", refreshToken: "refresh")
        let currentUser = makeUser(nickname: "before", phone: "010-0000-0000")

        let authService = ProfileMockAuthService(
            autoLoginResult: AuthResult(
                session: session,
                user: currentUser,
                needsOnboarding: false,
                onboardingPrefill: nil
            ),
            updateResult: .failure(ProfileMockError.updateFailed)
        )

        let appViewModel = AppViewModel(
            authService: authService,
            launchTiming: .init(
                minimumSplashDuration: .milliseconds(10),
                autoLoginTimeout: .milliseconds(120)
            )
        )
        await appViewModel.start()

        let viewModel = ProfileViewModel()
        viewModel.beginEdit(from: appViewModel.currentUser)
        viewModel.nickname = "after"

        await viewModel.save(appViewModel: appViewModel)

        #expect(viewModel.isSaving == false)
        #expect(viewModel.isEditSheetPresented == true)
        #expect(viewModel.saveErrorMessage?.contains("프로필 수정 실패") == true)
    }

    private func makeUser(nickname: String?, phone: String?) -> AppUser {
        AppUser(
            id: UUID(),
            role: nil,
            nickname: nickname,
            phone: phone,
            profileImageURL: "https://example.com/profile.png",
            createdAt: nil,
            updatedAt: nil
        )
    }
}

private enum ProfileMockError: Error {
    case unsupported
    case updateFailed
}

private actor ProfileMockAuthService: AuthServicing {
    let autoLoginResult: AuthResult?
    let updateResult: Result<(AppUser, AppSession), Error>

    init(autoLoginResult: AuthResult?, updateResult: Result<(AppUser, AppSession), Error>) {
        self.autoLoginResult = autoLoginResult
        self.updateResult = updateResult
    }

    func tryAutoLogin(traceId: String, timeout: Duration) async throws -> AuthResult? {
        autoLoginResult
    }

    func signInWithKakao(traceId: String) async throws -> AuthResult {
        throw ProfileMockError.unsupported
    }

    func completeOnboarding(
        traceId: String,
        session: AppSession,
        nickname: String,
        phone: String?,
        profileImageURL: String?
    ) async throws -> (user: AppUser, needsOnboarding: Bool, session: AppSession) {
        throw ProfileMockError.unsupported
    }

    func updateMyProfile(
        traceId: String,
        session: AppSession,
        nickname: String,
        phone: String?,
        profileImageURL: String?
    ) async throws -> (user: AppUser, session: AppSession) {
        let result = try updateResult.get()
        return (user: result.0, session: result.1)
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
        throw ProfileMockError.unsupported
    }

    func uploadImageToSignedURL(
        traceId: String,
        signedUploadURL: String,
        contentType: String,
        imageData: Data
    ) async throws {
        throw ProfileMockError.unsupported
    }

    func createNailGenerationJob(
        traceId: String,
        session: AppSession,
        shape: NailGenShape,
        userPrompt: String,
        handObjectPath: String,
        referenceObjectPath: String
    ) async throws -> (response: NailGenCreateJobResponse, session: AppSession) {
        throw ProfileMockError.unsupported
    }

    func getNailGenerationJobStatus(
        traceId: String,
        session: AppSession,
        jobId: UUID
    ) async throws -> (response: NailGenJobStatusResponse, session: AppSession) {
        throw ProfileMockError.unsupported
    }

    func signOut(traceId: String) async {
    }

    func clearLocalSession() async {
    }
}
