import Foundation
@testable import NailClient

enum MockAutoLoginBehavior {
    case immediate(AuthResult?)
    case immediateFailure(Error)
    case respectTimeoutAndFail
}

enum MockAuthError: Error {
    case timeout
    case unsupported
    case profileUpdateFailed
    case deleteFailed
}

enum MockUpdateMyProfileBehavior {
    case unsupported
    case success(user: AppUser, session: AppSession)
    case failure(Error)
}

enum MockDeleteMyAccountBehavior {
    case unsupported
    case success
    case failure(Error)
}

actor MockAuthService: AuthServicing {
    let behavior: MockAutoLoginBehavior
    let signInWithGoogleResult: Result<AuthResult, Error>?
    let signInWithAppleResult: Result<AuthResult, Error>?
    let updateMyProfileBehavior: MockUpdateMyProfileBehavior
    let deleteMyAccountBehavior: MockDeleteMyAccountBehavior
    private(set) var clearLocalSessionCallCount: Int = 0
    private(set) var upsertPushTokenCallCount: Int = 0

    init(
        behavior: MockAutoLoginBehavior,
        signInWithGoogleResult: Result<AuthResult, Error>? = nil,
        signInWithAppleResult: Result<AuthResult, Error>? = nil,
        updateMyProfileBehavior: MockUpdateMyProfileBehavior = .unsupported,
        deleteMyAccountBehavior: MockDeleteMyAccountBehavior = .unsupported
    ) {
        self.behavior = behavior
        self.signInWithGoogleResult = signInWithGoogleResult
        self.signInWithAppleResult = signInWithAppleResult
        self.updateMyProfileBehavior = updateMyProfileBehavior
        self.deleteMyAccountBehavior = deleteMyAccountBehavior
    }

    func tryAutoLogin(traceId: String, timeout: Duration) async throws -> AuthResult? {
        _ = traceId
        switch behavior {
        case .immediate(let result):
            return result
        case .immediateFailure(let error):
            throw error
        case .respectTimeoutAndFail:
            try await Task.sleep(for: timeout + .milliseconds(80))
            throw MockAuthError.timeout
        }
    }

    func signInWithKakao(traceId: String) async throws -> AuthResult {
        _ = traceId
        throw MockAuthError.unsupported
    }

    func signInWithGoogle(traceId: String) async throws -> AuthResult {
        _ = traceId
        guard let signInWithGoogleResult else {
            throw MockAuthError.unsupported
        }
        return try signInWithGoogleResult.get()
    }

    func signInWithApple(traceId: String) async throws -> AuthResult {
        _ = traceId
        guard let signInWithAppleResult else {
            throw MockAuthError.unsupported
        }
        return try signInWithAppleResult.get()
    }

    func completeOnboarding(
        traceId: String,
        session: AppSession,
        nickname: String,
        profileImageURL: String?
    ) async throws -> (user: AppUser, needsOnboarding: Bool, session: AppSession) {
        _ = traceId
        _ = session
        _ = nickname
        _ = profileImageURL
        throw MockAuthError.unsupported
    }

    func updateMyProfile(
        traceId: String,
        session: AppSession,
        nickname: String,
        profileImageURL: String?
    ) async throws -> (user: AppUser, session: AppSession) {
        _ = traceId
        _ = session
        _ = nickname
        _ = profileImageURL
        switch updateMyProfileBehavior {
        case .unsupported:
            throw MockAuthError.unsupported
        case let .success(user, session):
            return (user, session)
        case let .failure(error):
            throw error
        }
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
        _ = session
        _ = kind
        _ = ext
        _ = contentType
        _ = bytes
        _ = jobId
        throw MockAuthError.unsupported
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
        throw MockAuthError.unsupported
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
        _ = session
        _ = shape
        _ = extensionMode
        _ = handObjectPath
        _ = referenceObjectPath
        throw MockAuthError.unsupported
    }

    func refineNailGenerationJob(
        traceId: String,
        session: AppSession,
        sourceJobId: UUID,
        shape: NailGenShape,
        extensionMode: NailGenExtensionMode
    ) async throws -> (response: NailGenRefineJobResponse, session: AppSession) {
        _ = traceId
        _ = session
        _ = sourceJobId
        _ = shape
        _ = extensionMode
        throw MockAuthError.unsupported
    }

    func getNailGenerationJobStatus(
        traceId: String,
        session: AppSession,
        jobId: UUID
    ) async throws -> (response: NailGenJobStatusResponse, session: AppSession) {
        _ = traceId
        _ = session
        _ = jobId
        throw MockAuthError.unsupported
    }

    func deleteMyAccount(
        traceId: String,
        session: AppSession,
        reason: String?
    ) async throws {
        _ = traceId
        _ = session
        _ = reason
        switch deleteMyAccountBehavior {
        case .unsupported:
            throw MockAuthError.unsupported
        case .success:
            return
        case let .failure(error):
            throw error
        }
    }

    func upsertPushToken(
        traceId: String,
        session: AppSession,
        deviceId: String,
        apnsToken: String,
        apnsEnvHint: String
    ) async throws -> (response: OKResponse, session: AppSession) {
        _ = traceId
        _ = deviceId
        _ = apnsToken
        _ = apnsEnvHint
        upsertPushTokenCallCount += 1
        return (OKResponse(ok: true), session)
    }

    func signOut(traceId: String) async {
        _ = traceId
    }

    func clearLocalSession() async {
        clearLocalSessionCallCount += 1
    }
}

@MainActor
final class MockPushNotificationManager: PushNotificationManaging {
    var latestDeviceTokenHex: String?
    var latestEnvironmentHint: APNSEnvironmentHint
    var onDeviceTokenUpdated: ((String, APNSEnvironmentHint) -> Void)?
    var onNotificationTapped: ((PushNotificationRoutePayload) -> Void)?

    private(set) var requestAuthorizationCallCount: Int = 0
    private(set) var fetchAuthorizationStateCallCount: Int = 0

    var requestAuthorizationResult: Bool
    var authorizationState: PushAuthorizationState

    init(
        latestDeviceTokenHex: String? = nil,
        latestEnvironmentHint: APNSEnvironmentHint = .sandbox,
        requestAuthorizationResult: Bool,
        authorizationState: PushAuthorizationState
    ) {
        self.latestDeviceTokenHex = latestDeviceTokenHex
        self.latestEnvironmentHint = latestEnvironmentHint
        self.requestAuthorizationResult = requestAuthorizationResult
        self.authorizationState = authorizationState
    }

    func configure() {}

    func requestAuthorizationIfNeeded() async -> Bool {
        requestAuthorizationCallCount += 1
        return requestAuthorizationResult
    }

    func fetchAuthorizationState() async -> PushAuthorizationState {
        fetchAuthorizationStateCallCount += 1
        return authorizationState
    }

    func handleDidRegisterForRemoteNotifications(deviceToken: Data) {
        latestDeviceTokenHex = deviceToken.map { String(format: "%02x", $0) }.joined()
    }

    func handleDidFailToRegisterForRemoteNotifications(error: Error) {
        _ = error
    }

    func handleLaunchRemoteNotification(userInfo: [AnyHashable: Any]) {
        _ = userInfo
    }
}
