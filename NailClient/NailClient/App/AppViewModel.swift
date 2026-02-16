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
    enum Route: Equatable {
        case login
        case onboarding
        case home
    }

    enum LaunchPhase: Equatable {
        case booting
        case routing
        case ready
    }

    struct LaunchTiming {
        let minimumSplashDuration: Duration
        let autoLoginTimeout: Duration

        static let `default` = LaunchTiming(
            minimumSplashDuration: .milliseconds(400),
            autoLoginTimeout: .seconds(5)
        )
    }

    @Published private(set) var launchPhase: LaunchPhase = .booting
    @Published private(set) var route: Route = .login
    @Published var errorMessage: String?
    @Published private(set) var currentUser: AppUser?
    @Published private(set) var session: AppSession?
    @Published private(set) var onboardingPrefill: OnboardingPrefill?

    private let authService: any AuthServicing
    private let launchTiming: LaunchTiming
    private let launchTraceId: String

    private var didStart: Bool = false
    private var didLogFirstFrame: Bool = false

    init(
        authService: (any AuthServicing)? = nil,
        launchTiming: LaunchTiming = .init(
            minimumSplashDuration: .milliseconds(400),
            autoLoginTimeout: .seconds(5)
        )
    ) {
        self.authService = authService ?? AuthService()
        self.launchTiming = launchTiming
        self.launchTraceId = AppLog.makeErrorId()
    }

    func markFirstFrameIfNeeded() {
        guard !didLogFirstFrame else { return }
        didLogFirstFrame = true
        AppLog.launch.info("\(AppLog.prefix(self.launchTraceId, "LAUNCH")) first_frame")
    }

    func start() async {
        guard !didStart else { return }
        didStart = true

        errorMessage = nil
        launchPhase = .booting
        AppLog.launch.info("\(AppLog.prefix(self.launchTraceId, "LAUNCH")) launch_start")

        let clock = ContinuousClock()
        let splashStart = clock.now

        launchPhase = .routing
        AppLog.launch.info("\(AppLog.prefix(self.launchTraceId, "LAUNCH")) auto_login_start")

        var nextRoute: Route = .login
        var nextSession: AppSession?
        var nextUser: AppUser?
        var nextPrefill: OnboardingPrefill?

        do {
            if let result = try await authService.tryAutoLogin(
                traceId: self.launchTraceId,
                timeout: launchTiming.autoLoginTimeout
            ) {
                nextSession = result.session
                nextUser = result.user
                nextPrefill = result.needsOnboarding ? prefillFromUser(result.user) : nil
                nextRoute = result.needsOnboarding ? .onboarding : .home
                AppLog.launch.info("\(AppLog.prefix(self.launchTraceId, "LAUNCH")) auto_login_end status=success")
            } else {
                AppLog.launch.info("\(AppLog.prefix(self.launchTraceId, "LAUNCH")) auto_login_end status=no_session")
            }
        } catch {
            AppLog.auth.error(
                "\(AppLog.prefix(self.launchTraceId, "AUTH")) auto-login failed. err=\(String(describing: error), privacy: .public)"
            )
            AppLog.launch.error("\(AppLog.prefix(self.launchTraceId, "LAUNCH")) auto_login_end status=failed")
            await authService.clearLocalSession()
        }

        let elapsed = splashStart.duration(to: clock.now)
        if elapsed < launchTiming.minimumSplashDuration {
            try? await Task.sleep(for: launchTiming.minimumSplashDuration - elapsed)
        }

        session = nextSession
        currentUser = nextUser
        onboardingPrefill = nextPrefill
        route = nextRoute
        launchPhase = .ready

        AppLog.launch.info(
            "\(AppLog.prefix(self.launchTraceId, "LAUNCH")) route_ready route=\(self.routeLabel(nextRoute), privacy: .public)"
        )
    }

    func signInWithKakao() async {
        errorMessage = nil
        let traceId = AppLog.makeErrorId()

        do {
            let result = try await authService.signInWithKakao(traceId: traceId)
            session = result.session
            currentUser = result.user
            if result.needsOnboarding {
                onboardingPrefill = result.onboardingPrefill ?? prefillFromUser(result.user)
            } else {
                onboardingPrefill = nil
            }
            route = result.needsOnboarding ? .onboarding : .home
        } catch {
            AppLog.auth.error("\(AppLog.prefix(traceId, "AUTH")) signInWithKakao failed: \(String(describing: error), privacy: .public)")
            errorMessage = "카카오 로그인 실패 (\(traceId)): \(error.localizedDescription)"
            onboardingPrefill = nil
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
            onboardingPrefill = updated.needsOnboarding ? prefillFromUser(updated.user) : nil
            route = updated.needsOnboarding ? .onboarding : .home
        } catch {
            AppLog.api.error("\(AppLog.prefix(traceId, "API")) completeOnboarding failed: \(String(describing: error), privacy: .public)")
            errorMessage = "회원가입(프로필 저장) 실패 (\(traceId)): \(error.localizedDescription)"
        }
    }

    func updateMyProfile(nickname: String, phone: String?) async -> Bool {
        errorMessage = nil
        let traceId = AppLog.makeErrorId()

        do {
            guard let session else {
                AppLog.api.error("\(AppLog.prefix(traceId, "API")) update profile blocked: missing session")
                throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
            }

            let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            let phoneTrimmed = phone?.trimmingCharacters(in: .whitespacesAndNewlines)
            let currentProfileImageURL = currentUser?.profileImageURL?.trimmingCharacters(in: .whitespacesAndNewlines)

            let updated = try await authService.updateMyProfile(
                traceId: traceId,
                session: session,
                nickname: trimmedNickname,
                phone: (phoneTrimmed?.isEmpty ?? true) ? nil : phoneTrimmed,
                profileImageURL: (currentProfileImageURL?.isEmpty ?? true) ? nil : currentProfileImageURL
            )

            self.session = updated.session
            currentUser = updated.user
            return true
        } catch {
            AppLog.api.error("\(AppLog.prefix(traceId, "API")) updateMyProfile failed: \(String(describing: error), privacy: .public)")
            errorMessage = "프로필 수정 실패 (\(traceId)): \(error.localizedDescription)"
            return false
        }
    }

    func issueNailGenerationUploadURL(
        kind: NailGenUploadKind,
        ext: String,
        contentType: String,
        bytes: Int,
        jobId: UUID?
    ) async throws -> NailGenUploadURLResponse {
        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.issueNailGenerationUploadURL(
            traceId: traceId,
            session: session,
            kind: kind,
            ext: ext,
            contentType: contentType,
            bytes: bytes,
            jobId: jobId
        )
        self.session = result.session
        return result.response
    }

    func uploadImageToSignedURL(
        signedUploadURL: String,
        contentType: String,
        imageData: Data
    ) async throws {
        let traceId = AppLog.makeErrorId()
        try await authService.uploadImageToSignedURL(
            traceId: traceId,
            signedUploadURL: signedUploadURL,
            contentType: contentType,
            imageData: imageData
        )
    }

    func createNailGenerationJob(
        shape: NailGenShape,
        userPrompt: String,
        handObjectPath: String,
        referenceObjectPath: String
    ) async throws -> NailGenCreateJobResponse {
        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.createNailGenerationJob(
            traceId: traceId,
            session: session,
            shape: shape,
            userPrompt: userPrompt,
            handObjectPath: handObjectPath,
            referenceObjectPath: referenceObjectPath
        )
        self.session = result.session
        return result.response
    }

    func getNailGenerationJobStatus(jobId: UUID) async throws -> NailGenJobStatusResponse {
        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.getNailGenerationJobStatus(
            traceId: traceId,
            session: session,
            jobId: jobId
        )
        self.session = result.session
        return result.response
    }

    func signOut() async {
        errorMessage = nil
        let traceId = AppLog.makeErrorId()

        await authService.signOut(traceId: traceId)
        await clearLocalSession()
        route = .login
    }

    func handleOpenURL(_ url: URL) {
        // KakaoSDK 로그인 redirect 처리
        _ = AuthController.handleOpenUrl(url: url)
    }

    private func clearLocalSession() async {
        session = nil
        currentUser = nil
        onboardingPrefill = nil
        await authService.clearLocalSession()
    }

    private func routeLabel(_ route: Route) -> String {
        switch route {
        case .login:
            return "login"
        case .onboarding:
            return "onboarding"
        case .home:
            return "home"
        }
    }

    private func prefillFromUser(_ user: AppUser) -> OnboardingPrefill? {
        let nickname = user.nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        let profileImageURL = user.profileImageURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        if (nickname?.isEmpty ?? true), (profileImageURL?.isEmpty ?? true) {
            return nil
        }

        return OnboardingPrefill(
            nickname: nickname?.isEmpty == false ? nickname : nil,
            profileImageURL: profileImageURL?.isEmpty == false ? profileImageURL : nil
        )
    }
}
