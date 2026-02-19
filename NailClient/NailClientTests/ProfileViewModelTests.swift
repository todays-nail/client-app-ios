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
    func 닉네임_유효성검증을수행한다() {
        let viewModel = ProfileViewModel()

        viewModel.nickname = ""
        #expect(viewModel.nicknameValidationMessage != nil)

        viewModel.nickname = "a"
        #expect(viewModel.nicknameValidationMessage != nil)

        viewModel.nickname = "valid_user"
        #expect(viewModel.nicknameValidationMessage == nil)
    }

    @Test
    func 동일값이면_저장버튼이비활성화된다() {
        let user = makeUser(nickname: "tester")
        let viewModel = ProfileViewModel()

        viewModel.sync(from: user)

        #expect(viewModel.hasChanges == false)
        #expect(viewModel.isSaveEnabled == false)
    }

    @Test
    func showComingSoon_신규케이스를정상설정한다() {
        let viewModel = ProfileViewModel()

        viewModel.showComingSoon(.fittedAIImages)
        #expect(viewModel.comingSoonItem == .fittedAIImages)

        viewModel.showComingSoon(.settings)
        #expect(viewModel.comingSoonItem == .settings)
    }

    @Test
    func makeHeaderDisplay_닉네임없으면_기본문구를반환한다() {
        let viewModel = ProfileViewModel()
        let user = makeUser(nickname: nil)

        let display = viewModel.makeHeaderDisplay(from: user)

        #expect(display.name == "닉네임 미설정")
    }

    @Test
    func makeHeaderDisplay_프로필URL이비었거나잘못되면_nil을반환한다() {
        let viewModel = ProfileViewModel()
        let emptyURLUser = makeUser(nickname: "tester", profileImageURL: " ")
        let invalidURLUser = makeUser(nickname: "tester", profileImageURL: "https://exam ple.com")

        let emptyURLDisplay = viewModel.makeHeaderDisplay(from: emptyURLUser)
        let invalidURLDisplay = viewModel.makeHeaderDisplay(from: invalidURLUser)

        #expect(emptyURLDisplay.profileImageURL == nil)
        #expect(invalidURLDisplay.profileImageURL == nil)
    }

    @Test
    func makeHeaderDisplay_정상값이면_trim후반영한다() {
        let viewModel = ProfileViewModel()
        let user = makeUser(
            nickname: "  네일매니아  ",
            profileImageURL: " https://example.com/profile.png "
        )

        let display = viewModel.makeHeaderDisplay(from: user)

        #expect(display.name == "네일매니아")
        #expect(display.profileImageURL?.absoluteString == "https://example.com/profile.png")
    }

    @Test
    func showProfilePhotoUpdatedToast_호출시_메시지를즉시설정한다() {
        let viewModel = ProfileViewModel(profilePhotoToastDuration: .seconds(1))

        viewModel.showProfilePhotoUpdatedToast()

        #expect(viewModel.profilePhotoToastMessage == "프로필 사진이 변경되었어요.")
    }

    @Test
    func showProfilePhotoUpdatedToast_지속시간후_자동으로사라진다() async {
        let viewModel = ProfileViewModel(profilePhotoToastDuration: .milliseconds(30))

        viewModel.showProfilePhotoUpdatedToast()
        #expect(viewModel.profilePhotoToastMessage == "프로필 사진이 변경되었어요.")

        try? await Task.sleep(for: .milliseconds(120))

        #expect(viewModel.profilePhotoToastMessage == nil)
    }

    @Test
    func dismissProfilePhotoUpdatedToast_호출시_즉시사라진다() {
        let viewModel = ProfileViewModel(profilePhotoToastDuration: .seconds(1))

        viewModel.showProfilePhotoUpdatedToast()
        viewModel.dismissProfilePhotoUpdatedToast()

        #expect(viewModel.profilePhotoToastMessage == nil)
    }

    @Test
    func save_성공시_시트를닫고에러를초기화한다() async {
        let currentSession = AppSession(accessToken: "access", refreshToken: "refresh")
        let updatedSession = AppSession(accessToken: "access-new", refreshToken: "refresh-new")
        let currentUser = makeUser(nickname: "before")
        let updatedUser = AppUser(
            id: currentUser.id,
            role: currentUser.role,
            nickname: "after",
            profileImageURL: currentUser.profileImageURL,
            defaultRegionID: nil,
            defaultRegionLabel: nil,
            defaultServiceRegionID: nil,
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

        await viewModel.save(appViewModel: appViewModel)

        #expect(viewModel.isSaving == false)
        #expect(viewModel.isEditSheetPresented == false)
        #expect(viewModel.saveErrorMessage == nil)
        #expect(appViewModel.currentUser?.nickname == "after")
    }

    @Test
    func save_실패시_시트를유지하고에러메시지를보여준다() async {
        let session = AppSession(accessToken: "access", refreshToken: "refresh")
        let currentUser = makeUser(nickname: "before")

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

    private func makeUser(nickname: String?, profileImageURL: String? = "https://example.com/profile.png") -> AppUser {
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

    func signInWithGoogle(traceId: String) async throws -> AuthResult {
        throw ProfileMockError.unsupported
    }

    func signInWithApple(traceId: String) async throws -> AuthResult {
        throw ProfileMockError.unsupported
    }

    func completeOnboarding(
        traceId: String,
        session: AppSession,
        nickname: String,
        profileImageURL: String?
    ) async throws -> (user: AppUser, needsOnboarding: Bool, session: AppSession) {
        throw ProfileMockError.unsupported
    }

    func updateMyProfile(
        traceId: String,
        session: AppSession,
        nickname: String,
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
        extensionMode: NailGenExtensionMode,
        handObjectPath: String,
        referenceObjectPath: String
    ) async throws -> (response: NailGenCreateJobResponse, session: AppSession) {
        throw ProfileMockError.unsupported
    }

    func refineNailGenerationJob(
        traceId: String,
        session: AppSession,
        sourceJobId: UUID,
        shape: NailGenShape,
        extensionMode: NailGenExtensionMode
    ) async throws -> (response: NailGenRefineJobResponse, session: AppSession) {
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
