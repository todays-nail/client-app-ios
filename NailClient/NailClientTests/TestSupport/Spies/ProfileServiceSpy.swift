import Foundation
@testable import NailClient

@MainActor
final class ProfileServiceSpy: ProfileServicing {
    var errorMessage: String?

    private let updateMyProfileResult: Bool
    private let uploadProfileImageResult: Result<String, Error>
    private let updateMyProfileImageResult: Bool

    private(set) var updateMyProfileCallCount: Int = 0
    private(set) var uploadProfileImageCallCount: Int = 0
    private(set) var updateMyProfileImageCallCount: Int = 0
    private(set) var capturedNicknames: [String] = []
    private(set) var capturedProfileImageURLs: [String?] = []

    init(
        updateMyProfileResult: Bool = true,
        uploadProfileImageResult: Result<String, Error> = .success("https://example.com/uploaded-profile.png"),
        updateMyProfileImageResult: Bool = true,
        errorMessage: String? = nil
    ) {
        self.updateMyProfileResult = updateMyProfileResult
        self.uploadProfileImageResult = uploadProfileImageResult
        self.updateMyProfileImageResult = updateMyProfileImageResult
        self.errorMessage = errorMessage
    }

    func updateMyProfile(nickname: String) async -> Bool {
        updateMyProfileCallCount += 1
        capturedNicknames.append(nickname)
        return updateMyProfileResult
    }

    func uploadProfileImage(imageData: Data) async throws -> String {
        _ = imageData
        uploadProfileImageCallCount += 1
        return try uploadProfileImageResult.get()
    }

    func updateMyProfileImage(profileImageURL: String?) async -> Bool {
        updateMyProfileImageCallCount += 1
        capturedProfileImageURLs.append(profileImageURL)
        return updateMyProfileImageResult
    }
}
