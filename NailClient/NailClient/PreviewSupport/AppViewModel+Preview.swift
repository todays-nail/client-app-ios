#if DEBUG
import Foundation

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
        viewModel.configurePreviewState(
            route: route,
            launchPhase: launchPhase,
            currentUser: currentUser,
            session: session,
            onboardingPrefill: onboardingPrefill,
            selectedMainTab: selectedMainTab,
            onboardingStyleImageURLs: onboardingStyleImageURLs,
            pushAuthorizationState: pushAuthorizationState
        )
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
        let resolvedJobID = jobId ?? UUID()
        return (
            NailGenUploadURLResponse(
                bucket: "preview",
                jobId: resolvedJobID,
                objectPath: "preview/\(resolvedJobID.uuidString).jpg",
                signedUploadURL: "https://example.com/upload",
                publicObjectURL: "https://example.com/generated-\(resolvedJobID.uuidString).jpg",
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
