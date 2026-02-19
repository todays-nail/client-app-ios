//
//  AppLog.swift
//  NailClient
//
//  Xcode Console share-friendly logging (no token/PII leakage).
//

import Foundation
import OSLog

enum AppLog {
    static let subsystem: String = Bundle.main.bundleIdentifier ?? "com.todaysnail.NailClient"

    static let auth = Logger(subsystem: subsystem, category: "AUTH")
    static let api = Logger(subsystem: subsystem, category: "API")
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let launch = Logger(subsystem: subsystem, category: "LAUNCH")

    static func makeErrorId() -> String {
        // Example: E6F3A91C
        let hex = UUID().uuidString.replacingOccurrences(of: "-", with: "").uppercased()
        return "E" + String(hex.prefix(8))
    }

    static func prefix(_ errorId: String, _ category: String) -> String {
        "[TODAYSNAIL][\(errorId)][\(category)]"
    }

    static func truncate(_ s: String, limit: Int = 1024) -> String {
        guard s.utf8.count > limit else { return s }
        // Keep it ASCII-safe and simple.
        return String(s.prefix(limit)) + "...(truncated)"
    }

    static func redact(_ s: String) -> String {
        var out = s

        // Authorization: Bearer <token>
        out = out.replacingOccurrences(
            of: #"(?i)Bearer\s+[A-Za-z0-9\-._~+/]+=*"#,
            with: "Bearer <redacted>",
            options: [.regularExpression]
        )

        // JSON fields that must not be logged.
        // e.g. "accessToken":"...", "refreshToken":"...", "kakaoAccessToken":"...", "idToken":"..."
        out = out.replacingOccurrences(
            of: #""(accessToken|refreshToken|kakaoAccessToken|idToken|googleIdToken)"\s*:\s*"[^"]*""#,
            with: "\"$1\":\"<redacted>\"",
            options: [.regularExpression]
        )

        // Also redact snake_case variants often returned by providers.
        out = out.replacingOccurrences(
            of: #""(access_token|refresh_token|id_token)"\s*:\s*"[^"]*""#,
            with: "\"$1\":\"<redacted>\"",
            options: [.regularExpression]
        )

        // Phone number (best-effort).
        out = out.replacingOccurrences(
            of: #""phone"\s*:\s*"[^"]*""#,
            with: "\"phone\":\"<redacted>\"",
            options: [.regularExpression]
        )

        return out
    }
}
