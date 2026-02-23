//
//  AITransferConsentStore.swift
//  NailClient
//

import Foundation

struct AITransferConsentStore {
    static let shared = AITransferConsentStore()

    private let defaults: UserDefaults
    private let consentKey: String

    init(
        defaults: UserDefaults = .standard,
        consentKey: String = "ai_transfer_consent_v1"
    ) {
        self.defaults = defaults
        self.consentKey = consentKey
    }

    var hasConsent: Bool {
        defaults.bool(forKey: consentKey)
    }

    func grantConsent() {
        defaults.set(true, forKey: consentKey)
    }

    func revokeConsent() {
        defaults.removeObject(forKey: consentKey)
    }
}
