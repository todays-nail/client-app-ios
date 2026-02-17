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
    let errorId: String?

    var errorDescription: String? {
        if let errorId {
            "(\(statusCode)) \(message) [\(errorId)]"
        } else {
            "(\(statusCode)) \(message)"
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
        phone: String?,
        profileImageURL: String?
    ) async throws -> UsersMeResponse {
        try await request(
            traceId: traceId,
            path: "users-me",
            method: "PATCH",
            accessToken: accessToken,
            body: UsersMePatchRequest(nickname: nickname, phone: phone, profileImageURL: profileImageURL)
        )
    }

    func getFeedList(
        traceId: String,
        accessToken: String,
        limit: Int = 20,
        cursor: String?,
        styles: [String],
        category: FeedListCategory,
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

        if let accessToken {
            req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
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
            let msg = (try? decoder.decode(EdgeErrorResponse.self, from: data).message)
                ?? raw
                ?? "Unknown error"

            let redactedRaw = AppLog.truncate(AppLog.redact(raw))
            let redactedMsg = AppLog.truncate(AppLog.redact(msg))
            AppLog.api.error(
                "\(AppLog.prefix(traceId, "API")) <- \(method, privacy: .public) \(pathForLog, privacy: .public) status=\(http.statusCode, privacy: .public) message=\(redactedMsg, privacy: .public) raw=\(redactedRaw, privacy: .public)"
            )

            throw EdgeAPIError(statusCode: http.statusCode, message: redactedMsg, errorId: traceId)
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
                errorId: traceId
            )
        }
    }
}

private struct EdgeErrorResponse: Decodable {
    let message: String
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
    let phone: String?
    let profileImageURL: String?

    enum CodingKeys: String, CodingKey {
        case nickname
        case phone
        case profileImageURL = "profile_image_url"
    }
}

struct AuthKakaoResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let user: AppUser
    let needsOnboarding: Bool
    let onboardingPrefill: OnboardingPrefillResponse?

    enum CodingKeys: String, CodingKey {
        case accessToken
        case refreshToken
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

struct FeedDetailPostResponse: Decodable, Sendable {
    let id: UUID
    let title: String
    let thumbnailURL: String
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
    let expiresInSec: Int

    enum CodingKeys: String, CodingKey {
        case bucket
        case jobId = "job_id"
        case objectPath = "object_path"
        case signedUploadURL = "signed_upload_url"
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

struct NailGenJobStatusResponse: Decodable, Sendable {
    let status: NailGenJobStatus
    let resultImageURL: String?
    let errorCode: String?
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case status
        case resultImageURL = "result_image_url"
        case errorCode = "error_code"
        case errorMessage = "error_message"
    }
}
