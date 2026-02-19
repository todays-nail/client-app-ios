//
//  AppConfig.swift
//  NailClient
//
//  Centralized access to Info.plist based configuration.
//

import Foundation

enum AppConfig {
    private static let fallbackSupportEmail = "galaxydh4110@gmail.com"

    static var kakaoNativeAppKey: String? {
        normalizedString(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY")
    }

    static var naverMapsIOSClientID: String? {
        normalizedString(forInfoDictionaryKey: "NMFNcpKeyId")
    }

    static var supportEmail: String {
        normalizedString(forInfoDictionaryKey: "SUPPORT_EMAIL") ?? fallbackSupportEmail
    }

    static var termsOfServiceURL: URL? {
        normalizedURL(forInfoDictionaryKey: "TERMS_OF_SERVICE_URL")
    }

    static var privacyPolicyURL: URL? {
        normalizedURL(forInfoDictionaryKey: "PRIVACY_POLICY_URL")
    }

    private static func normalizedString(forInfoDictionaryKey key: String) -> String? {
        let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? trimmed : nil
    }

    private static func normalizedURL(forInfoDictionaryKey key: String) -> URL? {
        guard let raw = normalizedString(forInfoDictionaryKey: key) else {
            return nil
        }
        return URL(string: raw)
    }
}
