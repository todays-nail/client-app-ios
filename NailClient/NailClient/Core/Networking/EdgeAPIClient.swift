//
//  EdgeAPIClient.swift
//  NailClient
//
//  Edge Function API client (소셜 로그인 + 앱 세션/JWT)
//

import Foundation
import OSLog

struct EdgeAPIError: Error, LocalizedError {
    let statusCode: Int
    let message: String
    let code: String?
    let errorId: String?

    init(statusCode: Int, message: String, code: String? = nil, errorId: String?) {
        self.statusCode = statusCode
        self.message = message
        self.code = code
        self.errorId = errorId
    }

    var errorDescription: String? {
        let codePart = code.map { " {\($0)}" } ?? ""
        return if let errorId {
            "(\(statusCode))\(codePart) \(message) [\(errorId)]"
        } else {
            "(\(statusCode))\(codePart) \(message)"
        }
    }
}

final class EdgeAPIClient {
    private let baseURL = URL(string: "https://twahqxjhyocyqrmtjbdf.supabase.co/functions/v1")!
    private let session: URLSession
    private let requestTimeout: TimeInterval
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        session: URLSession? = nil,
        requestTimeout: TimeInterval = 20,
        resourceTimeout: TimeInterval = 20
    ) {
        self.requestTimeout = requestTimeout
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = requestTimeout
            configuration.timeoutIntervalForResource = resourceTimeout
            self.session = URLSession(configuration: configuration)
        }

        decoder = JSONDecoder()
        // Supabase timestamptz는 fractional seconds 유무가 섞여 나올 수 있어 커스텀 파서로 처리.
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { d in
            let c = try d.singleValueContainer()
            let s = try c.decode(String.self)
            if let date = isoFrac.date(from: s) ?? iso.date(from: s) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: c,
                debugDescription: "Invalid date: \(s)"
            )
        }

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    func authKakao(traceId: String, kakaoAccessToken: String, deviceId: String) async throws -> AuthKakaoResponse {
        try await request(
            traceId: traceId,
            path: "auth-kakao",
            method: "POST",
            accessToken: nil,
            body: AuthKakaoRequest(kakaoAccessToken: kakaoAccessToken, deviceId: deviceId)
        )
    }

    func authGoogle(traceId: String, idToken: String, deviceId: String) async throws -> AuthKakaoResponse {
        try await request(
            traceId: traceId,
            path: "auth-google",
            method: "POST",
            accessToken: nil,
            body: AuthGoogleRequest(idToken: idToken, deviceId: deviceId)
        )
    }

    func authApple(traceId: String, idToken: String, deviceId: String) async throws -> AuthKakaoResponse {
        try await request(
            traceId: traceId,
            path: "auth-apple",
            method: "POST",
            accessToken: nil,
            body: AuthAppleRequest(idToken: idToken, deviceId: deviceId)
        )
    }

    func fetchPublicAppConfig(traceId: String) async throws -> PublicAppConfigResponse {
        try await request(
            traceId: traceId,
            path: "public-app-config",
            method: "GET",
            accessToken: nil,
            body: OptionalBody.none
        )
    }

    func fetchPublicOnboardingStyles(traceId: String) async throws -> PublicOnboardingStylesResponse {
        try await request(
            traceId: traceId,
            path: "public-onboarding-styles",
            method: "GET",
            accessToken: nil,
            body: OptionalBody.none
        )
    }

    func authRefresh(traceId: String, refreshToken: String, deviceId: String) async throws -> AuthRefreshResponse {
        try await request(
            traceId: traceId,
            path: "auth-refresh",
            method: "POST",
            accessToken: nil,
            body: AuthRefreshRequest(refreshToken: refreshToken, deviceId: deviceId)
        )
    }

    func authLogout(traceId: String, refreshToken: String, deviceId: String) async throws -> OKResponse {
        try await request(
            traceId: traceId,
            path: "auth-logout",
            method: "POST",
            accessToken: nil,
            body: AuthLogoutRequest(refreshToken: refreshToken, deviceId: deviceId)
        )
    }

    func upsertPushToken(
        traceId: String,
        accessToken: String,
        deviceId: String,
        apnsToken: String,
        apnsEnvHint: String
    ) async throws -> OKResponse {
        try await request(
            traceId: traceId,
            path: "push-token-upsert",
            method: "POST",
            accessToken: accessToken,
            body: PushTokenUpsertRequest(
                deviceId: deviceId,
                apnsToken: apnsToken,
                apnsEnvHint: apnsEnvHint
            )
        )
    }

    func deactivatePushToken(
        traceId: String,
        accessToken: String,
        deviceId: String
    ) async throws -> OKResponse {
        try await request(
            traceId: traceId,
            path: "push-token-deactivate",
            method: "POST",
            accessToken: accessToken,
            body: PushTokenDeactivateRequest(deviceId: deviceId)
        )
    }

    func usersMe(traceId: String, accessToken: String) async throws -> UsersMeResponse {
        try await request(
            traceId: traceId,
            path: "users-me",
            method: "GET",
            accessToken: accessToken,
            body: OptionalBody.none
        )
    }

    func patchUsersMe(
        traceId: String,
        accessToken: String,
        nickname: String?,
        profileImageURL: String?
    ) async throws -> UsersMeResponse {
        try await patchUsersMe(
            traceId: traceId,
            accessToken: accessToken,
            nickname: nickname,
            profileImageURL: profileImageURL,
            defaultRegionID: nil,
            includeDefaultRegionID: false
        )
    }

    func patchUsersMe(
        traceId: String,
        accessToken: String,
        nickname: String?,
        profileImageURL: String?,
        defaultRegionID: UUID?
    ) async throws -> UsersMeResponse {
        try await patchUsersMe(
            traceId: traceId,
            accessToken: accessToken,
            nickname: nickname,
            profileImageURL: profileImageURL,
            defaultRegionID: defaultRegionID,
            includeDefaultRegionID: true
        )
    }

    private func patchUsersMe(
        traceId: String,
        accessToken: String,
        nickname: String?,
        profileImageURL: String?,
        defaultRegionID: UUID?,
        includeDefaultRegionID: Bool
    ) async throws -> UsersMeResponse {
        try await request(
            traceId: traceId,
            path: "users-me",
            method: "PATCH",
            accessToken: accessToken,
            body: UsersMePatchRequest(
                nickname: nickname,
                profileImageURL: profileImageURL,
                defaultRegionID: defaultRegionID,
                includeDefaultRegionID: includeDefaultRegionID
            )
        )
    }

    func usersDelete(
        traceId: String,
        accessToken: String,
        reason: String?
    ) async throws -> OKResponse {
        try await request(
            traceId: traceId,
            path: "users-delete",
            method: "POST",
            accessToken: accessToken,
            body: UsersDeleteRequest(reason: reason)
        )
    }

    func getCompletedNailGenerationList(
        traceId: String,
        accessToken: String,
        limit: Int = 20,
        cursor: String?,
        likedOnly: Bool = false
    ) async throws -> NailGenListResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("nail-gen-list"), resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let cursor, !cursor.isEmpty {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        if likedOnly {
            queryItems.append(URLQueryItem(name: "liked_only", value: "1"))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw EdgeAPIError(statusCode: -1, message: "Invalid nail-gen-list URL", errorId: traceId)
        }

        return try await request(
            traceId: traceId,
            url: url,
            pathForLog: "nail-gen-list",
            method: "GET",
            accessToken: accessToken,
            body: OptionalBody.none
        )
    }

    func setNailGenerationLike(
        traceId: String,
        accessToken: String,
        jobId: UUID,
        isLiked: Bool
    ) async throws -> NailGenLikeResponse {
        try await request(
            traceId: traceId,
            path: "nail-gen-like",
            method: isLiked ? "POST" : "DELETE",
            accessToken: accessToken,
            body: NailGenLikeRequest(jobId: jobId.uuidString.lowercased())
        )
    }

    func deleteNailGeneration(
        traceId: String,
        accessToken: String,
        jobId: UUID
    ) async throws -> NailGenDeleteResponse {
        try await request(
            traceId: traceId,
            path: "nail-gen-delete",
            method: "POST",
            accessToken: accessToken,
            body: NailGenDeleteRequest(
                jobId: jobId.uuidString.lowercased()
            )
        )
    }

    func nailGenUploadURL(
        traceId: String,
        accessToken: String,
        kind: NailGenUploadKind,
        ext: String,
        contentType: String,
        bytes: Int,
        jobId: UUID?
    ) async throws -> NailGenUploadURLResponse {
        try await request(
            traceId: traceId,
            path: "nail-gen-upload-url",
            method: "POST",
            accessToken: accessToken,
            body: NailGenUploadURLRequest(
                kind: kind,
                ext: ext,
                contentType: contentType,
                bytes: bytes,
                jobId: jobId?.uuidString
            )
        )
    }

    func createNailGenerationJob(
        traceId: String,
        accessToken: String,
        shape: NailGenShape,
        extensionMode: NailGenExtensionMode,
        handObjectPath: String,
        referenceObjectPath: String
    ) async throws -> NailGenCreateJobResponse {
        try await request(
            traceId: traceId,
            path: "nail-gen-request",
            method: "POST",
            accessToken: accessToken,
            body: NailGenCreateJobRequest(
                shape: shape,
                extensionMode: extensionMode,
                handObjectPath: handObjectPath,
                referenceObjectPath: referenceObjectPath
            )
        )
    }

    func refineNailGenerationJob(
        traceId: String,
        accessToken: String,
        sourceJobId: UUID,
        shape: NailGenShape,
        extensionMode: NailGenExtensionMode
    ) async throws -> NailGenRefineJobResponse {
        try await request(
            traceId: traceId,
            path: "nail-gen-refine-request",
            method: "POST",
            accessToken: accessToken,
            body: NailGenRefineJobRequest(
                sourceJobId: sourceJobId.uuidString.lowercased(),
                shape: shape,
                extensionMode: extensionMode
            )
        )
    }

    func getNailGenerationJobStatus(
        traceId: String,
        accessToken: String,
        jobId: UUID,
        includeInputs: Bool = false
    ) async throws -> NailGenJobStatusResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("nail-gen-status"), resolvingAgainstBaseURL: false)
        var queryItems = [
            URLQueryItem(name: "job_id", value: jobId.uuidString.lowercased())
        ]
        if includeInputs {
            queryItems.append(URLQueryItem(name: "include_inputs", value: "1"))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw EdgeAPIError(statusCode: -1, message: "Invalid status URL", errorId: traceId)
        }

        return try await request(
            traceId: traceId,
            url: url,
            pathForLog: "nail-gen-status",
            method: "GET",
            accessToken: accessToken,
            body: OptionalBody.none
        )
    }

    func uploadImageToSignedURL(
        traceId: String,
        signedUploadURL: String,
        contentType: String,
        imageData: Data
    ) async throws {
        guard let url = URL(string: signedUploadURL) else {
            throw EdgeAPIError(statusCode: -1, message: "Invalid signed upload URL", errorId: traceId)
        }

        AppLog.api.debug("\(AppLog.prefix(traceId, "API")) -> PUT signed-upload \(url.path, privacy: .public)")
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.timeoutInterval = requestTimeout
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")

        let (_, resp) = try await session.upload(for: req, from: imageData)
        guard let http = resp as? HTTPURLResponse else {
            AppLog.api.error("\(AppLog.prefix(traceId, "API")) invalid upload response (not HTTPURLResponse)")
            throw EdgeAPIError(statusCode: -1, message: "Invalid upload response", errorId: traceId)
        }

        guard (200..<300).contains(http.statusCode) else {
            AppLog.api.error(
                "\(AppLog.prefix(traceId, "API")) <- PUT signed-upload \(url.path, privacy: .public) status=\(http.statusCode, privacy: .public)"
            )
            throw EdgeAPIError(statusCode: http.statusCode, message: "Signed upload failed", errorId: traceId)
        }

        AppLog.api.debug("\(AppLog.prefix(traceId, "API")) <- PUT signed-upload \(url.path, privacy: .public) status=\(http.statusCode, privacy: .public)")
    }

    private func request<T: Decodable, B: Encodable>(
        traceId: String,
        path: String,
        method: String,
        accessToken: String?,
        body: B
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        return try await request(
            traceId: traceId,
            url: url,
            pathForLog: path,
            method: method,
            accessToken: accessToken,
            body: body
        )
    }

    private func request<T: Decodable, B: Encodable>(
        traceId: String,
        url: URL,
        pathForLog: String,
        method: String,
        accessToken: String?,
        body: B
    ) async throws -> T {
        AppLog.api.debug("\(AppLog.prefix(traceId, "API")) -> \(method, privacy: .public) \(pathForLog, privacy: .public)")

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = requestTimeout
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("2", forHTTPHeaderField: "X-Auth-API-Version")

        if let token = normalizeBearerToken(accessToken), !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if method != "GET" {
            req.httpBody = try encoder.encode(body)
        }

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            AppLog.api.error("\(AppLog.prefix(traceId, "API")) invalid response (not HTTPURLResponse)")
            throw EdgeAPIError(statusCode: -1, message: "Invalid response", errorId: traceId)
        }

        guard (200..<300).contains(http.statusCode) else {
            let raw = String(data: data, encoding: .utf8) ?? ""
            let decodedError = try? decoder.decode(EdgeErrorResponse.self, from: data)
            let msg = decodedError?.message ?? (raw.isEmpty ? "Unknown error" : raw)
            let code = decodedError?.code

            let redactedRaw = AppLog.truncate(AppLog.redact(raw))
            let redactedMsg = AppLog.truncate(AppLog.redact(msg))
            let redactedCode = AppLog.truncate(AppLog.redact(code ?? ""))
            AppLog.api.error(
                "\(AppLog.prefix(traceId, "API")) <- \(method, privacy: .public) \(pathForLog, privacy: .public) status=\(http.statusCode, privacy: .public) code=\(redactedCode, privacy: .public) message=\(redactedMsg, privacy: .public) raw=\(redactedRaw, privacy: .public)"
            )

            throw EdgeAPIError(
                statusCode: http.statusCode,
                message: redactedMsg,
                code: code,
                errorId: traceId
            )
        }

        do {
            AppLog.api.debug("\(AppLog.prefix(traceId, "API")) <- \(method, privacy: .public) \(pathForLog, privacy: .public) status=\(http.statusCode, privacy: .public)")
            return try decoder.decode(T.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? ""
            let redactedRaw = AppLog.truncate(AppLog.redact(raw))
            AppLog.api.error(
                "\(AppLog.prefix(traceId, "API")) decode failed <- \(method, privacy: .public) \(pathForLog, privacy: .public) status=\(http.statusCode, privacy: .public) raw=\(redactedRaw, privacy: .public)"
            )
            throw EdgeAPIError(
                statusCode: http.statusCode,
                message: "Decode failed: \(redactedRaw)",
                code: nil,
                errorId: traceId
            )
        }
    }

    private func normalizeBearerToken(_ token: String?) -> String? {
        guard let token else { return nil }
        var result = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if let bearerRange = result.range(of: #"(?i)^bearer\s+"#, options: .regularExpression) {
            result.removeSubrange(bearerRange)
        }

        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        if result.hasPrefix("\""), result.hasSuffix("\""), result.count > 1 {
            result = String(result.dropFirst().dropLast())
        }

        result = result.replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
        return result.isEmpty ? nil : result
    }
}

private struct EdgeErrorResponse: Decodable {
    let message: String
    let code: String?
}

private enum OptionalBody: Encodable {
    case none

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }
}

// MARK: - Models

struct AuthKakaoRequest: Encodable {
    let kakaoAccessToken: String
    let deviceId: String
}

struct AuthGoogleRequest: Encodable {
    let idToken: String
    let deviceId: String
}

struct AuthAppleRequest: Encodable {
    let idToken: String
    let deviceId: String
}

struct AuthRefreshRequest: Encodable {
    let refreshToken: String
    let deviceId: String
}

struct AuthLogoutRequest: Encodable {
    let refreshToken: String
    let deviceId: String
}

struct PushTokenUpsertRequest: Encodable {
    let deviceId: String
    let apnsToken: String
    let apnsEnvHint: String

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case apnsToken = "apns_token"
        case apnsEnvHint = "apns_env_hint"
    }
}

struct PushTokenDeactivateRequest: Encodable {
    let deviceId: String

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
    }
}

struct UsersMePatchRequest: Encodable {
    let nickname: String?
    let profileImageURL: String?
    let defaultRegionID: UUID?
    let includeDefaultRegionID: Bool

    enum CodingKeys: String, CodingKey {
        case nickname
        case profileImageURL = "profile_image_url"
        case defaultRegionID = "default_region_id"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(nickname, forKey: .nickname)
        try container.encodeIfPresent(profileImageURL, forKey: .profileImageURL)
        if includeDefaultRegionID {
            try container.encodeIfPresent(defaultRegionID, forKey: .defaultRegionID)
            if defaultRegionID == nil {
                try container.encodeNil(forKey: .defaultRegionID)
            }
        }
    }
}

struct UsersDeleteRequest: Encodable {
    let reason: String?
}

struct AuthKakaoResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let accessTokenExpiresAt: Date?
    let refreshTokenExpiresAt: Date?
    let sessionID: String?
    let user: AppUser
    let needsOnboarding: Bool
    let onboardingPrefill: OnboardingPrefillResponse?

    enum CodingKeys: String, CodingKey {
        case accessToken
        case refreshToken
        case accessTokenExpiresAt = "access_token_expires_at"
        case refreshTokenExpiresAt = "refresh_token_expires_at"
        case sessionID = "session_id"
        case user
        case needsOnboarding
        case onboardingPrefill = "onboarding_prefill"
    }
}

struct OnboardingPrefillResponse: Decodable {
    let nickname: String?
    let profileImageURL: String?

    enum CodingKeys: String, CodingKey {
        case nickname
        case profileImageURL = "profile_image_url"
    }
}

struct AuthRefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let accessTokenExpiresAt: Date?
    let refreshTokenExpiresAt: Date?
    let sessionID: String?

    enum CodingKeys: String, CodingKey {
        case accessToken
        case refreshToken
        case accessTokenExpiresAt = "access_token_expires_at"
        case refreshTokenExpiresAt = "refresh_token_expires_at"
        case sessionID = "session_id"
    }
}

struct UsersMeResponse: Decodable {
    let user: AppUser
    let needsOnboarding: Bool
}

struct OKResponse: Decodable {
    let ok: Bool
}

struct PublicAppConfigResponse: Decodable {
    let socialLoginUIVariant: String
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case socialLoginUIVariant = "social_login_ui_variant"
        case updatedAt = "updated_at"
    }
}

struct OnboardingStyleAssetDTO: Decodable {
    let key: String
    let imageURL: String
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case key
        case imageURL = "image_url"
        case updatedAt = "updated_at"
    }
}

struct PublicOnboardingStylesResponse: Decodable {
    let styles: [OnboardingStyleAssetDTO]
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case styles
        case updatedAt = "updated_at"
    }
}

struct NailGenListResponse: Decodable, Sendable {
    let items: [NailGenListItemResponse]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}

struct NailGenListItemResponse: Decodable, Sendable {
    let jobId: UUID
    let resultImageURL: String?
    let shape: String?
    let extensionMode: NailGenExtensionMode?
    let createdAt: Date
    let parentJobId: UUID?
    let refinementTurn: Int
    let isLiked: Bool

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case resultImageURL = "result_image_url"
        case shape
        case extensionMode = "extension_mode"
        case createdAt = "created_at"
        case parentJobId = "parent_job_id"
        case refinementTurn = "refinement_turn"
        case isLiked = "is_liked"
    }

    init(
        jobId: UUID,
        resultImageURL: String?,
        shape: String?,
        extensionMode: NailGenExtensionMode?,
        createdAt: Date,
        parentJobId: UUID?,
        refinementTurn: Int,
        isLiked: Bool = false
    ) {
        self.jobId = jobId
        self.resultImageURL = resultImageURL
        self.shape = shape
        self.extensionMode = extensionMode
        self.createdAt = createdAt
        self.parentJobId = parentJobId
        self.refinementTurn = refinementTurn
        self.isLiked = isLiked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        jobId = try container.decode(UUID.self, forKey: .jobId)
        resultImageURL = try container.decodeIfPresent(String.self, forKey: .resultImageURL)
        shape = try container.decodeIfPresent(String.self, forKey: .shape)
        if let rawExtensionMode = try container.decodeIfPresent(String.self, forKey: .extensionMode) {
            extensionMode = NailGenExtensionMode(apiValue: rawExtensionMode)
        } else {
            extensionMode = nil
        }
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        parentJobId = try container.decodeIfPresent(UUID.self, forKey: .parentJobId)
        refinementTurn = try container.decode(Int.self, forKey: .refinementTurn)
        isLiked = try container.decodeIfPresent(Bool.self, forKey: .isLiked) ?? false
    }
}

struct NailGenLikeRequest: Encodable, Sendable {
    let jobId: String

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
    }
}

struct NailGenLikeResponse: Decodable, Sendable {
    let ok: Bool
    let jobId: UUID
    let isLiked: Bool

    enum CodingKeys: String, CodingKey {
        case ok
        case jobId = "job_id"
        case isLiked = "is_liked"
    }
}

struct NailGenDeleteRequest: Encodable, Sendable {
    let jobId: String

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
    }
}

struct NailGenDeleteResponse: Decodable, Sendable {
    let ok: Bool
    let deletedJobIDs: [UUID]

    enum CodingKeys: String, CodingKey {
        case ok
        case deletedJobIDs = "deleted_job_ids"
    }
}

enum NailGenUploadKind: String, Codable, Sendable {
    case hand
    case reference
    case profile
}

enum NailGenShape: String, Codable, Sendable, CaseIterable {
    case almond
    case square
    case round
}

enum NailGenExtensionMode: String, Codable, Sendable, CaseIterable {
    case natural = "NATURAL"
    case extend = "EXTEND"

    init?(apiValue: String) {
        self.init(rawValue: apiValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
    }
}

enum NailGenJobStatus: String, Codable, Sendable {
    case queued
    case processing
    case completed
    case failed
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = NailGenJobStatus(rawValue: raw) ?? .unknown
    }
}

struct NailGenUploadURLRequest: Encodable, Sendable {
    let kind: NailGenUploadKind
    let ext: String
    let contentType: String
    let bytes: Int
    let jobId: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case ext
        case contentType = "content_type"
        case bytes
        case jobId = "job_id"
    }
}

struct NailGenUploadURLResponse: Decodable, Sendable {
    let bucket: String
    let jobId: UUID
    let objectPath: String
    let signedUploadURL: String
    let publicObjectURL: String?
    let expiresInSec: Int

    enum CodingKeys: String, CodingKey {
        case bucket
        case jobId = "job_id"
        case objectPath = "object_path"
        case signedUploadURL = "signed_upload_url"
        case publicObjectURL = "public_object_url"
        case expiresInSec = "expires_in_sec"
    }
}

struct NailGenCreateJobRequest: Encodable, Sendable {
    let shape: NailGenShape
    let extensionMode: NailGenExtensionMode
    let handObjectPath: String
    let referenceObjectPath: String

    enum CodingKeys: String, CodingKey {
        case shape
        case extensionMode = "extension_mode"
        case handObjectPath = "hand_object_path"
        case referenceObjectPath = "reference_object_path"
    }
}

struct NailGenCreateJobResponse: Decodable, Sendable {
    let jobId: UUID
    let status: NailGenJobStatus
    let pollAfterMs: Int

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
        case pollAfterMs = "poll_after_ms"
    }
}

struct NailGenRefineJobRequest: Encodable, Sendable {
    let sourceJobId: String
    let shape: NailGenShape
    let extensionMode: NailGenExtensionMode

    enum CodingKeys: String, CodingKey {
        case sourceJobId = "source_job_id"
        case shape
        case extensionMode = "extension_mode"
    }
}

struct NailGenRefineJobResponse: Decodable, Sendable {
    let jobId: UUID
    let status: NailGenJobStatus
    let pollAfterMs: Int

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
        case pollAfterMs = "poll_after_ms"
    }
}

struct NailGenJobStatusResponse: Decodable, Sendable {
    let status: NailGenJobStatus
    let resultImageURL: String?
    let handImageURL: String?
    let referenceImageURL: String?
    let errorCode: String?
    let errorMessage: String?
    let parentJobId: String?
    let refinementTurn: Int?
    let canRefine: Bool?

    init(
        status: NailGenJobStatus,
        resultImageURL: String?,
        handImageURL: String? = nil,
        referenceImageURL: String? = nil,
        errorCode: String?,
        errorMessage: String?,
        parentJobId: String? = nil,
        refinementTurn: Int? = nil,
        canRefine: Bool? = nil
    ) {
        self.status = status
        self.resultImageURL = resultImageURL
        self.handImageURL = handImageURL
        self.referenceImageURL = referenceImageURL
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.parentJobId = parentJobId
        self.refinementTurn = refinementTurn
        self.canRefine = canRefine
    }

    enum CodingKeys: String, CodingKey {
        case status
        case resultImageURL = "result_image_url"
        case handImageURL = "hand_image_url"
        case referenceImageURL = "reference_image_url"
        case errorCode = "error_code"
        case errorMessage = "error_message"
        case parentJobId = "parent_job_id"
        case refinementTurn = "refinement_turn"
        case canRefine = "can_refine"
    }
}
