//
//  AppConfig.swift
//  NailClient
//
//  Centralized access to Info.plist based configuration.
//

import Foundation

enum AppConfig {
    static var kakaoNativeAppKey: String? {
        let raw = Bundle.main.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? trimmed : nil
    }
}

