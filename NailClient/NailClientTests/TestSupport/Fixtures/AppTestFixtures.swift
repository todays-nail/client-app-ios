import Foundation
@testable import NailClient

enum AppTestFixtures {
    static func makeUser(
        id: UUID = UUID(),
        nickname: String?,
        profileImageURL: String?
    ) -> AppUser {
        AppUser.preview(
            id: id,
            nickname: nickname,
            profileImageURL: profileImageURL
        )
    }

    static func makeSession(
        accessToken: String = "access",
        refreshToken: String = "refresh"
    ) -> AppSession {
        AppSession(accessToken: accessToken, refreshToken: refreshToken)
    }

    static func makeAuthResult(
        session: AppSession,
        user: AppUser,
        needsOnboarding: Bool,
        onboardingPrefill: OnboardingPrefill? = nil
    ) -> AuthResult {
        AuthResult(
            session: session,
            user: user,
            needsOnboarding: needsOnboarding,
            onboardingPrefill: onboardingPrefill
        )
    }
}
