//
//  AppViewModel.swift
//  NailClient
//

import Foundation
import Combine
import KakaoSDKAuth
import OSLog

enum MainTab: Hashable, Sendable {
    case home
    case feed
    case ai
    case reservations
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
    case feed
    case photoLibrary
}

enum AIGenerationLifecycleEvent: Sendable, Equatable {
    case started(jobId: UUID?)
    case progress(message: String)
    case completed(jobId: UUID, resultImageURL: URL?)
    case failed(jobId: UUID?, message: String)
}

struct AIGenerationBannerState: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case completed
        case failed
    }

    let id: UUID
    let kind: Kind
    let title: String
    let message: String
    let jobId: UUID?
    let resultImageURL: URL?
    let createdAt: Date

    var showsResultCTA: Bool {
        kind == .completed && resultImageURL != nil
    }
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

    @Published private(set) var launchPhase: LaunchPhase = .booting
    @Published private(set) var route: Route = .login
    @Published var errorMessage: String?
    @Published private(set) var currentUser: AppUser?
    @Published private(set) var session: AppSession?
    @Published private(set) var onboardingPrefill: OnboardingPrefill?
    @Published var selectedMainTab: MainTab = .home
    @Published private(set) var isAIDesignSelectionInProgress: Bool = false
    @Published private(set) var selectedAIDesignPayload: AIDesignSelectionPayload?
    @Published private(set) var lastAIDesignSource: AIDesignSourceKind?
    @Published private(set) var aiDesignSelectionFeedResetToken: UUID = UUID()
    @Published private(set) var aiGenerationBanner: AIGenerationBannerState?
    @Published private(set) var aiGenerationBadgeCount: Int = 0
    @Published private(set) var aiResultOpenRequestToken: UUID?
    @Published private(set) var aiGenerationIsRunning: Bool = false
    @Published private(set) var aiGenerationProgressMessage: String = ""
    @Published private(set) var pendingPushJobId: UUID?
    @Published private(set) var pushNavigationToken: UUID?

    private let authService: any AuthServicing
    private let pushManager: any PushNotificationManaging
    private let launchTiming: LaunchTiming
    private let launchTraceId: String

    private var didStart: Bool = false
    private var didLogFirstFrame: Bool = false
    private var activeAIGenerationJobId: UUID?
    private var pendingPushTokenRegistration: (token: String, envHint: APNSEnvironmentHint)?

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

        if isAIDesignSelectionInProgress, tab != .feed {
            isAIDesignSelectionInProgress = false
        }

        if tab == .ai, aiGenerationBadgeCount > 0 {
            aiGenerationBadgeCount = 0
        }
    }

    func beginAIDesignSelectionFromFeed() {
        lastAIDesignSource = .feed
        isAIDesignSelectionInProgress = true
        aiDesignSelectionFeedResetToken = UUID()
        selectedMainTab = .feed
    }

    func completeAIDesignSelection(with source: AIDesignSelectionPayload.Source) {
        switch source {
        case .remoteURL, .localAsset:
            lastAIDesignSource = .feed
        }
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
        aiGenerationBanner = nil
    }

    func updateAIGenerationProgress(message: String) {
        aiGenerationIsRunning = true
        aiGenerationProgressMessage = message
    }

    func completeAIGeneration(jobId: UUID, resultURL: URL?) {
        aiGenerationIsRunning = false
        aiGenerationProgressMessage = "생성이 완료되었습니다."
        activeAIGenerationJobId = nil
        aiGenerationBanner = AIGenerationBannerState(
            id: UUID(),
            kind: .completed,
            title: "AI 생성 완료",
            message: "결과가 준비되었습니다. 확인해 보세요.",
            jobId: jobId,
            resultImageURL: resultURL,
            createdAt: Date()
        )
        if selectedMainTab != .ai {
            aiGenerationBadgeCount += 1
        }
    }

    func failAIGeneration(jobId: UUID?, message: String) {
        aiGenerationIsRunning = false
        aiGenerationProgressMessage = message
        if activeAIGenerationJobId == nil || activeAIGenerationJobId == jobId {
            activeAIGenerationJobId = nil
        }
        aiGenerationBanner = AIGenerationBannerState(
            id: UUID(),
            kind: .failed,
            title: "AI 생성 실패",
            message: message,
            jobId: jobId,
            resultImageURL: nil,
            createdAt: Date()
        )
    }

    func consumeAIGenerationBanner() {
        aiGenerationBanner = nil
    }

    func requestOpenAIResult() {
        aiResultOpenRequestToken = UUID()
        aiGenerationBadgeCount = 0
        aiGenerationBanner = nil
    }

    func consumeAIResultOpenRequest() {
        aiResultOpenRequestToken = nil
    }

    func consumePushNavigationRequest() {
        pendingPushJobId = nil
        pushNavigationToken = nil
    }

    func preparePushNotificationsForAIGeneration() async {
        let granted = await pushManager.requestAuthorizationIfNeeded()
        guard granted else { return }

        guard let latestToken = pushManager.latestDeviceTokenHex else {
            return
        }

        await registerPushTokenIfPossible(
            token: latestToken,
            envHint: pushManager.latestEnvironmentHint
        )
    }

    func start() async {
        guard !didStart else { return }
        didStart = true

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
            await syncPushTokenRegistrationIfPossible()
            route = result.needsOnboarding ? .onboarding : .home
        } catch {
            AppLog.auth.error("\(AppLog.prefix(traceId, "AUTH")) signInWithKakao failed: \(String(describing: error), privacy: .public)")
            errorMessage = "카카오 로그인 실패 (\(traceId)): \(error.localizedDescription)"
            onboardingPrefill = nil
            route = .login
        }
    }

    func completeOnboarding(nickname: String, profileImageURL: String?, defaultRegionID: UUID?) async {
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
                profileImageURL: profileImageURL,
                defaultRegionID: defaultRegionID
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

    func refineNailGenerationJob(
        sourceJobId: UUID,
        shape: NailGenShape,
        userPrompt: String
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
            userPrompt: userPrompt
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

    func fetchFeedList(
        limit: Int,
        cursor: String?,
        styles: [String],
        category: FeedListCategory,
        reservationDate: String?,
        startTime: String?,
        endTime: String?
    ) async throws -> FeedListResponse {
        try await fetchFeedList(
            limit: limit,
            cursor: cursor,
            styles: styles,
            category: category,
            regionID: nil,
            includeDescendants: true,
            reservationDate: reservationDate,
            startTime: startTime,
            endTime: endTime
        )
    }

    func fetchFeedList(
        limit: Int,
        cursor: String?,
        styles: [String],
        category: FeedListCategory,
        regionID: UUID?,
        includeDescendants: Bool = true,
        reservationDate: String?,
        startTime: String?,
        endTime: String?
    ) async throws -> FeedListResponse {
        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.fetchFeedList(
            traceId: traceId,
            session: session,
            limit: limit,
            cursor: cursor,
            styles: styles,
            category: category,
            regionID: regionID,
            includeDescendants: includeDescendants,
            reservationDate: reservationDate,
            startTime: startTime,
            endTime: endTime
        )
        self.session = result.session
        return result.response
    }

    func fetchRegions() async throws -> RegionsListResponse {
        if ProcessInfo.processInfo.arguments.contains("--uitesting-feed-regions") {
            return Self.uiTestingFeedRegions
        }

        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.fetchRegions(
            traceId: traceId,
            session: session
        )
        self.session = result.session
        return result.response
    }

    func fetchRegionsTree() async throws -> RegionsTreeResponse {
        if ProcessInfo.processInfo.arguments.contains("--uitesting-feed-regions") {
            return Self.uiTestingRegionsTree
        }

        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.fetchRegionsTree(
            traceId: traceId,
            session: session
        )
        self.session = result.session
        return result.response
    }

    func fetchRegionBoundary(regionID: UUID) async throws -> RegionBoundaryResponse {
        if ProcessInfo.processInfo.arguments.contains("--uitesting-feed-regions") {
            return Self.uiTestingRegionBoundary(for: regionID)
        }

        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.fetchRegionBoundary(
            traceId: traceId,
            session: session,
            regionID: regionID
        )
        self.session = result.session
        return result.response
    }

    func fetchLikedFeedList(limit: Int, cursor: String?) async throws -> FeedListResponse {
        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.fetchLikedFeedList(
            traceId: traceId,
            session: session,
            limit: limit,
            cursor: cursor
        )
        self.session = result.session
        return result.response
    }

    func fetchFeedDetail(postId: UUID) async throws -> FeedDetailResponse {
        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.fetchFeedDetail(
            traceId: traceId,
            session: session,
            postId: postId
        )
        self.session = result.session
        return result.response
    }

    func setFeedLike(postId: UUID, isLiked: Bool) async throws -> FeedLikeResponse {
        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.setFeedLike(
            traceId: traceId,
            session: session,
            postId: postId,
            isLiked: isLiked
        )
        self.session = result.session
        return result.response
    }

    func searchShops(query: String, limit: Int = 20) async throws -> ShopSearchResponse {
        try await searchShops(query: query, limit: limit, regionId: nil)
    }

    func searchShops(
        query: String,
        limit: Int,
        regionId: UUID?
    ) async throws -> ShopSearchResponse {
        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.searchShops(
            traceId: traceId,
            session: session,
            query: query,
            limit: limit,
            regionId: regionId
        )
        self.session = result.session
        return result.response
    }

    func fetchShopDetail(shopId: UUID) async throws -> ShopDetailResponse {
        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.fetchShopDetail(
            traceId: traceId,
            session: session,
            shopId: shopId
        )
        self.session = result.session
        return result.response
    }

    func fetchShopRecommendations(
        sido: String?,
        sigungu: String?,
        limit: Int = 3
    ) async throws -> ShopRecommendResponse {
        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.fetchShopRecommendations(
            traceId: traceId,
            session: session,
            sido: sido,
            sigungu: sigungu,
            limit: limit
        )
        self.session = result.session
        return result.response
    }

    func fetchReservationSlots(
        referenceId: UUID,
        fromDate: String,
        days: Int = 7
    ) async throws -> ReservationSlotsResponse {
        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.fetchReservationSlots(
            traceId: traceId,
            session: session,
            referenceId: referenceId,
            fromDate: fromDate,
            days: days
        )
        self.session = result.session
        return result.response
    }

    func createReservation(
        referenceId: UUID,
        slotId: UUID,
        selectedOptionsSnapshot: [String: Int]? = nil,
        attachedImageURL: String? = nil,
        aiGenerationId: UUID? = nil
    ) async throws -> ReservationCreateResponse {
        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.createReservation(
            traceId: traceId,
            session: session,
            referenceId: referenceId,
            slotId: slotId,
            selectedOptionsSnapshot: selectedOptionsSnapshot,
            attachedImageURL: attachedImageURL,
            aiGenerationId: aiGenerationId
        )
        self.session = result.session
        return result.response
    }

    func fetchReservationList(
        segment: ReservationListSegment,
        limit: Int = 20,
        cursor: String? = nil
    ) async throws -> ReservationListResponse {
        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.fetchReservationList(
            traceId: traceId,
            session: session,
            segment: segment,
            limit: limit,
            cursor: cursor
        )
        self.session = result.session
        return result.response
    }

    func fetchProfileStyleInsight(postLimit: Int = 12) async throws -> ProfileStyleInsightResponse {
        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.fetchProfileStyleInsight(
            traceId: traceId,
            session: session,
            postLimit: postLimit
        )
        self.session = result.session
        return result.response
    }

    func fetchCompletedNailGenerationList(
        limit: Int = 20,
        cursor: String? = nil
    ) async throws -> NailGenListResponse {
        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.fetchCompletedNailGenerationList(
            traceId: traceId,
            session: session,
            limit: limit,
            cursor: cursor
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

    func createQuoteRequest(
        jobId: UUID,
        targetMode: QuoteTargetMode,
        regionId: UUID,
        selectedShopIDs: [UUID],
        preferredDate: String,
        requestNote: String
    ) async throws -> QuoteRequestCreateResponse {
        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.createQuoteRequest(
            traceId: traceId,
            session: session,
            jobId: jobId,
            targetMode: targetMode,
            regionId: regionId,
            selectedShopIDs: selectedShopIDs,
            preferredDate: preferredDate,
            requestNote: requestNote
        )
        self.session = result.session
        return result.response
    }

    func fetchQuoteRequestList(limit: Int = 20) async throws -> QuoteRequestListResponse {
        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.fetchQuoteRequestList(
            traceId: traceId,
            session: session,
            limit: limit
        )
        self.session = result.session
        return result.response
    }

    func fetchQuoteResponseList(quoteRequestId: UUID) async throws -> QuoteResponseListResponse {
        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.fetchQuoteResponseList(
            traceId: traceId,
            session: session,
            quoteRequestId: quoteRequestId
        )
        self.session = result.session
        return result.response
    }

    func selectQuoteResponse(
        quoteRequestId: UUID,
        targetId: UUID
    ) async throws -> QuoteResponseSelectResponse {
        let traceId = AppLog.makeErrorId()
        guard let session else {
            throw EdgeAPIError(statusCode: 401, message: "No session", errorId: traceId)
        }

        let result = try await authService.selectQuoteResponse(
            traceId: traceId,
            session: session,
            quoteRequestId: quoteRequestId,
            targetId: targetId
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
        // KakaoSDK 로그인 redirect 처리
        _ = AuthController.handleOpenUrl(url: url)
    }

    private func clearLocalSession() async {
        session = nil
        currentUser = nil
        onboardingPrefill = nil
        selectedMainTab = .home
        isAIDesignSelectionInProgress = false
        selectedAIDesignPayload = nil
        lastAIDesignSource = nil
        aiGenerationBanner = nil
        aiGenerationBadgeCount = 0
        aiResultOpenRequestToken = nil
        aiGenerationIsRunning = false
        aiGenerationProgressMessage = ""
        activeAIGenerationJobId = nil
        pendingPushJobId = nil
        pushNavigationToken = nil
        pendingPushTokenRegistration = nil
        await authService.clearLocalSession()
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
        guard route == .home, session != nil else { return }

        selectedMainTab = .ai
        pendingPushJobId = payload.jobId
        pushNavigationToken = UUID()
        aiGenerationBadgeCount = 0
        aiGenerationBanner = nil
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
        FeedRegionPreferenceStore().clear()
        FeedRecentNeighborhoodStore().clear()
        AppRegionSelectionStore().clear()
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

    private static var uiTestingFeedRegions: RegionsListResponse {
        RegionsListResponse(
            cities: [
                RegionsListCityResponse(
                    id: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
                    name: "서울",
                    parentID: nil,
                    level: 1,
                    districts: []
                ),
                RegionsListCityResponse(
                    id: UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!,
                    name: "부산",
                    parentID: nil,
                    level: 1,
                    districts: []
                )
            ]
        )
    }

    private static var uiTestingRegionsTree: RegionsTreeResponse {
        RegionsTreeResponse(
            roots: [
                RegionsTreeNodeResponse(
                    id: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
                    name: "서울특별시",
                    level: 1,
                    parentID: nil,
                    serviceScopeID: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
                    children: [
                        RegionsTreeNodeResponse(
                            id: UUID(uuidString: "aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaa1")!,
                            name: "강남구",
                            level: 2,
                            parentID: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
                            serviceScopeID: UUID(uuidString: "aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaa1")!,
                            children: []
                        )
                    ]
                ),
                RegionsTreeNodeResponse(
                    id: UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!,
                    name: "경기도",
                    level: 1,
                    parentID: nil,
                    serviceScopeID: UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!,
                    children: [
                        RegionsTreeNodeResponse(
                            id: UUID(uuidString: "bbbbbbb1-bbbb-4bbb-8bbb-bbbbbbbbbbb1")!,
                            name: "수원시",
                            level: 2,
                            parentID: UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!,
                            serviceScopeID: UUID(uuidString: "bbbbbbb1-bbbb-4bbb-8bbb-bbbbbbbbbbb1")!,
                            children: [
                                RegionsTreeNodeResponse(
                                    id: UUID(uuidString: "bbbbbbb2-bbbb-4bbb-8bbb-bbbbbbbbbbb2")!,
                                    name: "장안구",
                                    level: 3,
                                    parentID: UUID(uuidString: "bbbbbbb1-bbbb-4bbb-8bbb-bbbbbbbbbbb1")!,
                                    serviceScopeID: UUID(uuidString: "bbbbbbb1-bbbb-4bbb-8bbb-bbbbbbbbbbb1")!,
                                    children: []
                                )
                            ]
                        )
                    ]
                )
            ],
            version: "uitest",
            syncedAt: Date()
        )
    }

    private static func uiTestingRegionBoundary(for regionID: UUID) -> RegionBoundaryResponse {
        RegionBoundaryResponse(
            regionID: regionID,
            resolvedRegionID: regionID,
            bbox: [126.95, 37.25, 127.12, 37.35],
            center: [127.03, 37.30],
            geometry: RegionBoundaryGeometryResponse(
                type: "Polygon",
                coordinates: .array([
                    .array([
                        .array([.number(126.95), .number(37.25)]),
                        .array([.number(127.12), .number(37.25)]),
                        .array([.number(127.12), .number(37.35)]),
                        .array([.number(126.95), .number(37.35)]),
                        .array([.number(126.95), .number(37.25)]),
                    ]),
                ])
            ),
            source: "uitest",
            sourceVersion: "uitest"
        )
    }
}
