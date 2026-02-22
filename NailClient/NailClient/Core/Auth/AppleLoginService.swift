//
//  AppleLoginService.swift
//  NailClient
//

import AuthenticationServices
import Foundation
import OSLog
import UIKit

enum AppleLoginServiceError: LocalizedError {
    case missingPresentationAnchor
    case missingIdentityToken
    case invalidIdentityTokenEncoding
    case authorizationFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingPresentationAnchor:
            return "Apple 로그인 화면을 표시할 수 없습니다."
        case .missingIdentityToken:
            return "Apple ID 토큰을 가져오지 못했습니다."
        case .invalidIdentityTokenEncoding:
            return "Apple ID 토큰 형식이 올바르지 않습니다."
        case .authorizationFailed:
            return "Apple 로그인에 실패했습니다."
        case .cancelled:
            return "Apple 로그인이 취소되었습니다."
        }
    }
}

final class AppleLoginService {
    private var activeSession: AppleAuthorizationSession?

    @MainActor
    func loginIDToken(traceId: String) async throws -> String {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let anchor = try presentationAnchor()

        do {
            return try await withCheckedThrowingContinuation { continuation in
                let session = AppleAuthorizationSession(anchor: anchor) { [weak self] result in
                    self?.activeSession = nil
                    continuation.resume(with: result)
                }
                self.activeSession = session
                session.perform(request: request)
            }
        } catch {
            AppLog.auth.error(
                "\(AppLog.prefix(traceId, "AUTH")) apple authorization failed: \(String(describing: error), privacy: .public)"
            )
            throw error
        }
    }

    @MainActor
    private func presentationAnchor() throws -> ASPresentationAnchor {
        let activeScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }

        if let keyWindow = activeScenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) {
            return keyWindow
        }

        if let fallbackWindow = activeScenes
            .flatMap(\.windows)
            .first {
            return fallbackWindow
        }

        throw AppleLoginServiceError.missingPresentationAnchor
    }
}

@MainActor
private final class AppleAuthorizationSession: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let anchor: ASPresentationAnchor
    private let onComplete: (Result<String, Error>) -> Void
    private var finished = false

    init(
        anchor: ASPresentationAnchor,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        self.anchor = anchor
        self.onComplete = onComplete
    }

    func perform(request: ASAuthorizationAppleIDRequest) {
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        _ = controller
        return anchor
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        _ = controller

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(with: .failure(AppleLoginServiceError.authorizationFailed))
            return
        }

        guard let tokenData = credential.identityToken else {
            finish(with: .failure(AppleLoginServiceError.missingIdentityToken))
            return
        }

        guard let idToken = String(data: tokenData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !idToken.isEmpty else {
            finish(with: .failure(AppleLoginServiceError.invalidIdentityTokenEncoding))
            return
        }

        finish(with: .success(idToken))
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        _ = controller

        if let authorizationError = error as? ASAuthorizationError,
           authorizationError.code == .canceled {
            finish(with: .failure(AppleLoginServiceError.cancelled))
            return
        }

        finish(with: .failure(error))
    }

    private func finish(with result: Result<String, Error>) {
        guard !finished else { return }
        finished = true
        onComplete(result)
    }
}
