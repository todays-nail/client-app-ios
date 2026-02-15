//
//  KakaoLoginService.swift
//  NailClient
//

import Foundation
import KakaoSDKAuth
import KakaoSDKUser
import OSLog

enum KakaoLoginServiceError: Error {
    case missingAccessToken
}

final class KakaoLoginService {
    func loginAccessToken(traceId: String) async throws -> String {
        let oauth = try await login(traceId: traceId)
        guard !oauth.accessToken.isEmpty else { throw KakaoLoginServiceError.missingAccessToken }
        return oauth.accessToken
    }

    private func login(traceId: String) async throws -> OAuthToken {
        if UserApi.isKakaoTalkLoginAvailable() {
            AppLog.auth.debug("\(AppLog.prefix(traceId, "AUTH")) KakaoTalk login available -> loginWithKakaoTalk")
            return try await withCheckedThrowingContinuation { cont in
                UserApi.shared.loginWithKakaoTalk { token, error in
                    if let error {
                        AppLog.auth.error("\(AppLog.prefix(traceId, "AUTH")) KakaoTalk login failed: \(String(describing: error), privacy: .public)")
                        cont.resume(throwing: error)
                        return
                    }
                    if let token { cont.resume(returning: token); return }
                    cont.resume(throwing: KakaoLoginServiceError.missingAccessToken)
                }
            }
        }

        AppLog.auth.debug("\(AppLog.prefix(traceId, "AUTH")) KakaoTalk not available -> loginWithKakaoAccount")
        return try await withCheckedThrowingContinuation { cont in
            UserApi.shared.loginWithKakaoAccount { token, error in
                if let error {
                    AppLog.auth.error("\(AppLog.prefix(traceId, "AUTH")) KakaoAccount login failed: \(String(describing: error), privacy: .public)")
                    cont.resume(throwing: error)
                    return
                }
                if let token { cont.resume(returning: token); return }
                cont.resume(throwing: KakaoLoginServiceError.missingAccessToken)
            }
        }
    }
}
