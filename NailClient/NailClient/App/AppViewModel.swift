//
//  AppViewModel.swift
//  NailClient
//

import Foundation
import Combine
import KakaoSDKAuth
import OSLog

@MainActor
final class AppViewModel: ObservableObject {
    enum Route {
        case login
        case onboarding
        case home
    }

    @Published private(set) var route: Route = .login
    @Published var errorMessage: String?
    @Published private(set) var currentUser: AppUser?
    @Published private(set) var session: AppSession?
    @Published private(set) var onboardingPrefill: OnboardingPrefill?

    private let authService: AuthService

    init(authService: AuthService? = nil) {
        self.authService = authService ?? AuthService()
    }

    func start() async {
        errorMessage = nil
        let traceId = AppLog.makeErrorId()

        do {
            if let result = try await authService.tryAutoLogin(traceId: traceId) {
                session = result.session
                currentUser = result.user
                route = result.needsOnboarding ? .onboarding : .home
            } else {
                route = .login
            }
        } catch {
            AppLog.auth.error(
                "\(AppLog.prefix(traceId, "AUTH")) auto-login failed. err=\(String(describing: error), privacy: .public)"
            )
            clearLocalSession()
            route = .login
        }
    }

    func signInWithKakao() async {
        errorMessage = nil
        let traceId = AppLog.makeErrorId()

        do {
            let result = try await authService.signInWithKakao(traceId: traceId)
            session = result.session
            currentUser = result.user
            route = result.needsOnboarding ? .onboarding : .home
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
            guard let session else {
                AppLog.api.error("\(AppLog.prefix(traceId, "API")) onboarding blocked: missing session")
                throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
            }

            let updated = try await authService.completeOnboarding(
                traceId: traceId,
                session: session,
                nickname: nickname,
                phone: phone,
                profileImageURL: profileImageURL
            )

            self.session = updated.session
            currentUser = updated.user
            route = updated.needsOnboarding ? .onboarding : .home
        } catch {
            AppLog.api.error("\(AppLog.prefix(traceId, "API")) completeOnboarding failed: \(String(describing: error), privacy: .public)")
            errorMessage = "회원가입(프로필 저장) 실패 (\(traceId)): \(error.localizedDescription)"
        }
    }

    func signOut() async {
        errorMessage = nil
        let traceId = AppLog.makeErrorId()

        await authService.signOut(traceId: traceId)
        clearLocalSession()
        route = .login
    }

    func handleOpenURL(_ url: URL) {
        // KakaoSDK 로그인 redirect 처리
        _ = AuthController.handleOpenUrl(url: url)
    }

    private func clearLocalSession() {
        session = nil
        currentUser = nil
        authService.clearLocalSession()
    }
}
