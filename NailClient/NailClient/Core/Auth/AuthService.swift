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

protocol AuthServicing {
    func tryAutoLogin(traceId: String, timeout: Duration) async throws -> AuthResult?
    func signInWithKakao(traceId: String) async throws -> AuthResult
    func completeOnboarding(
        traceId: String,
        session: AppSession,
        nickname: String,
        phone: String?,
        profileImageURL: String?
    ) async throws -> (user: AppUser, needsOnboarding: Bool, session: AppSession)
    func updateMyProfile(
        traceId: String,
        session: AppSession,
        nickname: String,
        phone: String?,
        profileImageURL: String?
    ) async throws -> (user: AppUser, session: AppSession)
    func issueNailGenerationUploadURL(
        traceId: String,
        session: AppSession,
        kind: NailGenUploadKind,
        ext: String,
        contentType: String,
        bytes: Int,
        jobId: UUID?
    ) async throws -> (response: NailGenUploadURLResponse, session: AppSession)
    func uploadImageToSignedURL(
        traceId: String,
        signedUploadURL: String,
        contentType: String,
        imageData: Data
    ) async throws
    func createNailGenerationJob(
        traceId: String,
        session: AppSession,
        shape: NailGenShape,
        userPrompt: String,
        handObjectPath: String,
        referenceObjectPath: String
    ) async throws -> (response: NailGenCreateJobResponse, session: AppSession)
    func getNailGenerationJobStatus(
        traceId: String,
        session: AppSession,
        jobId: UUID
    ) async throws -> (response: NailGenJobStatusResponse, session: AppSession)
    func fetchFeedList(
        traceId: String,
        session: AppSession,
        limit: Int,
        cursor: String?,
        styles: [String],
        category: FeedListCategory,
        reservationDate: String?,
        startTime: String?,
        endTime: String?
    ) async throws -> (response: FeedListResponse, session: AppSession)
    func fetchLikedFeedList(
        traceId: String,
        session: AppSession,
        limit: Int,
        cursor: String?
    ) async throws -> (response: FeedListResponse, session: AppSession)
    func fetchFeedDetail(
        traceId: String,
        session: AppSession,
        postId: UUID
    ) async throws -> (response: FeedDetailResponse, session: AppSession)
    func setFeedLike(
        traceId: String,
        session: AppSession,
        postId: UUID,
        isLiked: Bool
    ) async throws -> (response: FeedLikeResponse, session: AppSession)
    func signOut(traceId: String) async
    func clearLocalSession() async
}

private enum AuthServiceTimeoutError: LocalizedError {
    case autoLoginTimeout

    var errorDescription: String? {
        switch self {
        case .autoLoginTimeout:
            return "자동 로그인 시간이 초과되었습니다."
        }
    }
}

final class AuthService: @unchecked Sendable, AuthServicing {
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

    func ensureDeviceId() async -> String {
        if let existing = await readDeviceId(), !existing.isEmpty { return existing }
        let newId = UUID().uuidString
        await writeDeviceId(newId)
        return newId
    }

    func tryAutoLogin(traceId: String, timeout: Duration = .seconds(5)) async throws -> AuthResult? {
        try await withTimeout(timeout: timeout) { [self] in
            _ = await ensureDeviceId()
            guard let refreshToken = await readRefreshToken(), !refreshToken.isEmpty else { return nil }

            let session = try await refreshSession(traceId: traceId, refreshToken: refreshToken)
            let me = try await api.usersMe(traceId: traceId, accessToken: session.accessToken)
            return AuthResult(
                session: session,
                user: me.user,
                needsOnboarding: me.needsOnboarding,
                onboardingPrefill: nil
            )
        }
    }

    func signInWithKakao(traceId: String) async throws -> AuthResult {
        let deviceId = await ensureDeviceId()
        let kakaoAccessToken = try await kakao.loginAccessToken(traceId: traceId)

        let response = try await api.authKakao(
            traceId: traceId,
            kakaoAccessToken: kakaoAccessToken,
            deviceId: deviceId
        )

        let session = AppSession(accessToken: response.accessToken, refreshToken: response.refreshToken)
        await writeRefreshToken(response.refreshToken)
        return AuthResult(
            session: session,
            user: response.user,
            needsOnboarding: response.needsOnboarding,
            onboardingPrefill: mapOnboardingPrefill(response.onboardingPrefill)
        )
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

    func updateMyProfile(
        traceId: String,
        session: AppSession,
        nickname: String,
        phone: String?,
        profileImageURL: String?
    ) async throws -> (user: AppUser, session: AppSession) {
        let (updated, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.patchUsersMe(
                traceId: traceId,
                accessToken: accessToken,
                nickname: nickname,
                phone: phone,
                profileImageURL: profileImageURL
            )
        }

        return (updated.user, newSession)
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
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.nailGenUploadURL(
                traceId: traceId,
                accessToken: accessToken,
                kind: kind,
                ext: ext,
                contentType: contentType,
                bytes: bytes,
                jobId: jobId
            )
        }
        return (response, newSession)
    }

    func uploadImageToSignedURL(
        traceId: String,
        signedUploadURL: String,
        contentType: String,
        imageData: Data
    ) async throws {
        try await api.uploadImageToSignedURL(
            traceId: traceId,
            signedUploadURL: signedUploadURL,
            contentType: contentType,
            imageData: imageData
        )
    }

    func createNailGenerationJob(
        traceId: String,
        session: AppSession,
        shape: NailGenShape,
        userPrompt: String,
        handObjectPath: String,
        referenceObjectPath: String
    ) async throws -> (response: NailGenCreateJobResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.createNailGenerationJob(
                traceId: traceId,
                accessToken: accessToken,
                shape: shape,
                userPrompt: userPrompt,
                handObjectPath: handObjectPath,
                referenceObjectPath: referenceObjectPath
            )
        }
        return (response, newSession)
    }

    func getNailGenerationJobStatus(
        traceId: String,
        session: AppSession,
        jobId: UUID
    ) async throws -> (response: NailGenJobStatusResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.getNailGenerationJobStatus(
                traceId: traceId,
                accessToken: accessToken,
                jobId: jobId
            )
        }
        return (response, newSession)
    }

    func fetchFeedList(
        traceId: String,
        session: AppSession,
        limit: Int,
        cursor: String?,
        styles: [String],
        category: FeedListCategory,
        reservationDate: String?,
        startTime: String?,
        endTime: String?
    ) async throws -> (response: FeedListResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.getFeedList(
                traceId: traceId,
                accessToken: accessToken,
                limit: limit,
                cursor: cursor,
                styles: styles,
                category: category,
                reservationDate: reservationDate,
                startTime: startTime,
                endTime: endTime
            )
        }
        return (response, newSession)
    }

    func fetchLikedFeedList(
        traceId: String,
        session: AppSession,
        limit: Int,
        cursor: String?
    ) async throws -> (response: FeedListResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.getLikedFeedList(
                traceId: traceId,
                accessToken: accessToken,
                limit: limit,
                cursor: cursor
            )
        }
        return (response, newSession)
    }

    func fetchFeedDetail(
        traceId: String,
        session: AppSession,
        postId: UUID
    ) async throws -> (response: FeedDetailResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.getFeedDetail(
                traceId: traceId,
                accessToken: accessToken,
                postId: postId
            )
        }
        return (response, newSession)
    }

    func setFeedLike(
        traceId: String,
        session: AppSession,
        postId: UUID,
        isLiked: Bool
    ) async throws -> (response: FeedLikeResponse, session: AppSession) {
        let (response, newSession) = try await withAutoRefresh(traceId: traceId, session: session) { accessToken in
            try await api.setFeedLike(
                traceId: traceId,
                accessToken: accessToken,
                postId: postId,
                isLiked: isLiked
            )
        }
        return (response, newSession)
    }

    func signOut(traceId: String) async {
        _ = await ensureDeviceId()
        guard let refreshToken = await readRefreshToken(), let deviceId = await readDeviceId() else {
            await writeRefreshToken(nil)
            return
        }

        do {
            _ = try await api.authLogout(traceId: traceId, refreshToken: refreshToken, deviceId: deviceId)
        } catch {
            // Server revoke failure must not block local sign out.
            AppLog.api.error("\(AppLog.prefix(traceId, "API")) signOut server revoke failed: \(String(describing: error), privacy: .public)")
        }

        await writeRefreshToken(nil)
    }

    func clearLocalSession() async {
        await writeRefreshToken(nil)
    }

    private func refreshSession(traceId: String, refreshToken: String) async throws -> AppSession {
        guard let deviceId = await readDeviceId() else {
            throw EdgeAPIError(statusCode: 400, message: "Missing deviceId", errorId: traceId)
        }

        let refreshed = try await api.authRefresh(traceId: traceId, refreshToken: refreshToken, deviceId: deviceId)
        await writeRefreshToken(refreshed.refreshToken)
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

    private func withTimeout<T: Sendable>(
        timeout: Duration,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw AuthServiceTimeoutError.autoLoginTimeout
            }

            guard let first = try await group.next() else {
                throw AuthServiceTimeoutError.autoLoginTimeout
            }
            group.cancelAll()
            return first
        }
    }

    private func readDeviceId() async -> String? {
        await Task.detached(priority: .utility) { [keychain] in
            keychain.deviceId
        }.value
    }

    private func writeDeviceId(_ value: String?) async {
        await Task.detached(priority: .utility) { [keychain] in
            keychain.deviceId = value
        }.value
    }

    private func readRefreshToken() async -> String? {
        await Task.detached(priority: .utility) { [keychain] in
            keychain.refreshToken
        }.value
    }

    private func writeRefreshToken(_ value: String?) async {
        await Task.detached(priority: .utility) { [keychain] in
            keychain.refreshToken = value
        }.value
    }

    private func mapOnboardingPrefill(_ response: OnboardingPrefillResponse?) -> OnboardingPrefill? {
        guard let response else { return nil }

        let nickname = response.nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        let profileImageURL = response.profileImageURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        if (nickname?.isEmpty ?? true), (profileImageURL?.isEmpty ?? true) {
            return nil
        }

        return OnboardingPrefill(
            nickname: nickname?.isEmpty == false ? nickname : nil,
            profileImageURL: profileImageURL?.isEmpty == false ? profileImageURL : nil
        )
    }
}
