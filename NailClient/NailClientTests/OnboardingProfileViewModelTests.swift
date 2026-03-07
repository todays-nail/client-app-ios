import Testing
import UIKit
@testable import NailClient

@MainActor
struct OnboardingProfileViewModelTests {
    @Test
    func submit_이미지업로드성공시_업로드URL로완료요청한다() async {
        let uploadedProfileImageURL = "https://example.com/new-profile.jpg"
        let service = OnboardingProfileServiceSpy(
            uploadProfileImageResult: .success(uploadedProfileImageURL)
        )
        let viewModel = OnboardingProfileViewModel(
            prefill: OnboardingPrefill(nickname: "tester", profileImageURL: "https://example.com/old.png")
        )
        viewModel.nickname = "tester"
        viewModel.selectedStyles = [.natural]
        viewModel.profileUIImage = makeProfileImage()
        viewModel.bind(service: service)

        await viewModel.submit()

        #expect(service.uploadProfileImageCallCount == 1)
        #expect(service.completeOnboardingCallCount == 1)
        #expect(service.capturedNicknames == ["tester"])
        #expect(service.capturedProfileImageURLs == [uploadedProfileImageURL])
        #expect(viewModel.photoUploadNoticeMessage == nil)
    }

    @Test
    func submit_이미지업로드실패시_fallbackURL로완료요청하고안내문구를노출한다() async {
        let fallbackURL = "https://example.com/original.png"
        let service = OnboardingProfileServiceSpy(
            uploadProfileImageResult: .failure(OnboardingProfileServiceSpyError.uploadFailed)
        )
        let viewModel = OnboardingProfileViewModel(
            prefill: OnboardingPrefill(nickname: "tester", profileImageURL: fallbackURL)
        )
        viewModel.nickname = "tester"
        viewModel.selectedStyles = [.natural]
        viewModel.profileUIImage = makeProfileImage()
        viewModel.bind(service: service)

        await viewModel.submit()

        #expect(service.uploadProfileImageCallCount == 1)
        #expect(service.completeOnboardingCallCount == 1)
        #expect(service.capturedProfileImageURLs == [fallbackURL])
        #expect(viewModel.photoUploadNoticeMessage?.isEmpty == false)
    }

    private func makeProfileImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2))
        return renderer.image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
    }
}

private enum OnboardingProfileServiceSpyError: Error {
    case uploadFailed
}

@MainActor
private final class OnboardingProfileServiceSpy: OnboardingProfileServicing {
    private let uploadProfileImageResult: Result<String, Error>

    private(set) var uploadProfileImageCallCount: Int = 0
    private(set) var completeOnboardingCallCount: Int = 0
    private(set) var capturedNicknames: [String] = []
    private(set) var capturedProfileImageURLs: [String?] = []

    init(uploadProfileImageResult: Result<String, Error>) {
        self.uploadProfileImageResult = uploadProfileImageResult
    }

    func uploadProfileImage(imageData: Data) async throws -> String {
        _ = imageData
        uploadProfileImageCallCount += 1
        return try uploadProfileImageResult.get()
    }

    func completeOnboarding(nickname: String, profileImageURL: String?) async {
        completeOnboardingCallCount += 1
        capturedNicknames.append(nickname)
        capturedProfileImageURLs.append(profileImageURL)
    }
}
