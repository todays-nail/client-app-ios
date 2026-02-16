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
        requestTimeout: TimeInterval = 4,
        resourceTimeout: TimeInterval = 8
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

    private func request<T: Decodable, B: Encodable>(
        traceId: String,
        path: String,
        method: String,
        accessToken: String?,
        body: B
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        AppLog.api.debug("\(AppLog.prefix(traceId, "API")) -> \(method, privacy: .public) \(path, privacy: .public)")

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
                "\(AppLog.prefix(traceId, "API")) <- \(method, privacy: .public) \(path, privacy: .public) status=\(http.statusCode, privacy: .public) message=\(redactedMsg, privacy: .public) raw=\(redactedRaw, privacy: .public)"
            )

            throw EdgeAPIError(statusCode: http.statusCode, message: redactedMsg, errorId: traceId)
        }

        do {
            AppLog.api.debug("\(AppLog.prefix(traceId, "API")) <- \(method, privacy: .public) \(path, privacy: .public) status=\(http.statusCode, privacy: .public)")
            return try decoder.decode(T.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? ""
            let redactedRaw = AppLog.truncate(AppLog.redact(raw))
            AppLog.api.error(
                "\(AppLog.prefix(traceId, "API")) decode failed <- \(method, privacy: .public) \(path, privacy: .public) status=\(http.statusCode, privacy: .public) raw=\(redactedRaw, privacy: .public)"
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
