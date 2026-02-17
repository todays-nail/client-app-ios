import Foundation
import Testing
import UIKit
@testable import NailClient

@MainActor
struct OnboardingProfileViewModelTests {

    @Test
    func submit_이미지업로드성공시_업로드URL로완료요청한다() async {
        let session = AppSession(accessToken: "access", refreshToken: "refresh")
        let authService = MockOnboardingAuthService(
            autoLoginResult: AuthResult(
                session: session,
                user: makeUser(nickname: "tester", profileImageURL: "https://example.com/old.png"),
                needsOnboarding: true,
                onboardingPrefill: nil
            ),
            uploadResponse: NailGenUploadURLResponse(
                bucket: "profile-images-public",
                jobId: UUID(),
                objectPath: "user/profile/new.jpg",
                signedUploadURL: "https://example.com/upload",
                publicObjectURL: "https://example.com/new-profile.jpg",
                expiresInSec: 600
            ),
            shouldFailUpload: false
        )

        let appViewModel = AppViewModel(
            authService: authService,
            launchTiming: .init(minimumSplashDuration: .zero, autoLoginTimeout: .seconds(1))
        )
        await appViewModel.start()

        let viewModel = OnboardingProfileViewModel(
            prefill: OnboardingPrefill(nickname: "tester", profileImageURL: "https://example.com/old.png")
        )
        viewModel.nickname = "tester"
        viewModel.selectedStyles = [.natural]
        viewModel.profileUIImage = makeProfileImage()

        await viewModel.submit(appViewModel: appViewModel)

        let capturedProfileURL = await authService.capturedCompleteOnboardingProfileImageURL()
        let capturedKinds = await authService.capturedUploadKinds()
        #expect(capturedProfileURL == "https://example.com/new-profile.jpg")
        #expect(capturedKinds == [.profile])
        #expect(viewModel.photoUploadNoticeMessage == nil)
    }

    @Test
    func submit_이미지업로드실패시_fallbackURL로완료요청하고안내문구를노출한다() async {
        let session = AppSession(accessToken: "access", refreshToken: "refresh")
        let authService = MockOnboardingAuthService(
            autoLoginResult: AuthResult(
                session: session,
                user: makeUser(nickname: "tester", profileImageURL: "https://example.com/original.png"),
                needsOnboarding: true,
                onboardingPrefill: nil
            ),
            uploadResponse: NailGenUploadURLResponse(
                bucket: "profile-images-public",
                jobId: UUID(),
                objectPath: "user/profile/new.jpg",
                signedUploadURL: "https://example.com/upload",
                publicObjectURL: "https://example.com/new-profile.jpg",
                expiresInSec: 600
            ),
            shouldFailUpload: true
        )

        let appViewModel = AppViewModel(
            authService: authService,
            launchTiming: .init(minimumSplashDuration: .zero, autoLoginTimeout: .seconds(1))
        )
        await appViewModel.start()

        let fallbackURL = "https://example.com/original.png"
        let viewModel = OnboardingProfileViewModel(
            prefill: OnboardingPrefill(nickname: "tester", profileImageURL: fallbackURL)
        )
        viewModel.nickname = "tester"
        viewModel.selectedStyles = [.natural]
        viewModel.profileUIImage = makeProfileImage()

        await viewModel.submit(appViewModel: appViewModel)

        let capturedProfileURL = await authService.capturedCompleteOnboardingProfileImageURL()
        #expect(capturedProfileURL == fallbackURL)
        #expect(viewModel.photoUploadNoticeMessage?.isEmpty == false)
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

    private func makeProfileImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2))
        return renderer.image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
    }
}

private enum OnboardingMockError: Error {
    case unsupported
    case uploadFailed
}

private actor MockOnboardingAuthService: AuthServicing {
    private let autoLoginResult: AuthResult
    private let uploadResponse: NailGenUploadURLResponse
    private let shouldFailUpload: Bool

    private var recordedCompleteOnboardingProfileImageURL: String?
    private var recordedKinds: [NailGenUploadKind] = []

    init(
        autoLoginResult: AuthResult,
        uploadResponse: NailGenUploadURLResponse,
        shouldFailUpload: Bool
    ) {
        self.autoLoginResult = autoLoginResult
        self.uploadResponse = uploadResponse
        self.shouldFailUpload = shouldFailUpload
    }

    func capturedCompleteOnboardingProfileImageURL() -> String? {
        recordedCompleteOnboardingProfileImageURL
    }

    func capturedUploadKinds() -> [NailGenUploadKind] {
        recordedKinds
    }

    func tryAutoLogin(traceId: String, timeout: Duration) async throws -> AuthResult? {
        autoLoginResult
    }

    func signInWithKakao(traceId: String) async throws -> AuthResult {
        throw OnboardingMockError.unsupported
    }

    func completeOnboarding(
        traceId: String,
        session: AppSession,
        nickname: String,
        phone: String?,
        profileImageURL: String?
    ) async throws -> (user: AppUser, needsOnboarding: Bool, session: AppSession) {
        let sourceUser = await MainActor.run { autoLoginResult.user }
        recordedCompleteOnboardingProfileImageURL = profileImageURL
        let user = await MainActor.run {
            AppUser(
                id: sourceUser.id,
                role: sourceUser.role,
                nickname: nickname,
                phone: phone,
                profileImageURL: profileImageURL,
                createdAt: sourceUser.createdAt,
                updatedAt: sourceUser.updatedAt
            )
        }
        return (user, false, session)
    }

    func updateMyProfile(
        traceId: String,
        session: AppSession,
        nickname: String,
        phone: String?,
        profileImageURL: String?
    ) async throws -> (user: AppUser, session: AppSession) {
        throw OnboardingMockError.unsupported
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
        recordedKinds.append(kind)
        return (uploadResponse, session)
    }

    func uploadImageToSignedURL(
        traceId: String,
        signedUploadURL: String,
        contentType: String,
        imageData: Data
    ) async throws {
        if shouldFailUpload {
            throw OnboardingMockError.uploadFailed
        }
    }

    func createNailGenerationJob(
        traceId: String,
        session: AppSession,
        shape: NailGenShape,
        userPrompt: String,
        handObjectPath: String,
        referenceObjectPath: String
    ) async throws -> (response: NailGenCreateJobResponse, session: AppSession) {
        throw OnboardingMockError.unsupported
    }

    func refineNailGenerationJob(
        traceId: String,
        session: AppSession,
        sourceJobId: UUID,
        shape: NailGenShape,
        userPrompt: String
    ) async throws -> (response: NailGenRefineJobResponse, session: AppSession) {
        throw OnboardingMockError.unsupported
    }

    func getNailGenerationJobStatus(
        traceId: String,
        session: AppSession,
        jobId: UUID
    ) async throws -> (response: NailGenJobStatusResponse, session: AppSession) {
        throw OnboardingMockError.unsupported
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
        throw OnboardingMockError.unsupported
    }

    func fetchLikedFeedList(
        traceId: String,
        session: AppSession,
        limit: Int,
        cursor: String?
    ) async throws -> (response: FeedListResponse, session: AppSession) {
        throw OnboardingMockError.unsupported
    }

    func fetchFeedDetail(
        traceId: String,
        session: AppSession,
        postId: UUID
    ) async throws -> (response: FeedDetailResponse, session: AppSession) {
        throw OnboardingMockError.unsupported
    }

    func setFeedLike(
        traceId: String,
        session: AppSession,
        postId: UUID,
        isLiked: Bool
    ) async throws -> (response: FeedLikeResponse, session: AppSession) {
        throw OnboardingMockError.unsupported
    }

    func searchShops(
        traceId: String,
        session: AppSession,
        query: String,
        limit: Int
    ) async throws -> (response: ShopSearchResponse, session: AppSession) {
        throw OnboardingMockError.unsupported
    }

    func fetchShopDetail(
        traceId: String,
        session: AppSession,
        shopId: UUID
    ) async throws -> (response: ShopDetailResponse, session: AppSession) {
        throw OnboardingMockError.unsupported
    }

    func fetchShopRecommendations(
        traceId: String,
        session: AppSession,
        sido: String?,
        sigungu: String?,
        limit: Int
    ) async throws -> (response: ShopRecommendResponse, session: AppSession) {
        throw OnboardingMockError.unsupported
    }

    func fetchReservationSlots(
        traceId: String,
        session: AppSession,
        referenceId: UUID,
        fromDate: String,
        days: Int
    ) async throws -> (response: ReservationSlotsResponse, session: AppSession) {
        throw OnboardingMockError.unsupported
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
        throw OnboardingMockError.unsupported
    }

    func fetchReservationList(
        traceId: String,
        session: AppSession,
        segment: ReservationListSegment,
        limit: Int,
        cursor: String?
    ) async throws -> (response: ReservationListResponse, session: AppSession) {
        throw OnboardingMockError.unsupported
    }

    func signOut(traceId: String) async {}
    func clearLocalSession() async {}
}
