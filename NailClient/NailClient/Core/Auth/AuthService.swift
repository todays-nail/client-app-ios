//
//  AuthService.swift
//  NailClient
//
//  Orchestrates Kakao login + Supabase Edge Functions session lifecycle.
//

import Foundation
import OSLog

struct OnboardingPrefill: Sendable, Equatable {
    let nickname: String?
    let profileImageURL: String?
}

struct AuthResult: Sendable {
    let session: AppSession
    let user: AppUser
    let needsOnboarding: Bool
    let onboardingPrefill: OnboardingPrefill?
}

final class AuthService {
    private let keychain: KeychainStore
    private let api: EdgeAPIClient
    private let kakao: KakaoLoginService

    init(
        keychain: KeychainStore = KeychainStore(service: "com.todaysnail.NailClient"),
        api: EdgeAPIClient = EdgeAPIClient(),
        kakao: KakaoLoginService = KakaoLoginService()
    ) {
        self.keychain = keychain
        self.api = api
        self.kakao = kakao
    }

    func ensureDeviceId() -> String {
        if let existing = keychain.deviceId, !existing.isEmpty { return existing }
        let newId = UUID().uuidString
        keychain.deviceId = newId
        return newId
    }

    func tryAutoLogin(traceId: String) async throws -> AuthResult? {
        _ = ensureDeviceId()
        guard let refreshToken = keychain.refreshToken, !refreshToken.isEmpty else { return nil }

        let session = try await refreshSession(traceId: traceId, refreshToken: refreshToken)
        let me = try await api.usersMe(traceId: traceId, accessToken: session.accessToken)
        return AuthResult(session: session, user: me.user, needsOnboarding: me.needsOnboarding)
    }

    func signInWithKakao(traceId: String) async throws -> AuthResult {
        let deviceId = ensureDeviceId()
        let kakaoAccessToken = try await kakao.loginAccessToken(traceId: traceId)

        let response = try await api.authKakao(
            traceId: traceId,
            kakaoAccessToken: kakaoAccessToken,
            deviceId: deviceId
        )

        let session = AppSession(accessToken: response.accessToken, refreshToken: response.refreshToken)
        keychain.refreshToken = response.refreshToken
        return AuthResult(session: session, user: response.user, needsOnboarding: response.needsOnboarding)
    }

    func completeOnboarding(
        traceId: String,
        session: AppSession,
        nickname: String,
        phone: String?,
        profileImageURL: String?
    ) async throws -> (user: AppUser, needsOnboarding: Bool, session: AppSession) {
        let (updated, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.patchUsersMe(
                traceId: traceId,
                accessToken: accessToken,
                nickname: nickname,
                phone: phone,
                profileImageURL: profileImageURL
            )
        }

        return (updated.user, updated.needsOnboarding, newSession)
    }

    func signOut(traceId: String) async {
        _ = ensureDeviceId()
        guard let refreshToken = keychain.refreshToken, let deviceId = keychain.deviceId else {
            keychain.refreshToken = nil
            return
        }

        do {
            _ = try await api.authLogout(traceId: traceId, refreshToken: refreshToken, deviceId: deviceId)
        } catch {
            // Server revoke failure must not block local sign out.
            AppLog.api.error("\(AppLog.prefix(traceId, "API")) signOut server revoke failed: \(String(describing: error), privacy: .public)")
        }

        keychain.refreshToken = nil
    }

    func clearLocalSession() {
        keychain.refreshToken = nil
    }

    private func refreshSession(traceId: String, refreshToken: String) async throws -> AppSession {
        guard let deviceId = keychain.deviceId else {
            throw EdgeAPIError(statusCode: 400, message: "Missing deviceId", errorId: traceId)
        }

        let refreshed = try await api.authRefresh(traceId: traceId, refreshToken: refreshToken, deviceId: deviceId)
        keychain.refreshToken = refreshed.refreshToken
        return AppSession(accessToken: refreshed.accessToken, refreshToken: refreshed.refreshToken)
    }

    private func withAutoRefresh<T>(
        traceId: String,
        session: AppSession,
        _ block: (String) async throws -> T
    ) async throws -> (T, AppSession) {
        do {
            return (try await block(session.accessToken), session)
        } catch let apiError as EdgeAPIError {
            if apiError.statusCode != 401 { throw apiError }

            // 401 is retried once after refresh (no infinite loops).
            AppLog.auth.error("\(AppLog.prefix(traceId, "AUTH")) got 401 -> trying refresh once")
            let refreshed = try await refreshSession(traceId: traceId, refreshToken: session.refreshToken)
            return (try await block(refreshed.accessToken), refreshed)
        }
    }
}
