//
//  GoogleLoginService.swift
//  NailClient
//

import Foundation
import GoogleSignIn
import OSLog
import UIKit

enum GoogleLoginServiceError: LocalizedError {
    case missingClientID
    case missingPresentingViewController
    case missingIDToken

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Google Client ID 설정이 없습니다."
        case .missingPresentingViewController:
            return "Google 로그인 화면을 표시할 수 없습니다."
        case .missingIDToken:
            return "Google ID 토큰을 가져오지 못했습니다."
        }
    }
}

final class GoogleLoginService {
    @MainActor
    func loginIDToken(traceId: String) async throws -> String {
        guard let clientID = AppConfig.googleIOSClientID else {
            AppLog.auth.error("\(AppLog.prefix(traceId, "AUTH")) missing GOOGLE_IOS_CLIENT_ID in Info.plist")
            throw GoogleLoginServiceError.missingClientID
        }

        let config = GIDConfiguration(
            clientID: clientID,
            serverClientID: AppConfig.googleWebClientID
        )
        GIDSignIn.sharedInstance.configuration = config

        let presentingViewController = try topMostPresentingViewController()
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
        guard let idToken = result.user.idToken?.tokenString,
              !idToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GoogleLoginServiceError.missingIDToken
        }
        return idToken
    }

    @MainActor
    private func topMostPresentingViewController() throws -> UIViewController {
        let activeScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }

        let rootViewController = activeScenes
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .rootViewController
            ?? activeScenes.flatMap { $0.windows }.first?.rootViewController

        guard let rootViewController else {
            throw GoogleLoginServiceError.missingPresentingViewController
        }

        var top = rootViewController
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
