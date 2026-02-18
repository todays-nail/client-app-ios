//
//  EdgeAPIClient.swift
//  NailClient
//
//  Edge Function API client (KakaoSDK 로그인 + 앱 세션/JWT)
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
        try await request(
            traceId: traceId,
            path: "users-me",
            method: "PATCH",
            accessToken: accessToken,
            body: UsersMePatchRequest(nickname: nickname, profileImageURL: profileImageURL)
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

    func getFeedList(
        traceId: String,
        accessToken: String,
        limit: Int = 20,
        cursor: String?,
        styles: [String],
        category: FeedListCategory,
        regionID: UUID? = nil,
        includeDescendants: Bool = true,
        reservationDate: String?,
        startTime: String?,
        endTime: String?
    ) async throws -> FeedListResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("feed-list"), resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "category", value: category.rawValue)
        ]
        if let cursor, !cursor.isEmpty {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        if !styles.isEmpty {
            queryItems.append(URLQueryItem(name: "styles", value: styles.joined(separator: ",")))
        }
        if let regionID {
            queryItems.append(URLQueryItem(name: "region_id", value: regionID.uuidString.lowercased()))
            queryItems.append(URLQueryItem(name: "include_descendants", value: includeDescendants ? "true" : "false"))
        }
        if let reservationDate, !reservationDate.isEmpty {
            queryItems.append(URLQueryItem(name: "reservation_date", value: reservationDate))
        }
        if let startTime, !startTime.isEmpty {
            queryItems.append(URLQueryItem(name: "start_time", value: startTime))
        }
        if let endTime, !endTime.isEmpty {
            queryItems.append(URLQueryItem(name: "end_time", value: endTime))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw EdgeAPIError(statusCode: -1, message: "Invalid feed-list URL", errorId: traceId)
        }

        return try await request(
            traceId: traceId,
            url: url,
            pathForLog: "feed-list",
            method: "GET",
            accessToken: accessToken,
            body: OptionalBody.none
        )
    }

    func getRegionsList(
        traceId: String,
        accessToken: String
    ) async throws -> RegionsListResponse {
        try await request(
            traceId: traceId,
            path: "regions-list",
            method: "GET",
            accessToken: accessToken,
            body: OptionalBody.none
        )
    }

    func getLikedFeedList(
        traceId: String,
        accessToken: String,
        limit: Int = 20,
        cursor: String?
    ) async throws -> FeedListResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("feed-list"), resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "liked_only", value: "1")
        ]
        if let cursor, !cursor.isEmpty {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw EdgeAPIError(statusCode: -1, message: "Invalid liked feed-list URL", errorId: traceId)
        }

        return try await request(
            traceId: traceId,
            url: url,
            pathForLog: "feed-list?liked_only=1",
            method: "GET",
            accessToken: accessToken,
            body: OptionalBody.none
        )
    }

    func getFeedDetail(
        traceId: String,
        accessToken: String,
        postId: UUID
    ) async throws -> FeedDetailResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("feed-detail"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "post_id", value: postId.uuidString.lowercased())
        ]
        guard let url = components?.url else {
            throw EdgeAPIError(statusCode: -1, message: "Invalid feed-detail URL", errorId: traceId)
        }

        return try await request(
            traceId: traceId,
            url: url,
            pathForLog: "feed-detail",
            method: "GET",
            accessToken: accessToken,
            body: OptionalBody.none
        )
    }

    func setFeedLike(
        traceId: String,
        accessToken: String,
        postId: UUID,
        isLiked: Bool
    ) async throws -> FeedLikeResponse {
        try await request(
            traceId: traceId,
            path: "feed-like",
            method: isLiked ? "POST" : "DELETE",
            accessToken: accessToken,
            body: FeedLikeRequest(postId: postId.uuidString.lowercased())
        )
    }

    func searchShops(
        traceId: String,
        accessToken: String,
        query: String,
        limit: Int = 20
    ) async throws -> ShopSearchResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("shop-search"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        guard let url = components?.url else {
            throw EdgeAPIError(statusCode: -1, message: "Invalid shop-search URL", errorId: traceId)
        }

        return try await request(
            traceId: traceId,
            url: url,
            pathForLog: "shop-search",
            method: "GET",
            accessToken: accessToken,
            body: OptionalBody.none
        )
    }

    func getShopDetail(
        traceId: String,
        accessToken: String,
        shopId: UUID
    ) async throws -> ShopDetailResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("shop-detail"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "shop_id", value: shopId.uuidString.lowercased())
        ]
        guard let url = components?.url else {
            throw EdgeAPIError(statusCode: -1, message: "Invalid shop-detail URL", errorId: traceId)
        }

        return try await request(
            traceId: traceId,
            url: url,
            pathForLog: "shop-detail",
            method: "GET",
            accessToken: accessToken,
            body: OptionalBody.none
        )
    }

    func getShopRecommendations(
        traceId: String,
        accessToken: String,
        sido: String?,
        sigungu: String?,
        limit: Int = 3
    ) async throws -> ShopRecommendResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("shop-recommend"), resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let sido, !sido.isEmpty {
            queryItems.append(URLQueryItem(name: "sido", value: sido))
        }
        if let sigungu, !sigungu.isEmpty {
            queryItems.append(URLQueryItem(name: "sigungu", value: sigungu))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw EdgeAPIError(statusCode: -1, message: "Invalid shop-recommend URL", errorId: traceId)
        }

        return try await request(
            traceId: traceId,
            url: url,
            pathForLog: "shop-recommend",
            method: "GET",
            accessToken: accessToken,
            body: OptionalBody.none
        )
    }

    func getReservationSlots(
        traceId: String,
        accessToken: String,
        referenceId: UUID,
        fromDate: String,
        days: Int
    ) async throws -> ReservationSlotsResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("reservation-slots"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "reference_id", value: referenceId.uuidString.lowercased()),
            URLQueryItem(name: "from_date", value: fromDate),
            URLQueryItem(name: "days", value: "\(days)")
        ]
        guard let url = components?.url else {
            throw EdgeAPIError(statusCode: -1, message: "Invalid reservation-slots URL", errorId: traceId)
        }

        return try await request(
            traceId: traceId,
            url: url,
            pathForLog: "reservation-slots",
            method: "GET",
            accessToken: accessToken,
            body: OptionalBody.none
        )
    }

    func createReservation(
        traceId: String,
        accessToken: String,
        referenceId: UUID,
        slotId: UUID,
        selectedOptionsSnapshot: [String: Int]?,
        attachedImageURL: String?,
        aiGenerationId: UUID?
    ) async throws -> ReservationCreateResponse {
        try await request(
            traceId: traceId,
            path: "reservation-create",
            method: "POST",
            accessToken: accessToken,
            body: ReservationCreateRequest(
                referenceId: referenceId.uuidString.lowercased(),
                slotId: slotId.uuidString.lowercased(),
                selectedOptionsSnapshot: selectedOptionsSnapshot,
                attachedImageURL: attachedImageURL,
                aiGenerationId: aiGenerationId?.uuidString.lowercased()
            )
        )
    }

    func getReservationList(
        traceId: String,
        accessToken: String,
        segment: ReservationListSegment,
        limit: Int = 20,
        cursor: String?
    ) async throws -> ReservationListResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("reservation-list"), resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "segment", value: segment.rawValue),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let cursor, !cursor.isEmpty {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw EdgeAPIError(statusCode: -1, message: "Invalid reservation-list URL", errorId: traceId)
        }

        return try await request(
            traceId: traceId,
            url: url,
            pathForLog: "reservation-list",
            method: "GET",
            accessToken: accessToken,
            body: OptionalBody.none
        )
    }

    func getProfileStyleInsight(
        traceId: String,
        accessToken: String,
        postLimit: Int = 12
    ) async throws -> ProfileStyleInsightResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("profile-style-insight"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "post_limit", value: "\(postLimit)")
        ]
        guard let url = components?.url else {
            throw EdgeAPIError(statusCode: -1, message: "Invalid profile-style-insight URL", errorId: traceId)
        }

        return try await request(
            traceId: traceId,
            url: url,
            pathForLog: "profile-style-insight",
            method: "GET",
            accessToken: accessToken,
            body: OptionalBody.none
        )
    }

    func getCompletedNailGenerationList(
        traceId: String,
        accessToken: String,
        limit: Int = 20,
        cursor: String?
    ) async throws -> NailGenListResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("nail-gen-list"), resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let cursor, !cursor.isEmpty {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
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
        userPrompt: String,
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
                userPrompt: userPrompt,
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
        userPrompt: String
    ) async throws -> NailGenRefineJobResponse {
        try await request(
            traceId: traceId,
            path: "nail-gen-refine-request",
            method: "POST",
            accessToken: accessToken,
            body: NailGenRefineJobRequest(
                sourceJobId: sourceJobId.uuidString.lowercased(),
                shape: shape,
                userPrompt: userPrompt
            )
        )
    }

    func getNailGenerationJobStatus(
        traceId: String,
        accessToken: String,
        jobId: UUID
    ) async throws -> NailGenJobStatusResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("nail-gen-status"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "job_id", value: jobId.uuidString.lowercased())
        ]
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

struct AuthRefreshRequest: Encodable {
    let refreshToken: String
    let deviceId: String
}

struct AuthLogoutRequest: Encodable {
    let refreshToken: String
    let deviceId: String
}

struct UsersMePatchRequest: Encodable {
    let nickname: String?
    let profileImageURL: String?

    enum CodingKeys: String, CodingKey {
        case nickname
        case profileImageURL = "profile_image_url"
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

enum FeedListCategory: String, Codable, Sendable {
    case all
    case style
    case reservable
}

struct FeedListResponse: Decodable, Sendable {
    let items: [FeedListItemResponse]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}

struct FeedListItemResponse: Decodable, Sendable {
    let id: UUID
    let thumbnailURL: String
    let likeCount: Int
    let shapeCategory: String
    let isReservable: Bool
    let isLiked: Bool
    let styleTags: [String]
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case thumbnailURL = "thumbnail_url"
        case likeCount = "like_count"
        case shapeCategory = "shape_category"
        case isReservable = "is_reservable"
        case isLiked = "is_liked"
        case styleTags = "style_tags"
        case createdAt = "created_at"
    }
}

struct RegionsListResponse: Decodable, Sendable {
    let cities: [RegionsListCityResponse]
}

struct RegionsListCityResponse: Decodable, Sendable {
    let id: UUID
    let name: String
    let parentID: UUID?
    let level: Int?
    let districts: [RegionsListDistrictResponse]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case parentID = "parent_id"
        case level
        case districts
    }
}

struct RegionsListDistrictResponse: Decodable, Sendable {
    let id: UUID
    let name: String
    let parentID: UUID?
    let level: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case parentID = "parent_id"
        case level
    }
}

struct FeedDetailResponse: Decodable, Sendable {
    let post: FeedDetailPostResponse
    let galleryImageURLs: [String]
    let recentReviews: [FeedRecentReviewResponse]

    enum CodingKeys: String, CodingKey {
        case post
        case galleryImageURLs = "gallery_image_urls"
        case recentReviews = "recent_reviews"
    }
}

struct FeedLikeRequest: Encodable, Sendable {
    let postId: String

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
    }
}

struct FeedLikeResponse: Decodable, Sendable {
    let ok: Bool
    let postId: UUID
    let isLiked: Bool
    let likeCount: Int

    enum CodingKeys: String, CodingKey {
        case ok
        case postId = "post_id"
        case isLiked = "is_liked"
        case likeCount = "like_count"
    }
}

struct ShopSearchResponse: Decodable, Sendable {
    let items: [ShopSearchItemResponse]
}

struct ShopSearchItemResponse: Decodable, Sendable {
    let id: UUID
    let name: String
    let address: String
}

struct ShopDetailResponse: Decodable, Sendable {
    let shop: ShopDetailItemResponse
}

struct ShopRecommendResponse: Decodable, Sendable {
    let scope: String
    let regionLabel: String?
    let items: [ShopRecommendItemResponse]

    enum CodingKeys: String, CodingKey {
        case scope
        case regionLabel = "region_label"
        case items
    }
}

struct ShopRecommendItemResponse: Decodable, Sendable {
    let id: UUID
    let name: String
    let address: String
    let likeCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case likeCount = "like_count"
    }
}

struct ShopDetailItemResponse: Decodable, Sendable {
    let id: UUID
    let name: String
    let address: String
    let addressDetail: String?
    let phone: String?
    let status: String
    let intro: String?
    let openTime: String?
    let closeTime: String?
    let closedWeekdays: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case addressDetail = "address_detail"
        case phone
        case status
        case intro
        case openTime = "open_time"
        case closeTime = "close_time"
        case closedWeekdays = "closed_weekdays"
    }
}

enum ReservationListSegment: String, Codable, Sendable {
    case upcoming
    case past
}

struct ReservationSlotsResponse: Decodable, Sendable {
    let referenceId: UUID
    let shopId: UUID
    let requiredDurationMin: Int
    let fromDate: String
    let days: Int
    let slots: [ReservationSlotResponse]

    enum CodingKeys: String, CodingKey {
        case referenceId = "reference_id"
        case shopId = "shop_id"
        case requiredDurationMin = "required_duration_min"
        case fromDate = "from_date"
        case days
        case slots
    }
}

struct ReservationSlotResponse: Decodable, Sendable {
    let id: UUID
    let shopId: UUID
    let startAt: Date
    let durationMin: Int
    let capacity: Int
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case shopId = "shop_id"
        case startAt = "start_at"
        case durationMin = "duration_min"
        case capacity
        case status
    }
}

struct ReservationCreateRequest: Encodable, Sendable {
    let referenceId: String
    let slotId: String
    let selectedOptionsSnapshot: [String: Int]?
    let attachedImageURL: String?
    let aiGenerationId: String?

    enum CodingKeys: String, CodingKey {
        case referenceId = "reference_id"
        case slotId = "slot_id"
        case selectedOptionsSnapshot = "selected_options_snapshot"
        case attachedImageURL = "attached_image_url"
        case aiGenerationId = "ai_generation_id"
    }
}

struct ReservationCreateResponse: Decodable, Sendable {
    let ok: Bool
    let reservation: ReservationItemResponse
}

struct ReservationListResponse: Decodable, Sendable {
    let items: [ReservationItemResponse]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}

struct ProfileStyleInsightResponse: Decodable, Sendable {
    let summary: ProfileStyleInsightSummaryResponse
    let basis: ProfileStyleInsightBasisResponse
    let recommendations: ProfileStyleInsightRecommendationsResponse
}

struct ProfileStyleInsightSummaryResponse: Decodable, Sendable {
    let rankText: String
    let subtitle: String
    let items: [ProfileStyleInsightItemResponse]
    let confidence: Double

    enum CodingKeys: String, CodingKey {
        case rankText = "rank_text"
        case subtitle
        case items
        case confidence
    }
}

struct ProfileStyleInsightItemResponse: Decodable, Sendable {
    let tag: String
    let ratio: Double
    let likedScore: Double
    let serviceScore: Double

    enum CodingKeys: String, CodingKey {
        case tag
        case ratio
        case likedScore = "liked_score"
        case serviceScore = "service_score"
    }
}

struct ProfileStyleInsightBasisResponse: Decodable, Sendable {
    let likedDesignCount: Int
    let completedServiceCount: Int

    enum CodingKeys: String, CodingKey {
        case likedDesignCount = "liked_design_count"
        case completedServiceCount = "completed_service_count"
    }
}

struct ProfileStyleInsightRecommendationsResponse: Decodable, Sendable {
    let tags: [String]
    let posts: [ProfileStyleInsightRecommendationPostResponse]
}

struct ProfileStyleInsightRecommendationPostResponse: Decodable, Sendable {
    let id: UUID
    let thumbnailURL: String
    let styleTags: [String]
    let isReservable: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case thumbnailURL = "thumbnail_url"
        case styleTags = "style_tags"
        case isReservable = "is_reservable"
        case createdAt = "created_at"
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
    let userPrompt: String?
    let createdAt: Date
    let parentJobId: UUID?
    let refinementTurn: Int

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case resultImageURL = "result_image_url"
        case shape
        case userPrompt = "user_prompt"
        case createdAt = "created_at"
        case parentJobId = "parent_job_id"
        case refinementTurn = "refinement_turn"
    }
}

struct ReservationItemResponse: Decodable, Sendable {
    let id: UUID
    let status: String
    let shopId: UUID
    let shopName: String
    let shopAddress: String
    let referenceId: UUID
    let referenceTitle: String
    let slotId: UUID
    let slotStartAt: Date
    let slotDurationMin: Int
    let attachedImageURL: String?
    let aiGenerationId: UUID?
    let selectedOptionsSnapshot: [String: Int]
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case shopId = "shop_id"
        case shopName = "shop_name"
        case shopAddress = "shop_address"
        case referenceId = "reference_id"
        case referenceTitle = "reference_title"
        case slotId = "slot_id"
        case slotStartAt = "slot_start_at"
        case slotDurationMin = "slot_duration_min"
        case attachedImageURL = "attached_image_url"
        case aiGenerationId = "ai_generation_id"
        case selectedOptionsSnapshot = "selected_options_snapshot"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        status = try container.decode(String.self, forKey: .status)
        shopId = try container.decode(UUID.self, forKey: .shopId)
        shopName = try container.decode(String.self, forKey: .shopName)
        shopAddress = try container.decode(String.self, forKey: .shopAddress)
        referenceId = try container.decode(UUID.self, forKey: .referenceId)
        referenceTitle = try container.decode(String.self, forKey: .referenceTitle)
        slotId = try container.decode(UUID.self, forKey: .slotId)
        slotStartAt = try container.decode(Date.self, forKey: .slotStartAt)
        slotDurationMin = try container.decode(Int.self, forKey: .slotDurationMin)
        attachedImageURL = try container.decodeIfPresent(String.self, forKey: .attachedImageURL)
        aiGenerationId = try container.decodeIfPresent(UUID.self, forKey: .aiGenerationId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)

        if let ints = try? container.decode([String: Int].self, forKey: .selectedOptionsSnapshot) {
            selectedOptionsSnapshot = ints
        } else if let doubles = try? container.decode([String: Double].self, forKey: .selectedOptionsSnapshot) {
            selectedOptionsSnapshot = doubles.reduce(into: [:]) { partialResult, item in
                partialResult[item.key] = Int(item.value)
            }
        } else if let strings = try? container.decode([String: String].self, forKey: .selectedOptionsSnapshot) {
            selectedOptionsSnapshot = strings.reduce(into: [:]) { partialResult, item in
                partialResult[item.key] = Int(item.value) ?? 0
            }
        } else {
            selectedOptionsSnapshot = [:]
        }
    }
}

struct FeedDetailPostResponse: Decodable, Sendable {
    let id: UUID
    let title: String
    let thumbnailURL: String
    let shopId: UUID?
    let likeCount: Int
    let shapeCategory: String
    let isReservable: Bool
    let isLiked: Bool
    let styleTags: [String]
    let studioName: String
    let locationText: String
    let distanceKM: Double?
    let originalPrice: Int
    let discountedPrice: Int
    let durationMin: Int
    let description: String
    let reviewCount: Int
    let ratingAvg: Double
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case thumbnailURL = "thumbnail_url"
        case shopId = "shop_id"
        case likeCount = "like_count"
        case shapeCategory = "shape_category"
        case isReservable = "is_reservable"
        case isLiked = "is_liked"
        case styleTags = "style_tags"
        case studioName = "studio_name"
        case locationText = "location_text"
        case distanceKM = "distance_km"
        case originalPrice = "original_price"
        case discountedPrice = "discounted_price"
        case durationMin = "duration_min"
        case description
        case reviewCount = "review_count"
        case ratingAvg = "rating_avg"
        case createdAt = "created_at"
    }
}

struct FeedRecentReviewResponse: Decodable, Sendable {
    let userName: String
    let rating: Int
    let comment: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case userName = "user_name"
        case rating
        case comment
        case createdAt = "created_at"
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
    let userPrompt: String
    let handObjectPath: String
    let referenceObjectPath: String

    enum CodingKeys: String, CodingKey {
        case shape
        case userPrompt = "user_prompt"
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
    let userPrompt: String

    enum CodingKeys: String, CodingKey {
        case sourceJobId = "source_job_id"
        case shape
        case userPrompt = "user_prompt"
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
    let errorCode: String?
    let errorMessage: String?
    let parentJobId: String?
    let refinementTurn: Int?
    let canRefine: Bool?

    init(
        status: NailGenJobStatus,
        resultImageURL: String?,
        errorCode: String?,
        errorMessage: String?,
        parentJobId: String? = nil,
        refinementTurn: Int? = nil,
        canRefine: Bool? = nil
    ) {
        self.status = status
        self.resultImageURL = resultImageURL
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.parentJobId = parentJobId
        self.refinementTurn = refinementTurn
        self.canRefine = canRefine
    }

    enum CodingKeys: String, CodingKey {
        case status
        case resultImageURL = "result_image_url"
        case errorCode = "error_code"
        case errorMessage = "error_message"
        case parentJobId = "parent_job_id"
        case refinementTurn = "refinement_turn"
        case canRefine = "can_refine"
    }
}
