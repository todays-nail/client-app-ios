//
//  SocialLoginUIVariant.swift
//  NailClient
//

import Foundation

enum SocialLoginUIVariant: String, Sendable {
    case circular
    case official

    init(apiValue: String?) {
        let normalized = apiValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        self = SocialLoginUIVariant(rawValue: normalized ?? "") ?? .circular
    }
}
