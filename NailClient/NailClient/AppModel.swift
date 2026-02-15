//
//  AppModel.swift
//  NailClient
//
//  Created by 김대환 on 2/15/26.
//

import Foundation
import Combine
import KakaoSDKAuth
import OSLog

@MainActor
final class AppModel: ObservableObject {
    enum Route {
        case login
        case onboarding
        case home
    }

    @Published private(set) var route: Route = .login
    @Published var errorMessage: String?
    @Published private(set) var currentUser: AppUser?

    private let keychain = KeychainStore(service: "com.todaysnail.NailClient")
    private let api = EdgeAPIClient()
    private let kakao = KakaoLoginService()

    private var accessToken: String?

    func start() async {
        errorMessage = nil
        await ensureDeviceId()

        guard let refreshToken = keychain.refreshToken else {
            route = .login
            return
        }

        let traceId = AppLog.makeErrorId()
        do {
            try await refreshSessionIfNeeded(traceId: traceId, refreshToken: refreshToken)
            try await fetchMeAndRoute(traceId: traceId)
        } catch {
            // 자동 로그인 실패 시: 로컬 세션을 정리하고 로그인 화면으로 보냄
            AppLog.auth.error(
                "\(AppLog.prefix(traceId, "AUTH")) auto-login failed. hasRefresh=\(true, privacy: .public) hasDeviceId=\((self.keychain.deviceId != nil), privacy: .public) err=\(String(describing: error), privacy: .public)"
            )
            clearLocalSession()
            route = .login
        }
    }

    func signInWithKakao() async {
        errorMessage = nil

        await ensureDeviceId()
        guard let deviceId = keychain.deviceId else {
            let traceId = AppLog.makeErrorId()
            AppLog.auth.error("\(AppLog.prefix(traceId, "AUTH")) deviceId missing (failed to generate)")
            errorMessage = "디바이스 식별자 생성 실패 (\(traceId))"
            route = .login
            return
        }

        let traceId = AppLog.makeErrorId()
        do {
            let kakaoAccessToken = try await kakao.loginAccessToken(traceId: traceId)
            let response = try await api.authKakao(
                traceId: traceId,
                kakaoAccessToken: kakaoAccessToken,
                deviceId: deviceId
            )

            accessToken = response.accessToken
            keychain.refreshToken = response.refreshToken
            currentUser = response.user

            route = response.needsOnboarding ? .onboarding : .home
        } catch {
            AppLog.auth.error("\(AppLog.prefix(traceId, "AUTH")) signInWithKakao failed: \(String(describing: error), privacy: .public)")
            errorMessage = "카카오 로그인 실패 (\(traceId)): \(error.localizedDescription)"
            route = .login
        }
    }

    func completeOnboarding(nickname: String, phone: String?, profileImageURL: String?) async {
        errorMessage = nil
        let traceId = AppLog.makeErrorId()
        do {
            guard let accessToken else {
                AppLog.api.error("\(AppLog.prefix(traceId, "API")) onboarding blocked: missing accessToken")
                throw EdgeAPIError(statusCode: 401, message: "No access token", errorId: traceId)
            }

            let updated = try await withAutoRefresh(traceId: traceId) {
                try await api.patchUsersMe(
                    traceId: traceId,
                    accessToken: accessToken,
                    nickname: nickname,
                    phone: phone,
                    profileImageURL: profileImageURL
                )
            }

            currentUser = updated.user
            route = updated.needsOnboarding ? .onboarding : .home
        } catch {
            AppLog.api.error("\(AppLog.prefix(traceId, "API")) completeOnboarding failed: \(String(describing: error), privacy: .public)")
            errorMessage = "회원가입(프로필 저장) 실패 (\(traceId)): \(error.localizedDescription)"
        }
    }

    func signOut() async {
        errorMessage = nil

        await ensureDeviceId()
        if let refreshToken = keychain.refreshToken, let deviceId = keychain.deviceId {
            let traceId = AppLog.makeErrorId()
            do {
                _ = try await api.authLogout(traceId: traceId, refreshToken: refreshToken, deviceId: deviceId)
            } catch {
                // 서버 로그아웃 실패는 로컬 로그아웃을 막지 않음
                AppLog.api.error("\(AppLog.prefix(traceId, "API")) signOut server revoke failed: \(String(describing: error), privacy: .public)")
            }
        }

        clearLocalSession()
        route = .login
    }

    func handleOpenURL(_ url: URL) {
        // KakaoSDK 로그인 redirect 처리
        _ = AuthController.handleOpenUrl(url: url)
    }

    private func ensureDeviceId() async {
        if keychain.deviceId == nil {
            keychain.deviceId = UUID().uuidString
        }
    }

    private func fetchMeAndRoute(traceId: String) async throws {
        guard let accessToken else {
            throw EdgeAPIError(statusCode: 401, message: "No access token", errorId: traceId)
        }

        let me = try await withAutoRefresh(traceId: traceId) {
            try await api.usersMe(traceId: traceId, accessToken: accessToken)
        }

        currentUser = me.user
        route = me.needsOnboarding ? .onboarding : .home
    }

    private func refreshSessionIfNeeded(traceId: String, refreshToken: String) async throws {
        guard let deviceId = keychain.deviceId else {
            throw EdgeAPIError(statusCode: 400, message: "Missing deviceId", errorId: traceId)
        }

        let refreshed = try await api.authRefresh(traceId: traceId, refreshToken: refreshToken, deviceId: deviceId)
        accessToken = refreshed.accessToken
        keychain.refreshToken = refreshed.refreshToken
    }

    private func withAutoRefresh<T>(traceId: String, _ block: () async throws -> T) async throws -> T {
        do {
            return try await block()
        } catch let apiError as EdgeAPIError {
            if apiError.statusCode != 401 {
                throw apiError
            }

            // 401은 1회만 refresh 시도 후 재시도 (무한루프 방지)
            guard let refreshToken = keychain.refreshToken else { throw apiError }
            AppLog.auth.error("\(AppLog.prefix(traceId, "AUTH")) got 401 -> trying refresh once")
            try await refreshSessionIfNeeded(traceId: traceId, refreshToken: refreshToken)
            return try await block()
        }
    }

    private func clearLocalSession() {
        accessToken = nil
        currentUser = nil
        keychain.refreshToken = nil
    }
}

struct AppUser: Codable, Sendable {
    let id: UUID
    let role: String?
    let nickname: String?
    let phone: String?
    let profileImageURL: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case nickname
        case phone
        case profileImageURL = "profile_image_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
