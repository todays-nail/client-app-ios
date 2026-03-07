//
//  AppViewModel.swift
//  NailClient
//

import Foundation
import Combine
import CoreGraphics
import GoogleSignIn
import KakaoSDKAuth
import OSLog

enum MainTab: Hashable, Sendable {
    case home
    case ai
    case results
    case myPage
}

struct AIDesignSelectionPayload: Identifiable, Equatable, Sendable {
    enum Source: Equatable, Sendable {
        case remoteURL(String)
        case localAsset(String)
    }

    let id: UUID
    let source: Source
    let selectedAt: Date
}

enum AIDesignSourceKind: String, Equatable, Sendable {
    case photoLibrary
}

enum AIGenerationLifecycleEvent: Sendable, Equatable {
    case started(jobId: UUID?)
    case progress(message: String)
    case completed(jobId: UUID, resultImageURL: URL?)
    case failed(jobId: UUID?, message: String)
}

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

    private struct NailGenListCacheKey: Hashable {
        let limit: Int
        let likedOnly: Bool
    }

    private struct NailGenListCacheEntry {
        let response: NailGenListResponse
        let cachedAt: Date
    }

    @Published private(set) var launchPhase: LaunchPhase = .booting
    @Published private(set) var route: Route = .login
    @Published private(set) var onboardingStyleImageURLs: [String: URL] = [:]
    @Published var errorMessage: String?
    @Published private(set) var currentUser: AppUser?
    @Published private(set) var session: AppSession?
    @Published private(set) var onboardingPrefill: OnboardingPrefill?
    @Published var selectedMainTab: MainTab = .home
    @Published private(set) var isAIDesignSelectionInProgress: Bool = false
    @Published private(set) var selectedAIDesignPayload: AIDesignSelectionPayload?
    @Published private(set) var lastAIDesignSource: AIDesignSourceKind?
    @Published private(set) var aiGenerationIsRunning: Bool = false
    @Published private(set) var aiGenerationProgressMessage: String = ""
    @Published private(set) var pendingPushJobId: UUID?
    @Published private(set) var pushNavigationToken: UUID?
    @Published private(set) var pushAuthorizationState: PushAuthorizationState = .notDetermined

    private let authService: any AuthServicing
    private let edgeAPIClient = EdgeAPIClient()
    private let pushManager: any PushNotificationManaging
    private let launchTiming: LaunchTiming
    private let launchTraceId: String

    private var didStart: Bool = false
    private var didLogFirstFrame: Bool = false
    private var onboardingStyleAssetsFetchedAt: Date?
    private var activeAIGenerationJobId: UUID?
    private var pendingPushTokenRegistration: (token: String, envHint: APNSEnvironmentHint)?
    private var pendingPushRoutePayload: PushNotificationRoutePayload?
    private var nailGenListFirstPageCache: [NailGenListCacheKey: NailGenListCacheEntry] = [:]
    private var nailGenListFirstPagePreloadTasks: [NailGenListCacheKey: Task<Void, Never>] = [:]

    private let nailGenListCacheTTL: TimeInterval = 45

    static var isRunningForPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    init(
        authService: (any AuthServicing)? = nil,
        pushManager: (any PushNotificationManaging)? = nil,
        launchTiming: LaunchTiming = .init(
            minimumSplashDuration: .milliseconds(400),
            autoLoginTimeout: .seconds(5)
        )
    ) {
        self.authService = authService ?? AuthService()
        self.pushManager = pushManager ?? PushNotificationManager.shared
        self.launchTiming = launchTiming
        self.launchTraceId = AppLog.makeErrorId()
        bindPushManagerCallbacks()
    }

    func markFirstFrameIfNeeded() {
        guard !didLogFirstFrame else { return }
        didLogFirstFrame = true
        AppLog.launch.info("\(AppLog.prefix(self.launchTraceId, "LAUNCH")) first_frame")
    }

    func syncSelectedMainTab(_ tab: MainTab) {
        if selectedMainTab != tab {
            selectedMainTab = tab
        }

        if isAIDesignSelectionInProgress, tab != .ai {
            isAIDesignSelectionInProgress = false
        }
    }

    func completeAIDesignSelection(with source: AIDesignSelectionPayload.Source) {
        _ = source
        lastAIDesignSource = .photoLibrary
        selectedAIDesignPayload = AIDesignSelectionPayload(
            id: UUID(),
            source: source,
            selectedAt: Date()
        )
        isAIDesignSelectionInProgress = false
        selectedMainTab = .ai
    }

    func cancelAIDesignSelection() {
        isAIDesignSelectionInProgress = false
    }

    func noteAIDesignSelectionSource(_ source: AIDesignSourceKind) {
        lastAIDesignSource = source
    }

    func clearSelectedAIDesignPayload() {
        selectedAIDesignPayload = nil
    }

    func handleAIGenerationLifecycleEvent(_ event: AIGenerationLifecycleEvent) {
        switch event {
        case .started(let jobId):
            beginAIGeneration(jobId: jobId)
        case .progress(let message):
            updateAIGenerationProgress(message: message)
        case .completed(let jobId, let resultImageURL):
            completeAIGeneration(jobId: jobId, resultURL: resultImageURL)
        case .failed(let jobId, let message):
            failAIGeneration(jobId: jobId, message: message)
        }
    }

    func beginAIGeneration(jobId: UUID?) {
        aiGenerationIsRunning = true
        aiGenerationProgressMessage = "AI 생성 요청을 준비 중입니다."
        activeAIGenerationJobId = jobId
    }

    func updateAIGenerationProgress(message: String) {
        aiGenerationIsRunning = true
        aiGenerationProgressMessage = message
    }

    func completeAIGeneration(jobId _: UUID, resultURL _: URL?) {
        aiGenerationIsRunning = false
        aiGenerationProgressMessage = "생성이 완료되었습니다."
        activeAIGenerationJobId = nil
        refreshNailGenerationFirstPageCache(likedOnly: false)
    }

    func failAIGeneration(jobId: UUID?, message: String) {
        aiGenerationIsRunning = false
        aiGenerationProgressMessage = message
        if activeAIGenerationJobId == nil || activeAIGenerationJobId == jobId {
            activeAIGenerationJobId = nil
        }
    }

    func consumePushNavigationRequest() {
        pendingPushJobId = nil
        pushNavigationToken = nil
    }

    func preparePushNotificationsForAIGeneration() async {
        guard !Self.isRunningForPreviews else { return }
        let granted = await pushManager.requestAuthorizationIfNeeded()
        await refreshPushAuthorizationState()
        guard granted else { return }

        guard let latestToken = pushManager.latestDeviceTokenHex else {
            return
        }

        await registerPushTokenIfPossible(
            token: latestToken,
            envHint: pushManager.latestEnvironmentHint
        )
    }

    func refreshPushAuthorizationState() async {
        guard !Self.isRunningForPreviews else { return }
        pushAuthorizationState = await pushManager.fetchAuthorizationState()
    }

    func start() async {
        guard !didStart else { return }
        guard !Self.isRunningForPreviews else {
            didStart = true
            if launchPhase != .ready {
                launchPhase = .ready
            }
            return
        }
        didStart = true

        if ProcessInfo.processInfo.arguments.contains("--uitesting-route-login") {
            applyUITestingLoginRoute()
            return
        }

        if ProcessInfo.processInfo.arguments.contains("--uitesting-route-home") {
            applyUITestingHomeRoute()
            return
        }

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
            errorMessage = autoLoginFailureMessage(for: error)
        }

        let elapsed = splashStart.duration(to: clock.now)
        if elapsed < launchTiming.minimumSplashDuration {
            try? await Task.sleep(for: launchTiming.minimumSplashDuration - elapsed)
        }

        session = nextSession
        currentUser = nextUser
        onboardingPrefill = nextPrefill
        await syncPushTokenRegistrationIfPossible()
        route = nextRoute
        if nextRoute == .home {
            await preloadNailGenerationFirstPage(limit: 20, likedOnly: false)
        }
        launchPhase = .ready
        flushPendingPushRouteIfPossible()

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
            await syncPushTokenRegistrationIfPossible()
            route = result.needsOnboarding ? .onboarding : .home
            if route == .home {
                await preloadNailGenerationFirstPage(limit: 20, likedOnly: false)
            }
            flushPendingPushRouteIfPossible()
        } catch {
            AppLog.auth.error("\(AppLog.prefix(traceId, "AUTH")) signInWithKakao failed: \(String(describing: error), privacy: .public)")
            errorMessage = "카카오 로그인 실패. 다시 시도해주세요."
            onboardingPrefill = nil
            route = .login
        }
    }

    func signInWithGoogle() async {
        errorMessage = nil
        let traceId = AppLog.makeErrorId()

        do {
            let result = try await authService.signInWithGoogle(traceId: traceId)
            session = result.session
            currentUser = result.user
            if result.needsOnboarding {
                onboardingPrefill = result.onboardingPrefill ?? prefillFromUser(result.user)
            } else {
                onboardingPrefill = nil
            }
            await syncPushTokenRegistrationIfPossible()
            route = result.needsOnboarding ? .onboarding : .home
            if route == .home {
                await preloadNailGenerationFirstPage(limit: 20, likedOnly: false)
            }
            flushPendingPushRouteIfPossible()
        } catch {
            AppLog.auth.error("\(AppLog.prefix(traceId, "AUTH")) signInWithGoogle failed: \(String(describing: error), privacy: .public)")
            errorMessage = "Google 로그인 실패. 다시 시도해주세요."
            onboardingPrefill = nil
            route = .login
        }
    }

    func signInWithApple() async {
        errorMessage = nil
        let traceId = AppLog.makeErrorId()

        do {
            let result = try await authService.signInWithApple(traceId: traceId)
            session = result.session
            currentUser = result.user
            if result.needsOnboarding {
                onboardingPrefill = result.onboardingPrefill ?? prefillFromUser(result.user)
            } else {
                onboardingPrefill = nil
            }
            await syncPushTokenRegistrationIfPossible()
            route = result.needsOnboarding ? .onboarding : .home
            if route == .home {
                await preloadNailGenerationFirstPage(limit: 20, likedOnly: false)
            }
            flushPendingPushRouteIfPossible()
        } catch {
            AppLog.auth.error("\(AppLog.prefix(traceId, "AUTH")) signInWithApple failed: \(String(describing: error), privacy: .public)")
            errorMessage = "Apple 로그인 실패. 다시 시도해주세요."
            onboardingPrefill = nil
            route = .login
        }
    }

    func refreshOnboardingStyleAssets(force: Bool = false) async {
        guard !Self.isRunningForPreviews else { return }
        if !force,
           let fetchedAt = onboardingStyleAssetsFetchedAt,
           Date().timeIntervalSince(fetchedAt) < 300 {
            return
        }

        let traceId = AppLog.makeErrorId()
        do {
            let response = try await edgeAPIClient.fetchPublicOnboardingStyles(traceId: traceId)
            var next: [String: URL] = [:]
            var prefetchURLs: [URL] = []

            for item in response.styles {
                let rawURL = item.imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !rawURL.isEmpty, let parsedURL = URL(string: rawURL) else {
                    continue
                }
                next[item.key] = parsedURL
                prefetchURLs.append(parsedURL)
            }

            onboardingStyleImageURLs = next
            onboardingStyleAssetsFetchedAt = Date()
            NailImagePipeline.prefetch(
                urls: Array(prefetchURLs.prefix(12)),
                targetSize: CGSize(width: 220, height: 220),
                resizeMode: .fill
            )

            AppLog.api.info(
                "\(AppLog.prefix(traceId, "API")) onboarding_style_assets_loaded count=\(next.count, privacy: .public)"
            )
        } catch {
            let redacted = AppLog.truncate(AppLog.redact(String(describing: error)))
            AppLog.api.error(
                "\(AppLog.prefix(traceId, "API")) onboarding_style_assets_failed err=\(redacted, privacy: .public)"
            )
        }
    }

    func completeOnboarding(nickname: String, profileImageURL: String?) async {
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
                profileImageURL: profileImageURL
            )

            self.session = updated.session
            currentUser = updated.user
            onboardingPrefill = updated.needsOnboarding ? prefillFromUser(updated.user) : nil
            route = updated.needsOnboarding ? .onboarding : .home
            if route == .home {
                await preloadNailGenerationFirstPage(limit: 20, likedOnly: false)
            }
            flushPendingPushRouteIfPossible()
        } catch {
            AppLog.api.error("\(AppLog.prefix(traceId, "API")) completeOnboarding failed: \(String(describing: error), privacy: .public)")
            errorMessage = "회원가입(프로필 저장) 실패 (\(traceId)): \(error.localizedDescription)"
        }
    }

    func updateMyProfile(nickname: String) async -> Bool {
        errorMessage = nil
        let traceId = AppLog.makeErrorId()

        do {
            guard let session else {
                AppLog.api.error("\(AppLog.prefix(traceId, "API")) update profile blocked: missing session")
                throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
            }

            let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            let currentProfileImageURL = currentUser?.profileImageURL?.trimmingCharacters(in: .whitespacesAndNewlines)

            let updated = try await authService.updateMyProfile(
                traceId: traceId,
                session: session,
                nickname: trimmedNickname,
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

    func updateMyProfileImage(profileImageURL: String?) async -> Bool {
        errorMessage = nil
        let traceId = AppLog.makeErrorId()

        do {
            guard let session else {
                AppLog.api.error("\(AppLog.prefix(traceId, "API")) update profile image blocked: missing session")
                throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
            }

            let trimmedNickname = currentUser?.nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
            let imageURLTrimmed = profileImageURL?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let trimmedNickname, !trimmedNickname.isEmpty else {
                throw EdgeAPIError(statusCode: -1, message: "Missing nickname for profile image update", errorId: traceId)
            }

            let updated = try await authService.updateMyProfile(
                traceId: traceId,
                session: session,
                nickname: trimmedNickname,
                profileImageURL: (imageURLTrimmed?.isEmpty ?? true) ? nil : imageURLTrimmed
            )

            self.session = updated.session
            currentUser = updated.user
            return true
        } catch {
            AppLog.api.error("\(AppLog.prefix(traceId, "API")) updateMyProfileImage failed: \(String(describing: error), privacy: .public)")
            errorMessage = "프로필 이미지 수정 실패 (\(traceId)): \(error.localizedDescription)"
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

    func uploadProfileImage(imageData: Data) async throws -> String {
        let uploadResponse = try await issueNailGenerationUploadURL(
            kind: .profile,
            ext: "jpg",
            contentType: "image/jpeg",
            bytes: imageData.count,
            jobId: nil
        )

        try await uploadImageToSignedURL(
            signedUploadURL: uploadResponse.signedUploadURL,
            contentType: "image/jpeg",
            imageData: imageData
        )

        let publicURL = uploadResponse.publicObjectURL?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let publicURL, !publicURL.isEmpty else {
            throw EdgeAPIError(statusCode: -1, message: "Missing public profile image URL", errorId: nil)
        }
        return publicURL
    }

    func createNailGenerationJob(
        shape: NailGenShape,
        extensionMode: NailGenExtensionMode,
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
            extensionMode: extensionMode,
            handObjectPath: handObjectPath,
            referenceObjectPath: referenceObjectPath
        )
        self.session = result.session
        return result.response
    }

    func refineNailGenerationJob(
        sourceJobId: UUID,
        shape: NailGenShape,
        extensionMode: NailGenExtensionMode
    ) async throws -> NailGenRefineJobResponse {
        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.refineNailGenerationJob(
            traceId: traceId,
            session: session,
            sourceJobId: sourceJobId,
            shape: shape,
            extensionMode: extensionMode
        )
        self.session = result.session
        return result.response
    }

    func getNailGenerationJobStatus(jobId: UUID) async throws -> NailGenJobStatusResponse {
        try await getNailGenerationJobStatus(jobId: jobId, includeInputs: false)
    }

    func getNailGenerationJobStatus(
        jobId: UUID,
        includeInputs: Bool
    ) async throws -> NailGenJobStatusResponse {
        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.getNailGenerationJobStatus(
            traceId: traceId,
            session: session,
            jobId: jobId,
            includeInputs: includeInputs
        )
        self.session = result.session
        return result.response
    }

    func fetchCompletedNailGenerationList(
        limit: Int = 20,
        cursor: String? = nil,
        likedOnly: Bool = false
    ) async throws -> NailGenListResponse {
        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.fetchCompletedNailGenerationList(
            traceId: traceId,
            session: session,
            limit: limit,
            cursor: cursor,
            likedOnly: likedOnly
        )
        self.session = result.session
        return result.response
    }

    func cachedNailGenerationFirstPage(
        limit: Int,
        likedOnly: Bool
    ) -> NailGenListResponse? {
        let key = NailGenListCacheKey(limit: limit, likedOnly: likedOnly)
        guard let entry = nailGenListFirstPageCache[key] else { return nil }
        let age = Date().timeIntervalSince(entry.cachedAt)
        guard age <= nailGenListCacheTTL else {
            nailGenListFirstPageCache[key] = nil
            return nil
        }
        return entry.response
    }

    func setCachedNailGenerationFirstPage(
        _ response: NailGenListResponse,
        limit: Int,
        likedOnly: Bool
    ) {
        let key = NailGenListCacheKey(limit: limit, likedOnly: likedOnly)
        nailGenListFirstPageCache[key] = NailGenListCacheEntry(
            response: response,
            cachedAt: Date()
        )
    }

    func preloadNailGenerationFirstPage(
        limit: Int,
        likedOnly: Bool
    ) async {
        let key = NailGenListCacheKey(limit: limit, likedOnly: likedOnly)
        if cachedNailGenerationFirstPage(limit: limit, likedOnly: likedOnly) != nil {
            return
        }

        if let existingTask = nailGenListFirstPagePreloadTasks[key] {
            await existingTask.value
            return
        }

        guard session != nil else { return }

        let task = Task<Void, Never> { [weak self] in
            guard let self else { return }
            await self.runNailGenListFirstPagePreload(key: key)
        }
        nailGenListFirstPagePreloadTasks[key] = task
        await task.value
    }

    func invalidateNailGenerationFirstPageCache(likedOnly: Bool? = nil) {
        let cacheKeys = nailGenListFirstPageCache.keys.filter { key in
            guard let likedOnly else { return true }
            return key.likedOnly == likedOnly
        }
        for key in cacheKeys {
            nailGenListFirstPageCache[key] = nil
        }

        let taskKeys = nailGenListFirstPagePreloadTasks.keys.filter { key in
            guard let likedOnly else { return true }
            return key.likedOnly == likedOnly
        }
        for key in taskKeys {
            nailGenListFirstPagePreloadTasks[key]?.cancel()
            nailGenListFirstPagePreloadTasks[key] = nil
        }
    }

    func refreshNailGenerationFirstPageCache(
        likedOnly: Bool,
        limit: Int = 20
    ) {
        invalidateNailGenerationFirstPageCache(likedOnly: likedOnly)
        guard session != nil else { return }

        Task { [weak self] in
            await self?.preloadNailGenerationFirstPage(
                limit: limit,
                likedOnly: likedOnly
            )
        }
    }

    func setNailGenerationLike(jobId: UUID, isLiked: Bool) async throws -> NailGenLikeResponse {
        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.setNailGenerationLike(
            traceId: traceId,
            session: session,
            jobId: jobId,
            isLiked: isLiked
        )
        self.session = result.session
        return result.response
    }

    func deleteNailGeneration(jobId: UUID) async throws -> NailGenDeleteResponse {
        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.deleteNailGeneration(
            traceId: traceId,
            session: session,
            jobId: jobId
        )
        self.session = result.session
        return result.response
    }

    func deleteMyAccount(reason: String?) async -> Bool {
        errorMessage = nil
        let traceId = AppLog.makeErrorId()

        do {
            guard let session else {
                AppLog.api.error("\(AppLog.prefix(traceId, "API")) delete account blocked: missing session")
                throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
            }

            try await authService.deleteMyAccount(
                traceId: traceId,
                session: session,
                reason: reason
            )

            await clearLocalSession()
            route = .login
            return true
        } catch {
            AppLog.api.error("\(AppLog.prefix(traceId, "API")) deleteMyAccount failed: \(String(describing: error), privacy: .public)")
            errorMessage = "회원 탈퇴 실패 (\(traceId)): \(error.localizedDescription)"
            return false
        }
    }

    func signOut() async {
        errorMessage = nil
        let traceId = AppLog.makeErrorId()

        if let session {
            await deactivatePushTokenBeforeSignOut(session: session, traceId: traceId)
        }
        await authService.signOut(traceId: traceId)
        await clearLocalSession()
        route = .login
    }

    func handleOpenURL(_ url: URL) {
        // Google SDK 로그인 redirect 처리
        if GIDSignIn.sharedInstance.handle(url) {
            return
        }

        // KakaoSDK 로그인 redirect 처리
        _ = AuthController.handleOpenUrl(url: url)
    }

    private func clearLocalSession() async {
        for task in nailGenListFirstPagePreloadTasks.values {
            task.cancel()
        }
        nailGenListFirstPagePreloadTasks.removeAll()
        nailGenListFirstPageCache.removeAll()
        session = nil
        currentUser = nil
        onboardingPrefill = nil
        selectedMainTab = .home
        isAIDesignSelectionInProgress = false
        selectedAIDesignPayload = nil
        lastAIDesignSource = nil
        aiGenerationIsRunning = false
        aiGenerationProgressMessage = ""
        activeAIGenerationJobId = nil
        pendingPushJobId = nil
        pushNavigationToken = nil
        pendingPushTokenRegistration = nil
        pendingPushRoutePayload = nil
        pushAuthorizationState = .notDetermined
        await authService.clearLocalSession()
    }

    private func runNailGenListFirstPagePreload(key: NailGenListCacheKey) async {
        defer { nailGenListFirstPagePreloadTasks[key] = nil }

        do {
            let response = try await fetchCompletedNailGenerationList(
                limit: key.limit,
                cursor: nil,
                likedOnly: key.likedOnly
            )
            setCachedNailGenerationFirstPage(
                response,
                limit: key.limit,
                likedOnly: key.likedOnly
            )
            let traceId = AppLog.makeErrorId()
            AppLog.api.debug(
                "\(AppLog.prefix(traceId, "API")) nail-gen-list preload_success likedOnly=\(key.likedOnly, privacy: .public) limit=\(key.limit, privacy: .public)"
            )
        } catch {
            let traceId = AppLog.makeErrorId()
            let redacted = AppLog.truncate(AppLog.redact(String(describing: error)))
            AppLog.api.debug(
                "\(AppLog.prefix(traceId, "API")) nail-gen-list preload_failed likedOnly=\(key.likedOnly, privacy: .public) limit=\(key.limit, privacy: .public) err=\(redacted, privacy: .public)"
            )
        }
    }

    private func bindPushManagerCallbacks() {
        pushManager.onDeviceTokenUpdated = { [weak self] token, envHint in
            guard let self else { return }
            Task { @MainActor in
                await self.registerPushTokenIfPossible(token: token, envHint: envHint)
            }
        }

        pushManager.onNotificationTapped = { [weak self] payload in
            guard let self else { return }
            Task { @MainActor in
                self.handlePushNotificationTapped(payload)
            }
        }
    }

    private func handlePushNotificationTapped(_ payload: PushNotificationRoutePayload) {
        if canRoutePushPayloadNow {
            applyPushRoutePayload(payload)
            return
        }
        pendingPushRoutePayload = payload
    }

    private func syncPushTokenRegistrationIfPossible() async {
        if let pending = pendingPushTokenRegistration {
            await registerPushTokenIfPossible(token: pending.token, envHint: pending.envHint)
            return
        }

        guard let latestToken = pushManager.latestDeviceTokenHex else { return }
        await registerPushTokenIfPossible(
            token: latestToken,
            envHint: pushManager.latestEnvironmentHint
        )
    }

    private var canRoutePushPayloadNow: Bool {
        route == .home && session != nil && launchPhase == .ready
    }

    private func flushPendingPushRouteIfPossible() {
        guard canRoutePushPayloadNow, let payload = pendingPushRoutePayload else {
            return
        }
        pendingPushRoutePayload = nil
        applyPushRoutePayload(payload)
    }

    private func applyPushRoutePayload(_ payload: PushNotificationRoutePayload) {
        selectedMainTab = .ai
        pendingPushJobId = payload.jobId
        pushNavigationToken = UUID()
    }

    private func registerPushTokenIfPossible(
        token: String,
        envHint: APNSEnvironmentHint
    ) async {
        guard let session else {
            pendingPushTokenRegistration = (token: token, envHint: envHint)
            return
        }

        let traceId = AppLog.makeErrorId()
        let deviceId = await authService.ensureDeviceId()

        do {
            let result = try await authService.upsertPushToken(
                traceId: traceId,
                session: session,
                deviceId: deviceId,
                apnsToken: token,
                apnsEnvHint: envHint.rawValue
            )
            self.session = result.session
            pendingPushTokenRegistration = nil
        } catch {
            let redacted = AppLog.truncate(AppLog.redact(String(describing: error)))
            AppLog.api.error("\(AppLog.prefix(traceId, "API")) push_token_upsert_failed err=\(redacted, privacy: .public)")
            pendingPushTokenRegistration = (token: token, envHint: envHint)
        }
    }

    private func deactivatePushTokenBeforeSignOut(
        session: AppSession,
        traceId: String
    ) async {
        let deviceId = await authService.ensureDeviceId()

        do {
            let result = try await authService.deactivatePushToken(
                traceId: traceId,
                session: session,
                deviceId: deviceId
            )
            self.session = result.session
        } catch {
            let redacted = AppLog.truncate(AppLog.redact(String(describing: error)))
            AppLog.api.error("\(AppLog.prefix(traceId, "API")) push_token_deactivate_failed err=\(redacted, privacy: .public)")
        }
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

    private func autoLoginFailureMessage(for error: Error) -> String? {
        guard let apiError = error as? EdgeAPIError else { return nil }
        let code = apiError.code?.uppercased()
        if code == "AUTH_REFRESH_EXPIRED"
            || code == "AUTH_REFRESH_REVOKED"
            || code == "AUTH_INVALID_REFRESH_TOKEN"
            || code == "AUTH_ACCOUNT_DELETED" {
            return "세션이 만료되었어요. 다시 로그인해 주세요."
        }
        return nil
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

    private func applyUITestingHomeRoute() {
        errorMessage = nil
        session = nil
        onboardingPrefill = nil
        currentUser = AppUser(
            id: UUID(),
            role: nil,
            nickname: "UI 테스트 사용자",
            profileImageURL: nil,
            defaultRegionID: nil,
            defaultRegionLabel: nil,
            defaultServiceRegionID: nil,
            createdAt: nil,
            updatedAt: nil
        )
        route = .home
        launchPhase = .ready
    }

    private func applyUITestingLoginRoute() {
        errorMessage = nil
        session = nil
        onboardingPrefill = nil
        currentUser = nil
        route = .login
        launchPhase = .ready
    }
}

#if DEBUG
extension AppViewModel {
    static func preview(
        route: Route = .home,
        launchPhase: LaunchPhase = .ready,
        currentUser: AppUser? = .preview(),
        session: AppSession? = AppSession(accessToken: "preview-access", refreshToken: "preview-refresh"),
        onboardingPrefill: OnboardingPrefill? = nil,
        selectedMainTab: MainTab = .home,
        onboardingStyleImageURLs: [String: URL] = [:],
        pushAuthorizationState: PushAuthorizationState = .allowed
    ) -> AppViewModel {
        let authService = PreviewAuthService(
            session: session,
            user: currentUser,
            onboardingPrefill: onboardingPrefill
        )
        let pushManager = PreviewPushNotificationManager(
            authorizationState: pushAuthorizationState
        )
        let viewModel = AppViewModel(
            authService: authService,
            pushManager: pushManager,
            launchTiming: .init(
                minimumSplashDuration: .zero,
                autoLoginTimeout: .seconds(1)
            )
        )
        viewModel.launchPhase = launchPhase
        viewModel.route = route
        viewModel.currentUser = currentUser
        viewModel.session = session
        viewModel.onboardingPrefill = onboardingPrefill
        viewModel.selectedMainTab = selectedMainTab
        viewModel.onboardingStyleImageURLs = onboardingStyleImageURLs
        viewModel.pushAuthorizationState = pushAuthorizationState
        viewModel.didStart = true
        viewModel.didLogFirstFrame = true
        return viewModel
    }
}

@MainActor
private final class PreviewPushNotificationManager: PushNotificationManaging {
    var latestDeviceTokenHex: String?
    var latestEnvironmentHint: APNSEnvironmentHint = .sandbox
    var onDeviceTokenUpdated: ((String, APNSEnvironmentHint) -> Void)?
    var onNotificationTapped: ((PushNotificationRoutePayload) -> Void)?

    private let authorizationState: PushAuthorizationState

    init(authorizationState: PushAuthorizationState) {
        self.authorizationState = authorizationState
    }

    func configure() {}

    func requestAuthorizationIfNeeded() async -> Bool {
        authorizationState == .allowed
    }

    func fetchAuthorizationState() async -> PushAuthorizationState {
        authorizationState
    }

    func handleDidRegisterForRemoteNotifications(deviceToken: Data) {}

    func handleDidFailToRegisterForRemoteNotifications(error: Error) {}

    func handleLaunchRemoteNotification(userInfo: [AnyHashable: Any]) {}
}

private actor PreviewAuthService: AuthServicing {
    private var session: AppSession?
    private var user: AppUser?
    private let onboardingPrefill: OnboardingPrefill?
    private var nailGenerationItems: [NailGenListItemResponse] = []

    init(
        session: AppSession?,
        user: AppUser?,
        onboardingPrefill: OnboardingPrefill?
    ) {
        self.session = session
        self.user = user
        self.onboardingPrefill = onboardingPrefill
    }

    func tryAutoLogin(traceId: String, timeout: Duration) async throws -> AuthResult? {
        _ = traceId
        _ = timeout
        guard let session, let user else { return nil }
        return AuthResult(
            session: session,
            user: user,
            needsOnboarding: onboardingPrefill != nil,
            onboardingPrefill: onboardingPrefill
        )
    }

    func signInWithKakao(traceId: String) async throws -> AuthResult {
        try await previewAuthResult(traceId: traceId)
    }

    func signInWithGoogle(traceId: String) async throws -> AuthResult {
        try await previewAuthResult(traceId: traceId)
    }

    func signInWithApple(traceId: String) async throws -> AuthResult {
        try await previewAuthResult(traceId: traceId)
    }

    func completeOnboarding(
        traceId: String,
        session: AppSession,
        nickname: String,
        profileImageURL: String?
    ) async throws -> (user: AppUser, needsOnboarding: Bool, session: AppSession) {
        _ = traceId
        let updatedUser = AppUser(
            id: user?.id ?? UUID(),
            role: user?.role,
            nickname: nickname,
            profileImageURL: profileImageURL,
            defaultRegionID: user?.defaultRegionID,
            defaultRegionLabel: user?.defaultRegionLabel,
            defaultServiceRegionID: user?.defaultServiceRegionID,
            createdAt: user?.createdAt,
            updatedAt: Date()
        )
        self.session = session
        self.user = updatedUser
        return (updatedUser, false, session)
    }

    func updateMyProfile(
        traceId: String,
        session: AppSession,
        nickname: String,
        profileImageURL: String?
    ) async throws -> (user: AppUser, session: AppSession) {
        _ = traceId
        let updatedUser = AppUser(
            id: user?.id ?? UUID(),
            role: user?.role,
            nickname: nickname,
            profileImageURL: profileImageURL,
            defaultRegionID: user?.defaultRegionID,
            defaultRegionLabel: user?.defaultRegionLabel,
            defaultServiceRegionID: user?.defaultServiceRegionID,
            createdAt: user?.createdAt,
            updatedAt: Date()
        )
        self.session = session
        self.user = updatedUser
        return (updatedUser, session)
    }

    func issueNailGenerationUploadURL(
        traceId: String,
        session: AppSession,
        kind: NailGenUploadKind,
        ext: String,
        contentType: String,
        bytes: Int,
        jobId: UUID?
    ) async throws -> (response: NailGenUploadURLResponse, session: AppSession) {
        _ = traceId
        _ = kind
        _ = ext
        _ = contentType
        _ = bytes
        let resolvedJobId = jobId ?? UUID()
        return (
            NailGenUploadURLResponse(
                bucket: "preview",
                jobId: resolvedJobId,
                objectPath: "preview/\(resolvedJobId.uuidString).jpg",
                signedUploadURL: "https://example.com/upload",
                publicObjectURL: "https://example.com/generated-\(resolvedJobId.uuidString).jpg",
                expiresInSec: 600
            ),
            session
        )
    }

    func uploadImageToSignedURL(
        traceId: String,
        signedUploadURL: String,
        contentType: String,
        imageData: Data
    ) async throws {
        _ = traceId
        _ = signedUploadURL
        _ = contentType
        _ = imageData
    }

    func createNailGenerationJob(
        traceId: String,
        session: AppSession,
        shape: NailGenShape,
        extensionMode: NailGenExtensionMode,
        handObjectPath: String,
        referenceObjectPath: String
    ) async throws -> (response: NailGenCreateJobResponse, session: AppSession) {
        _ = traceId
        _ = shape
        _ = extensionMode
        _ = handObjectPath
        _ = referenceObjectPath
        return (
            NailGenCreateJobResponse(
                jobId: UUID(),
                status: .completed,
                pollAfterMs: 0
            ),
            session
        )
    }

    func refineNailGenerationJob(
        traceId: String,
        session: AppSession,
        sourceJobId: UUID,
        shape: NailGenShape,
        extensionMode: NailGenExtensionMode
    ) async throws -> (response: NailGenRefineJobResponse, session: AppSession) {
        _ = traceId
        _ = sourceJobId
        _ = shape
        _ = extensionMode
        return (
            NailGenRefineJobResponse(
                jobId: UUID(),
                status: .completed,
                pollAfterMs: 0
            ),
            session
        )
    }

    func getNailGenerationJobStatus(
        traceId: String,
        session: AppSession,
        jobId: UUID
    ) async throws -> (response: NailGenJobStatusResponse, session: AppSession) {
        _ = traceId
        let response = await MainActor.run {
            NailGenJobStatusResponse(
                status: .completed,
                resultImageURL: "https://example.com/result-\(jobId.uuidString).jpg",
                errorCode: nil,
                errorMessage: nil,
                parentJobId: nil,
                refinementTurn: 0,
                canRefine: true
            )
        }
        return (
            response,
            session
        )
    }

    func fetchCompletedNailGenerationList(
        traceId: String,
        session: AppSession,
        limit: Int,
        cursor: String?,
        likedOnly: Bool
    ) async throws -> (response: NailGenListResponse, session: AppSession) {
        _ = traceId
        _ = cursor
        let items = nailGenerationItems
            .filter { likedOnly ? $0.isLiked : true }
        return (
            NailGenListResponse(
                items: Array(items.prefix(limit)),
                nextCursor: nil
            ),
            session
        )
    }

    func setNailGenerationLike(
        traceId: String,
        session: AppSession,
        jobId: UUID,
        isLiked: Bool
    ) async throws -> (response: NailGenLikeResponse, session: AppSession) {
        _ = traceId
        if let index = nailGenerationItems.firstIndex(where: { $0.jobId == jobId }) {
            let current = nailGenerationItems[index]
            nailGenerationItems[index] = await MainActor.run {
                NailGenListItemResponse(
                    jobId: current.jobId,
                    resultImageURL: current.resultImageURL,
                    thumbnailImageURL: current.thumbnailImageURL,
                    shape: current.shape,
                    extensionMode: current.extensionMode,
                    createdAt: current.createdAt,
                    parentJobId: current.parentJobId,
                    refinementTurn: current.refinementTurn,
                    isLiked: isLiked
                )
            }
        }

        return (
            NailGenLikeResponse(
                ok: true,
                jobId: jobId,
                isLiked: isLiked
            ),
            session
        )
    }

    func deleteNailGeneration(
        traceId: String,
        session: AppSession,
        jobId: UUID
    ) async throws -> (response: NailGenDeleteResponse, session: AppSession) {
        _ = traceId
        nailGenerationItems.removeAll { $0.jobId == jobId || $0.parentJobId == jobId }
        return (
            NailGenDeleteResponse(
                ok: true,
                deletedJobIDs: [jobId]
            ),
            session
        )
    }

    func deleteMyAccount(
        traceId: String,
        session: AppSession,
        reason: String?
    ) async throws {
        _ = traceId
        _ = session
        _ = reason
        self.session = nil
        self.user = nil
    }

    func signOut(traceId: String) async {
        _ = traceId
        session = nil
        user = nil
    }

    func clearLocalSession() async {
        session = nil
        user = nil
    }

    private func previewAuthResult(traceId: String) async throws -> AuthResult {
        _ = traceId
        guard let session, let user else {
            throw EdgeAPIError(statusCode: 401, message: "Preview session unavailable", errorId: "preview-auth")
        }
        return AuthResult(
            session: session,
            user: user,
            needsOnboarding: onboardingPrefill != nil,
            onboardingPrefill: onboardingPrefill
        )
    }
}
#endif
